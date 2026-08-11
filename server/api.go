package main

import (
	"encoding/json"
	"errors"
	"log"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const maxBodyBytes = 1 << 20

// protocolVersion is the wire protocol version shared by app and relay.
// Bump it only when a change would break older clients against newer servers
// (or vice versa); clients refuse to operate against a mismatched relay.
const protocolVersion = 1

// Rate limit budgets. Generous enough for the app's real traffic (a 1-min
// foreground ping per group, a ~15-min background fetch, a 5s member poll
// while the sheet is open) while still bounding abuse.
const (
	messagesPerMinute  = 60
	groupsPerMinute    = 30
	invitesPerMinute   = 10
	readsPerMinute     = 120
	registrationsPerIP = 10 // per hour
)

// rateLimiter is a minimal sliding-window counter, safe for concurrent use.
// Entries are pruned lazily once the map grows past a threshold.
type rateLimiter struct {
	mu     sync.Mutex
	limit  int
	window time.Duration
	usage  map[string]*windowState
}

type windowState struct {
	start time.Time
	count int
}

func newRateLimiter(limit int, window time.Duration) *rateLimiter {
	return &rateLimiter{
		limit:  limit,
		window: window,
		usage:  make(map[string]*windowState),
	}
}

func (rl *rateLimiter) allow(key string, now time.Time) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	st := rl.usage[key]
	if st == nil || now.Sub(st.start) >= rl.window {
		st = &windowState{start: now}
		rl.usage[key] = st
	}
	st.count++
	if len(rl.usage) > 4096 {
		rl.prune(now)
	}
	return st.count <= rl.limit
}

func (rl *rateLimiter) prune(now time.Time) {
	for key, st := range rl.usage {
		if now.Sub(st.start) >= rl.window {
			delete(rl.usage, key)
		}
	}
}

type Server struct {
	store  *Store
	hub    *Hub
	ws     *websocket.Upgrader
	maxLog int

	msgLimiter    *rateLimiter // POST /messages per user
	groupLimiter  *rateLimiter // POST /groups per user
	inviteLimiter *rateLimiter // POST /invites per user
	readLimiter   *rateLimiter // GETs per user
	ipLimiter     *rateLimiter // per-IP budget (registration)
}

func NewServer(store *Store, hub *Hub, maxLog int) *Server {
	return &Server{
		store:  store,
		hub:    hub,
		maxLog: maxLog,
		ws: &websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
			CheckOrigin:     func(*http.Request) bool { return true },
		},
		msgLimiter:    newRateLimiter(messagesPerMinute, time.Minute),
		groupLimiter:  newRateLimiter(groupsPerMinute, time.Minute),
		inviteLimiter: newRateLimiter(invitesPerMinute, time.Minute),
		readLimiter:   newRateLimiter(readsPerMinute, time.Minute),
		ipLimiter:     newRateLimiter(registrationsPerIP, time.Hour),
	}
}

func (s *Server) routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /", s.handleRoot)

	mux.HandleFunc("GET /api/health", s.handleHealth)

	mux.HandleFunc("POST /api/users", s.handleCreateUser)
	mux.HandleFunc("PATCH /api/users/me", s.withAuth(s.handleUpdateUser))

	mux.HandleFunc("GET /api/groups", s.withAuth(s.handleListGroups))
	mux.HandleFunc("POST /api/groups", s.withAuth(s.handleCreateGroup))
	mux.HandleFunc("GET /api/groups/{id}", s.withAuth(s.handleGetGroup))
	mux.HandleFunc("PATCH /api/groups/{id}", s.withAuth(s.handleRenameGroup))
	mux.HandleFunc("POST /api/groups/{id}/leave", s.withAuth(s.handleLeaveGroup))
	mux.HandleFunc("POST /api/groups/{id}/members/{userId}/remove", s.withAuth(s.handleRemoveMember))
	mux.HandleFunc("POST /api/groups/{id}/invites", s.withAuth(s.handleCreateInvite))
	mux.HandleFunc("POST /api/groups/{id}/join", s.withAuth(s.handleJoinGroup))
	mux.HandleFunc("GET /api/groups/{id}/members", s.withAuth(s.handleListMembers))
	mux.HandleFunc("GET /api/groups/{id}/messages", s.withAuth(s.handleGetMessages))
	mux.HandleFunc("POST /api/groups/{id}/messages", s.withAuth(s.handleSendMessage))

	mux.HandleFunc("GET /ws", s.handleWebSocket)

	return s.cors(mux)
}

