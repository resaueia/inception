# Inception — Action Plan
> Login: `rsaueia-` | Domain: `rsaueia-.42.fr` | Subject v5.2

---

## Subject First

**Before implementing anything, the subject (`en.subject.pdf`) must be consulted.**

The subject defines every requirement, restriction, and constraint of this project.
It is the evaluation criteria — deviating from it means failing the defense, regardless of whether the result works.

- Before writing a new Dockerfile → re-read the relevant subject section
- Before adding a configuration option → verify it is not forbidden
- Before every commit → check the critical rules table at the bottom of this file
- When in doubt → the subject wins over any tutorial, reference project, or advice

---

## Legend
- [ ] = not started
- [~] = in progress
- [x] = done

---

## Phase 0 — Foundation & Concepts

- [x] **0.1** Understand what a container is vs a Virtual Machine (analogy + diagram)
- [x] **0.2** Understand what Docker is and why it exists
- [x] **0.3** Understand what a Docker image vs a Docker container is
- [x] **0.4** Understand what a Dockerfile is and how it works
- [x] **0.5** Understand what Docker Compose is and why we need it
- [x] **0.6** Understand Docker volumes (named vs bind mounts)
- [x] **0.7** Understand Docker networks (bridge vs host)
- [x] **0.8** Understand Docker secrets vs environment variables vs .env files
- [x] **0.9** Understand PID 1 and why it matters for containers
- [x] **0.10** Install Docker and Docker Compose on the VM (verify installation)

---

## Phase 1 — Project Skeleton

- [x] **1.1** Create the required directory structure (`srcs/`, `secrets/`, etc.)
- [x] **1.2** Create the root `Makefile` (stub — to be filled as services are built)
- [x] **1.3** Create `srcs/.env` with all environment variable placeholders
- [x] **1.4** Create `secrets/` files (db_password.txt, db_root_password.txt, credentials.txt)
- [x] **1.5** Set up `.gitignore` to protect secrets and `.env` from being committed
- [x] **1.6** Create stub `srcs/docker-compose.yml`

---

## Phase 2 — MariaDB Container

- [x] **2.1** Learn what MariaDB is and its role in the stack
- [x] **2.2** Write `srcs/requirements/mariadb/Dockerfile` (Debian base, no latest tag)
- [x] **2.3** Write MariaDB configuration files in `srcs/requirements/mariadb/conf/`
- [x] **2.4** Write entrypoint script in `srcs/requirements/mariadb/tools/`
- [x] **2.5** Create WordPress database, admin user (no "admin" in name), and regular user via script
- [x] **2.6** Add MariaDB service to `docker-compose.yml` with named volume
- [x] **2.7** Test: build and run MariaDB container, verify DB and users exist

---

## Phase 3 — WordPress + php-fpm Container

- [x] **3.1** Learn what WordPress, php-fpm are and how they interact
- [x] **3.2** Write `srcs/requirements/wordpress/Dockerfile`
- [x] **3.3** Configure php-fpm to listen on port 9000
- [x] **3.4** Write entrypoint script: install WP-CLI, configure wp-config.php, create users
- [x] **3.5** Add WordPress service to `docker-compose.yml` with named volume
- [x] **3.6** Ensure WordPress container depends on MariaDB being healthy
- [x] **3.7** Test: WordPress connects to MariaDB, files are written to volume

---

## Phase 4 — NGINX Container

- [x] **4.1** Learn what NGINX is and its role as a reverse proxy
- [x] **4.2** Understand TLS/SSL (what TLSv1.2 and TLSv1.3 are and why they matter)
- [x] **4.3** Generate a self-signed TLS certificate for `rsaueia-.42.fr`
- [x] **4.4** Write `srcs/requirements/nginx/Dockerfile`
- [x] **4.5** Write NGINX config: TLS only (1.2/1.3), port 443, proxy to WordPress on port 9000
- [x] **4.6** Add NGINX service to `docker-compose.yml` (port 443 exposed)
- [x] **4.7** Test: access `https://rsaueia-.42.fr` from host browser

---

## Phase 5 — Integration & Full Stack Test

- [x] **5.1** Configure `docker-compose.yml` network (custom bridge, no host network)
- [x] **5.2** Verify restart policies (`restart: unless-stopped`)
- [x] **5.3** Verify volumes are named and data is stored in `/home/rsaueia-/data`
- [ ] **5.4** Configure `/etc/hosts` on VM: `rsaueia-.42.fr` → local IP
- [ ] **5.5** Full stack up: `make` builds everything, all 3 services run
- [ ] **5.6** Test crash recovery: kill a container manually, verify it restarts
- [x] **5.7** Test WordPress site works end-to-end via browser (HTTPS only)
- [x] **5.8** Verify no passwords are hardcoded anywhere in Dockerfiles

---

## Phase 6 — Makefile & Finalization

- [~] **6.1** Complete `Makefile` with targets: `all`, `up`, `down`, `clean`, `fclean`, `re`
- [ ] **6.2** Write `README.md` (EN, mandatory format with all required sections)
- [ ] **6.3** Write `USER_DOC.md` (end-user documentation)
- [ ] **6.4** Write `DEV_DOC.md` (developer documentation)
- [ ] **6.5** Final security audit: no secrets in git, no `latest` tags, no forbidden commands
- [ ] **6.6** Final structure audit: all folders/files match subject requirements

---

## Critical Rules (check before every commit — violations cause automatic failure)

| Rule | Status |
|------|--------|
| No passwords in Dockerfiles | verified |
| No `latest` tag in any FROM | verified |
| Secrets not committed to git | verified |
| Named volumes only (no bind mounts for WP data) | verified |
| NGINX is sole entry point via port 443 | verified |
| No `network: host`, `--link`, `links:` | verified |
| No `tail -f`, `sleep infinity`, `while true` as entrypoint | verified |
| Admin username contains no "admin"/"administrator" | verified |
| Domain: rsaueia-.42.fr | verified |
| Data path: /home/rsaueia-/data | verified |
| One service per container | verified |
| Build your own images (no pre-built except Alpine/Debian) | verified |
