# Documento de Especificação e Estado Atual do Sistema

## SeederLinux Lite

**Versão do Documento:** 2.0  
**Data de Geração:** 21 de Julho de 2026  
**Status:** Em Desenvolvimento (Fase Final de MVP)  

---

## Índice

1. [Visão Geral do Produto](#1-visão-geral-do-produto)
2. [Stack Tecnológica e Ambiente](#2-stack-tecnológica-e-ambiente)
3. [Arquitetura e Design Técnico](#3-arquitetura-e-design-técnico)
4. [Guia de Implementação Atual (Estado "As-Is")](#4-guia-de-implementação-atual-estado-as-is)
5. [Backlog de Funcionalidades Planejadas (Estado "To-Be")](#5-backlog-de-funcionalidades-planejadas-estado-to-be)
6. [Regras de Negócio e Decisões Críticas](#6-regras-de-negócio-e-decisões-críticas)

---

## 1. Visão Geral do Produto

### 1.1 Resumo

O **SeederLinux Lite** é um sistema de provisionamento automatizado de estações Linux com integração a Active Directory, concebido para ambientes militares multi-organizacionais (OMs). O sistema gera **bundles** — scripts shell autônomos que configuram uma estação Linux do zero, realizando ingresso no AD, instalação de pacotes, configuração de proxy, navegadores, impressoras, VNC, Conky, branding e scripts de logon/logoff persistentes.

O sistema substitui o projeto anterior **SoftwareLivre**, que consistia em scripts Bash monolíticos com valores hardcoded. O SeederLinux Lite introduz um painel web administrativo, banco de dados PostgreSQL, 17 scripts Core modulares com placeholders `{{VARIAVEL}}`, e um agente Python para check-in periódico.

### 1.2 Problema que Resolve

- Elimina a necessidade de scripts Bash com valores fixos (IPs, domínios, siglas)
- Centraliza a gestão de múltiplas OMs em uma única interface
- Permite que operadores sem conhecimento de shell scripting provisionem estações
- Garante conformidade contínua através de scripts de logon/logoff persistentes
- Opera offline após o download do bundle

### 1.3 Perfis de Usuário (RBAC)

| Perfil | Descrição | Permissões |
|--------|-----------|------------|
| `admin_gap` | Administrador global | CRUD completo: OMs, usuários, scripts, variáveis, bundles, auditoria |
| `operador_om` | Operador vinculado a uma OM | Gerencia apenas sua própria OM: variáveis, scripts customizados, bundles |
| `auditor` | Auditoria e leitura | Visualização global de usuários, auditoria e bundles (sem escrita) |

---

## 2. Stack Tecnológica e Ambiente

### 2.1 Tecnologias

| Componente | Tecnologia | Versão | Observações |
|------------|-----------|--------|-------------|
| Backend | PHP | 8+ | API monolítica em `api/index.php` (~1464 linhas). Sem framework. |
| Banco de Dados | PostgreSQL | 16+ | 10 tabelas. Conexão via PDO. |
| Frontend | HTML5 + CSS3 + JavaScript | - | Vanilla JS, sem frameworks. Fetch API para comunicação. |
| CSS | CSS customizado | - | Paleta escura (`#0f172a`, `#1e293b`, `#f1f5f9`). Fontes: Inter, JetBrains Mono. |
| Scripts Core | Bash | 5+ | 17 scripts modulares com placeholders `{{VARIAVEL}}`. |
| Agente | Python | 3.6+ | Stdlib apenas (sem dependências externas). |
| Servidor Web | Apache 2.4 | 2.4+ | Com mod_ssl, mod_rewrite. VirtualHost com SSL (certificado snakeoil para dev). |
| SO Servidor | Debian 13 (Trixie) | - | Ou Ubuntu 22.04+. Instalador (`install.sh`) detecta a versão. |

### 2.2 Bibliotecas e Dependências Específicas

- **PHP:** `php-pgsql`, `php-mbstring`, `php-xml`, `php-curl`, `php-zip`, `php-gd`
- **PostgreSQL:** `postgresql`, `postgresql-contrib`
- **Apache:** `libapache2-mod-php`
- **Sistema (instaladas pelo bundle):** `sssd`, `realmd`, `adcli`, `samba`, `krb5-user`, `x11vnc`, `conky-all`, `ocsinventory-agent`, `cups`

### 2.3 Estrutura de Diretórios do Projeto

```
seederlinux-lite/
├── api/
│   └── index.php              # API REST monolítica (todos os endpoints)
├── assets/
│   ├── css/style.css          # Estilos customizados (Tailwind removido)
│   ├── js/
│   │   ├── app.js             # Objeto API (fetch wrapper), Toast, Utils
│   │   └── admin.js           # Lógica completa do painel admin (~1700 linhas)
│   ├── images/
│   │   ├── seederlinux-logo.png
│   │   └── distros/           # Logos SVG das distros (debian, ubuntu, linuxmint, zorin)
│   ├── wallpapers/            # Wallpapers enviados por OM
│   └── logos/                 # Logos enviados por OM
├── scripts/core/              # 17 scripts Core (.sh)
│   ├── core_dns.sh            # 01 - DNS, NTP, hostname
│   ├── core_repositories.sh   # 02 - Repositórios APT
│   ├── core_packages.sh       # 03 - Instalação de TODOS os pacotes
│   ├── core_apps.sh           # 04 - Chrome, OnlyOffice, Chromium
│   ├── core_legados.sh        # 05 - Java 8, Firefox 52.7 ESR
│   ├── core_domain.sh         # 06 - Ingresso no AD (SSSD + Winbind fallback)
│   ├── core_browser.sh        # 07 - Políticas Firefox/Chrome/Chromium
│   ├── core_inventory.sh      # 08 - OCS Inventory Agent
│   ├── core_printers.sh       # 09 - CUPS e impressoras
│   ├── core_vnc.sh            # 10 - x11vnc
│   ├── core_conky.sh          # 11 - Conky
│   ├── core_config.sh         # 12 - Arquivo persistente /etc/seederlinux/config.env
│   ├── core_branding.sh       # 13 - Wallpaper, logo, tema (por DE)
│   ├── core_logon.sh          # 14 - Script permanente de logon (multi-DE)
│   ├── core_logoff.sh         # 15 - Script permanente de logoff
│   ├── core_session_lightdm.sh # 16a - LightDM
│   ├── core_session_gdm3.sh   # 16b - GDM3
│   ├── core_session_sddm.sh   # 16c - SDDM
│   └── core_proxy.sh          # 17 - Proxy (último script)
├── admin.html                 # Painel administrativo (HTML único, múltiplas views)
├── login.html                 # Tela de login
├── index.html                 # Página pública com bundles disponíveis
├── lib/
│   ├── config.php             # Configuração (carrega .env manualmente) — NÃO ALTERAR
│   ├── db.php                 # Classe Database (PDO, singleton, transações)
│   └── functions.php          # Helpers: requireAuth, sanitizeInput, log_audit, substituir_placeholders
├── install/
│   ├── install.sh             # Instalador automático (detecta Debian/Ubuntu)
│   ├── schema.sql             # Schema completo do banco (tabelas + seed data genérico)
│   ├── insert_core_scripts.sql # 19 scripts Core com dollar-quoting + UPDATEs de placeholders
│   ├── agent_install.sh       # Instalador do agente na estação
│   └── migration_add_bundle_description.sql # Migration para coluna description
├── downloads/
│   └── agent.py               # Agente Python de check-in
├── storage/logs/              # Logs do sistema
├── lixeira/                   # Arquivos obsoletos (debug.html, schemas antigos, etc.)
└── .env                       # Credenciais de ambiente (DB_HOST, DB_NAME, DB_USER, DB_PASS)
```

---

## 3. Arquitetura e Design Técnico

### 3.1 Modelo Arquitetural

**Monólito Modular.** O backend é um único arquivo PHP (`api/index.php`) que contém todos os endpoints, organizados em funções handler separadas. O frontend é HTML/JS vanilla com múltiplas views controladas por `showView()`.

### 3.2 Diagrama de Fluxo de Dados

```
┌─────────────────────────────────────────────────────────────────┐
│                        SERVIDOR CENTRAL                          │
│                                                                  │
│  ┌──────────────┐    HTTP/HTTPS    ┌──────────────────────────┐  │
│  │ Frontend     │ ←──────────────→ │ api/index.php (PHP)      │  │
│  │ (admin.html) │                  │                          │  │
│  │ + admin.js   │                  │ ┌──────────────────────┐ │  │
│  └──────────────┘                  │ │ handleGenerateBundle │ │  │
│                                    │ │ handleCreateOrg      │ │  │
│                                    │ │ handleLogin          │ │  │
│                                    │ │ ... (30+ handlers)   │ │  │
│                                    │ └──────────┬───────────┘ │  │
│                                    └────────────┼─────────────┘  │
│                                                 │                │
│                                    ┌────────────┴─────────────┐  │
│                                    │ PostgreSQL 16+           │  │
│                                    │                          │  │
│                                    │ Tabelas:                 │  │
│                                    │ - organizations          │  │
│                                    │ - users + user_tokens    │  │
│                                    │ - variable_definitions   │  │
│                                    │ - organization_variables │  │
│                                    │ - scripts                │  │
│                                    │ - deploy_bundles         │  │
│                                    │ - stations               │  │
│                                    │ - audit_events           │  │
│                                    └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                     │
                          HTTPS (REST API)
                                     │
┌─────────────────────────────────────────────────────────────────┐
│                       ESTAÇÃO LINUX                              │
│                                                                  │
│  ┌──────────────┐    ┌──────────────────────────────────────┐   │
│  │ agent.py     │    │ bundle.sh (gerado pelo servidor)      │   │
│  │              │    │                                      │   │
│  │ - check-in   │    │ 01. core_dns.sh                      │   │
│  │ - download   │───→│ 02. core_repositories.sh             │   │
│  │ - execução   │    │ 03. core_packages.sh                 │   │
│  └──────────────┘    │ ...                                  │   │
│                      │ 17. core_proxy.sh                    │   │
│                      └──────────────────────────────────────┘   │
│                                      │                          │
│                                      ▼                          │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Scripts Permanentes (pós-bundle)                          │ │
│  │ - /usr/local/bin/seederlinux-logon (a cada login)         │ │
│  │ - /usr/local/bin/seederlinux-logoff (a cada logoff)       │ │
│  │ - /etc/seederlinux/config.env (configuração persistente)  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Modelagem do Banco de Dados

#### Tabela: `organizations`
| Coluna | Tipo | Restrições | Descrição |
|--------|------|-----------|-----------|
| id | SERIAL | PRIMARY KEY | Identificador único |
| name | VARCHAR(200) | NOT NULL | Nome completo da OM |
| acronym | VARCHAR(20) | UNIQUE, NOT NULL | Sigla (ex: COMARA) |
| domain | VARCHAR(100) | - | Domínio AD (ex: comara.intraer) |
| description | TEXT | - | Descrição da OM |
| is_active | BOOLEAN | DEFAULT true | Status da OM |
| serial_config | INTEGER | DEFAULT 1 | Incrementado ao alterar configurações |
| logo_url | TEXT | - | URL do logo da OM |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de criação |
| updated_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de atualização |

#### Tabela: `users`
| Coluna | Tipo | Restrições | Descrição |
|--------|------|-----------|-----------|
| id | SERIAL | PRIMARY KEY | Identificador único |
| username | VARCHAR(100) | UNIQUE, NOT NULL | Nome de usuário para login |
| password_hash | VARCHAR(255) | NOT NULL | Hash bcrypt da senha |
| full_name | VARCHAR(200) | - | Nome completo |
| email | VARCHAR(200) | - | Email do usuário |
| role | VARCHAR(50) | NOT NULL, DEFAULT 'operador_om' | admin_gap, operador_om, auditor |
| organization_id | INTEGER | FK → organizations(id) | OM vinculada (NULL para admin_gap) |
| is_active | BOOLEAN | DEFAULT true | Status do usuário |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de criação |
| updated_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de atualização |

#### Tabela: `user_tokens`
| Coluna | Tipo | Restrições | Descrição |
|--------|------|-----------|-----------|
| id | SERIAL | PRIMARY KEY | Identificador único |
| user_id | INTEGER | FK → users(id) ON DELETE CASCADE | Usuário vinculado |
| token_hash | VARCHAR(255) | NOT NULL | Hash do token Bearer (password_hash) |
| expires_at | TIMESTAMP | DEFAULT NOW() + 24h | Expiração do token |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de criação |

#### Tabela: `variable_definitions`
| Coluna | Tipo | Restrições | Descrição |
|--------|------|-----------|-----------|
| id | SERIAL | PRIMARY KEY | Identificador único |
| name | VARCHAR(100) | UNIQUE, NOT NULL | Nome da variável (ex: DOMINIO) |
| placeholder | VARCHAR(150) | UNIQUE, NOT NULL | Placeholder (ex: DOMINIO) |
| description | TEXT | - | Descrição da variável |
| type | VARCHAR(50) | DEFAULT 'string' | Tipo: string, boolean, array, url, ip, password, select |
| category | VARCHAR(100) | - | Categoria: Dominio, Rede, Proxy, etc. |
| is_required | BOOLEAN | DEFAULT false | Se a variável é obrigatória |
| default_value | TEXT | - | Valor padrão |
| display_order | INTEGER | DEFAULT 0 | Ordem de exibição |

#### Tabela: `organization_variables`
| Coluna | Tipo | Restrições | Descrição |
|--------|------|-----------|-----------|
| id | SERIAL | PRIMARY KEY | Identificador único |
| organization_id | INTEGER | FK → organizations(id) ON DELETE CASCADE | OM vinculada |
| variable_id | INTEGER | FK → variable_definitions(id) ON DELETE CASCADE | Variável vinculada |
| value | TEXT | - | Valor da variável para esta OM |
| UNIQUE | (organization_id, variable_id) | - | Uma OM não pode ter valores duplicados para a mesma variável |

#### Tabela: `scripts`
| Coluna | Tipo | Restrições | Descrição |
|--------|------|-----------|-----------|
| id | SERIAL | PRIMARY KEY | Identificador único |
| name | VARCHAR(200) | NOT NULL | Nome do script |
| filename | VARCHAR(200) | UNIQUE | Nome do arquivo (ex: core_dns.sh) |
| description | TEXT | - | Descrição do script |
| content | TEXT | NOT NULL | Conteúdo completo do script |
| is_core | BOOLEAN | DEFAULT false | Se é script Core (imutável) |
| is_active | BOOLEAN | DEFAULT true | Se está ativo |
| execution_order | INTEGER | DEFAULT 0 | Ordem de execução no bundle |
| version | INTEGER | DEFAULT 1 | Versão do script |
| organization_id | INTEGER | FK → organizations(id) | NULL para scripts Core |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de criação |
| updated_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de atualização |

#### Tabela: `deploy_bundles`
| Coluna | Tipo | Restrições | Descrição |
|--------|------|-----------|-----------|
| id | SERIAL | PRIMARY KEY | Identificador único |
| organization_id | INTEGER | FK → organizations(id) | OM vinculada |
| user_id | INTEGER | FK → users(id) ON DELETE SET NULL | Usuário que gerou |
| filename | VARCHAR(255) | - | Nome do arquivo |
| description | TEXT | - | Descrição do bundle |
| content | TEXT | NOT NULL | Conteúdo completo do bundle |
| script_ids | TEXT | - | JSON com IDs dos scripts incluídos |
| scripts_count | INTEGER | DEFAULT 0 | Quantidade de scripts |
| is_active | BOOLEAN | DEFAULT true | Se está disponível publicamente |
| generated_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data de geração |

#### Tabela: `stations`
| Coluna | Tipo | Restrições | Descrição |
|--------|------|-----------|-----------|
| id | SERIAL | PRIMARY KEY | Identificador único |
| organization_id | INTEGER | FK → organizations(id) | OM vinculada |
| hostname | VARCHAR(200) | - | Hostname da estação |
| ip_address | VARCHAR(50) | - | Endereço IP |
| mac_address | VARCHAR(50) | - | Endereço MAC |
| os_name | VARCHAR(100) | - | Sistema operacional |
| os_version | VARCHAR(50) | - | Versão do SO |
| last_checkin | TIMESTAMP | - | Último check-in |
| status | VARCHAR(50) | DEFAULT 'never_connected' | online, offline, delayed, never_connected |
| configuration_serial | INTEGER | DEFAULT 0 | Serial da configuração aplicada |
| token | TEXT | - | Token de autenticação da estação |

#### Tabela: `audit_events`
| Coluna | Tipo | Restrições | Descrição |
|--------|------|-----------|-----------|
| id | SERIAL | PRIMARY KEY | Identificador único |
| organization_id | INTEGER | - | OM relacionada |
| user_id | INTEGER | - | Usuário que realizou a ação |
| entity_type | VARCHAR(100) | - | Tipo de entidade (organizations, scripts, bundles) |
| entity_id | INTEGER | - | ID da entidade |
| action | VARCHAR(50) | NOT NULL | Ação: CREATE, UPDATE, DELETE, LOGIN, LOGOUT, DEPLOY |
| details | JSONB | DEFAULT '{}' | Detalhes adicionais |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Data do evento |

---

## 4. Guia de Implementação Atual (Estado "As-Is")

### 4.1 Autenticação e Sessão

**Descrição:** Login com username/senha, geração de token Bearer (24h) + sessão PHP. `requireAuth()` aceita tanto token Bearer quanto cookie de sessão.

**Endpoint:** `POST /api/?action=login`
- **Request:** `{"username": "admin", "password": "admin123"}`
- **Response (200):** `{"success": true, "data": {"id": 1, "username": "admin", "role": "admin_gap", "token": "...", "organization_id": null}}`
- **Response (401):** `{"success": false, "error": "Credenciais invalidas"}`
- **Tratamento de erro:** 3 tentativas antes de lockout (não implementado — [A DEFINIR: rate limiting])

**Lógica de negócio:**
1. Recebe `username` e `password`
2. Busca usuário por `username` e `is_active = true`
3. Verifica senha com `password_verify()` (bcrypt)
4. Gera token aleatório: `bin2hex(random_bytes(32))`
5. Salva hash do token em `user_tokens` (expira em 24h)
6. Retorna token + dados do usuário

### 4.2 CRUD de Organizações

**Descrição:** Administração de OMs com geração automática de variáveis padrão.

**Endpoint:** `POST /api/?action=organizations`
- **Request:** `{"name": "Comando da Comara", "acronym": "COMARA", "domain": "comara.intraer", "dc_ip": "10.108.64.51", "dns_primario": "10.108.64.51"}`
- **Response (200):** `{"success": true, "data": {"id": 2, "name": "...", ...}}`
- **Validação:** `acronym` deve ser único. `name` obrigatório.

**Lógica de negócio (criação):**
1. Valida permissão (`admin_gap`)
2. Insere em `organizations`
3. Copia 56+ variáveis de `variable_definitions` para `organization_variables`
4. Preenche valores dinâmicos: `DOMINIO` = domain informado, `OU_PADRAO` = `DC=...,DC=...`, `BASE_URL` = `https://seederlinux.{domain}`, etc.
5. Incrementa `serial_config`

**UI:** Modal "Nova Organização" com campos: Nome, Sigla, Domínio, DC IP, DNS Primário, DNS Secundário. Botão "Editar" (lápis) na tela da OM. Botão "Excluir" com confirmação.

### 4.3 Gerenciamento de Variáveis

**Descrição:** Cada OM tem 56+ variáveis organizadas por categoria. Renderização com controles adequados ao tipo.

**Endpoint:** `GET /api/?action=variables&id={orgId}`
- **Response:** `{"success": true, "data": {"organization": {...}, "variables": [{"id": 1, "name": "DOMINIO", "value": "comara.intraer", "type": "string", ...}]}}`

**Endpoint:** `POST /api/?action=variables-update`
- **Request:** `{"organization_id": 1, "variables": {"1": "novo_valor", "2": "outro_valor"}}`
- **Lógica:** Itera sobre as variáveis, faz `INSERT ... ON CONFLICT (organization_id, variable_id) DO UPDATE`. Incrementa `serial_config`.

**UI:** Abas horizontais por categoria. Controles: toggle (boolean), select (dropdown para PROXY_MODE, REPOSITORY_MODE, etc.), textarea (array), input text (string), input type="url" (url). Campo de busca com filtro em tempo real. Galeria de imagens para WALLPAPER_URL e LOGO_URL com upload e miniaturas clicáveis.

### 4.4 Geração de Bundle

**Descrição:** Motor principal do sistema. Gera um script shell concatenando 17 sub-scripts com placeholders substituídos por valores reais da OM.

**Endpoint:** `POST /api/?action=generate-bundle`
- **Request:** `{"organization_id": 1, "scripts": [1, 2, 3, ...], "description": "Bundle de teste"}`
- **Response (200):** `{"success": true, "data": {"bundle_id": 5, "filename": "bundle_COMARA_20260721_120000.sh", "download_url": "/api/?action=bundle-by-id&id=5", "scripts_count": 17}}`
- **Validação:** Bloqueia se houver placeholders `{{...}}` não resolvidos. Verifica permissão do usuário.

**Lógica de negócio:**
1. Carrega scripts selecionados do banco
2. Carrega variáveis da OM (`organization_variables`)
3. Para cada script, chama `substituir_placeholders($content, $orgId)` — substitui `{{VARIAVEL}}` por valor real
4. Concatena scripts na ordem de `execution_order`
5. Adiciona cabeçalho com verificação de root e seção de export de variáveis
6. Pula variáveis do tipo `password` na export
7. Codifica `ADMIN_PASSWORD_B64` em base64
8. Prefixa URLs de imagens com FQDN do servidor
9. Salva em `deploy_bundles`
10. Desativa bundles anteriores da mesma OM (`UPDATE deploy_bundles SET is_active = FALSE WHERE organization_id = ? AND id != ?`)
11. Incrementa `serial_config`
12. Registra auditoria

**UI:** Aba "Gerar Bundle" com checkboxes para selecionar scripts, campo de descrição (textarea), botão "Gerar Bundle". Galeria de bundles com tabela: Data, Descrição, Scripts, Tamanho, Status, Ações (Download, Ativar/Desativar, Editar descrição, Excluir).

### 4.5 Agente Python (agent.py)

**Descrição:** Script Python que faz check-in periódico no servidor, verifica se há bundle novo, baixa e executa.

**Funcionamento:**
1. **Primeiro run:** `sudo seeder-agent --org COMARA` — envia `organization_acronym` no payload, recebe `station_token`, salva em `/etc/seeder/station_token`
2. **Runs seguintes:** `sudo seeder-agent` — envia token no header `Authorization: Bearer`, verifica `update_available`
3. Se `update_available = true`, baixa bundle via `GET /api/?action=bundle-by-id&id=X`, salva em `/var/cache/seeder/bundle.sh`, executa com `bash`
4. Logs em `/var/log/seeder/agent.log`
5. Cron a cada 15 minutos

**Endpoint:** `POST /api/?action=checkin`
- **Request:** `{"hostname": "estacao1", "os_name": "Linux Mint", "os_version": "22", "ip_address": "10.0.0.1", "mac_address": "AA:BB:CC:DD:EE:FF", "token": "...", "organization_acronym": "COMARA"}`
- **Response:** `{"success": true, "data": {"status": "ok", "station_id": 2, "update_available": true, "latest_bundle_id": 5, "current_serial": 0, "latest_serial": 19}}`

### 4.6 Scripts Core (Bundle)

**Ordem de execução e funcionalidades:**

| Ordem | Script | Funcionalidade |
|-------|--------|---------------|
| 01 | `core_dns.sh` | Configura DNS temporário (internet primeiro), pergunta hostname, configura /etc/hosts, sincroniza NTP |
| 02 | `core_repositories.sh` | Detecta distro (Mint/Ubuntu/Debian/Zorin). Modo PUBLIC mantém padrão. MIRROR configura se habilitado por distro |
| 03 | `core_packages.sh` | Instala TODOS os pacotes: base, autenticação (SSSD, Kerberos, Samba), extras (CUPS, VNC, Conky, OCS, Java 8), Firefox ESR (com fallback). Configura SSH (porta + AllowGroups) |
| 04 | `core_apps.sh` | Instala Chrome (.deb via curl), OnlyOffice (repositório + fallback .deb), Chromium (apt) — apenas se toggles ativos |
| 05 | `core_legados.sh` | Java 8 (com exceções de segurança) e Firefox 52.7 ESR (com plugin Java) — apenas se toggles ativos |
| 06 | `core_domain.sh` | Altera DNS para AD. Kerberos (krb5.conf), Samba (smb.conf). kinit com 4 combinações. realm join (SSSD) com fallback net ads join (Winbind). SSSD com cache offline. NSS, PAM (mkhomedir), sudo para grupos AD |
| 07 | `core_browser.sh` | Políticas Firefox (policies.json + autoconfig), Chrome (JSON), Chromium (JSON). Homepage, proxy, certificados |
| 08 | `core_inventory.sh` | OCS Inventory Agent (apenas se INVENTORY_ENABLED=true). Configura servidor, tag, cron |
| 09 | `core_printers.sh` | CUPS e impressoras (apenas se PRINT_SERVER definido). Adiciona filas, define padrão |
| 10 | `core_vnc.sh` | x11vnc (apenas se VNC_ENABLED=true). Senha fornecida ou aleatória. Serviço systemd |
| 11 | `core_conky.sh` | Conky com configuração dinâmica (JSON). Script de inicialização, autostart por DE |
| 12 | `core_config.sh` | Cria /etc/seederlinux/config.env com variáveis não sensíveis (perm 644) |
| 13 | `core_branding.sh` | Wallpaper, wallpaper login, logo, greeter. Tema GTK. Config por DE (Cinnamon, MATE, GNOME, XFCE, KDE, LXDE) |
| 14 | `core_logon.sh` | Cria script permanente /usr/local/bin/seederlinux-logon. Mapeamento CIFS, atalhos, políticas Firefox/Chrome, exceções Java |
| 15 | `core_logoff.sh` | Cria script permanente /usr/local/bin/seederlinux-logoff. Desmontagem CIFS, limpeza cache, lixeira, processos |
| 16 | `core_session_*.sh` | Configura Display Manager (LightDM/GDM3/SDDM). Apenas 1 executado, detectado automaticamente |
| 17 | `core_proxy.sh` | ÚLTIMO. Configura proxy (apt.conf.d + /etc/environment). Alerta que internet pode exigir autenticação |

**Mecanismos de segurança e controle de fluxo:**
- `set -e` em cada sub-script (aborta em erro não tratado)
- `return 0` em vez de `exit 0` para scripts desativados (não aborta o bundle)
- Verificação de root no cabeçalho: `if [ "$(id -u)" -ne 0 ]; then exit 1; fi`
- Senhas: `ADMIN_PASSWORD_B64` (base64), `VNC_PASSWORD` não exportada no bundle (armazenada em `/etc/seederlinux/secrets.env` perm 600)
- Credenciais do AD: pergunta interativamente se `ADMIN_PASSWORD_B64` vazio; caso contrário, decodifica e usa

### 4.7 Painel Administrativo (admin.html + admin.js)

**Estrutura de Views:**
- `view-dashboard`: 6 cards de estatísticas + tabela de estações recentes + OMs recentes
- `view-organizations`: Grid de cards de OMs com barra de conformidade + campo de busca
- `view-om-detail`: Dashboard da OM + abas (Variáveis, Scripts, Gerar Bundle)
- `view-users`: Tabela de usuários com CRUD via modais
- `view-scripts-core`: Lista de scripts Core (somente leitura)
- `view-stations`: Tabela de estações com status colorido
- `view-audit`: Tabela de eventos de auditoria com filtro por data

**Sidebar:** Menu lateral com itens por role. Logo do sistema. Lista de OMs no sidebar. Botão "Nova OM" (admin_gap).

**Modais:** Nova OM, Editar OM, Novo Usuário, Editar Usuário, Upload Script, Adicionar Variável, Visualizar Script, Editar Script.

**Melhorias de UX aplicadas:**
- Logos das OMs padronizados em 48×48px com `object-fit: cover`
- Toggles para booleanos, selects para opções fixas
- Abas horizontais para categorias de variáveis
- Galeria de imagens para wallpaper/logo com miniaturas clicáveis
- Barra de conformidade (verde/âmbar/vermelho) no dashboard de OMs
- Confirmação antes de excluir (OM, usuário, script, bundle)
- Toast notifications para feedback de ações
- `continue` → `return` no admin.js (linha 623) para evitar quebra de loop
- Proteção de `onerror` em `<img>` contra elementos nulos

### 4.8 Página Pública (index.html)

- Hero section com logo e descrição
- Estatísticas públicas (bundles, organizações, scripts) via endpoint `public-bundles`
- Seção de features (6 cards)
- Tabela de downloads com bundles disponíveis (apenas `is_active = true`)
- Guia de 3 passos para uso
- Tailwind CDN removido — classes utilitárias migradas para `style.css`

---

## 5. Backlog de Funcionalidades Planejadas (Estado "To-Be")

### 5.1 Segurança — Correções P1

| ID | Funcionalidade | Descrição | Status | Motivo do Adiamento | Pré-requisitos |
|----|---------------|-----------|--------|---------------------|----------------|
| SEC-01 | Rate limiting no login | Limitar tentativas de login a 5 por minuto por IP | Planejado - Não Iniciado | MVP funcional é prioridade | Implementar contador em `$_SESSION` ou tabela `login_attempts` |
| SEC-02 | Invalidação de tokens no logout | Ao fazer logout, remover token de `user_tokens` | Planejado - Não Iniciado | MVP funcional é prioridade | Adicionar `DELETE FROM user_tokens WHERE user_id = ?` em `handleLogout()` |
| SEC-03 | Validação de upload por magic-byte | Verificar tipo real do arquivo com `fileinfo` em vez de confiar em `$_FILES['type']` | Planejado - Não Iniciado | MVP funcional é prioridade | Usar `finfo_open(FILEINFO_MIME_TYPE)` no handler de upload |
| SEC-04 | CSRF protection | Adicionar token CSRF nos formulários | Planejado - Não Iniciado | MVP funcional é prioridade | Gerar token em `$_SESSION`, validar no backend |
| SEC-05 | Headers de segurança | X-Frame-Options, X-Content-Type-Options, Strict-Transport-Security | Planejado - Não Iniciado | MVP funcional é prioridade | Adicionar no VirtualHost Apache ou `.htaccess` |
| SEC-06 | Criptografia real do bundle | Substituir base64 por AES-256 com chave derivada do station_token | Planejado - Bloqueado | Depende do agente estar 100% funcional | Agente precisa validar assinatura antes de executar |

### 5.2 Performance — Correções P2

| ID | Funcionalidade | Descrição | Status | Motivo do Adiamento | Pré-requisitos |
|----|---------------|-----------|--------|---------------------|----------------|
| PERF-01 | Índice composto para check-in | `CREATE INDEX idx_bundles_org_active_date ON deploy_bundles(organization_id, is_active, generated_at DESC)` | Planejado - Não Iniciado | MVP funcional é prioridade | Executar migration no banco |
| PERF-02 | Paginação em bundles e auditoria | Adicionar `LIMIT` e `OFFSET` nas queries de listagem | Planejado - Não Iniciado | MVP funcional é prioridade | Adicionar parâmetros `page` e `limit` nos endpoints |
| PERF-03 | Streaming de download de bundle | Usar `fread` em vez de carregar conteúdo inteiro em memória | Planejado - Não Iniciado | Bundles atuais são < 1MB | Refatorar `handleDownloadBundle()` |
| PERF-04 | Otimização do `requireAuth()` | Substituir loop O(n) sobre tokens por índice `token_prefix` | Planejado - Não Iniciado | Número de tokens ainda é baixo | Adicionar coluna `token_prefix` e índice |

### 5.3 UX — Melhorias P2

| ID | Funcionalidade | Descrição | Status | Motivo do Adiamento | Pré-requisitos |
|----|---------------|-----------|--------|---------------------|----------------|
| UX-01 | Substituir `prompt()` por modal HTML | Campo de descrição do bundle usar modal em vez de prompt nativo | Planejado - Não Iniciado | MVP funcional é prioridade | Criar modal `modal-bundle-desc` no admin.html |
| UX-02 | Filtro por descrição na galeria pública | Campo de busca na tabela de bundles públicos | Planejado - Não Iniciado | MVP funcional é prioridade | Adicionar input e lógica de filtro no index.html |
| UX-03 | Sidebar mobile com hamburger | Menu colapsável em telas < 768px | Planejado - Não Iniciado | Uso principal é desktop | Adicionar botão toggle e media query CSS |

### 5.4 Funcionalidades Maiores (V2)

| ID | Funcionalidade | Descrição | Status | Motivo do Adiamento | Pré-requisitos |
|----|---------------|-----------|--------|---------------------|----------------|
| V2-01 | SeederHub | Compartilhamento federado de módulos entre OMs | Planejado - Não Iniciado | Complexidade alta, MVP primeiro | Sistema core 100% funcional |
| V2-02 | Mirror Manager | Criação e gerenciamento de mirrors APT corporativos | Planejado - Não Iniciado | Funcionalidade independente do core | Interface de repositórios já implementada |
| V2-03 | Desired State Management | Compliance contínuo com correção automática de desvios | Planejado - Não Iniciado | Depende do agente e check-in | Agente funcional, serial_config implementado |
| V2-04 | Assinatura criptográfica de bundles | SHA-256 + GPG para verificar integridade | Planejado - Bloqueado | Depende de SEC-06 | Infraestrutura de chaves definida |
| V2-05 | Refatoração modular do api/index.php | Separar handlers em arquivos por domínio | Planejado - Não Iniciado | Não bloqueia funcionalidade | Estabilização do MVP |

---

## 6. Regras de Negócio e Decisões Críticas

### 6.1 Isolamento Multi-OM

- Cada OM tem suas próprias variáveis, scripts customizados e bundles
- `operador_om` só pode ver e modificar dados da sua própria OM
- Scripts Core (`is_core = true`) são globais e imutáveis por OMs
- Bundles gerados para uma OM nunca devem conter dados de outra OM

### 6.2 Placeholders e Substituição

- Scripts Core contêm `{{NOME_VARIAVEL}}` como placeholder
- `substituir_placeholders()` busca o valor em `organization_variables` filtrando por `organization_id`
- Variáveis do tipo `password` não são exportadas na seção de variáveis do bundle
- A geração de bundle é BLOQUEADA se houver qualquer `{{...}}` não resolvido (erro 400)
- Placeholders `{{VARIAVEL}}` (texto descritivo) são substituídos por `VARIAVEL` (sem chaves) via UPDATE no banco

### 6.3 Ordem de Execução dos Scripts

**Decisão:** Pacotes e aplicativos (ordens 03-05) executam ANTES do ingresso no AD (ordem 06). Proxy (ordem 17) executa por ÚLTIMO.

**Justificativa:** Após o ingresso no AD, o DNS é alterado para o DNS do AD (que não resolve internet). Se o proxy for configurado antes, o apt-get exige autenticação (erro 407) e os pacotes restantes falham. Portanto, todos os pacotes devem ser instalados antes, e o proxy só deve ser configurado depois que tudo estiver pronto.

### 6.4 `return 0` vs `exit 0` nos Scripts Condicionais

**Decisão:** Scripts desativados usam `return 0` em vez de `exit 0`.

**Justificativa:** O bundle é um script concatenado. `exit 0` em um sub-script encerra o bundle inteiro, impedindo a execução dos scripts seguintes. `return 0` apenas sai do sub-script atual.

### 6.5 Senha do AD em Base64

**Decisão:** A senha do AD é armazenada como `ADMIN_PASSWORD_B64` (base64) no banco e no bundle.

**Justificativa:** Base64 não é criptografia — é apenas ofuscação. A decisão foi consciente para o MVP, com a recomendação de que o admin deixe o campo vazio e informe a senha interativamente durante a execução do bundle. A solução definitiva (criptografia AES-256) está planejada para V2.

### 6.6 Detecção Automática de Ambiente Gráfico

**Decisão:** O bundle detecta automaticamente o DE e DM em vez de instalar um ambiente pré-determinado.

**Justificativa:** O bundle deve funcionar em estações que já têm um DE instalado. A detecção usa `command -v` (ex: `cinnamon-session`) e `systemctl is-active` (ex: `lightdm`). A instalação de um DE específico é opcional (`INSTALL_DESKTOP=true`).

### 6.7 OM Padrão Genérica na Instalação

**Decisão:** A instalação padrão usa uma OM genérica ("OM Padrão", sigla "OM", domínio "om.local", IPs 10.0.0.x) em vez de dados reais.

**Justificativa:** Evitar vazamento de informações institucionais no código-fonte. O admin deve configurar os dados reais após a instalação.

### 6.8 PostgreSQL vs Supabase

**Decisão:** O sistema usa PostgreSQL local, NUNCA Supabase.

**Justificativa:** Ambientes militares operam offline. Dependência de serviços cloud é inaceitável. O Bolt frequentemente tentou usar Supabase por limitação do ambiente de preview dele — essas tentativas foram sempre rejeitadas.

### 6.9 Frontend Vanilla JS vs React

**Decisão:** Manter HTML/CSS/JS vanilla, sem frameworks.

**Justificativa:** Simplicidade operacional, sem dependências de build (Node.js, npm, Vite). Facilita a manutenção por militares sem conhecimento de frameworks modernos. O Bolt sugeriu React em um momento, mas a decisão foi manter vanilla.

### 6.10 Dollar-Quoting no SQL

**Decisão:** O arquivo `insert_core_scripts.sql` usa dollar-quoting (`$SeederScript$`) do PostgreSQL para evitar problemas de escaping de aspas simples.

**Justificativa:** Os scripts Bash contêm muitas aspas simples. Escapá-las manualmente (`''`) causava erros de sintaxe frequentes. O dollar-quoting permite que o conteúdo do script seja inserido literalmente, sem nenhum escaping.

---

## Apêndice A: Correções Manuais Aplicadas (NÃO DESFAZER)

Estas correções foram feitas manualmente no servidor e precisam ser preservadas em qualquer deploy futuro:

1. **Constraint UNIQUE em `scripts.filename`** — `ALTER TABLE scripts ADD CONSTRAINT scripts_filename_key UNIQUE (filename);`
2. **`continue` → `return` no admin.js linha 623** — Corrige loop quebrado no `renderRepositoryCards()`
3. **`array_merge([$orgId], $selectedScripts)` → `$selectedScripts` no api/index.php linha 741** — Remove parâmetro extra na query de scripts
4. **Query INSERT do bundle com `is_active`** — Coluna adicionada à query na linha 857
5. **`$newStatus = !$bundle['is_active']` → `$currentStatus = $bundle['is_active'] ?? false; $newStatus = $currentStatus ? 'false' : 'true';`** — Corrige toggle booleano no bundle-toggle (linha 1456)
6. **Placeholders `{{VARIAVEL}}`, `{{INSTALL_APPS}}`, `{{INSTALL_LEGADOS}}` eliminados** — UPDATEs no banco e no `insert_core_scripts.sql`
7. **Campo Sigla readonly removido** — `admin.html` linha 458
8. **`conky` genérico removido** — Array `EXTRA_PACKAGES` no `core_packages.sh`
9. **`IFS=$'\n,'` corrigido** — `core_packages.sh` linha 270
10. **Ordens dos scripts atualizadas** — `core_dns.sh=1`, `core_repositories.sh=2`, `core_apps.sh=4`, `core_legados.sh=5`, `core_domain.sh=6`, `core_proxy.sh=17`

---

## Apêndice B: Glossário

| Termo | Definição |
|-------|-----------|
| **Bundle** | Script shell autônomo gerado pelo sistema, contendo 17 sub-scripts concatenados com placeholders substituídos |
| **OM** | Organização Militar — unidade de isolamento administrativo no sistema |
| **Script Core** | Script de provisionamento imutável, mantido centralmente, usado por todas as OMs |
| **Placeholder** | Marcador `{{VARIAVEL}}` nos scripts que é substituído pelo valor real da OM |
| **DE** | Desktop Environment (Cinnamon, MATE, GNOME, XFCE, KDE, LXDE) |
| **DM** | Display Manager (LightDM, GDM3, SDDM) |
| **SSSD** | System Security Services Daemon — método moderno de integração com AD |
| **Winbind** | Componente do Samba para integração Windows — método legado |
| **RBAC** | Role-Based Access Control (admin_gap, operador_om, auditor) |
| **Dollar-quoting** | Sintaxe PostgreSQL (`$tag$...$tag$`) que permite strings literais sem escaping |
