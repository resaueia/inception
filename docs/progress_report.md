# Inception — Progress Report

> Login: `rsaueia-` | Domain: `rsaueia-.42.fr` | Subject v5.2

---

## What we have done so far

### Environment setup
- Installed VirtualBox 7.1 (from Oracle's official repository — Ubuntu's default version 6.1 is incompatible with kernel 6.8+)
- Created a Debian 13 VM with: 4096MB RAM, 2 CPUs, 30GB disk, NAT network
- VM user: `rsaueia-` (matches the required `/home/rsaueia-/data` path from the subject)
- Configured SSH port forwarding (host port 2222 → VM port 22) for comfortable terminal access
- Installed Docker 29.4.1 and Docker Compose v5.1.3 inside the VM
- Verified Docker works correctly (`docker run hello-world`)

### Repository setup
- Created `.gitignore` protecting secrets and `.env` from being committed
- Created `docs/action-plan.md` with all project phases and critical rules checklist
- Created this progress report

### Concepts covered
- What a Virtual Machine is and why the project requires one
- What a kernel is and why containers share it
- What Docker is and the problem it solves
- Docker image vs Docker container distinction
- What a Dockerfile is and how it works
- What Docker Compose is and why we need it
- Docker volumes: named volumes vs bind mounts, and why the subject forbids bind mounts
- (pending) Docker networks
- (pending) Secrets vs environment variables
- (pending) PID 1 and proper process management in containers

---

## Current state

We are in **Phase 0 (Foundation & Concepts)** — finishing the conceptual groundwork before writing any code.

The VM is running and Docker is operational. The next step is to finish the remaining concepts (networks, secrets, PID 1) and then move into Phase 1 (project skeleton).

---

## What comes next

### Phase 0 — remaining concepts
- Docker networks (bridge vs host, why host is forbidden by the subject)
- Docker secrets vs environment variables vs `.env` files
- PID 1 and why `tail -f`, `sleep infinity`, `while true` are forbidden

### Phase 1 — Project skeleton
Create the full directory structure, `.env`, `secrets/`, stub `Makefile` and stub `docker-compose.yml`.

```
.
├── Makefile
├── secrets/
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── docker-compose.yml
    ├── .env
    └── requirements/
        ├── mariadb/
        ├── nginx/
        └── wordpress/
```

### Phase 2 — MariaDB container
First service to build. Dockerfile + entrypoint script that initializes the database, creates users, and starts MariaDB correctly as PID 1.

### Phase 3 — WordPress + php-fpm container
Second service. Connects to MariaDB. Uses WP-CLI to automate WordPress installation and user creation.

### Phase 4 — NGINX container
Third service. TLS only (v1.2/v1.3), port 443, reverse proxy to WordPress on port 9000. Self-signed certificate for `rsaueia-.42.fr`.

### Phase 5 — Integration & full stack test
All three services running together, volumes persisting data, crash recovery working, domain resolving correctly.

### Phase 6 — Finalization
Complete Makefile, write README.md, USER_DOC.md and DEV_DOC.md as required by the subject.

---

## The subject is the single source of truth

**Before implementing anything new, the subject must be consulted.**

The subject (`en.subject.pdf`) defines every requirement, restriction, and constraint of this project. It is not a suggestion — it is the evaluation criteria. Deviating from it, even with a working result, means failing the defense.

This means:
- Before writing a new Dockerfile, re-read the relevant section of the subject
- Before adding a new configuration option, verify it is not forbidden
- Before committing anything, check the security rules
- When in doubt, the subject wins over any external tutorial or advice

The subject is located at: `en.subject.pdf` in the repository root.

---

## Critical rules (never violate these)

Violations of the rules below result in **automatic project failure**, regardless of whether the rest works correctly.

| Rule | Description |
|------|-------------|
| No passwords in Dockerfiles | Use environment variables and secrets instead |
| No `latest` tag | Use `debian:bookworm` for containers — never `debian:latest` |
| Secrets never in git | `.gitignore` already configured — credentials in git = instant failure |
| Named volumes only | Bind mounts forbidden for WordPress and DB data |
| NGINX is the sole entry point | Port 443 only, TLSv1.2 or TLSv1.3 — no other ports exposed externally |
| No forbidden network options | `network: host`, `--link`, `links:` are all explicitly forbidden |
| No infinite loop entrypoints | `tail -f`, `sleep infinity`, `while true` as CMD/ENTRYPOINT are forbidden |
| Admin username | Must not contain "admin", "Admin", "administrator" or "Administrator" |
| Data path on VM | Volumes must store data at `/home/rsaueia-/data` |
| One service per container | Do not run multiple services inside a single container |
| Build your own images | Pulling pre-built images (except Alpine/Debian base) is forbidden |
