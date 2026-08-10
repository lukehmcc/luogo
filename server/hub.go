package main

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 54 * time.Second
	maxMessageSize = 1 << 20
	sendBufferSize = 256
)

// Hub tracks live WebSocket connections per user and per group so messages
// can be fanned out only to current group members.
type Hub struct {
	mu         sync.Mutex
	conns      map[string]*Client             // by userID
	groupUsers map[string]map[string]struct{} // groupID -> set of userIDs
}

func NewHub() *Hub {
	return &Hub{
		conns:      make(map[string]*Client),
		groupUsers: make(map[string]map[string]struct{}),
	}
}

func (h *Hub) register(c *Client, groupIDs []string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.conns[c.userID] = c
	for _, g := range groupIDs {
		if h.groupUsers[g] == nil {
			h.groupUsers[g] = make(map[string]struct{})
		}
		h.groupUsers[g][c.userID] = struct{}{}
	}
}

func (h *Hub) unregister(c *Client) {
	h.mu.Lock()
	conn, ok := h.conns[c.userID]
	if ok && conn == c {
		delete(h.conns, c.userID)
	}
	for _, groupID := range c.groupIDs {
		if users := h.groupUsers[groupID]; users != nil {
			delete(users, c.userID)
			if len(users) == 0 {
				delete(h.groupUsers, groupID)
			}
		}
	}
	groups := c.groupIDs
	userID := c.userID
	h.mu.Unlock()

	// Announce the departure to remaining members.
	for _, g := range groups {
		h.broadcast(g, map[string]any{"type": "presence", "groupId": g, "online": h.onlineFor(g), "offline": userID})
	}
	close(c.send)
}

// onlineFor returns the connected user ids of a group (caller holds no lock).
func (h *Hub) onlineFor(groupID string) []string {
	h.mu.Lock()
	defer h.mu.Unlock()
	var ids []string
	for id := range h.groupUsers[groupID] {
		ids = append(ids, id)
	}
	return ids
}

// broadcast sends a payload to all connected members of a group.
func (h *Hub) broadcast(groupID string, payload any) {
	data, err := json.Marshal(payload)
	if err != nil {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	for userID := range h.groupUsers[groupID] {
		if c := h.conns[userID]; c != nil {
			select {
			case c.send <- data:
			default: // slow client; drop rather than block the hub
			}
		}
	}
}

// Client is a single authenticated WebSocket connection.
type Client struct {
	hub      *Hub
	conn     *websocket.Conn
	userID   string
	groupIDs []string
	send     chan []byte
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister(c)
		c.conn.Close()
	}()
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(pongWait))
	})
	for {
		// Client->server frames are ignored for now; this loop keeps
		// control frames (pong/close) processed.
		if _, _, err := c.conn.ReadMessage(); err != nil {
			return
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case data, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, data); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
