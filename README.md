*This project has been created as part of the 42 curriculum by rsaueia-.*

# Inception

## Description

Inception is a system administration project that sets up a small web infrastructure
using Docker and Docker Compose, running entirely inside a virtual machine.

The stack consists of three containers communicating over a private Docker network:

```
Browser (HTTPS :443)
    │
  NGINX          ← TLS termination, reverse proxy
    │ FastCGI :9000
  WordPress      ← PHP application + php-fpm
  + php-fpm
    │ SQL :3306
  MariaDB        ← database
```

Each service runs in its own container built from a custom Dockerfile using
`debian:bookworm` as the base image. No pre-built application images are used.

### Design choices

**Virtual Machines vs Docker**

A VM virtualizes an entire machine including its own kernel. A container shares the
host kernel and only isolates the process and its filesystem. Docker containers are
faster to start, smaller in size, and easier to reproduce than VMs — which is why
they are used here to package each service independently.

**Docker Secrets vs Environment Variables**

Environment variables are visible in `docker inspect` output and in the process
environment — they are not suitable for passwords. Docker secrets are mounted as
files inside the container at `/run/secrets/<name>` and are not exposed through
the Docker API. All passwords in this project are passed via secrets; non-sensitive
configuration uses environment variables via `.env`.

**Docker Network vs Host Network**

`network: host` removes container network isolation — the container shares the
host's network stack directly. This is forbidden by the subject. This project uses
a custom bridge network (`inception`), which gives each container an isolated
network namespace while allowing inter-container communication via Docker's internal
DNS (containers reach each other by service name, e.g., `wordpress`, `mariadb`).

**Docker Volumes vs Bind Mounts**

A bind mount directly maps a host path into the container, creating tight coupling
between the container and the host filesystem layout. A named volume is managed by
Docker and provides a stable abstraction. The subject requires named volumes for
data persistence. Both volumes store their data at `/home/rsaueia-/data/` on the
host machine, configured via `driver_opts` in `docker-compose.yml`.

---

## Instructions

### Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- `make`
- A virtual machine running Debian or similar Linux distribution
- Domain `rsaueia-.42.fr` pointing to the VM's IP (or `127.0.0.1` for local testing)

### Setup

1. Clone the repository inside the VM:

```bash
git clone <repository-url> ~/inception
cd ~/inception
```

2. Create the secrets files (never committed to git):

```bash
mkdir -p secrets
echo "your_db_password"       > secrets/db_password.txt
echo "your_db_root_password"  > secrets/db_root_password.txt
echo "your_wp_admin_password" > secrets/credentials.txt
echo "your_wp_user_password"  > secrets/wp_user_password.txt
```

3. Create `srcs/.env` with your configuration:

```env
DOMAIN_NAME=rsaueia-.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_HOST=mariadb
WP_TITLE=Inception
WP_ADMIN_USER=rsaueia_root
WP_ADMIN_EMAIL=admin@rsaueia-.42.fr
WP_USER=rsaueia_editor
WP_USER_EMAIL=editor@rsaueia-.42.fr
```

4. Configure the domain in `/etc/hosts` (local VM only):

```bash
sudo sh -c 'echo "127.0.0.1 rsaueia-.42.fr" >> /etc/hosts'
```

### Running the project

```bash
# Build all images and start all containers
make

# Stop and remove containers (data preserved)
make down

# Remove containers, images, and volumes
make clean

# Remove everything including data on disk
make fclean

# Full rebuild from scratch
make re
```

### Verifying the stack

```bash
# Check all three containers are running
docker ps

# Access the site
curl -k https://rsaueia-.42.fr

# View logs
docker logs nginx
docker logs wordpress
docker logs mariadb
```

---

## Resources

### Documentation used

- [Docker Engine documentation](https://docs.docker.com/engine/)
- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [NGINX documentation — ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [MariaDB Server documentation](https://mariadb.com/kb/en/documentation/)
- [WP-CLI documentation](https://wp-cli.org/)
- [php-fpm configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [OpenSSL — generating self-signed certificates](https://www.openssl.org/docs/manmaster/man1/openssl-req.html)

### AI usage

Claude (Anthropic) was used as a tutor throughout this project. Specifically:

- **Concepts**: explaining Docker internals (PID 1, bridge networks, named volumes,
  secrets) before any implementation was written
- **Debugging**: diagnosing entrypoint failures (MariaDB socket vs TCP, marker file
  initialization, php-fpm crash on restart)
- **Review**: checking Dockerfiles and entrypoint scripts for subject violations
  (no `latest` tags, no hardcoded passwords, no infinite loops)
- **Documentation**: structuring this README and the accompanying USER_DOC.md and
  DEV_DOC.md according to subject requirements

All AI-generated content was reviewed, tested, and understood before being included.
The implementation decisions and the understanding of each component are the author's own.
