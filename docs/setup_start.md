# Inception — Setup Session Log

---

## Sessão 1 (2026-05-16) — VM criada, Debian instalado

### O que foi feito

1. Versão Debian escolhida: **bookworm (12)** — penultimate stable, consistente com os Dockerfiles
2. Sgoinfre: `/sgoinfre/rsaueia-/` (caminho absoluto) ou `~/sgoinfre/` (symlink)
3. ISO: Debian 12.13 bookworm netinstall (amd64), salva em `/sgoinfre/rsaueia-/`
4. VirtualBox: Default Machine Folder → `/sgoinfre/rsaueia-`
5. VM criada: nome `inception`, 4 GB RAM, 2 CPUs, 30 GB VDI dinâmico
6. Redes: Adapter 1 NAT com port forwarding `2222 → 22`. Adapter 2 host-only desabilitado (módulo vboxnet não carregado na 42)
7. Debian instalado: hostname `inception`, usuário `rsaueia-`, SSH server, GRUB em `/dev/sda`

---

## Sessão 2 (2026-05-17) — VM configurada, projeto rodando

### O que foi feito

#### Acesso e dependências

- SSH via `ssh -p 2222 rsaueia-@localhost`
- sudo instalado como root: `apt-get install -y sudo && usermod -aG sudo rsaueia-`
- make e Docker Engine instalados (Docker 29.5.0, Compose v5.1.3)
- Usuário adicionado ao grupo docker

#### Chave SSH para o vogsphere

- Host da 42 tem chave RSA em `~/.ssh/id_rsa` (não ed25519)
- Chave copiada do host para a VM via `scp -P 2222`
- Permissão ajustada: `chmod 600 ~/.ssh/id_rsa`
- Clone do vogsphere funcionou: `git clone git@vogsphere.42.rio:vogsphere/intra-uuid-124cdb17-6d99-435b-8a43-27d51211e8c0-7363610-rsaueia- inception`

#### Secrets e .env

- `secrets/` criado manualmente (não commitado)
- `srcs/.env` criado com emails corrigidos:
  - `WP_ADMIN_EMAIL=admin@inception.42.fr`
  - `WP_USER_EMAIL=editor@inception.42.fr`
  - **Motivo:** WP-CLI rejeita `@rsaueia-.42.fr` porque subdomínio termina com hífen (inválido por RFC)

#### Projeto rodando

- `make` executado com sucesso
- Três containers rodando: `nginx` (443), `wordpress` (9000), `mariadb` (3306)
- `curl -k https://rsaueia-.42.fr` retorna HTML do WordPress
- `/etc/hosts` configurado na VM: `127.0.0.1 rsaueia-.42.fr`

#### Interface gráfica

- GNOME instalado: `sudo apt-get install -y task-gnome-desktop`
- Boot configurado para modo gráfico: `sudo systemctl set-default graphical.target`
- Firefox abre `https://rsaueia-.42.fr` dentro da VM — aviso de certificado self-signed esperado, aceita e o WordPress carrega
- `wp-admin` acessível com `rsaueia_root` e senha em `secrets/credentials.txt`

#### Acesso ao navegador (sem host-only)

- `lsmod | grep vboxnet` retornou vazio — módulo não carregado
- Solução: usar o Firefox dentro da própria VM (GNOME)
- Não é necessário host-only nem editar `/etc/hosts` no host

#### Documentação atualizada

Os seguintes arquivos foram corrigidos/atualizados:
- `DEV_DOC.md`: Debian 13 → 12, emails corrigidos
- `README.md`: emails corrigidos
- `CLAUDE.md`: emails corrigidos, nota sobre crash recovery no Docker 29
- `docs/42_setup_guide.md`: adicionado comando de limpeza pré-avaliação (seção 8), teste de Configuration modification (novo na régua), crash recovery atualizado

#### Observação sobre crash recovery

A régua atual **não exige** `docker exec kill -9 1`. O único teste de persistência exigido é o **reboot da VM**. O teste com `kill -9` estava no guia interno mas não na régua oficial.

Adicionalmente: em Docker 29 + kernel 6.1, `docker exec wordpress kill -9 1` não mata o container (regressão conhecida). O método que funciona é:
```bash
sudo kill -9 $(docker inspect wordpress --format '{{.State.Pid}}')
```

---

## O que falta (próxima sessão)

### Testes obrigatórios ainda não executados

1. **Persistência** — reboot da VM e verificar que WordPress e MariaDB sobem com dados intactos:
   ```bash
   sudo reboot
   # após boot, na VM:
   cd ~/inception && make
   curl -k https://rsaueia-.42.fr
   ```

2. **Teste de volumes** — verificar paths corretos:
   ```bash
   docker volume ls
   docker volume inspect srcs_wp_data srcs_db_data
   ```
   Esperado: path contendo `/home/rsaueia-/data/`

3. **Teste de portas** — só nginx exposto:
   ```bash
   docker ps --format "table {{.Names}}\t{{.Ports}}"
   ```

4. **Teste de TLS** — versões antigas rejeitadas:
   ```bash
   openssl s_client -connect rsaueia-.42.fr:443 -tls1_1 2>&1 | grep -i "alert\|error"
   openssl s_client -connect rsaueia-.42.fr:443 -tls1_2 2>&1 | grep "Protocol"
   ```

5. **Checklist pré-avaliação completa** — ver `docs/42_setup_guide.md` seção 10

### Antes da defesa

- Treinar o **Configuration modification test**: o evaluador vai pedir pra mudar a porta de um serviço ao vivo e rebuildar com `make re`
- Preparar respostas para as perguntas conceituais: Docker vs VM, bridge network, named volumes vs bind mounts, Docker secrets vs env vars
