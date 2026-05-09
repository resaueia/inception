# Inception — Progress Report

> Login: `rsaueia-` | Domain: `rsaueia-.42.fr` | Subject v5.2

---

## Subject First

**The subject (`en.subject.pdf`) is the single source of truth.**

Before implementing anything new, the subject must be consulted. It defines every
requirement, restriction, and constraint. Deviating from it — even with a working
result — means failing the defense.

- Before writing a new Dockerfile → re-read the relevant subject section
- Before adding a configuration option → verify it is not forbidden
- Before every commit → check the critical rules in `action-plan.md`
- When in doubt → the subject wins over any tutorial, reference project, or advice

---

## Current State (2026-05-09)

**Phase 5 in progress** — three containers running, full stack tested end-to-end.

---

## What Has Been Done

### Phase 0 — Concepts (complete)
- Container vs VM, Docker, images, Dockerfiles, Docker Compose
- Volumes (named vs bind mounts), networks (bridge vs host)
- Docker secrets vs environment variables vs `.env`
- PID 1 and proper process management in containers
- NGINX as reverse proxy, TLS/SSL, php-fpm, WordPress, PHP

### Phase 1 — Project Skeleton (complete)
- Full directory structure: `srcs/`, `secrets/`, `requirements/`
- Root `Makefile` with `all`, `up`, `down`, `clean`, `fclean`, `re`
- `srcs/.env` with all environment variables
- `secrets/` files: `db_password.txt`, `db_root_password.txt`, `credentials.txt`, `wp_user_password.txt`
- `.gitignore` protecting secrets and `.env`
- `srcs/docker-compose.yml` with three services, named volumes, custom bridge network

### Phase 2 — MariaDB Container (complete)
- `Dockerfile`: Debian bookworm, mariadb-server, socket directory creation
- `conf/50-server.cnf`: bind-address 0.0.0.0, skip-name-resolve, utf8mb4
- `tools/entrypoint.sh`: marker-file initialization, passwords via secrets, MariaDB as PID 1
- Tested: `wordpress` database and `wp_user` created and verified

### Phase 3 — WordPress + php-fpm Container (complete)
- `Dockerfile`: Debian bookworm, php8.2-fpm + extensions, WP-CLI
- `conf/www.conf`: php-fpm pool on port 9000, dynamic process management
- `tools/entrypoint.sh`: waits for MariaDB, downloads WordPress, configures wp-config.php, installs WordPress, creates two users via WP-CLI
- Tested: WordPress installed successfully, both users created

### Phase 4 — NGINX Container (complete)
- `Dockerfile`: Debian bookworm, nginx, openssl; self-signed TLS cert generated at build time
- `conf/nginx.conf`: port 443 only, TLSv1.2/TLSv1.3, FastCGI proxy to wordpress:9000
- `tools/entrypoint.sh`: minimal — ensures runtime dir exists, exec nginx
- Tested: `https://rsaueia-.42.fr` loads WordPress with valid TLS connection

### Key issues solved during development
- MariaDB `MYSQL_HOST` env var was intercepted by the MariaDB client → fixed with `unset MYSQL_HOST` in entrypoint
- MariaDB init block was being skipped after partial failures → fixed with marker file `.inception_initialized`
- TCP vs socket connection issues → fixed with `--protocol=SOCKET` and `skip-name-resolve`
- VirtualBox NAT doesn't forward port 443 without root → tested via port 8443 locally; at 42 this won't be needed

---

## What Comes Next

### Phase 5 — Integration & Full Stack Test (in progress)
- Configure `/etc/hosts` on the VM
- Test `make` from the root directory
- Test crash recovery (kill a container, verify it restarts)
- Final verification of all critical rules

### Phase 6 — Finalization
- Update `Makefile` to match reference (add `logs`, `status`, `start`, `stop` targets)
- Write `README.md`, `USER_DOC.md`, `DEV_DOC.md`
- Final security and structure audit

---

## Environment

| Component | Details |
|---|---|
| Host OS | Ubuntu (kernel 6.8) |
| VM | Debian 13, 4096MB RAM, 2 CPUs, 30GB disk |
| VM user | `rsaueia-` |
| VirtualBox | 7.1 (Oracle repository) |
| Docker | 29.4.1 |
| Docker Compose | v5.1.3 |
| SSH access | host port 2222 → VM port 22 |
| HTTPS access (local) | host port 8443 → VM port 443 (VirtualBox NAT) |

---

## Critical Rules (never violate — automatic failure)

| Rule | Description |
|------|-------------|
| No passwords in Dockerfiles | Use secrets only |
| No `:latest` tag | Use `debian:bookworm` |
| Secrets never in git | `.gitignore` configured |
| Named volumes only | Bind mounts forbidden for data |
| NGINX sole entry point | Port 443, TLSv1.2/1.3 only |
| No forbidden network options | `network: host`, `--link`, `links:` all forbidden |
| No infinite loop entrypoints | Use `exec` at end of entrypoint |
| Admin username | Must not contain "admin" or "administrator" |
| Data path on VM | `/home/rsaueia-/data` |
| One service per container | Never run multiple services in one container |
| Build your own images | Only Alpine/Debian as external base |
