# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Inception is a 42-school system administration project. The goal is to build a WordPress site served over HTTPS using three Docker containers, each built from a custom Dockerfile — no pre-built application images allowed.

## Commands

All commands run from the repository root.

```bash
make          # build images and start containers (docker compose up -d --build)
make down     # stop and remove containers (volumes preserved)
make clean    # remove containers, images, and volumes
make fclean   # remove everything including /home/rsaueia-/data on disk
make re       # fclean + make (full rebuild from scratch)
```

Debugging:
```bash
docker ps
docker logs -f <nginx|wordpress|mariadb>
docker exec -it wordpress bash
docker exec wordpress wp --allow-root core is-installed --path=/var/www/html
docker inspect wordpress --format '{{.HostConfig.RestartPolicy.Name}}'
```

## First-time setup (required on each new machine)

Two files are gitignored and must be created manually before `make`:

**`secrets/` directory** (plain-text password files):
```bash
mkdir -p secrets
echo "your_db_password"       > secrets/db_password.txt
echo "your_db_root_password"  > secrets/db_root_password.txt
echo "your_wp_admin_password" > secrets/credentials.txt
echo "your_wp_user_password"  > secrets/wp_user_password.txt
```

**`srcs/.env`** (non-sensitive configuration):
```env
DOMAIN_NAME=rsaueia-.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_HOST=mariadb
WP_TITLE=Inception
WP_ADMIN_USER=rsaueia_root
WP_ADMIN_EMAIL=admin@inception.42.fr
WP_USER=rsaueia_editor
WP_USER_EMAIL=editor@inception.42.fr
```

Add domain to `/etc/hosts` (use the VM's actual IP at 42, `127.0.0.1` locally):
```bash
sudo sh -c 'echo "127.0.0.1 rsaueia-.42.fr" >> /etc/hosts'
```

## Architecture

```
Browser (HTTPS :443)
    │
  nginx          ← TLS termination, reverse proxy (only port exposed to host)
    │ FastCGI :9000
  wordpress      ← php-fpm serves PHP; WP-CLI handles installation
    │ SQL :3306
  mariadb        ← database
```

All three services share a custom bridge network (`inception`). Containers resolve each other by service name via Docker's internal DNS. Only port 443 is exposed to the host.

**Volumes:**

| Volume | Host path | Container path |
|---|---|---|
| `srcs_wp_data` | `/home/rsaueia-/data/wordpress` | `/var/www/html` |
| `srcs_db_data` | `/home/rsaueia-/data/mariadb` | `/var/lib/mysql` |

`nginx` and `wordpress` share the `wp_data` volume so NGINX can serve static assets directly without going through php-fpm.

**Secrets vs env vars:** passwords are passed via Docker secrets (files mounted at `/run/secrets/<name>` inside containers — not visible in `docker inspect`). Non-sensitive config uses `.env` variables.

## Entrypoint pattern

Each entrypoint script follows the same pattern:

1. Validate required env vars with `: "${VAR:?message}"`
2. Read passwords from `/run/secrets/` into local shell variables
3. Perform idempotent initialization (guarded by marker files or existence checks)
4. End with `exec "$@"` or `exec <service>` — replaces the script with the real service as PID 1

**MariaDB init guard:** checks for `/var/lib/mysql/mysql` directory. Runs `mysql_install_db` and the setup SQL only once, then touches `.inception_initialized` as a marker.

**WordPress init guard:** checks for `wp-load.php` (download), `wp-config.php` (config create), and `wp core is-installed` (installation) — each step only runs if its output is absent.

**MariaDB socket vs TCP:** the MariaDB entrypoint temporarily starts `mysqld --skip-networking` and connects via `--protocol=SOCKET` for initial setup. `MYSQL_HOST` (set in `.env` for WordPress) is `unset` at the top of the MariaDB entrypoint to prevent the MariaDB client from trying TCP to itself.

## Crash recovery test (Docker 29 + kernel 6.1 note)

`docker exec <container> kill -9 1` não funciona nessa combinação de versões — o sinal é enviado (exit 0) mas não termina o PID 1 do container. O método correto nesse ambiente é:

```bash
sudo kill -9 $(docker inspect wordpress --format '{{.State.Pid}}')
```

Para verificar o restart policy:
```bash
docker inspect mariadb wordpress nginx --format '{{.Name}}: {{.HostConfig.RestartPolicy.Name}}'
```

## Subject constraints

These are evaluation failure conditions — do not violate them:

| Constraint | Where enforced |
|---|---|
| No `:latest` tag | All Dockerfiles use `FROM debian:bookworm` |
| No passwords in Dockerfiles or env vars | Read from `/run/secrets/` at runtime |
| `secrets/` and `srcs/.env` never committed | `.gitignore` |
| Named volumes only (no bind mounts for data) | `driver: local` + `driver_opts` in compose |
| NGINX sole entry point on port 443, TLS only | `ssl_protocols TLSv1.2 TLSv1.3`, no HTTP listener |
| No `network: host`, no `--link` | Custom bridge network `inception` |
| No infinite loops as PID 1 | All entrypoints end with `exec` |
| WordPress admin username must not contain "admin" | `WP_ADMIN_USER=rsaueia_root` |
| One service per container | Enforced by Dockerfile structure |
| Data stored at `/home/rsaueia-/data` | Makefile creates dirs, compose `driver_opts` bind there |
