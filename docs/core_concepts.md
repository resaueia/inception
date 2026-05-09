# Inception — Core Concepts
> Referência de estudo e consulta para a avaliação

---

## Subject First

**O subject (`en.subject.pdf`) é a fonte de verdade do projeto.**

Toda implementação deve ser verificada contra o subject antes de ser feita.
Tutoriais, projetos de referência e conselhos externos são úteis — mas o subject
prevalece sempre. Uma solução que funciona mas viola o subject falha na defesa.

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

Named volumes são gerenciados pelo Docker. No Inception, os dados devem ficar em `/home/rsaueia-/data` — configurado via `driver_opts` no compose.

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

**Host network** (proibida pelo subject): remove o isolamento de rede.

Regras do subject:
- `network: host` → proibido
- `--link` e `links:` → proibidos
- Porta 443 é a única exposta externamente (via NGINX)

---

## Secrets vs Variáveis de Ambiente vs `.env`

### `.env`
Lido pelo Compose antes de subir os containers. Parametriza o `docker-compose.yml`. Nunca deve conter senhas. Não vai para o git.

### Variáveis de ambiente (`environment:`)
Injetadas no container na inicialização. Visíveis em `docker inspect`. Use para configurações não-sensíveis.

### Docker Secrets
Arquivos do host montados pelo Docker em `/run/secrets/<nome>`. Não aparecem em `docker inspect`. Forma correta de passar senhas.

```
secrets/db_password.txt → /run/secrets/db_password (dentro do container)
```

```bash
DB_PASSWORD=$(cat /run/secrets/db_password)
```

A pasta `secrets/` nunca vai para o git.

---

## Daemon

Um daemon é um processo que roda em segundo plano, sem interação direta com o usuário e sem terminal de controle. O nome vem da mitologia grega — um espírito auxiliar que trabalha nos bastidores.

No Linux, daemons geralmente iniciam no boot do sistema e ficam rodando indefinidamente aguardando eventos ou requisições. Por convenção, seus nomes terminam em `d`: `sshd` (SSH), `mysqld` (MariaDB), `nginx` (quando rodando como serviço), `dockerd` (Docker).

**O Docker daemon (`dockerd`)** é o processo central que gerencia todos os objetos Docker — containers, imagens, volumes, redes. Quando você digita `docker ps` no terminal, o CLI envia uma requisição para o daemon via socket Unix (`/var/run/docker.sock`). O daemon é quem realmente faz o trabalho.

```
docker CLI  →  /var/run/docker.sock  →  dockerd  →  containers
```

**Por que isso importa para o Inception:**

A política `restart: always` reinicia containers automaticamente quando o processo principal morre (crash). Mas há uma distinção importante:

- `docker kill` / `docker stop` → parada intencional via API → o daemon marca o container como "parado pelo usuário" → **não reinicia automaticamente**
- Processo morre por dentro (`kill -9 1` de dentro do container) → o daemon interpreta como crash → **reinicia automaticamente**

Quando o **daemon reinicia** (ex: `sudo systemctl restart docker` ou reboot da VM):
- `restart: always` → containers voltam automaticamente
- `restart: unless-stopped` → containers que foram parados manualmente antes do reboot **não voltam**

---

## PID 1

O primeiro processo de qualquer sistema Linux. Dentro de um container, é o processo definido no `CMD`/`ENTRYPOINT`.

**Responsabilidades do PID 1:**
- Receber `SIGTERM` quando o container para e encerrar de forma limpa
- Gerenciar processos filhos zumbis

**Regra:** o serviço real (`mysqld`, `php-fpm`, `nginx`) deve ser o PID 1. Todo entrypoint script termina com `exec`:

```bash
exec mysqld --user=mysql   # substitui o script pelo serviço — vira PID 1
```

**Proibidos como CMD/ENTRYPOINT:**
- `tail -f /dev/null`
- `sleep infinity`
- `while true; do ...; done`

---

## PHP e WordPress

**PHP** é uma linguagem de programação para web. O servidor executa o código PHP e devolve HTML ao navegador.

**WordPress** é um CMS escrito em PHP. Cada requisição executa arquivos `.php` que buscam dados no MariaDB e montam o HTML.

**php-fpm** (FastCGI Process Manager) é o interpretador PHP. NGINX não executa PHP — ele delega para o php-fpm via protocolo FastCGI na porta 9000.

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

## TLS/SSL

TLS cria um canal criptografado entre navegador e servidor. O "S" do HTTPS.

**Certificado self-signed:** o próprio servidor assina o certificado — sem CA externa. O navegador mostra aviso de segurança mas a criptografia funciona. É o que o subject permite.

**TLSv1.2 vs TLSv1.3:** versões do protocolo. O subject exige que apenas essas duas sejam aceitas — versões anteriores têm vulnerabilidades conhecidas.

```bash
# Gera certificado self-signed válido por 180 dias
openssl req -x509 -nodes -days 180 -newkey rsa:2048 \
  -keyout selfsigned.key -out selfsigned.crt \
  -subj "/CN=rsaueia-.42.fr"
```

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
