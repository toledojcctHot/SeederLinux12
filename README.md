# SeederLinux Lite - Documentação Completa

**Versão:** 2.0 | **Data:** Julho 2026

---

## Visão Geral

O SeederLinux Lite é um sistema de provisionamento automatizado de estações Linux com integração a Active Directory, concebido para ambientes multi-organizacionais (OMs). O sistema gera **bundles** (scripts shell autônomos) que configuram uma estação Linux do zero: ingressam no AD, instalam pacotes, configuram proxy, navegadores, impressoras, VNC, Conky, branding e scripts de logon/logoff persistentes.

### Objetivos Principais

- **Multi-OM:** Cada organização tem seu próprio conjunto de variáveis, branding e scripts
- **Substituição Dinâmica:** Placeholders `{{VARIAVEL}}` nos scripts são preenchidos automaticamente
- **Offline-First:** Bundles `.sh` autônomos executáveis sem conexão de rede
- **Provisionamento Completo:** Do DNS ao proxy, tudo configurado em um único bundle
- **Conformidade Contínua:** Scripts de logon/logoff mantêm as estações atualizadas

---

## Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    SERVIDOR CENTRAL                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Frontend     │  │ API REST     │  │ Motor Bundle │       │
│  │ (HTML/JS)    │  │ (PHP 8)      │  │ (PHP)       │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│           │                │                │                │
│           └────────────────┼────────────────┘               │
│                            │                                 │
│                    ┌───────┴───────┐                        │
│                    │  PostgreSQL  │                        │
│                    └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
                             │
                    HTTPS (REST API)
                             │
┌─────────────────────────────────────────────────────────────┐
│                    ESTAÇÃO LINUX                             │
│  ┌──────────────┐                                           │
│  │ agent.py     │ ──> Check-in a cada 15 min               │
│  │              │ ──> Baixa Bundle .sh                     │
│  │              │ ──> Executa com sudo                      │
│  └──────────────┘                                           │
│  ┌──────────────┐                                           │
│  │ Bundle .sh   │ ──> 17 scripts modulares                 │
│  │              │ ──> Provisionamento completo             │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Tecnologias Utilizadas

| Componente    | Tecnologia                    |
|---------------|-------------------------------|
| Backend       | PHP 8+ (PDO, API monolítica)  |
| Banco de Dados| PostgreSQL 16+                |
| Frontend      | HTML5, CSS3, JavaScript vanilla |
| Scripts Core  | Bash Shell (19 módulos)       |
| Agente        | Python 3 (stdlib only)        |

---

## Estrutura do Projeto

```
seederlinux-lite/
├── api/
│   └── index.php              # API REST (todos os endpoints)
├── assets/
│   ├── css/style.css          # Estilos do painel
│   ├── js/
│   │   ├── app.js             # Utilitários (API, Toast, Utils)
│   │   └── admin.js           # Lógica do painel admin
│   ├── images/
│   │   ├── seederlinux-logo.png
│   │   └── distros/           # Logos das distribuições
│   ├── wallpapers/            # Wallpapers por OM
│   └── logos/                 # Logos por OM
├── scripts/core/              # 17 scripts Core (.sh)
│   ├── core_dns.sh            # 01 - DNS, NTP, hostname
│   ├── core_repositories.sh   # 02 - Repositórios APT
│   ├── core_packages.sh       # 03 - Pacotes essenciais
│   ├── core_apps.sh           # 04 - Chrome, OnlyOffice, Chromium
│   ├── core_legados.sh        # 05 - Java 8, Firefox 52.7 ESR
│   ├── core_domain.sh         # 06 - Ingresso no AD
│   ├── core_browser.sh        # 07 - Políticas Firefox/Chrome
│   ├── core_inventory.sh      # 08 - OCS Inventory
│   ├── core_printers.sh       # 09 - CUPS e impressoras
│   ├── core_vnc.sh            # 10 - x11vnc
│   ├── core_conky.sh          # 11 - Conky
│   ├── core_config.sh         # 12 - Configuração persistente
│   ├── core_branding.sh       # 13 - Wallpaper, logo, tema
│   ├── core_logon.sh          # 14 - Script de logon
│   ├── core_logoff.sh         # 15 - Script de logoff
│   ├── core_session_lightdm.sh # 16a - LightDM
│   ├── core_session_gdm3.sh   # 16b - GDM3
│   ├── core_session_sddm.sh   # 16c - SDDM
│   └── core_proxy.sh          # 17 - Proxy (último)
├── admin.html                 # Painel administrativo
├── login.html                 # Tela de login
├── index.html                 # Página pública
├── lib/
│   ├── config.php             # Configuração (NÃO ALTERAR)
│   ├── db.php                 # Classe Database (PDO)
│   └── functions.php          # Helpers, auth, audit
├── install/
│   ├── install.sh             # Instalador automático
│   ├── schema.sql             # Schema completo do banco
│   ├── insert_core_scripts.sql # Scripts Core (dollar-quoting)
│   └── agent_install.sh       # Instalador do agente
├── downloads/
│   └── agent.py               # Agente Python
├── storage/logs/              # Logs do sistema
├── lixeira/                   # Arquivos obsoletos
└── .env                       # Credenciais de ambiente
```

