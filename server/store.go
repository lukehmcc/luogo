package main

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"time"

	_ "modernc.org/sqlite"
)

var (
	ErrNotFound      = errors.New("not found")
	ErrInviteInvalid = errors.New("invite invalid, used or expired")
)

const (
	inviteTTL = 7 * 24 * time.Hour
)

// User is a registered device identity.
type User struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Color     int64  `json:"color"`
	PublicKey string `json:"publicKey"`
	CreatedAt int64  `json:"createdAt"`
}

// Group is a routing group. The server knows membership but never sees
// message plaintext: payloads are encrypted end-to-end with a group key
// that travels only through out-of-band invites.
type Group struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	OwnerID     string `json:"ownerId"`
	CreatedAt   int64  `json:"createdAt"`
	MemberCount int    `json:"memberCount"`
}

// Message is a stored, seq-ordered encrypted payload.
type Message struct {
	GroupID    string `json:"-"`
	Seq        int64  `json:"seq"`
	Ts         int64  `json:"ts"`
	SenderID   string `json:"senderId"`
	Ciphertext string `json:"ciphertext"`
}

// Store is the SQLite persistence layer.
type Store struct {
	db *sql.DB
}

func NewStore(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(8)
	if _, err := db.Exec("PRAGMA journal_mode=WAL"); err != nil {
		return nil, err
	}
	if _, err := db.Exec("PRAGMA busy_timeout=5000"); err != nil {
		return nil, err
	}
	s := &Store{db: db}
	if err := s.migrate(); err != nil {
		db.Close()
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) migrate() error {
	_, err := s.db.Exec(`
CREATE TABLE IF NOT EXISTS users (
	id         TEXT PRIMARY KEY,
	name       TEXT NOT NULL,
	color      INTEGER NOT NULL DEFAULT 0,
	public_key TEXT NOT NULL,
	token_hash TEXT NOT NULL UNIQUE,
	created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS groups (
	id         TEXT PRIMARY KEY,
	name       TEXT NOT NULL,
	owner_id   TEXT NOT NULL,
	created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS memberships (
	group_id  TEXT NOT NULL,
	user_id   TEXT NOT NULL,
	joined_at INTEGER NOT NULL,
	PRIMARY KEY (group_id, user_id)
);
CREATE TABLE IF NOT EXISTS messages (
	group_id   TEXT NOT NULL,
	seq        INTEGER NOT NULL,
	ts         INTEGER NOT NULL,
	sender_id  TEXT NOT NULL,
	ciphertext TEXT NOT NULL,
	PRIMARY KEY (group_id, seq)
);
CREATE INDEX IF NOT EXISTS idx_messages_group ON messages(group_id, seq);
CREATE TABLE IF NOT EXISTS invites (
	token      TEXT PRIMARY KEY,
	group_id   TEXT NOT NULL,
	created_at INTEGER NOT NULL,
	expires_at INTEGER NOT NULL,
	used_at    INTEGER
);
`)
	return err
}

func newID() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}

func newToken() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

func hashToken(tok string) string {
	h := sha256.Sum256([]byte(tok))
	return hex.EncodeToString(h[:])
}

// CreateUser registers a new device identity and returns its auth token.
func (s *Store) CreateUser(name string, color int64, publicKey string) (User, string, error) {
	u := User{
		ID:        newID(),
		Name:      name,
		Color:     color,
		PublicKey: publicKey,
		CreatedAt: time.Now().UnixMilli(),
	}
	token := newToken()
	_, err := s.db.Exec(
		`INSERT INTO users(id, name, color, public_key, token_hash, created_at) VALUES(?,?,?,?,?,?)`,
		u.ID, u.Name, u.Color, u.PublicKey, hashToken(token), u.CreatedAt,
	)
	if err != nil {
		return User{}, "", err
	}
	return u, token, nil
}

// Authenticate resolves a bearer token to its user.
func (s *Store) Authenticate(token string) (User, bool, error) {
	return s.userBy("token_hash", hashToken(token))
}

func (s *Store) GetUser(id string) (User, bool, error) {
	return s.userBy("id", id)
}

