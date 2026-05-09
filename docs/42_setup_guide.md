# Inception — Setup Guide for 42

Este guia documenta o passo a passo completo para recriar o ambiente na 42:
criar a VM, configurar o acesso remoto, clonar o projeto e executar todos os testes.

---

## 1. Criar a VM no VirtualBox

### Parâmetros usados no desenvolvimento

| Parâmetro | Valor |
|---|---|
| Nome | inception |
| Sistema operacional | Debian 64-bit |
| Versão Debian | bookworm (12) ou trixie (13) |
| RAM | 4096 MB |
| CPUs | 2 |
| Disco | 30 GB (VDI, alocação dinâmica) |

### Configuração de rede (duas interfaces)

A VM precisa de duas interfaces de rede para funcionar bem:

**Interface 1 — NAT** (acesso à internet para instalar pacotes e clonar o repo)
- Tipo: NAT
- Port forwarding: `2222 → 22` (SSH da máquina host para a VM)

**Interface 2 — Host-only** (acesso direto ao site pelo navegador do host)
- Tipo: Host-only Adapter
- Adaptador: `vboxnet0` (criar em VirtualBox → File → Host Network Manager se não existir)
- Esta interface dará à VM um IP fixo acessível do host (ex: `192.168.56.101`)

> **Por que duas interfaces?**
> A interface NAT permite a VM sair para a internet mas não permite o host acessar
> a VM diretamente na porta 443. A interface host-only cria uma rede privada entre
> host e VM — o navegador do host consegue abrir `https://rsaueia-.42.fr` sem
> nenhum port forwarding para a porta 443.

---

## 2. Instalar o Debian na VM

Durante a instalação:
- Criar usuário: `rsaueia-`
- Hostname: `inception`
- Instalar apenas "SSH server" e "standard system utilities" (sem desktop)
- Particionar disco inteiro em uma única partição

---

## 3. Configuração inicial dentro da VM

### Acesso SSH do host para a VM (via NAT, porta 2222)

```bash
ssh -p 2222 rsaueia-@localhost
```

### Dentro da VM: instalar dependências

```bash
# Sudo
su -
apt-get install -y sudo
usermod -aG sudo rsaueia-
exit
# Reconectar via SSH para o grupo surtir efeito

# Make
sudo apt-get install -y make

# Docker Engine
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Adicionar usuário ao grupo docker (sem sudo para cada comando)
sudo usermod -aG docker rsaueia-
# Reconectar para o grupo surtir efeito
exit
```

### Reconectar e verificar Docker

```bash
ssh -p 2222 rsaueia-@localhost
docker --version
docker compose version
```

---

## 4. Descobrir o IP da interface host-only

Dentro da VM:

```bash
ip addr show
```

Procure a interface que não é `lo` nem `enp0s3` (NAT) — geralmente `enp0s8`.
O IP será algo como `192.168.56.101`.

Anote esse IP — você vai precisar dele para configurar o host.

---

## 5. Configurar o domínio no host (computador da 42)

No terminal **do computador host** (não da VM):

```bash
# Substitua pelo IP real da interface host-only
sudo sh -c 'echo "192.168.56.101 rsaueia-.42.fr" >> /etc/hosts'
```

Verificar:
```bash
grep rsaueia-.42.fr /etc/hosts
```

---

## 6. Clonar o projeto e configurar

Dentro da VM:

```bash
cd ~
git clone git@github.com:resaueia/inception.git inception
cd inception
```

> Se SSH não funcionar com o GitHub, use HTTPS:
> ```bash
> git clone https://github.com/resaueia/inception.git inception
> ```

### Criar os secrets

```bash
mkdir -p secrets
echo "SUA_SENHA_DB"       > secrets/db_password.txt
echo "SUA_SENHA_ROOT"     > secrets/db_root_password.txt
echo "SUA_SENHA_ADMIN_WP" > secrets/credentials.txt
echo "SUA_SENHA_USER_WP"  > secrets/wp_user_password.txt
```

> As senhas devem ser as mesmas usadas no desenvolvimento — caso contrário o
> WordPress não conseguirá conectar ao banco (as credenciais precisam ser consistentes
> entre a primeira instalação e reinstalações futuras, ou você precisa usar `make fclean`
> para apagar tudo e começar do zero com as novas senhas).

### Criar o .env

```bash
cat > srcs/.env << 'EOF'
DOMAIN_NAME=rsaueia-.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_HOST=mariadb
WP_TITLE=Inception
WP_ADMIN_USER=rsaueia_root
WP_ADMIN_EMAIL=admin@rsaueia-.42.fr
WP_USER=rsaueia_editor
WP_USER_EMAIL=editor@rsaueia-.42.fr
EOF
```

### Configurar /etc/hosts na VM

```bash
sudo sh -c 'echo "127.0.0.1 rsaueia-.42.fr" >> /etc/hosts'
grep rsaueia-.42.fr /etc/hosts
```