---

## Instalação

### Pré-requisitos

- Debian 12/13 ou Ubuntu 22.04+
- Acesso root (sudo)
- Conexão com internet (para download de pacotes)

### Instalação Automatizada

```bash
git clone https://github.com/seu-usuario/seederlinux-lite.git
cd seederlinux-lite
sudo bash install/install.sh
```

O instalador realiza:
1. Configuração de repositórios (detecta Debian/Ubuntu)
2. Instalação de Apache2, PHP 8+, PostgreSQL
3. Criação do banco e usuário
4. Aplicação do schema (`install/schema.sql`)
5. Carregamento dos scripts Core (`install/insert_core_scripts.sql`)
6. Configuração do VirtualHost com SSL
7. Ajuste de permissões

### Instalação Manual

```bash
# 1. Instalar dependências
sudo apt update
sudo apt install -y apache2 php php-pgsql php-mbstring php-xml php-curl postgresql

# 2. Criar banco
sudo -u postgres psql << EOF
CREATE DATABASE seederlinux;
CREATE USER seeder WITH PASSWORD 'seeder123';
GRANT ALL PRIVILEGES ON DATABASE seederlinux TO seeder;
GRANT ALL ON SCHEMA public TO seeder;
EOF

# 3. Aplicar schema e carregar scripts
PGPASSWORD=seeder123 psql -h localhost -U seeder -d seederlinux -f install/schema.sql
PGPASSWORD=seeder123 psql -h localhost -U seeder -d seederlinux -f install/insert_core_scripts.sql

# 4. Copiar arquivos e ajustar permissões
sudo cp -r . /var/www/seederlinux-lite/
sudo chown -R www-data:www-data /var/www/seederlinux-lite/
sudo chmod 755 /var/www/seederlinux-lite/scripts/core/*.sh
```

---

## Acesso

- **Painel Admin:** `https://servidor/admin.html`
- **Login:** `https://servidor/login.html`
- **Página Pública:** `https://servidor/`

### Credenciais Padrão

| Campo | Valor |
|-------|-------|
| Usuário | `admin` |
| Senha | `admin123` |

**⚠️ ALTERE A SENHA APÓS O PRIMEIRO LOGIN!**

---

## Painel Administrativo

### Dashboard

Visão geral com 6 cards de estatísticas:
- Organizações cadastradas
- Scripts disponíveis
- Variáveis configuradas
- Bundles gerados no mês
- Estações online
- Estações desatualizadas

### Gerenciamento de OMs

**Criar Nova OM:**
1. Clique em "Nova OM" no menu lateral
2. Preencha: Nome, Sigla, Domínio, DC IP, DNS Primário, DNS Secundário
3. As variáveis padrão são geradas automaticamente com valores baseados nos dados informados

**Dashboard da OM:**
- Ao clicar em uma OM, veja cards com estatísticas específicas
- Barra de conformidade: % de estações atualizadas
- Clique em "Editar Config." para acessar as abas de configuração

### Abas da OM

**Variáveis:**
- Organizadas por categoria (abas horizontais)
- Controles por tipo: toggle (boolean), select (dropdown), textarea (array)
- Upload de wallpaper/logo com galeria de miniaturas
- Campo de busca com filtro em tempo real

**Scripts:**
- Sub-tabs Core/Custom
- Scripts Core são somente leitura
- Scripts Custom podem ser editados e versionados

