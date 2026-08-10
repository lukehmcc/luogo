package main

import (
	"testing"
)

func newTestStore(t *testing.T) *Store {
	t.Helper()
	s, err := NewStore("file:test-" + t.Name() + "-?mode=memory&cache=shared")
	if err != nil {
		t.Fatalf("store: %v", err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

func TestUserLifecycle(t *testing.T) {
	s := newTestStore(t)

	u, token, err := s.CreateUser("Alice", 0xFF00FF, "pk-alice")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if u.ID == "" || token == "" {
		t.Fatal("expected id and token")
	}

	got, ok, err := s.Authenticate(token)
	if err != nil || !ok {
		t.Fatalf("authenticate: ok=%v err=%v", ok, err)
	}
	if got.ID != u.ID || got.Name != "Alice" {
		t.Fatalf("mismatch: %+v", got)
	}

	if _, ok, _ := s.Authenticate("bogus"); ok {
		t.Fatal("bogus token authenticated")
	}
}

func TestGroupLifecycle(t *testing.T) {
	s := newTestStore(t)
	alice, _, _ := s.CreateUser("Alice", 1, "pk-a")
	bob, _, _ := s.CreateUser("Bob", 2, "pk-b")

	g, err := s.CreateGroup(alice.ID, "Camping")
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	if g.MemberCount != 1 {
		t.Fatalf("expected 1 member, got %d", g.MemberCount)
	}

	member, _ := s.IsMember(g.ID, alice.ID)
	if !member {
		t.Fatal("owner should be a member")
	}

	if err := s.AddMember(g.ID, bob.ID); err != nil {
		t.Fatalf("add member: %v", err)
	}
	members, err := s.Members(g.ID)
	if err != nil {
		t.Fatalf("members: %v", err)
	}
	if len(members) != 2 {
		t.Fatalf("expected 2 members, got %d", len(members))
	}

	groups, err := s.GroupsForUser(bob.ID)
	if err != nil || len(groups) != 1 || groups[0].ID != g.ID {
		t.Fatalf("groups for bob: %+v err=%v", groups, err)
	}

	if err := s.RenameGroup(g.ID, "Camping Trip"); err != nil {
		t.Fatalf("rename: %v", err)
	}
	got, ok, _ := s.GetGroup(g.ID)
	if !ok || got.Name != "Camping Trip" {
		t.Fatalf("rename not persisted: %+v", got)
	}

	if err := s.RemoveMember(g.ID, bob.ID); err != nil {
		t.Fatalf("remove: %v", err)
	}
	if m, _ := s.IsMember(g.ID, bob.ID); m {
		t.Fatal("bob should be removed")
	}
	if err := s.RemoveMember(g.ID, alice.ID); err != nil {
		t.Fatalf("remove owner: %v", err)
	}
	if _, ok, _ := s.GetGroup(g.ID); ok {
		t.Fatal("empty group should be pruned")
	}
}

func TestInviteSingleUse(t *testing.T) {
	s := newTestStore(t)
	alice, _, _ := s.CreateUser("Alice", 1, "pk-a")
	bob, _, _ := s.CreateUser("Bob", 2, "pk-b")
	g, _ := s.CreateGroup(alice.ID, "G")

	tok, err := s.CreateInvite(g.ID)
	if err != nil {
		t.Fatalf("invite: %v", err)
	}

	groupID, err := s.ConsumeInvite(tok)
	if err != nil || groupID != g.ID {
		t.Fatalf("consume: %v", err)
	}
	if _, err := s.ConsumeInvite(tok); err == nil {
		t.Fatal("invite should be single-use")
	}
	if _, err := s.ConsumeInvite("nope"); err == nil {
		t.Fatal("bogus invite should fail")
	}

	// Bob joins via the consumed invite.
	_ = s.AddMember(g.ID, bob.ID)
	groups, _ := s.GroupsForUser(bob.ID)
	if len(groups) != 1 {
		t.Fatalf("bob not in group: %+v", groups)
	}
}

func TestMessagesSeqAndPruning(t *testing.T) {
	s := newTestStore(t)
	alice, _, _ := s.CreateUser("Alice", 1, "pk-a")
	g, _ := s.CreateGroup(alice.ID, "G")

	last := int64(0)
	for i := 0; i < 10; i++ {
		msg, err := s.InsertMessage(g.ID, alice.ID, "ct-"+string(rune('a'+i)), 5)
		if err != nil {
			t.Fatalf("insert: %v", err)
		}
		if msg.Seq != int64(i+1) {
			t.Fatalf("expected seq %d, got %d", i+1, msg.Seq)
		}
		last = msg.Seq
	}

	msgs, latest, err := s.MessagesAfter(g.ID, 0, 1000)
	if err != nil {
		t.Fatalf("after: %v", err)
	}
	if latest != last {
		t.Fatalf("latest: got %d want %d", latest, last)
	}
	if len(msgs) != 5 {
		t.Fatalf("expected pruning to 5 messages, got %d", len(msgs))
	}
	if msgs[0].Seq != 6 || msgs[len(msgs)-1].Seq != 10 {
		t.Fatalf("unexpected seq range: %d..%d", msgs[0].Seq, msgs[len(msgs)-1].Seq)
	}

	// Resync from a cursor works.
	resync, _, err := s.MessagesAfter(g.ID, 8, 1000)
	if err != nil || len(resync) != 2 {
		t.Fatalf("resync: %+v err=%v", resync, err)
	}
}