func (s *Store) userBy(column, value string) (User, bool, error) {
	var u User
	err := s.db.QueryRow(
		`SELECT id, name, color, public_key, created_at FROM users WHERE `+column+` = ?`,
		value,
	).Scan(&u.ID, &u.Name, &u.Color, &u.PublicKey, &u.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, false, nil
	}
	if err != nil {
		return User{}, false, err
	}
	return u, true, nil
}

func (s *Store) UpdateUser(id, name string, color int64) error {
	_, err := s.db.Exec(`UPDATE users SET name = ?, color = ? WHERE id = ?`, name, color, id)
	return err
}

func (s *Store) CreateGroup(ownerID, name string) (Group, error) {
	g := Group{
		ID:          newID(),
		Name:        name,
		OwnerID:     ownerID,
		CreatedAt:   time.Now().UnixMilli(),
		MemberCount: 1,
	}
	tx, err := s.db.Begin()
	if err != nil {
		return Group{}, err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(
		`INSERT INTO groups(id, name, owner_id, created_at) VALUES(?,?,?,?)`,
		g.ID, g.Name, g.OwnerID, g.CreatedAt,
	); err != nil {
		return Group{}, err
	}
	if _, err := tx.Exec(
		`INSERT INTO memberships(group_id, user_id, joined_at) VALUES(?,?,?)`,
		g.ID, ownerID, time.Now().UnixMilli(),
	); err != nil {
		return Group{}, err
	}
	if err := tx.Commit(); err != nil {
		return Group{}, err
	}
	return g, nil
}

func (s *Store) GroupsForUser(userID string) ([]Group, error) {
	rows, err := s.db.Query(`
		SELECT g.id, g.name, g.owner_id, g.created_at,
		       (SELECT COUNT(*) FROM memberships m WHERE m.group_id = g.id) AS member_count
		FROM groups g
		JOIN memberships me ON me.group_id = g.id
		WHERE me.user_id = ?
		ORDER BY g.created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	groups := make([]Group, 0)
	for rows.Next() {
		var g Group
		if err := rows.Scan(&g.ID, &g.Name, &g.OwnerID, &g.CreatedAt, &g.MemberCount); err != nil {
			return nil, err
		}
		groups = append(groups, g)
	}
	return groups, rows.Err()
}

func (s *Store) GetGroup(id string) (Group, bool, error) {
	var g Group
	err := s.db.QueryRow(`
		SELECT g.id, g.name, g.owner_id, g.created_at,
		       (SELECT COUNT(*) FROM memberships m WHERE m.group_id = g.id) AS member_count
		FROM groups g WHERE g.id = ?`, id,
	).Scan(&g.ID, &g.Name, &g.OwnerID, &g.CreatedAt, &g.MemberCount)
	if errors.Is(err, sql.ErrNoRows) {
		return Group{}, false, nil
	}
	if err != nil {
		return Group{}, false, err
	}
	return g, true, nil
}

func (s *Store) IsMember(groupID, userID string) (bool, error) {
	var one int
	err := s.db.QueryRow(
		`SELECT 1 FROM memberships WHERE group_id = ? AND user_id = ?`, groupID, userID,
	).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (s *Store) AddMember(groupID, userID string) error {
	_, err := s.db.Exec(
		`INSERT OR IGNORE INTO memberships(group_id, user_id, joined_at) VALUES(?,?,?)`,
		groupID, userID, time.Now().UnixMilli(),
	)
	return err
}

func (s *Store) RemoveMember(groupID, userID string) error {
	if _, err := s.db.Exec(
		`DELETE FROM memberships WHERE group_id = ? AND user_id = ?`, groupID, userID,
	); err != nil {
		return err
	}
	// Prune groups with no remaining members.
	_, err := s.db.Exec(`
		DELETE FROM groups WHERE id = ? AND NOT EXISTS (
			SELECT 1 FROM memberships m WHERE m.group_id = groups.id
		)`, groupID)
	return err
}

func (s *Store) Members(groupID string) ([]User, error) {
	rows, err := s.db.Query(`
		SELECT u.id, u.name, u.color, u.public_key, u.created_at
		FROM users u JOIN memberships m ON m.user_id = u.id
		WHERE m.group_id = ?
		ORDER BY m.joined_at ASC`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	users := make([]User, 0)
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Name, &u.Color, &u.PublicKey, &u.CreatedAt); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	return users, rows.Err()
}

func (s *Store) RenameGroup(groupID, name string) error {
	_, err := s.db.Exec(`UPDATE groups SET name = ? WHERE id = ?`, name, groupID)
	return err
}

func (s *Store) CreateInvite(groupID string) (string, error) {
	token := newToken()
	now := time.Now()
	_, err := s.db.Exec(
		`INSERT INTO invites(token, group_id, created_at, expires_at) VALUES(?,?,?,?)`,
		token, groupID, now.UnixMilli(), now.Add(inviteTTL).UnixMilli(),
	)
	if err != nil {
		return "", err
	}
	return token, nil
}

// ConsumeInvite atomically marks a one-time invite as used. Returns the
// owning group id on success.
func (s *Store) ConsumeInvite(token string) (string, error) {
	now := time.Now().UnixMilli()
	tx, err := s.db.Begin()
	if err != nil {
		return "", err
	}
	defer tx.Rollback()
	var groupID string
	var usedAt sql.NullInt64
	err = tx.QueryRow(
		`SELECT group_id, used_at FROM invites WHERE token = ? AND expires_at > ?`,
		token, now,
	).Scan(&groupID, &usedAt)
	if errors.Is(err, sql.ErrNoRows) || usedAt.Valid {
		return "", ErrInviteInvalid
	}
	if err != nil {
		return "", err
	}
	if _, err := tx.Exec(`UPDATE invites SET used_at = ? WHERE token = ?`, now, token); err != nil {
		return "", err
	}
	if err := tx.Commit(); err != nil {
		return "", err
	}
	return groupID, nil
}

// InsertMessage persists an encrypted payload and returns it with its
// group-scoped seq. Delivery is acked only after this returns.
func (s *Store) InsertMessage(groupID, senderID, ciphertext string, maxLog int) (Message, error) {
	now := time.Now().UnixMilli()
	tx, err := s.db.Begin()
	if err != nil {
		return Message{}, err
	}
	defer tx.Rollback()

	var seq int64
	if err := tx.QueryRow(
		`SELECT COALESCE(MAX(seq), 0) + 1 FROM messages WHERE group_id = ?`, groupID,
	).Scan(&seq); err != nil {
		return Message{}, err
	}
	if _, err := tx.Exec(
		`INSERT INTO messages(group_id, seq, ts, sender_id, ciphertext) VALUES(?,?,?,?,?)`,
		groupID, seq, now, senderID, ciphertext,
	); err != nil {
		return Message{}, err
	}
	if _, err := tx.Exec(
		`DELETE FROM messages WHERE group_id = ? AND seq < ?`,
		groupID, seq-int64(maxLog)+1,
	); err != nil {
		return Message{}, err
	}
	if err := tx.Commit(); err != nil {
		return Message{}, err
	}
	return Message{GroupID: groupID, Seq: seq, Ts: now, SenderID: senderID, Ciphertext: ciphertext}, nil
}

func (s *Store) LatestSeq(groupID string) (int64, error) {
	var seq sql.NullInt64
	if err := s.db.QueryRow(
		`SELECT MAX(seq) FROM messages WHERE group_id = ?`, groupID,
	).Scan(&seq); err != nil {
		return 0, err
	}
	return seq.Int64, nil
}

func (s *Store) MessagesAfter(groupID string, afterSeq int64, limit int) ([]Message, int64, error) {
	latest, err := s.LatestSeq(groupID)
	if err != nil {
		return nil, 0, err
	}
	rows, err := s.db.Query(`
		SELECT seq, ts, sender_id, ciphertext FROM messages
		WHERE group_id = ? AND seq > ?
		ORDER BY seq ASC LIMIT ?`, groupID, afterSeq, limit)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	msgs := make([]Message, 0)
	for rows.Next() {
		var m Message
		if err := rows.Scan(&m.Seq, &m.Ts, &m.SenderID, &m.Ciphertext); err != nil {
			return nil, 0, err
		}
		m.GroupID = groupID
		msgs = append(msgs, m)
	}
	return msgs, latest, rows.Err()
}
