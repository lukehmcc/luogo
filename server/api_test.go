package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

type testClient struct {
	t     *testing.T
	base  string
	token string
	user  User
}

type testEnv struct {
	t     *testing.T
	store *Store
	hub   *Hub
}

func newTestEnv(t *testing.T) *testEnv {
	t.Helper()
	store, err := NewStore("file:test-api-" + t.Name() + "-?mode=memory&cache=shared")
	if err != nil {
		t.Fatalf("store: %v", err)
	}
	t.Cleanup(func() { store.Close() })
	return &testEnv{t: t, store: store, hub: NewHub()}
}

// server spins up a new HTTP listener sharing the env's store and hub, so
// multiple simulated clients talk to the same relay.
func (e *testEnv) server() *testClient {
	e.t.Helper()
	srv := NewServer(e.store, e.hub, 500)
	ts := httptest.NewServer(srv.routes())
	e.t.Cleanup(ts.Close)
	return &testClient{t: e.t, base: ts.URL}
}

func (c *testClient) register(name string, color int64) {
	c.t.Helper()
	resp := c.do(http.MethodPost, "/api/users", map[string]any{
		"name": name, "color": color, "publicKey": "pk-" + name,
	})
	var body struct {
		User  User   `json:"user"`
		Token string `json:"token"`
	}
	mustDecode(c.t, resp, &body)
	c.token = body.Token
	c.user = body.User
}

func (c *testClient) do(method, path string, payload any) map[string]any {
	c.t.Helper()
	var rdr io.Reader
	if payload != nil {
		data, _ := json.Marshal(payload)
		rdr = bytes.NewReader(data)
	}
	req, _ := http.NewRequest(method, c.base+path, rdr)
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		c.t.Fatalf("%s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		c.t.Fatalf("decode %s %s: %v", method, path, err)
	}
	return body
}

func mustDecode(t *testing.T, v any, out any) {
	t.Helper()
	data, _ := json.Marshal(v)
	if err := json.Unmarshal(data, out); err != nil {
		t.Fatalf("decode: %v", err)
	}
}

func (c *testClient) createGroup(name string) Group {
	var g Group
	mustDecode(c.t, c.do(http.MethodPost, "/api/groups", map[string]any{"name": name}), &g)
	return g
}

func (c *testClient) dialWS() *websocket.Conn {
	c.t.Helper()
	url := "ws" + c.base[4:] + "/ws?token=" + c.token
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		c.t.Fatalf("ws dial: %v", err)
	}
	return conn
}

func (c *testClient) nextWS(t *testing.T, conn *websocket.Conn) map[string]any {
	t.Helper()
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, data, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("ws read: %v", err)
	}
	var evt map[string]any
	if err := json.Unmarshal(data, &evt); err != nil {
		t.Fatalf("ws decode: %v", err)
	}
	return evt
}

func TestFullAPIFlow(t *testing.T) {
	env := newTestEnv(t)
	c := env.server()
	c.register("Alice", 0xFF0000)
	g := c.createGroup("Trip")

	// Alice can see her group.
	resp := c.do(http.MethodGet, "/api/groups", nil)
	if len(resp["groups"].([]any)) != 1 {
		t.Fatalf("expected 1 group: %v", resp)
	}

	// Create an invite.
	inv := c.do(http.MethodPost, "/api/groups/"+g.ID+"/invites", map[string]any{})
	tok, _ := inv["inviteToken"].(string)
	if tok == "" {
		t.Fatalf("no invite token: %v", inv)
	}

	// Bob registers and joins.
	bob := env.server()
	bob.register("Bob", 0x00FF00)
	bob.do(http.MethodPost, "/api/groups/"+g.ID+"/join", map[string]any{"inviteToken": tok})

	// Bob sends a message.
	msg := bob.do(http.MethodPost, "/api/groups/"+g.ID+"/messages",
		map[string]any{"ciphertext": "encrypted-blob-1"})
	seq, _ := msg["seq"].(float64)
	if seq != 1 {
		t.Fatalf("expected seq 1, got %v", seq)
	}

	// Alice resyncs and gets it.
	resync := c.do(http.MethodGet, "/api/groups/"+g.ID+"/messages?afterSeq=0", nil)
	msgs := resync["messages"].([]any)
	if len(msgs) != 1 {
		t.Fatalf("expected 1 message: %v", resync)
	}
	first := msgs[0].(map[string]any)
	if first["ciphertext"] != "encrypted-blob-1" {
		t.Fatalf("wrong payload: %v", first)
	}

	// Second resync from cursor is empty.
	resync2 := c.do(http.MethodGet, "/api/groups/"+g.ID+"/messages?afterSeq=1", nil)
	if len(resync2["messages"].([]any)) != 0 {
		t.Fatalf("expected no messages after seq 1: %v", resync2)
	}

	// Members list includes both.
	members := c.do(http.MethodGet, "/api/groups/"+g.ID+"/members", nil)
	if len(members["members"].([]any)) != 2 {
		t.Fatalf("expected 2 members: %v", members)
	}
}

