# Luogo Relay

A single-binary Go relay server for [Luogo](https://github.com/lukehmcc/luogo). It
replaces the S5 network as the transport: the app and relay speak HTTPS/JSON and
WebSocket, and all location payloads are encrypted end-to-end on the device with
a per-group key that is shared only through out-of-band invite QRs — **the relay
never sees message plaintext**.

The relay only handles routing and authentication: who is in which group, live
fan-out to connected members, and a bounded per-group message log (default last
500) so clients can resync everything they missed whenever they wake up or
reconnect.

## Build

Requires Go 1.26+.

```bash
go build -o luogo-relay .
```

This produces one static binary. There is also a `Dockerfile`:

```bash
docker build -t luogo-relay .
docker run -p 8080:8080 -v relay-data:/data luogo-relay -db /data/luogo-relay.db
```

### Docker Compose

Prebuilt images are published to GHCR on every `v*` tag. Create a `docker-compose.yml`:

```yaml
services:
  luogo-relay:
    image: ghcr.io/lukehmcc/luogo-relay:latest
    container_name: luogo-relay
    restart: unless-stopped
    ports:
      - "8040:8040"
    volumes:
      - ./data:/data
```

```bash
docker compose up -d
```

The container working directory is `/`, so the default `-db ./data/luogo-relay.db`
resolves to `/data/luogo-relay.db`, which lands on the mounted volume. If you don't
mount a volume (or point `-db` elsewhere), the database lives in the container's
ephemeral layer and is destroyed the next time the container is recreated.

To update to the latest release:

```bash
docker compose pull && docker compose up -d
```

This example serves plain HTTP, which is fine for localhost development. For production, expose TLS via Caddy/nginx in front of the container, or pass `-tls-cert` and `-tls-key` (see [Flags](#flags)) and map port `8443`.

## Run

```bash
# Plain HTTP (dev only)
./luogo-relay -addr :8080

# HTTPS (production) — or run behind Caddy/nginx for automatic Let's Encrypt
./luogo-relay -addr :8443 -tls-cert /etc/certs/fullchain.pem -tls-key /etc/certs/privkey.pem
```

### Flags

| Flag | Default | Description |
| --- | --- | --- |
| `-addr` | `:8080` | listen address |
| `-db` | `./data/luogo-relay.db` | SQLite database path (WAL mode; parent dir is created if missing) |
| `-max-log` | `500` | messages retained per group |
| `-tls-cert` / `-tls-key` | — | enable HTTPS (both required) |

## API

All endpoints (except `/api/health` and `POST /api/users`) require
`Authorization: Bearer <token>`.

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/api/health` | liveness check (`{"ok":true}`) |
| `POST` | `/api/users` | register `{name, color, publicKey}` → `{user, token}` |
| `PATCH` | `/api/users/me` | update `{name?, color?}` |
| `GET` | `/api/groups` | list my groups |
| `POST` | `/api/groups` | create `{name}` |
| `GET` | `/api/groups/{id}` | group info (members only) |
| `PATCH` | `/api/groups/{id}` | rename `{name}` (members only) |
| `POST` | `/api/groups/{id}/leave` | leave the group |
| `POST` | `/api/groups/{id}/invites` | issue a one-time invite token |
| `POST` | `/api/groups/{id}/join` | join with `{inviteToken}` (single use, 7d expiry) |
| `GET` | `/api/groups/{id}/members` | member list with names/colors |
| `GET` | `/api/groups/{id}/messages?afterSeq=N` | resync from a cursor |
| `POST` | `/api/groups/{id}/messages` | publish `{ciphertext}`; acked with `{seq}` only after persistence |
| `GET` | `/ws?token=...` | live push (also accepts the `Authorization` header) |

### WebSocket events (server → client)

- `{"type":"hello","userId":...}` — sent on connect
- `{"type":"message","groupId","seq","ts","senderId","ciphertext"}` — live message
- `{"type":"member","groupId","action":"joined|left|renamed","userId","name"?}` — membership change
- `{"type":"presence","groupId","online":[...],"offline"?}` — connected members

Clients reconnect with `GET /messages?afterSeq=<lastSeq>` to fill any gap.

## Invite payload (client-defined)

The server issues only the one-time `inviteToken`. The client wraps it with the
group encryption key that the server never sees:

```
luogo-invite-key: v1:<groupId>:<inviteToken>:<base64url(groupKey)>
```

## Test

```bash
go test ./...
```

Covers the store (users, groups, invites, seq ordering, pruning, resync) and the
full HTTP + WebSocket flow (auth, membership enforcement, single-use invites,
live fan-out).
