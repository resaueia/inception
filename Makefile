# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: rsaueia <rsaueia@student.42.fr>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/05/09 15:40:25 by rsaueia           #+#    #+#              #
#    Updated: 2026/05/09 15:40:26 by rsaueia          ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

DATA_PATH	= /home/rsaueia-/data

all: up

up:
	@mkdir -p $(DATA_PATH)/wordpress $(DATA_PATH)/mariadb
	docker compose -f srcs/docker-compose.yml up -d --build

down:
	docker compose -f srcs/docker-compose.yml down

clean: down
	docker compose -f srcs/docker-compose.yml down --rmi all --volumes

fclean: clean
	sudo rm -rf $(DATA_PATH)

re: fclean all

.PHONY: all up down clean fclean re
