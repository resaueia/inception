# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rsaueia <rsaueia@student.42.fr>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/05/09 15:45:43 by rsaueia           #+#    #+#              #
#    Updated: 2026/05/09 15:46:49 by rsaueia          ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Never :latest — use a fixed tag so builds are reproducible
FROM debian:bookworm

# Clean apt cache in the same layer to keep the image size small
RUN apt-get update && apt-get install -y \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/*

# Create the socket directory — MariaDB needs it to start, but it doesn't
# exist by default in the container. Must be owned by the mysql user.
RUN mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld

# Custom config: changes bind-address so other containers can connect
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Entrypoint: initializes DB on first run, then starts MariaDB as PID 1
COPY tools/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Internal port only — not exposed to the host, reachable via Docker network
EXPOSE 3306

# JSON array form: script receives signals directly (no shell wrapper)
ENTRYPOINT ["/entrypoint.sh"]