---

## 7. Subir o projeto

```bash
cd ~/inception
make
```

Aguarde o build das imagens (pode levar 2–5 minutos na primeira vez).

Verificar:
```bash
docker ps
```

Esperado: três containers rodando — `nginx` (443), `wordpress` (9000), `mariadb` (3306).

---

## 8. Testes obrigatórios

### Teste 1 — Acesso HTTPS pelo terminal da VM

```bash
curl -k https://rsaueia-.42.fr
```

Esperado: HTML do WordPress na resposta.

### Teste 2 — Acesso visual pelo navegador do host

No computador host, abra o Firefox ou Chrome e acesse:

```
https://rsaueia-.42.fr
```

O navegador vai mostrar um aviso de certificado (self-signed) — clique em
"Avançado" / "Aceitar o risco e continuar" para prosseguir.

Esperado: página inicial do WordPress carregando.

Para acessar o painel de administração:

```
https://rsaueia-.42.fr/wp-admin
```

Login com `rsaueia_root` e a senha em `secrets/credentials.txt`.

### Teste 3 — Crash recovery

```bash
docker exec wordpress kill -9 1
sleep 10
docker ps
```

Esperado: `wordpress` aparece novamente com `Up X seconds`.

Repetir para mariadb e nginx:

```bash
docker exec mariadb kill -9 1 ; sleep 10 ; docker ps
docker exec nginx kill -9 1   ; sleep 10 ; docker ps
```

> **Nota para o evaluador:** `docker kill <container>` é tratado como parada
> intencional pelo Docker daemon (equivalente a `docker stop`) e não aciona o
> restart automático — isso é comportamento documentado do Docker 24+, não um
> bug do projeto. O teste correto de crash é `docker exec <container> kill -9 1`,
> que simula a morte inesperada do processo principal.

### Teste 4 — Persistência de dados

```bash
# Derrubar containers sem apagar volumes
docker compose -f srcs/docker-compose.yml down

# Verificar que os dados persistem no disco
ls /home/rsaueia-/data/wordpress
ls /home/rsaueia-/data/mariadb

# Subir de novo
docker compose -f srcs/docker-compose.yml up -d

# Site deve funcionar normalmente
curl -k https://rsaueia-.42.fr
```

### Teste 5 — Nenhuma senha em Dockerfiles

```bash
grep -r "password\|passwd" srcs/requirements/*/Dockerfile
```

Esperado: sem resultados.

### Teste 6 — Usuários do WordPress

```bash
docker exec wordpress wp --allow-root user list --path=/var/www/html
```

Esperado: dois usuários — `rsaueia_root` (administrator) e `rsaueia_editor` (author).
Confirmar que nenhum username contém "admin".

### Teste 7 — Somente porta 443 exposta

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

Esperado: apenas `nginx` com `0.0.0.0:443->443/tcp`. WordPress e MariaDB sem portas externas.

### Teste 8 — TLS: versões antigas rejeitadas

```bash
openssl s_client -connect rsaueia-.42.fr:443 -tls1_1 2>&1 | grep -i "alert\|error"
openssl s_client -connect rsaueia-.42.fr:443 -tls1_2 2>&1 | grep "Protocol"
```

Esperado: TLS 1.1 rejeitado, TLS 1.2 aceito.

---

## 9. Checklist rápida pré-avaliação

```bash
# 1. Três containers rodando
docker ps

# 2. Restart policy correta
docker inspect mariadb wordpress nginx \
    --format '{{.Name}}: {{.HostConfig.RestartPolicy.Name}}'

# 3. Volumes apontam para o path correto
docker volume inspect srcs_wp_data srcs_db_data \
    --format '{{.Name}}: {{.Options.device}}'

# 4. Sem secrets no histórico do git
git log --all --oneline -- secrets/ srcs/.env

# 5. Rede custom bridge (não host)
docker network inspect srcs_inception \
    --format 'Driver: {{.Driver}}'

# 6. Site acessível
curl -sk https://rsaueia-.42.fr | grep -i wordpress
```

---

## Troubleshooting comum

**Containers não sobem — erro de volume:**
```bash
sudo mkdir -p /home/rsaueia-/data/wordpress /home/rsaueia-/data/mariadb
```
O Makefile faz isso automaticamente, mas se executado manualmente é necessário.

**WordPress não conecta ao banco:**
Verifique se as senhas nos secrets são as mesmas usadas na instalação original.
Se mudou as senhas, rode `make fclean` e `make` para reinstalar do zero.

**Site não abre no navegador do host:**
- Verificar se o IP host-only está correto no `/etc/hosts` do computador host
- Verificar se a interface host-only está ativa: `ip addr show enp0s8` na VM
- Verificar se nginx está rodando: `docker ps | grep nginx`

**`make` não encontrado:**
```bash
sudo apt-get install -y make
```
