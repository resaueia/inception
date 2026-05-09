# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rsaueia <rsaueia@student.42.fr>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/05/09 by rsaueia                    #+#    #+#              #
#    Updated: 2026/05/09 by rsaueia                   ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM debian:bookworm

# php8.2-fpm    : the PHP process manager (serves PHP to NGINX via FastCGI)
# php8.2-mysql  : lets PHP connect to MariaDB
# php8.2-curl/gd/mbstring/xml/zip : extensions required by WordPress
# mariadb-client: lets the entrypoint script ping MariaDB before starting
# curl + ca-certificates + tar : used to download WordPress and WP-CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip \
    mariadb-client curl ca-certificates tar \
    && rm -rf /var/lib/apt/lists/*

# Replace default php-fpm pool config with ours (sets port 9000, process limits)
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# WP-CLI: command-line tool to configure and install WordPress without a browser
RUN curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

RUN mkdir -p /var/www/html
WORKDIR /var/www/html

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Internal port — NGINX connects here via FastCGI (not exposed to the host)
EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# CMD is passed as arguments to the entrypoint — starts php-fpm in foreground
# -F flag keeps php-fpm in the foreground so it becomes and stays as PID 1
CMD ["php-fpm8.2", "-F"]