func (s *Server) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// --- helpers ------------------------------------------------------------

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// rateLimit enforces a limiter budget for key. Returns false (after writing
// a 429) when the budget is exhausted.
func rateLimit(w http.ResponseWriter, rl *rateLimiter, key string) bool {
	if rl.allow(key, time.Now()) {
		return true
	}
	w.Header().Set("Retry-After", strconv.Itoa(int(rl.window.Seconds())))
	writeErr(w, http.StatusTooManyRequests, "rate limit exceeded, slow down")
	return false
}

// clientIP extracts the caller's IP from RemoteAddr. The relay is meant to
// be deployed behind TLS directly or a trusted proxy; proxy header handling
// can be added when there is a deployment that needs it.
func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func readJSON(r *http.Request, v any) error {
	r.Body = http.MaxBytesReader(nil, r.Body, maxBodyBytes)
	defer r.Body.Close()
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	return dec.Decode(v)
}

type authedHandler func(http.ResponseWriter, *http.Request, User)

// withAuth resolves the bearer token and injects the user.
func (s *Server) withAuth(next authedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, ok := bearerToken(r)
		if !ok {
			writeErr(w, http.StatusUnauthorized, "missing bearer token")
			return
		}
		user, ok, err := s.store.Authenticate(token)
		if err != nil {
			log.Printf("auth error: %v", err)
			writeErr(w, http.StatusInternalServerError, "auth error")
			return
		}
		if !ok {
			writeErr(w, http.StatusUnauthorized, "invalid token")
			return
		}
		next(w, r, user)
	}
}

func bearerToken(r *http.Request) (string, bool) {
	auth := r.Header.Get("Authorization")
	if strings.HasPrefix(auth, "Bearer ") && len(auth) > 7 {
		return strings.TrimSpace(auth[7:]), true
	}
	return "", false
}

// requireMember fetches the group and checks membership.
func (s *Server) requireMember(w http.ResponseWriter, groupID string, user User) (Group, bool) {
	group, ok, err := s.store.GetGroup(groupID)
	if err != nil {
		log.Printf("group lookup error: %v", err)
		writeErr(w, http.StatusInternalServerError, "group lookup error")
		return Group{}, false
	}
	if !ok {
		writeErr(w, http.StatusNotFound, "group not found")
		return Group{}, false
	}
	member, err := s.store.IsMember(groupID, user.ID)
	if err != nil {
		log.Printf("membership error: %v", err)
		writeErr(w, http.StatusInternalServerError, "membership error")
		return Group{}, false
	}
	if !member {
		writeErr(w, http.StatusForbidden, "not a group member")
		return Group{}, false
	}
	return group, true
}

// --- handlers -----------------------------------------------------------

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "protocolVersion": protocolVersion})
}

func (s *Server) handleRoot(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, "Hello from luogo-relay :)")
}

type createUserReq struct {
	Name      string `json:"name"`
	Color     int64  `json:"color"`
	PublicKey string `json:"publicKey"`
}

func (s *Server) handleCreateUser(w http.ResponseWriter, r *http.Request) {
	if !rateLimit(w, s.ipLimiter, clientIP(r)) {
		return
	}
	var req createUserReq
	if err := readJSON(r, &req); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.PublicKey == "" {
		writeErr(w, http.StatusBadRequest, "publicKey is required")
		return
	}
	user, token, err := s.store.CreateUser(req.Name, req.Color, req.PublicKey)
	if err != nil {
		log.Printf("create user error: %v", err)
		writeErr(w, http.StatusInternalServerError, "create user error")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"user": user, "token": token})
}

type updateUserReq struct {
	Name  *string `json:"name"`
	Color *int64  `json:"color"`
}

func (s *Server) handleUpdateUser(w http.ResponseWriter, r *http.Request, user User) {
	var req updateUserReq
	if err := readJSON(r, &req); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Name != nil {
		user.Name = *req.Name
	}
	if req.Color != nil {
		user.Color = *req.Color
	}
	if err := s.store.UpdateUser(user.ID, user.Name, user.Color); err != nil {
		log.Printf("update user error: %v", err)
		writeErr(w, http.StatusInternalServerError, "update user error")
		return
	}
	writeJSON(w, http.StatusOK, user)
}

type createGroupReq struct {
	Name string `json:"name"`
}

func (s *Server) handleCreateGroup(w http.ResponseWriter, r *http.Request, user User) {
	if !rateLimit(w, s.groupLimiter, user.ID) {
		return
	}
	var req createGroupReq
	if err := readJSON(r, &req); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	group, err := s.store.CreateGroup(user.ID, req.Name)
	if err != nil {
		log.Printf("create group error: %v", err)
		writeErr(w, http.StatusInternalServerError, "create group error")
		return
	}
	writeJSON(w, http.StatusCreated, group)
}