func TestReplayAndAuth(t *testing.T) {
	env := newTestEnv(t)
	c := env.server()
	c.register("Alice", 1)
	g := c.createGroup("G")

	// Unauthenticated requests are rejected.
	req, _ := http.NewRequest(http.MethodGet, c.base+"/api/groups", nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("req: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", resp.StatusCode)
	}

	// Replaying the same invite fails (single use).
	inv := c.do(http.MethodPost, "/api/groups/"+g.ID+"/invites", map[string]any{})
	tok, _ := inv["inviteToken"].(string)
	bob := env.server()
	bob.register("Bob", 2)
	bob.do(http.MethodPost, "/api/groups/"+g.ID+"/join", map[string]any{"inviteToken": tok})
	mal := env.server()
	mal.register("Mallory", 3)
	resp2 := mal.rawDo(http.MethodPost, "/api/groups/"+g.ID+"/join",
		map[string]any{"inviteToken": tok})
	if resp2 != http.StatusBadRequest {
		t.Fatalf("expected 400 on invite replay, got %d", resp2)
	}
}

// rawDo returns just the status code.
func (c *testClient) rawDo(method, path string, payload any) int {
	c.t.Helper()
	var rdr io.Reader
	if payload != nil {
		data, _ := json.Marshal(payload)
		rdr = bytes.NewReader(data)
	}
	req, _ := http.NewRequest(method, c.base+path, rdr)
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		c.t.Fatalf("rawDo %s %s: %v", method, path, err)
	}
	resp.Body.Close()
	return resp.StatusCode
}

func TestWebSocketFanout(t *testing.T) {
	env := newTestEnv(t)
	c := env.server()
	c.register("Alice", 1)
	g := c.createGroup("G")

	// Alice connects; gets hello + presence.
	conn := c.dialWS()
	defer conn.Close()
	evt := c.nextWS(t, conn)
	if evt["type"] != "hello" {
		t.Fatalf("expected hello, got %v", evt)
	}

	// Bob joins and sends a message over HTTP.
	bob := env.server()
	bob.register("Bob", 2)
	inv := c.do(http.MethodPost, "/api/groups/"+g.ID+"/invites", map[string]any{})
	tok, _ := inv["inviteToken"].(string)
	bob.do(http.MethodPost, "/api/groups/"+g.ID+"/join", map[string]any{"inviteToken": tok})

	// Alice sees the member-joined event (skip presence/hello noise).
	var memberEvt map[string]any
	for {
		evt = c.nextWS(t, conn)
		if evt["type"] == "member" {
			memberEvt = evt
			break
		}
	}
	if memberEvt["action"] != "joined" {
		t.Fatalf("expected member joined, got %v", memberEvt)
	}

	// Bob's message fans out to Alice live.
	bob.do(http.MethodPost, "/api/groups/"+g.ID+"/messages", map[string]any{"ciphertext": "live-blob"})
	evt = c.nextWS(t, conn)
	if evt["type"] != "message" || evt["ciphertext"] != "live-blob" {
		t.Fatalf("expected live message, got %v", evt)
	}
	if evt["senderId"] != bob.user.ID {
		t.Fatalf("sender mismatch: %v", evt)
	}
}

