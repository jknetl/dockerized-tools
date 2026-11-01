# Immich

Self-hosted photo & video library ([immich.app](https://immich.app)), replacing Nextcloud for photos.
Multi-user: every user has a private library; sharing is explicit (albums, partner sharing, share links).

## Architecture

| Service | Container | Networks | Purpose |
|---|---|---|---|
| `immich-server` | `immich_server` | `backend`, `default`, `ingress` | Web UI + API on port 2283, jobs, transcoding (Intel QuickSync) |
| `immich-machine-learning` | `immich_machine_learning` | `default` | Face recognition, smart search (CPU) |
| `redis` | `immich_redis` | `backend` | Job queue (valkey) |
| `database` | `immich_postgres` | `backend` | Postgres with vector extensions |

Security measures:
- **No host ports are published.** The only entry point is `immich_server:2283` on the shared `ingress`
  network, i.e. through nginx-proxy-manager.
- `backend` is an `internal` network: postgres and redis have no internet access and are not reachable
  from other stacks.
- All containers run as non-root (`IMMICH_UID:IMMICH_GID`, default `1000:1000`) with
  `no-new-privileges` and `NET_RAW` dropped (based on upstream `docker-compose.rootless.yml`).
- DB password is a docker secret file (`db_password.secrets`, gitignored), not an env variable.
- Images pinned to an exact release (`IMMICH_VERSION`) and digests for postgres/valkey.
- CPU/memory limits on every service.

## Storage

Next to Nextcloud (`/home/docker/nextcloud`), everything lives in `STORAGE_DIR=/home/docker/immich`:

```
/home/docker/immich/
├── library/      # originals, thumbnails, encoded video, automatic DB dumps (library/backups)
├── postgres/     # database files - must stay on local disk (network shares unsupported)
├── model-cache/  # downloaded ML models (re-downloadable)
└── redis/        # job queue state (disposable)
```

All directories must be owned by `IMMICH_UID:IMMICH_GID`.

## Installation

1. Create storage directories:
   ```sh
   sudo mkdir -p /home/docker/immich/{library,postgres,model-cache,redis}
   sudo chown -R 1000:1000 /home/docker/immich
   sudo chmod 750 /home/docker/immich
   ```
2. Create the DB password secret (alphanumeric only - Immich requirement):
   ```sh
   (umask 077; openssl rand -hex 32 | tr -d '\n' > db_password.secrets)
   ```
   The file must be readable by UID 1000 (the containers' user).
3. Start the stack and wait until all containers are `healthy`:
   ```sh
   docker compose up -d
   docker compose ps
   ```
4. Check it is reachable on the ingress network (expect `{"res":"pong"}`):
   ```sh
   docker run --rm --network ingress curlimages/curl -s http://immich_server:2283/api/server/ping
   ```

## Reverse proxy (nginx-proxy-manager)

Add a Proxy Host:
- Domain: `photos.knetl.net`
- Forward: `http` / `immich_server` / `2283`
- Enable: **Websockets Support**, **Block Common Exploits**
- SSL: Let's Encrypt certificate, **Force SSL**, **HTTP/2**, **HSTS**
- Advanced (large uploads, long requests):
  ```nginx
  client_max_body_size 50000M;
  proxy_read_timeout 600s;
  proxy_send_timeout 600s;
  send_timeout 600s;
  ```
- **While testing: attach an Access List that allows only the LAN** (e.g. `192.168.2.0/24`) and
  deny all. Remove it only when going public (see checklist below).

## First run & users

1. **Immediately** after the first start open the web UI: the first account registered becomes admin.
   Use a strong, unique password.
2. Administration → Settings → Server → External domain: `https://photos.knetl.net`
   (used in share links).
3. Administration → Users → Create user for each person. There is no public self-registration.
   Set a storage quota per user as needed. Users log in on the mobile app with the server URL
   `https://photos.knetl.net`.
4. Administration → Settings → Video Transcoding → Hardware Acceleration → **Quick Sync**.

## Checklist before exposing to the internet

- [ ] Admin and all users have strong passwords
- [ ] Review Administration → Settings for public share links (consider expiry / passwords on links)
- [ ] Running the latest patched release
- [ ] NPM: Force SSL + HSTS on, access list removed only now
- [ ] `ss -ltnp | grep 2283` shows nothing (no host port)
- [ ] Optional: OAuth/OIDC login (Administration → Settings → Authentication), e.g. with keycloak
- [ ] Optional: fail2ban on NPM access logs for `/api/auth/login`

## Backups

Immich writes daily DB dumps to `library/backups` (Administration → Settings → Backup).
Back up the whole `/home/docker/immich/library` directory - it contains originals *and* those dumps.
`postgres/`, `model-cache/` and `redis/` do not need to be backed up separately.
Restore procedure: https://docs.immich.app/administration/backup-and-restore

## Upgrade

1. Read the release notes: https://github.com/immich-app/immich/releases
2. Compare with upstream `docker-compose.rootless.yml` / `example.env` of the new release
   (postgres/valkey digests may change).
3. Bump `IMMICH_VERSION` in `.env`, then:
   ```sh
   docker compose pull && docker compose up -d
   ```
