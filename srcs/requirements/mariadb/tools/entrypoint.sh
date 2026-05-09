#!/bin/bash
# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    entrypoint.sh                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rsaueia <rsaueia@student.42.fr>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/05/09 15:45:46 by rsaueia           #+#    #+#              #
#    Updated: 2026/05/09 15:45:47 by rsaueia          ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# -e: exit on error | -u: error on undefined vars | -o pipefail: catch pipe errors
set -euo pipefail

DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

# MYSQL_HOST is set in .env for WordPress — unset it here so the MariaDB
# client doesn't try to connect to 'mariadb' (TCP) instead of the local socket
unset MYSQL_HOST

# Validate required environment variables (from .env via docker-compose)
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"

# Read passwords from Docker secrets (mounted as files, never env vars)
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

# Step 1: Initialize system tables if the data directory is empty
if [ ! -d "$DATADIR/mysql" ]; then
    echo "[mariadb] Initializing data directory..."
    mysql_install_db --user=mysql --datadir="$DATADIR" > /dev/null
fi

# Step 2: First-time setup — create database, user, set root password.
# Uses a marker file so this block only runs once even if the container
# restarts after a partial/failed initialization.
if [ ! -f "$DATADIR/.inception_initialized" ]; then
    echo "[mariadb] Running first-time setup..."

    # Start MariaDB temporarily without network — socket only
    mysqld --user=mysql --datadir="$DATADIR" --skip-networking --socket="$SOCKET" &
    pid="$!"

    # Wait until MariaDB is ready. --protocol=SOCKET bypasses TCP entirely.
    for i in {1..50}; do
        if mariadb --protocol=SOCKET --socket="$SOCKET" -e "SELECT 1;" > /dev/null 2>&1; then
            break
        fi
        sleep 0.2
    done

    # Run setup SQL via socket connection
    mariadb --protocol=SOCKET --socket="$SOCKET" << SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

    # Shut down the temporary server cleanly
    mariadb-admin --protocol=SOCKET --socket="$SOCKET" -u root -p"${DB_ROOT_PASSWORD}" shutdown > /dev/null 2>&1 || true
    wait "$pid" || true

    # Mark setup as done so this block is never repeated
    touch "$DATADIR/.inception_initialized"
    echo "[mariadb] Setup complete."
fi

# Replace this script with mysqld — becomes PID 1 and receives signals properly
exec mysqld --user=mysql --datadir="$DATADIR"
