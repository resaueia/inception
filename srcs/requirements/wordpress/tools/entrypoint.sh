#!/bin/bash
# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    entrypoint.sh                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rsaueia <rsaueia@student.42.fr>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/05/09 by rsaueia                    #+#    #+#              #
#    Updated: 2026/05/09 by rsaueia                   ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

set -euo pipefail

# Validate required environment variables (set in .env via docker-compose)
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
: "${MYSQL_HOST:?MYSQL_HOST is required}"
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
: "${WP_TITLE:?WP_TITLE is required}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER is required}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL is required}"
: "${WP_USER:?WP_USER is required}"
: "${WP_USER_EMAIL:?WP_USER_EMAIL is required}"

# Read passwords from Docker secrets
DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/credentials)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

# Wait for MariaDB to accept connections before proceeding.
# Without this, WordPress setup would fail if the DB isn't ready yet.
echo "[wordpress] Waiting for MariaDB..."
for i in {1..60}; do
    if mariadb-admin ping -h "${MYSQL_HOST}" -u "${MYSQL_USER}" -p"${DB_PASSWORD}" --silent > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Download WordPress core files if not already present
if [ ! -f /var/www/html/wp-load.php ]; then
    echo "[wordpress] Downloading WordPress..."
    curl -fsSL https://wordpress.org/latest.tar.gz -o /tmp/wp.tar.gz
    tar -xzf /tmp/wp.tar.gz -C /tmp
    cp -R /tmp/wordpress/* /var/www/html/
    rm -rf /tmp/wp.tar.gz /tmp/wordpress
fi

# Generate wp-config.php with database credentials from secrets and env vars
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "[wordpress] Creating wp-config.php..."
    wp config create \
        --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="${MYSQL_HOST}:3306" \
        --path=/var/www/html
fi

# Run WordPress installation (creates tables in the DB, sets up admin user)
if ! wp --allow-root core is-installed --path=/var/www/html > /dev/null 2>&1; then
    echo "[wordpress] Installing WordPress..."
    wp core install \
        --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --path=/var/www/html
else
    echo "[wordpress] WordPress already installed — skipping."
fi

# Create the regular (non-admin) user if it doesn't exist yet
if ! wp --allow-root user get "${WP_USER}" --path=/var/www/html > /dev/null 2>&1; then
    echo "[wordpress] Creating second user..."
    wp user create \
        --allow-root \
        "${WP_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=author \
        --path=/var/www/html
else
    echo "[wordpress] User ${WP_USER} already exists — skipping."
fi

echo "[wordpress] Setup complete."

# Replace this script with php-fpm (CMD argument) — becomes PID 1
exec "$@"