**Gerar Bundle:**
- Selecione os scripts desejados (checkboxes)
- Adicione uma descrição (opcional)
- Clique em "Gerar Bundle"
- **Galeria de Bundles:** tabela com todos os bundles gerados
  - Download, Ativar/Desativar, Editar descrição, Excluir

---

## Scripts Core (Bundle)

O bundle executa 17 scripts na seguinte ordem:

| Ordem | Script | Função |
|-------|--------|--------|
| 01 | `core_dns.sh` | DNS, NTP, hostname |
| 02 | `core_repositories.sh` | Repositórios APT (detecta distro) |
| 03 | `core_packages.sh` | **TODOS** os pacotes (base, auth, extras) |
| 04 | `core_apps.sh` | Chrome, OnlyOffice, Chromium (antes do AD) |
| 05 | `core_legados.sh` | Java 8, Firefox 52.7 ESR (antes do AD) |
| 06 | `core_domain.sh` | **Ingresso no AD** (muda DNS) |
| 07 | `core_browser.sh` | Políticas Firefox/Chrome |
| 08 | `core_inventory.sh` | OCS Inventory Agent |
| 09 | `core_printers.sh` | CUPS e impressoras |
| 10 | `core_vnc.sh` | x11vnc |
| 11 | `core_conky.sh` | Conky |
| 12 | `core_config.sh` | Arquivo persistente `/etc/seederlinux/config.env` |
| 13 | `core_branding.sh` | Wallpaper, logo, tema (por DE) |
| 14 | `core_logon.sh` | Script permanente de logon |
| 15 | `core_logoff.sh` | Script permanente de logoff |
| 16 | `core_session_*.sh` | Display Manager (apenas 1) |
| 17 | `core_proxy.sh` | Proxy (ÚLTIMO) |

### Funcionalidades do Bundle

#### ✅ Sempre ativas
- DNS e NTP configurados
- Pacotes base, autenticação e complementares instalados
- Ingresso no AD (SSSD com cache offline ou Winbind)
- Criação automática de home (mkhomedir)
- Sudo para grupos do domínio
- Políticas de navegadores (Firefox + Chrome/Chromium)
- Arquivo de configuração persistente
- Scripts de logon/logoff permanentes
- Display Manager configurado
- Proxy (se aplicável)

#### ✅ Opcionais (toggles no painel)
- Google Chrome, OnlyOffice, Chromium
- Java 8 (com exceções), Firefox 52.7 ESR
- OCS Inventory, CUPS, VNC, Conky

#### ✅ Por Ambiente Gráfico
- Wallpaper, logo, tema GTK
- Configurações específicas (Cinnamon, MATE, GNOME, XFCE, KDE, LXDE)

---

## Uso do Agente Python

### Instalação na Estação

```bash
sudo bash install/agent_install.sh
```

### Primeiro Check-in (vincula à OM)

```bash
sudo seeder-agent --org COMARA
```

### Check-ins Subsequentes (já vinculado)

```bash
sudo seeder-agent
```

### Argumentos

| Argumento | Descrição |
|-----------|-----------|
| `--org SIGLA` | Sigla da OM (obrigatório no primeiro run) |
| `--server URL` | URL do servidor |
| `--insecure, -k` | Ignorar certificado SSL autoassinado |
| `--dry-run` | Simular sem executar bundle |
| `--verbose, -v` | Saída detalhada |

### Funcionamento

1. **Primeiro run:** Envia `organization_acronym`, recebe `station_token`
2. **Runs seguintes:** Envia token, verifica `update_available`
3. Se há bundle novo, baixa e executa
4. Logs em `/var/log/seeder/agent.log`
5. Cron: a cada 15 minutos

---

## Variáveis do Catálogo (56+)

### Domínio e Autenticação
`DOMINIO`, `DOMINIO_NETBIOS`, `DC_IP`, `DC_IP_LIST`, `DNS_PRIMARIO`, `DNS_SECUNDARIO`, `NTP_SERVER`, `OU_PADRAO`, `GRUPO_ADMIN`, `AUTH_METHOD`, `OFFLINE_AUTH_ENABLED`, `OFFLINE_AUTH_DAYS`, `ADMIN_USERNAME`, `ADMIN_PASSWORD_B64`

### Rede e Proxy
`PROXY_HTTP`, `PROXY_PORTA`, `PROXY_URL`, `PROXY_MODE`, `PAC_URL`, `NO_PROXY`, `DNS_INTERNET`

