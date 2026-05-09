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

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Directory where the TLS certificate and key will be stored
RUN mkdir -p /etc/nginx/ssl

COPY conf/nginx.conf /etc/nginx/nginx.conf

# Build argument: domain name is known at build time and not sensitive,
# so it's safe to pass as ARG (unlike passwords, which must use secrets)
ARG DOMAIN_NAME
ENV DOMAIN_NAME=${DOMAIN_NAME}

# Generate self-signed TLS certificate at build time.
# -x509        : self-signed (no CA required)
# -nodes       : no password on the key (NGINX needs to read it without interaction)
# -days 180    : valid for 6 months
# -newkey rsa:2048 : generate a 2048-bit RSA key pair
# -subj        : set certificate fields without interactive prompt
RUN openssl req -x509 -nodes -days 180 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/selfsigned.key \
    -out    /etc/nginx/ssl/selfsigned.crt \
    -subj   "/C=BR/ST=SP/L=SaoPaulo/O=42/OU=Inception/CN=${DOMAIN_NAME}"

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Port 443 is the only entry point — TLS only, no plain HTTP
EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# -g "daemon off;" keeps NGINX in the foreground so it becomes PID 1
CMD ["nginx", "-g", "daemon off;"]