func TestNonMemberBlocked(t *testing.T) {
	env := newTestEnv(t)
	c := env.server()
	c.register("Alice", 1)
	g := c.createGroup("G")

	mallory := env.server()
	mallory.register("Mallory", 2)
	if code := mallory.rawDo(http.MethodPost, "/api/groups/"+g.ID+"/messages",
		map[string]any{"ciphertext": "sneaky"}); code != http.StatusForbidden {
		t.Fatalf("expected 403 for non-member send, got %d", code)
	}
	if code := mallory.rawDo(http.MethodGet, "/api/groups/"+g.ID+"/messages?afterSeq=0",
		nil); code != http.StatusForbidden {
		t.Fatalf("expected 403 for non-member read, got %d", code)
	}
}

func TestRateLimitMessages(t *testing.T) {
	env := newTestEnv(t)
	alice := env.server()
	alice.register("alice", 0)
	g := alice.createGroup("g")

	// The budget is messagesPerMinute per user; the next one gets a 429.
	for i := 0; i < messagesPerMinute; i++ {
		if code := alice.rawDo(http.MethodPost, "/api/groups/"+g.ID+"/messages",
			map[string]any{"ciphertext": "x"}); code != http.StatusCreated {
			t.Fatalf("message %d: expected 201, got %d", i, code)
		}
	}
	if code := alice.rawDo(http.MethodPost, "/api/groups/"+g.ID+"/messages",
		map[string]any{"ciphertext": "x"}); code != http.StatusTooManyRequests {
		t.Fatalf("expected 429, got %d", code)
	}
}

func TestRateLimitRegistration(t *testing.T) {
	env := newTestEnv(t)
	c := env.server()
	// registrationsPerIP allowed per IP; the next one gets a 429.
	for i := 0; i < registrationsPerIP; i++ {
		c.register("u", 0)
	}
	if code := c.rawDo(http.MethodPost, "/api/users",
		map[string]any{"name": "u", "color": 0, "publicKey": "pk"}); code != http.StatusTooManyRequests {
		t.Fatalf("expected 429, got %d", code)
	}
}

func TestRemoveMemberOwnerOnly(t *testing.T) {
	env := newTestEnv(t)
	alice := env.server()
	alice.register("alice", 0)
	g := alice.createGroup("g")
	inv := alice.do(http.MethodPost, "/api/groups/"+g.ID+"/invites", map[string]any{})
	tok, _ := inv["inviteToken"].(string)
	if tok == "" {
		t.Fatalf("no invite token: %v", inv)
	}

	bob := env.server()
	bob.register("bob", 0)
	bob.do(http.MethodPost, "/api/groups/"+g.ID+"/join", map[string]any{"inviteToken": tok})

	// A non-owner can't kick.
	if code := bob.rawDo(http.MethodPost,
		"/api/groups/"+g.ID+"/members/"+alice.user.ID+"/remove",
		map[string]any{}); code != http.StatusForbidden {
		t.Fatalf("non-owner kick: expected 403, got %d", code)
	}

	// The owner can't kick themselves.
	if code := alice.rawDo(http.MethodPost,
		"/api/groups/"+g.ID+"/members/"+alice.user.ID+"/remove",
		map[string]any{}); code != http.StatusBadRequest {
		t.Fatalf("self-remove: expected 400, got %d", code)
	}

	// The owner kicks Bob.
	if code := alice.rawDo(http.MethodPost,
		"/api/groups/"+g.ID+"/members/"+bob.user.ID+"/remove",
		map[string]any{}); code != http.StatusOK {
		t.Fatalf("owner kick: expected 200, got %d", code)
	}

	// Kicked user loses access immediately.
	if code := bob.rawDo(http.MethodGet, "/api/groups/"+g.ID+"/messages?afterSeq=0",
		nil); code != http.StatusForbidden {
		t.Fatalf("kicked member read: expected 403, got %d", code)
	}
	if code := bob.rawDo(http.MethodPost, "/api/groups/"+g.ID+"/messages",
		map[string]any{"ciphertext": "x"}); code != http.StatusForbidden {
		t.Fatalf("kicked member send: expected 403, got %d", code)
	}
}