func (s *Server) handleListGroups(w http.ResponseWriter, r *http.Request, user User) {
	groups, err := s.store.GroupsForUser(user.ID)
	if err != nil {
		log.Printf("list groups error: %v", err)
		writeErr(w, http.StatusInternalServerError, "list groups error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"groups": groups})
}

func (s *Server) handleGetGroup(w http.ResponseWriter, r *http.Request, user User) {
	group, ok := s.requireMember(w, r.PathValue("id"), user)
	if !ok {
		return
	}
	writeJSON(w, http.StatusOK, group)
}

type renameGroupReq struct {
	Name string `json:"name"`
}

func (s *Server) handleRenameGroup(w http.ResponseWriter, r *http.Request, user User) {
	group, ok := s.requireMember(w, r.PathValue("id"), user)
	if !ok {
		return
	}
	var req renameGroupReq
	if err := readJSON(r, &req); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Name == "" {
		writeErr(w, http.StatusBadRequest, "name is required")
		return
	}
	if err := s.store.RenameGroup(group.ID, req.Name); err != nil {
		log.Printf("rename group error: %v", err)
		writeErr(w, http.StatusInternalServerError, "rename group error")
		return
	}
	group.Name = req.Name
	s.hub.broadcast(group.ID, map[string]any{
		"type": "member", "groupId": group.ID, "action": "renamed",
		"userId": user.ID, "name": req.Name,
	})
	writeJSON(w, http.StatusOK, group)
}

func (s *Server) handleLeaveGroup(w http.ResponseWriter, r *http.Request, user User) {
	group, ok := s.requireMember(w, r.PathValue("id"), user)
	if !ok {
		return
	}
	if err := s.store.RemoveMember(group.ID, user.ID); err != nil {
		log.Printf("leave group error: %v", err)
		writeErr(w, http.StatusInternalServerError, "leave group error")
		return
	}
	s.hub.broadcast(group.ID, map[string]any{
		"type": "member", "groupId": group.ID, "action": "left", "userId": user.ID,
	})
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleRemoveMember(w http.ResponseWriter, r *http.Request, user User) {
	group, ok := s.requireMember(w, r.PathValue("id"), user)
	if !ok {
		return
	}
	targetID := r.PathValue("userId")
	if targetID == user.ID {
		writeErr(w, http.StatusBadRequest, "cannot remove yourself, use leave instead")
		return
	}
	if group.OwnerID != user.ID {
		writeErr(w, http.StatusForbidden, "only the group owner can remove members")
		return
	}
	if !rateLimit(w, s.groupLimiter, user.ID) {
		return
	}
	if err := s.store.RemoveMember(group.ID, targetID); err != nil {
		log.Printf("remove member error: %v", err)
		writeErr(w, http.StatusInternalServerError, "remove member error")
		return
	}
	s.hub.broadcast(group.ID, map[string]any{
		"type": "member", "groupId": group.ID, "action": "left", "userId": targetID,
	})
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleCreateInvite(w http.ResponseWriter, r *http.Request, user User) {
	if !rateLimit(w, s.inviteLimiter, user.ID) {
		return
	}
	group, ok := s.requireMember(w, r.PathValue("id"), user)
	if !ok {
		return
	}
	token, err := s.store.CreateInvite(group.ID)
	if err != nil {
		log.Printf("create invite error: %v", err)
		writeErr(w, http.StatusInternalServerError, "create invite error")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"inviteToken": token, "groupId": group.ID})
}

type joinGroupReq struct {
	InviteToken string `json:"inviteToken"`
}

func (s *Server) handleJoinGroup(w http.ResponseWriter, r *http.Request, user User) {
	groupID := r.PathValue("id")
	var req joinGroupReq
	if err := readJSON(r, &req); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.InviteToken == "" {
		writeErr(w, http.StatusBadRequest, "inviteToken is required")
		return
	}
	invitedGroup, err := s.store.ConsumeInvite(req.InviteToken)
	if errors.Is(err, ErrInviteInvalid) {
		writeErr(w, http.StatusBadRequest, "invalid or expired invite")
		return
	}
	if err != nil {
		log.Printf("consume invite error: %v", err)
		writeErr(w, http.StatusInternalServerError, "consume invite error")
		return
	}
	if invitedGroup != groupID {
		writeErr(w, http.StatusBadRequest, "invite does not belong to this group")
		return
	}
	if err := s.store.AddMember(groupID, user.ID); err != nil {
		log.Printf("join group error: %v", err)
		writeErr(w, http.StatusInternalServerError, "join group error")
		return
	}
	group, _, _ := s.store.GetGroup(groupID)
	s.hub.broadcast(groupID, map[string]any{
		"type": "member", "groupId": groupID, "action": "joined", "userId": user.ID,
	})
	writeJSON(w, http.StatusOK, group)
}

func (s *Server) handleListMembers(w http.ResponseWriter, r *http.Request, user User) {
	if !rateLimit(w, s.readLimiter, user.ID) {
		return
	}
	if _, ok := s.requireMember(w, r.PathValue("id"), user); !ok {
		return
	}
	members, err := s.store.Members(r.PathValue("id"))
	if err != nil {
		log.Printf("list members error: %v", err)
		writeErr(w, http.StatusInternalServerError, "list members error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"members": members})
}

func (s *Server) handleGetMessages(w http.ResponseWriter, r *http.Request, user User) {
	if !rateLimit(w, s.readLimiter, user.ID) {
		return
	}
	group, ok := s.requireMember(w, r.PathValue("id"), user)
	if !ok {
		return
	}
	afterSeq := int64(0)
	if raw := r.URL.Query().Get("afterSeq"); raw != "" {
		n, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || n < 0 {
			writeErr(w, http.StatusBadRequest, "invalid afterSeq")
			return
		}
		afterSeq = n
	}
	limit := 500
	if raw := r.URL.Query().Get("limit"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 {
			writeErr(w, http.StatusBadRequest, "invalid limit")
			return
		}
		if n > 1000 {
			n = 1000
		}
		limit = n
	}
	msgs, latest, err := s.store.MessagesAfter(group.ID, afterSeq, limit)
	if err != nil {
		log.Printf("get messages error: %v", err)
		writeErr(w, http.StatusInternalServerError, "get messages error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"messages": msgs, "latestSeq": latest})
}

type sendMessageReq struct {
	Ciphertext string `json:"ciphertext"`
}

func (s *Server) handleSendMessage(w http.ResponseWriter, r *http.Request, user User) {
	if !rateLimit(w, s.msgLimiter, user.ID) {
		return
	}
	group, ok := s.requireMember(w, r.PathValue("id"), user)
	if !ok {
		return
	}
	var req sendMessageReq
	if err := readJSON(r, &req); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Ciphertext == "" {
		writeErr(w, http.StatusBadRequest, "ciphertext is required")
		return
	}
	msg, err := s.store.InsertMessage(group.ID, user.ID, req.Ciphertext, s.maxLog)
	if err != nil {
		log.Printf("insert message error: %v", err)
		writeErr(w, http.StatusInternalServerError, "insert message error")
		return
	}
	// Only acked to the sender after persistence, then fanned out live.
	s.hub.broadcast(group.ID, map[string]any{
		"type": "message", "groupId": group.ID, "seq": msg.Seq, "ts": msg.Ts,
		"senderId": msg.SenderID, "ciphertext": msg.Ciphertext,
	})
	writeJSON(w, http.StatusCreated, msg)
}

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	token, ok := bearerToken(r)
	if !ok {
		token = r.URL.Query().Get("token")
	}
	if token == "" {
		writeErr(w, http.StatusUnauthorized, "missing token")
		return
	}
	user, ok, err := s.store.Authenticate(token)
	if err != nil {
		log.Printf("ws auth error: %v", err)
		writeErr(w, http.StatusInternalServerError, "ws auth error")
		return
	}
	if !ok {
		writeErr(w, http.StatusUnauthorized, "invalid token")
		return
	}
	conn, err := s.ws.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("ws upgrade error: %v", err)
		return
	}
	groups, err := s.store.GroupsForUser(user.ID)
	if err != nil {
		log.Printf("ws groups error: %v", err)
		conn.Close()
		return
	}
	groupIDs := make([]string, 0, len(groups))
	for _, g := range groups {
		groupIDs = append(groupIDs, g.ID)
	}
	c := &Client{hub: s.hub, conn: conn, userID: user.ID, groupIDs: groupIDs, send: make(chan []byte, sendBufferSize)}
	s.hub.register(c, groupIDs)

	hello, _ := json.Marshal(map[string]any{"type": "hello", "userId": user.ID, "protocolVersion": protocolVersion})
	select {
	case c.send <- hello:
	default:
	}
	for _, g := range groups {
		c.send <- mustMarshal(map[string]any{
			"type": "presence", "groupId": g.ID, "online": s.hub.onlineFor(g.ID),
		})
	}
	go c.writePump()
	c.readPump()
}

func mustMarshal(v any) []byte {
	data, err := json.Marshal(v)
	if err != nil {
		return []byte(`{}`)
	}
	return data
}
