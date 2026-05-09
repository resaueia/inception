#!/bin/sh
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

set -eu

# Ensure NGINX runtime directory exists
mkdir -p /var/run/nginx

# Replace this script with the CMD argument (nginx -g "daemon off;")
exec "$@"
