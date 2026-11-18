# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of Docker Compose stacks for self-hosted services. There is no build, lint or test step: each directory is an independent stack, managed with `docker compose` from inside that directory.

- `avo/` holds the production stacks running on the home server ("avo"): nginx-proxy-manager, nextcloud, gitea, couchdb, wordpress-penta, unifi, portainer, netboot-pxe.
- `db/`, `keycloak/` and `wordpress/` are older local/dev stacks with hardcoded throwaway credentials. They use a shared external `databases` network (`docker network create databases`).

## Common commands

Run these from the stack's directory:

```bash
docker compose config          # validate the file and see the resolved .env / env_file values
docker compose pull && docker compose up -d   # apply an image upgrade
docker compose logs -f <service>
```

## How the `avo/` stacks fit together

- **Shared `ingress` network:** nginx-proxy-manager (`avo/nginx-proxy-manager`) is the only stack publishing 80/443, bound to the host IP `192.168.2.9`. Every web app joins the external `ingress` network, and NPM reaches it there by container/service name. Some stacks use `ingress` as their default network and others add it next to a private `default` network, so only the frontend service is exposed. The `ingress` network must exist before these stacks start.
- **Don't publish ports for proxied apps:** apps behind NPM should not publish host ports. A recent security fix removed published ports from nextcloud and wordpress-penta for this reason. Ports are published only where NPM can't proxy the traffic (gitea SSH `2222`, unifi device ports, couchdb, portainer).
- **Persistent data:** data is bind-mounted under `/home/docker/<service>`, usually through a `$STORAGE_DIR` variable set in the stack's `.env`. Some services need the host directories owned by a specific UID (see the per-stack READMEs, e.g. gitea, wordpress-penta).

## Config and secrets convention

- `.env` is **committed** and holds only non-secret values: `STORAGE_DIR`, DB/user names, and image versions in some stacks (nextcloud pins `NEXTCLOUD_VERSION`/`MARIA_DB_VERSION` here, not in the compose file).
- Secrets go in `.env.secrets` (or `*.secrets` files for file-based secrets, e.g. portainer's admin password). These are gitignored. Each one has a committed `.env.secrets.example` template. Services load both files through `env_file: [.env, .env.secrets]`.
- Nextcloud is the exception: it uses gitignored `db.env` / `app.env` with `*.example` templates.
- When a new secret is added, add a matching placeholder to the `.example` file. Never commit real values.
- Some values must be duplicated under two variable names, because the app container and the DB container expect different names (e.g. gitea `MYSQL_PASSWORD` = `GITEA__database__PASSWD`, wordpress-penta `MARIADB_PASSWORD` = `WORDPRESS_DB_PASSWORD`).

## Image upgrades

Most commits bump an image tag. Pin explicit versions rather than `latest`. Commit one service per commit, with messages like `Upgrade gitea to 28.2.0`. Nextcloud's version lives in `avo/nextcloud/.env`. Nextcloud's `app` and `cron` containers run `custom-entrypoint.sh`, which installs ffmpeg into the Alpine image before handing off to the stock entrypoint. Keep that working when changing the image variant (it relies on `apk`, so the image must stay `-alpine`).

## Known stale docs

`avo/wordpress-penta/README.md` is outdated: it mentions WordPress 6.9, port 8080 and `MYSQL_*` variables. The compose file pins `wordpress:7.1.3-php8.3-apache`, publishes no ports, and uses `MARIADB_*` variables split across `.env` / `.env.secrets`.
