# Inception — Core Concepts
> Referência de estudo e consulta para a avaliação

---

## Container vs Máquina Virtual

| | VM | Container |
|---|---|---|
| Isola | hardware inteiro | só o processo |
| Tem kernel próprio | sim | não — compartilha o do host |
| Tamanho | gigabytes | megabytes |
| Inicialização | minutos | segundos |

VM = computador virtual completo. Container = processo isolado que enxerga seu próprio sistema de arquivos, mas compartilha o kernel do host.

---

## Docker

Ferramenta que cria e gerencia containers. Resolve o problema "funciona na minha máquina" — a aplicação e todas as suas dependências ficam empacotadas juntas na imagem.

---

## Imagem vs Container

- **Imagem**: receita somente-leitura. Define o sistema de arquivos base, dependências e comando inicial. Criada pelo `docker build`.
- **Container**: instância em execução de uma imagem. É a imagem + uma camada de escrita em cima. Criado pelo `docker run`.

Uma imagem pode gerar vários containers. Destruir o container não destrói a imagem.

---

## Dockerfile

Arquivo de texto com instruções para construir uma imagem, camada por camada.

```dockerfile
FROM debian:bookworm          # base (nunca usar :latest)
RUN apt-get install -y nginx  # instala dependências
COPY conf/nginx.conf /etc/    # copia arquivos do host
EXPOSE 443                    # documenta a porta usada
CMD ["nginx", "-g", "daemon off;"]  # processo principal
```

Cada instrução `RUN`, `COPY`, `ADD` cria uma nova camada (cache). Imagens são imutáveis após o build.

---

## Docker Compose

Ferramenta para definir e orquestrar múltiplos containers em um único arquivo `docker-compose.yml`.

```yaml
services:
  nginx:
    build: ./requirements/nginx
    ports:
      - "443:443"
  wordpress:
    build: ./requirements/wordpress
  mariadb:
    build: ./requirements/mariadb
```

`docker compose up --build` sobe todos os serviços de uma vez.

---

## Volumes

Mecanismo para persistir dados fora do ciclo de vida do container. Sem volume, dados somem quando o container é destruído.

| Tipo | Definição | Uso |
|---|---|---|
| Named volume | `volumes: db_data:` no compose | **obrigatório no Inception** |
| Bind mount | caminho absoluto do host | **proibido pelo subject** |

Named volumes são gerenciados pelo Docker em `/var/lib/docker/volumes/`. No Inception, os dados devem ficar em `/home/rsaueia-/data` — configurado via driver-opts no compose.

---

## Networks

Redes virtuais que permitem containers se comunicarem pelo **nome do serviço** (DNS interno do Docker).

```
nginx → wordpress:9000 → mariadb:3306
```

**Bridge customizada** (obrigatória): criada pelo Compose, tem DNS interno automático.

```yaml
networks:
  inception:
    driver: bridge
```

**Host network** (proibida pelo subject): remove o isolamento de rede — container usa a interface do host diretamente.

Regras do subject:
- `network: host` → proibido
- `--link` e `links:` → proibidos
- Porta 443 é a única exposta externamente (via NGINX)

---

## Secrets vs Variáveis de Ambiente vs `.env`

### `.env`
Arquivo no host, lido pelo Compose antes de subir os containers. Serve para parametrizar o `docker-compose.yml`. Nunca deve conter senhas — é substituição de texto, não mecanismo de segurança.

```bash
DOMAIN_NAME=rsaueia-.42.fr
MYSQL_DATABASE=wordpress
```

### Variáveis de ambiente (`environment:`)
Injetadas no container na inicialização. Visíveis em texto puro via `docker inspect`. Use para configurações não-sensíveis (hosts, portas, nomes).

### Docker Secrets
Arquivos do host montados pelo Docker dentro do container em `/run/secrets/<nome>`. Não aparecem em `docker inspect`. Forma correta de passar senhas.

```
secrets/db_password.txt → /run/secrets/db_password (dentro do container)
```

```bash
# leitura no entrypoint script:
DB_PASSWORD=$(cat /run/secrets/db_password)
```

A pasta `secrets/` nunca vai para o git (`.gitignore`).

---

## PID 1

O primeiro processo de qualquer sistema Linux. Dentro de um container, é o processo definido no `CMD`/`ENTRYPOINT` do Dockerfile.

**Responsabilidades do PID 1:**
- Receber `SIGTERM` quando o container para (`docker stop`) e encerrar de forma limpa
- Gerenciar processos filhos zumbis

**Regra:** o serviço real (`mysqld`, `php-fpm`, `nginx`) deve ser o PID 1. Todo entrypoint script termina com `exec`:

```bash
exec mysqld --user=mysql   # substitui o script pelo serviço — vira PID 1
```

**Proibidos como CMD/ENTRYPOINT** (não são o serviço real, ignoram SIGTERM):
- `tail -f /dev/null`
- `sleep infinity`
- `while true; do ...; done`

---

## NGINX no Inception

Reverse proxy — único ponto de entrada da aplicação.

```
Navegador
    │ HTTPS porta 443
    ▼
  NGINX          ← termina TLS, valida certificado
    │ FastCGI porta 9000
    ▼
  WordPress      ← processa PHP
  + php-fpm
    │ SQL porta 3306
    ▼
  MariaDB        ← armazena dados
```

Configuração obrigatória:
- TLS v1.2 ou v1.3 apenas (sem HTTP)
- Porta 443 é a única exposta ao host
- Certificado self-signed para `rsaueia-.42.fr`

---

## Regras críticas (falha automática se violadas)

| Regra | Detalhe |
|---|---|
| Sem senhas em Dockerfiles | usar secrets |
| Sem tag `:latest` | usar `debian:bookworm` |
| Secrets fora do git | `.gitignore` já configurado |
| Somente named volumes | bind mounts proibidos para dados |
| NGINX único entry point | porta 443, TLS obrigatório |
| Sem `network: host` / `--link` | proibidos pelo subject |
| Sem loops infinitos no entrypoint | usar `exec` |
| Username admin sem "admin" | nem "Admin", "administrator" |
| Dados em `/home/rsaueia-/data` | path obrigatório na VM |
| Um serviço por container | não misturar serviços |
| Build próprio | só Alpine/Debian como base externa |