### URLs e Servidores
`BASE_URL`, `SEEDER_SERVER`, `HOMEPAGE`, `OCS_SERVER`, `OCS_TAG`, `PRINT_SERVER`, `SERVIDOR_ARQUIVOS`

### Identidade Visual
`OM_ACRONYM`, `OM_NAME`, `DISPLAY_NAME`, `WALLPAPER_URL`, `WALLPAPER_LOGIN_URL`, `LOGO_URL`, `GREETER_URL`, `THEME`, `CONKY_PROFILE`, `CONKY_CONFIG`

### Aplicações
`INSTALL_ONLYOFFICE`, `INSTALL_CHROME`, `INSTALL_CHROMIUM`, `INSTALL_JAVA8`, `INSTALL_FIREFOX52`, `JAVA_EXCEPTIONS`

### Acesso Remoto
`REMOTE_METHOD`, `SSH_PORT`, `SSH_GROUPS`, `VNC_ENABLED`

### Repositórios
`REPOSITORY_MODE`, `REPOSITORY_URL`, `REPOSITORY_FALLBACK`, `REPOSITORY_DEBIAN_ENABLED`, `REPOSITORY_DEBIAN_URL`, `REPOSITORY_UBUNTU_ENABLED`, `REPOSITORY_UBUNTU_URL`, `REPOSITORY_MINT_ENABLED`, `REPOSITORY_MINT_URL`, `REPOSITORY_ZORIN_ENABLED`, `REPOSITORY_ZORIN_URL`

### Compartilhamentos e Impressoras
`COMPARTILHAMENTOS`, `MOUNT_BASE`, `DEFAULT_PRINTER`, `PRINTERS`

### Segurança
`GRUPO_ADMIN_AD`, `GRUPO_ADMIN_LINUX`, `GRUPO_DASTI`, `CERTIFICATE_BUNDLE`, `CERTIFICATE_AUTO_INSTALL`

---

## Troubleshooting

### Erro de Conexão com PostgreSQL
```bash
sudo systemctl status postgresql
PGPASSWORD=seeder123 psql -h localhost -U seeder -d seederlinux -c "SELECT 1;"
```

### Erro 500 no Apache
```bash
sudo tail -f /var/log/apache2/seederlinux-lite_error.log
php -l /var/www/seederlinux-lite/api/index.php
```

### Bundle Não Gera (Erro 400)
```bash
# Verificar placeholders não resolvidos
sudo -u postgres psql -d seederlinux -c "SELECT COUNT(*) FROM scripts WHERE content LIKE '%{{%}}%';"
# Se > 0, executar:
sudo -u postgres psql -d seederlinux -f install/insert_core_scripts.sql
```

### Banco Zerado (0 scripts)
```bash
sudo -u postgres psql -d seederlinux -c "ALTER TABLE scripts ADD CONSTRAINT scripts_filename_key UNIQUE (filename);" 2>/dev/null
sudo -u postgres psql -d seederlinux -f install/insert_core_scripts.sql
```

---

## Segurança

### Recomendações
1. **Senhas:** Altere `admin123` e `seeder123` imediatamente
2. **HTTPS:** Use certificado SSL válido em produção
3. **Firewall:** Permita apenas portas 80/443
4. **Backup:** Configure `pg_dump` diário com cron
5. **Senha AD:** Use base64 apenas para ofuscação — prefira prompt interativo

---

## Backup e Recuperação

```bash
# Backup
pg_dump -U seeder seederlinux > backup_$(date +%Y%m%d_%H%M%S).sql

# Restauração
psql -U seeder seederlinux < backup_20260721_120000.sql
```

---

## Compatibilidade

| Distribuição | Ambiente | Status |
|-------------|----------|--------|
| Linux Mint 22+ | Cinnamon | ✅ Testado |
| Linux Mint 22+ | MATE | ✅ Suportado |
| Ubuntu 24.04+ | GNOME | ✅ Suportado |
| Debian 13+ | XFCE | ✅ Suportado |
| Zorin OS 17+ | GNOME/LXDE | ✅ Suportado |
| KDE Plasma | KDE | ✅ Suportado |

---

**SeederLinux Lite v2.0** — Sistema de Provisionamento Automatizado de Estações Linux
