# Inception — User Documentation

*This project has been created as part of the 42 curriculum by rsaueia-.*

---

## What this stack provides

This project runs a WordPress website served over HTTPS. Three services work together:

| Service | Role | Accessible at |
|---|---|---|
| NGINX | Reverse proxy, TLS termination | https://rsaueia-.42.fr |
| WordPress + php-fpm | Web application | Internal only (port 9000) |
| MariaDB | Database | Internal only (port 3306) |

Only NGINX is reachable from outside. WordPress and MariaDB communicate internally
and are never exposed directly.

---

## Starting and stopping the project

All commands must be run from the root of the repository (`~/inception`).

**Start everything (build images if needed):**
```bash
make
```

**Stop containers (data is preserved):**
```bash
make down
```

**Stop and remove images and volumes:**
```bash
make clean
```

**Full reset — removes everything including data on disk:**
```bash
make fclean
```

**Full rebuild from scratch:**
```bash
make re
```

---

## Accessing the website

Open a browser and navigate to:
```
https://rsaueia-.42.fr
```

The browser will warn about the self-signed certificate — this is expected.
Accept the warning to proceed.

**WordPress administration panel:**
```
https://rsaueia-.42.fr/wp-admin
```

Log in with the administrator credentials (see Credentials section below).

---

## Credentials

All credentials are stored as plain-text files in the `secrets/` directory
at the root of the repository. This directory is never committed to git.

| File | Contains |
|---|---|
| `secrets/db_password.txt` | MariaDB password for the WordPress user |
| `secrets/db_root_password.txt` | MariaDB root password |
| `secrets/credentials.txt` | WordPress administrator password |
| `secrets/wp_user_password.txt` | WordPress regular user password |

**Users in WordPress:**

| Role | Username | Password location |
|---|---|---|
| Administrator | `rsaueia_root` | `secrets/credentials.txt` |
| Author | `rsaueia_editor` | `secrets/wp_user_password.txt` |

To read a credential:
```bash
cat secrets/credentials.txt
```

---

## Checking that services are running correctly

**Check all three containers are up:**
```bash
docker ps
```

Expected output: three containers (`nginx`, `wordpress`, `mariadb`) with status `Up`.

**Check NGINX is responding:**
```bash
curl -k https://rsaueia-.42.fr
```

Expected: WordPress HTML in the response.

**Check WordPress can reach the database:**
```bash
docker exec wordpress wp --allow-root core is-installed --path=/var/www/html
```

Expected: `Success: WordPress is installed.`

**View logs for a specific service:**
```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

**Check data directories exist on disk:**
```bash
ls /home/rsaueia-/data/wordpress
ls /home/rsaueia-/data/mariadb
```

---

## Crash recovery

Containers are configured with `restart: always`. If a service crashes (process dies
unexpectedly), Docker restarts it automatically within seconds — no manual intervention
needed.

To verify crash recovery is working:
```bash
docker exec wordpress kill -9 1
sleep 10
docker ps
```

The `wordpress` container should reappear with a fresh `Up X seconds` uptime.
