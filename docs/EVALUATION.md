# Inception — Evaluation Reference

> Login: `rsaueia-` | Domain: `rsaueia-.42.fr` | Subject v5.2

This document records all evaluation-relevant tests performed during development,
their results, and technical context needed to defend the project during peer evaluation.

---

## Test 1 — Full stack build from scratch

**Command:**
```bash
make fclean
make
```

**Result:** All three images built from cache (Debian bookworm base), custom bridge
network `inception` created, named volumes `wp_data` and `db_data` created, all three
containers started in the correct order (mariadb → wordpress → nginx).

**What to verify:**
```bash
docker ps
```
Expected: three containers running — `mariadb` (3306), `wordpress` (9000), `nginx` (443).

---

## Test 2 — HTTPS access

**Command (from inside the VM):**
```bash
curl -k https://rsaueia-.42.fr
```

**Result:** WordPress HTML returned. TLS handshake completed with self-signed certificate.

**Prerequisites:**
- `/etc/hosts` on the VM must contain: `127.0.0.1 rsaueia-.42.fr`
- At 42, the domain is configured to point to the VM's actual IP — no iptables trick needed.

**To add the hosts entry if missing:**
```bash
sudo sh -c 'echo "127.0.0.1 rsaueia-.42.fr" >> /etc/hosts'
```

---

## Test 3 — Crash recovery

**What the subject requires:** "Your containers have to restart in case of a crash."

### The correct test

Kill the main process from **inside** the container (simulates a real crash):
```bash
docker exec wordpress kill -9 1
sleep 10
docker ps
```

**Result:** WordPress container restarted automatically and appeared in `docker ps`
with `Up ~7 seconds` — the entrypoint re-ran, skipped setup (already installed),
and launched php-fpm again.

The same test works for mariadb and nginx:
```bash
docker exec mariadb kill -9 1
sleep 10
docker ps

docker exec nginx kill -9 1
sleep 10
docker ps
```

### Why `docker kill` does NOT trigger a restart

`docker kill <container>` is a Docker CLI command that sends a signal via the Docker
API. In Docker 24+, the daemon treats any API-originated kill as a deliberate user
action (equivalent to `docker stop`). Both `restart: always` and `restart: unless-stopped`
explicitly do NOT restart containers after deliberate stops — this is documented behavior.

From Docker docs on `restart: always`:
> "If the container is manually stopped, it is restarted only when the Docker daemon restarts."

**Restart policy used:** `restart: always`

**`always` vs `unless-stopped`:**
| Scenario | `unless-stopped` | `always` |
|---|---|---|
| Process crashes (internal) | restarts | restarts |
| `docker kill` | does not restart | does not restart |
| `docker stop` | does not restart | does not restart |
| Docker daemon restarts | does NOT restart | restarts |

`restart: always` was chosen because it guarantees containers come back up after a
daemon restart (e.g., after a reboot of the VM).

---

## Test 4 — Volume persistence

**What the subject requires:** Data must survive container destruction and persist
in `/home/rsaueia-/data` on the host machine.

**Test:**
```bash
# Bring down containers (without --volumes)
docker compose -f srcs/docker-compose.yml down

# Verify data is still on disk
ls /home/rsaueia-/data/mariadb
ls /home/rsaueia-/data/wordpress

# Bring everything back up
docker compose -f srcs/docker-compose.yml up -d

# WordPress should be accessible and data intact
curl -k https://rsaueia-.42.fr
```

**Result:** Data directories persist on disk. After restart, WordPress loads with
all previously created content and users.

---

## Test 5 — No passwords in Dockerfiles or git

**What to verify:**
```bash
grep -r "password\|passwd\|secret" srcs/requirements/*/Dockerfile
```

Expected: no matches (passwords are never in Dockerfiles).

```bash
cat srcs/requirements/wordpress/tools/entrypoint.sh | grep -i password
```

Expected: passwords are read from `/run/secrets/`, never hardcoded.

```bash
git log --all --full-history -- secrets/
```

Expected: secrets directory was never committed.

---

## Test 6 — Single entry point (NGINX only on port 443)

**What the subject requires:** NGINX is the only container with an external port.
Only TLSv1.2 and TLSv1.3 are accepted.

**Verify port exposure:**
```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

Expected:
```
nginx       0.0.0.0:443->443/tcp
wordpress   (no external port — 9000 internal only)
mariadb     (no external port — 3306 internal only)
```

**Verify TLS version:**
```bash
openssl s_client -connect rsaueia-.42.fr:443 -tls1_1 2>&1 | grep -i "handshake\|alert"
```

Expected: handshake failure (TLS 1.1 rejected).

```bash
openssl s_client -connect rsaueia-.42.fr:443 -tls1_2 2>&1 | grep "Protocol"
```

Expected: `Protocol: TLSv1.2` — connection succeeds.

---

## Test 7 — WordPress users

**What the subject requires:** Two users in the WordPress database. The administrator's
username must not contain "admin", "Admin", "administrator", or "Administrator".

**Verify from inside the wordpress container:**
```bash
docker exec wordpress wp --allow-root user list --path=/var/www/html
```

Expected: two users listed — one with `administrator` role (but username without
"admin"), one with `author` role.

---

## Test 8 — Network isolation

**What the subject requires:** Custom bridge network, no `network: host`, no `--link`.

**Verify:**
```bash
docker inspect wordpress --format '{{json .HostConfig.NetworkMode}}'
docker network ls
docker network inspect srcs_inception
```

Expected: containers are on the `srcs_inception` bridge network. All inter-container
communication uses Docker's internal DNS (service names as hostnames).

---

## Test 9 — Login no MariaDB e banco não vazio

O avaliador pede para você demonstrar como acessar o banco e mostrar que ele tem dados.

```bash
docker exec -it mariadb mariadb -u wp_user -pSUA_SENHA wordpress
```

Dentro do cliente MariaDB:
```sql
SHOW TABLES;
SELECT COUNT(*) FROM wp_posts;
EXIT;
```

Esperado: tabelas do WordPress listadas (`wp_posts`, `wp_users`, etc.) e pelo menos 1 registro.

Como root (se necessário):
```bash
docker exec -it mariadb mariadb -u root -pSUA_SENHA_ROOT
```

---

## Test 10 — Persistência após reboot da VM

O avaliador vai reiniciar a VM e verificar que tudo volta com os dados preservados.

1. Antes do reboot: faça uma mudança visível no WordPress (edite uma página, adicione um post)
2. Reiniciar: `sudo reboot`
3. Após o boot: containers com `restart: always` sobem automaticamente com o daemon Docker
4. Confirmar: `docker ps` mostra os 3 containers rodando
5. Confirmar: o site abre com a mudança feita antes do reboot

Se os containers não subirem automaticamente após o reboot:
```bash
cd ~/inception && make
```

---

## Quick pre-evaluation checklist

```bash
# All three containers running
docker ps

# Image names match service names (nginx, wordpress, mariadb — no srcs- prefix)
docker image ls | grep -E "nginx|wordpress|mariadb"

# Restart policy on all containers
docker inspect mariadb wordpress nginx --format '{{.Name}}: {{.HostConfig.RestartPolicy.Name}}'

# Volumes pointing to correct path
docker volume inspect srcs_wp_data srcs_db_data --format '{{.Name}}: {{.Options.device}}'

# No secrets in git history
git log --all --oneline -- secrets/ srcs/.env
```
