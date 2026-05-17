# Inception — Developer Documentation

*This project has been created as part of the 42 curriculum by rsaueia-.*

---

## Environment setup from scratch

### Prerequisites

| Tool | Version used | Install |
|---|---|---|
| VirtualBox | 7.1 | https://www.virtualbox.org |
| Debian VM | 12 (bookworm) | 4 GB RAM, 2 CPUs, 30 GB disk |
| Docker Engine | 29.4.1 | see below |
| Docker Compose | v2 (plugin) | bundled with Docker Engine |
| make | any | `sudo apt-get install make` |

**Install Docker Engine on Debian:**
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
```

Log out and back in for the group change to take effect.

### Clone the repository

```bash
git clone <repository-url> ~/inception
cd ~/inception
```

### Create secrets

The `secrets/` directory is in `.gitignore` and must be created manually on each machine.

```bash
mkdir -p secrets
echo "choose_a_db_password"       > secrets/db_password.txt
echo "choose_a_root_password"     > secrets/db_root_password.txt
echo "choose_an_admin_password"   > secrets/credentials.txt
echo "choose_a_user_password"     > secrets/wp_user_password.txt
```

Constraints:
- Passwords must not be empty
- Do not use special characters that break shell quoting (`'`, `"`, `\`)
- Never commit these files — `.gitignore` already excludes `secrets/`

### Create the environment file

`srcs/.env` is also excluded from git and must be created manually:

```bash
cat > srcs/.env << 'EOF'
DOMAIN_NAME=rsaueia-.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_HOST=mariadb
WP_TITLE=Inception
WP_ADMIN_USER=rsaueia_root
WP_ADMIN_EMAIL=admin@inception.42.fr
WP_USER=rsaueia_editor
WP_USER_EMAIL=editor@inception.42.fr
EOF
```

### Configure domain resolution

```bash
sudo sh -c 'echo "127.0.0.1 rsaueia-.42.fr" >> /etc/hosts'
```

At 42, the VM's actual IP replaces `127.0.0.1`.

---

## Building and launching the project

```bash
# From the repository root:
make          # builds images and starts containers (docker compose up -d --build)
make down     # stops and removes containers (volumes preserved)
make clean    # removes containers, images, and volumes
make fclean   # removes everything including /home/rsaueia-/data
make re       # fclean + make (full rebuild from scratch)
```

The Makefile calls Docker Compose with:
```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

`--build` forces a rebuild of all images even if they are cached. The data directories
are created before compose runs:
```bash
mkdir -p /home/rsaueia-/data/wordpress /home/rsaueia-/data/mariadb
```

---

## Managing containers and volumes

**Container status:**
```bash
docker ps                          # running containers
docker ps -a                       # all containers including stopped
```

**Logs:**
```bash
docker logs mariadb
docker logs wordpress
docker logs nginx
docker logs -f wordpress           # follow (stream) logs
```

**Execute a command inside a running container:**
```bash
docker exec -it wordpress bash
docker exec -it mariadb bash
docker exec wordpress wp --allow-root user list --path=/var/www/html
```

**Inspect container configuration:**
```bash
docker inspect wordpress
docker inspect wordpress --format '{{.HostConfig.RestartPolicy.Name}}'
docker inspect wordpress --format '{{json .Mounts}}'
```

**Volume management:**
```bash
docker volume ls                   # list volumes
docker volume inspect srcs_wp_data
docker volume inspect srcs_db_data
```

**Network:**
```bash
docker network ls
docker network inspect srcs_inception
```

---

## Data storage and persistence

### Where data lives

| Volume name | Host path | Container path | Contains |
|---|---|---|---|
| `srcs_wp_data` | `/home/rsaueia-/data/wordpress` | `/var/www/html` | WordPress PHP files, themes, plugins, uploads |
| `srcs_db_data` | `/home/rsaueia-/data/mariadb` | `/var/lib/mysql` | MariaDB database files |

Volumes are defined in `srcs/docker-compose.yml` as named volumes with `driver: local`
and `driver_opts` that bind them to the specific host paths above.

### How persistence works

Named volumes are managed by Docker but stored on the host filesystem. When a container
is stopped or destroyed, the data remains on disk. When the container restarts, Docker
mounts the same volume, and the service resumes with its existing state.

`make down` (no `--volumes` flag) preserves volumes. `make clean` removes volumes.
`make fclean` removes volumes and deletes the host data directories.

### Idempotent initialization

Both MariaDB and WordPress use marker-based initialization:

- **MariaDB**: checks for `/var/lib/mysql/mysql` directory. If absent, runs full
  database initialization. Subsequent restarts skip initialization.
- **WordPress**: checks for `wp-load.php`, `wp-config.php`, and whether the site
  is installed. Each step is only run if its output is missing.

This means containers can crash and restart without corrupting or duplicating data.

---

## Project structure

```
inception/
├── Makefile                        # entry point: make, make clean, etc.
├── secrets/                        # NOT in git — passwords as plain text files
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── credentials.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                        # NOT in git — non-sensitive configuration
    ├── docker-compose.yml          # service definitions, volumes, network, secrets
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf  # MariaDB config: bind-address, charset
        │   └── tools/entrypoint.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf       # php-fpm pool: port 9000, process limits
        │   └── tools/entrypoint.sh
        └── nginx/
            ├── Dockerfile
            ├── conf/nginx.conf     # TLS 1.2/1.3, port 443, FastCGI proxy
            └── tools/entrypoint.sh
```

---

## Key design constraints (from the subject)

| Constraint | Implementation |
|---|---|
| No `:latest` tag | All Dockerfiles use `FROM debian:bookworm` |
| No passwords in Dockerfiles | Passwords read from `/run/secrets/` at runtime |
| Secrets not in git | `secrets/` and `srcs/.env` are in `.gitignore` |
| Named volumes only | `driver: local` with `driver_opts` — no bind mounts |
| NGINX sole entry point | Only port 443 exposed; wordpress and mariadb have no `ports:` |
| No `network: host` | Custom bridge network `inception` |
| No infinite loops | All entrypoints end with `exec "$@"` |
| One service per container | Enforced by Dockerfile and compose structure |
| Data path | `/home/rsaueia-/data` on the host VM |
| TLS only | `ssl_protocols TLSv1.2 TLSv1.3` in nginx.conf — no HTTP listener |
