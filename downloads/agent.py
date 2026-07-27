#!/usr/bin/env python3
"""
SeederLinux Lite - Provisioning Agent
=====================================

Faz check-in periódico com o servidor SeederLinux, enviando informações
da estação e baixando bundles de configuração quando disponíveis.

Uso:
    # Primeiro check-in (registra a estação na OM):
    sudo seeder-agent --org COMARA

    # Check-ins seguintes (token já salvo):
    sudo seeder-agent

    # Dry-run (apenas coleta informações, sem check-in):
    sudo seeder-agent --dry-run

    # Com servidor customizado:
    sudo seeder-agent --org COMARA --server https://seeder.om.local

    # Desabilitar verificação SSL (certificados autoassinados):
    sudo seeder-agent --no-check-certificate

Configuração:
    /etc/seeder/agent.conf        - URL do servidor e opções
    /etc/seeder/station_token     - Token da estação (automático)

Logs:
    /var/log/seeder/agent.log

Cron (recomendado a cada 15 minutos):
    */15 * * * * root /usr/local/bin/seeder-agent >> /var/log/seeder/agent.log 2>&1
"""

import argparse
import json
import os
import sys
import platform
import socket
import ssl
import subprocess
import uuid
from configparser import ConfigParser
from datetime import datetime
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

# --- Constantes ---
CONFIG_DIR = "/etc/seeder"
CONFIG_FILE = os.path.join(CONFIG_DIR, "agent.conf")
TOKEN_FILE = os.path.join(CONFIG_DIR, "station_token")
LOG_FILE = "/var/log/seeder/agent.log"
BUNDLE_CACHE_DIR = "/var/cache/seeder"
BUNDLE_FILE = os.path.join(BUNDLE_CACHE_DIR, "bundle.sh")
CHECKIN_TIMEOUT = 30
DOWNLOAD_TIMEOUT = 60


def log(message, level="INFO"):
    """Escreve mensagem de log com timestamp."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] [{level}] {message}"
    print(line, flush=True)
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except (IOError, PermissionError):
        pass


def load_config(config_path=CONFIG_FILE):
    """Carrega configuração do arquivo agent.conf."""
    config = {
        "url": "https://seederlinux.om.local",
        "no_check_certificate": False,
    }
    if not os.path.exists(config_path):
        return config
    parser = ConfigParser()
    parser.read(config_path)
    if parser.has_section("server"):
        if parser.has_option("server", "url"):
            config["url"] = parser.get("server", "url").strip()
        if parser.has_option("server", "no_check_certificate"):
            raw = parser.get("server", "no_check_certificate").strip().lower()
            config["no_check_certificate"] = raw in ("true", "1", "yes", "on")
    return config


def load_token():
    """Lê o token da estação salvo em disco."""
    if os.path.exists(TOKEN_FILE):
        try:
            with open(TOKEN_FILE, "r") as f:
                token = f.read().strip()
                if token:
                    return token
        except (IOError, PermissionError):
            pass
    return None


def save_token(token):
    """Salva o token da estação em disco."""
    try:
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(TOKEN_FILE, "w") as f:
            f.write(token)
        os.chmod(TOKEN_FILE, 0o600)
        log("Token da estação salvo com sucesso")
    except (IOError, PermissionError) as e:
        log(f"Erro ao salvar token: {e}", "ERROR")


def create_ssl_context(no_check=False):
    """Cria contexto SSL, opcionalmente sem verificação de certificado."""
    if no_check:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        return ctx
    return None


def collect_system_info():
    """Coleta informações do sistema para check-in."""
    hostname = socket.gethostname()

    # Obter IP
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip_address = s.getsockname()[0]
        s.close()
    except Exception:
        ip_address = "127.0.0.1"

    # Obter MAC
    try:
        mac = uuid.getnode()
        mac_address = ":".join(f"{(mac >> ele) & 0xff:02x}" for ele in range(40, -1, -8))
    except Exception:
        mac_address = "00:00:00:00:00:00"

    # Obter SO
    os_name = platform.system()
    os_version = platform.release()
    try:
        if os.path.exists("/etc/os-release"):
            with open("/etc/os-release", "r") as f:
                for line in f:
                    if line.startswith("NAME="):
                        os_name = line.split("=", 1)[1].strip().strip('"')
                    elif line.startswith("VERSION="):
                        os_version = line.split("=", 1)[1].strip().strip('"')
    except Exception:
        pass

    # Obter serial
    serial_number = ""
    try:
        result = subprocess.run(
            ["dmidecode", "-s", "system-serial-number"],
            capture_output=True, text=True, timeout=5
        )
        serial_number = result.stdout.strip()
    except Exception:
        pass

    return {
        "hostname": hostname,
        "os_name": os_name,
        "os_version": os_version,
        "ip_address": ip_address,
        "mac_address": mac_address,
        "serial_number": serial_number,
    }


def checkin(server_url, payload, no_check_cert=False):
    """Envia check-in para o servidor e retorna a resposta JSON."""
    url = f"{server_url}/api/?action=checkin"
    data = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "SeederLinux-Agent/1.2",
    }

    # Adicionar token como Bearer se disponível
    if payload.get("station_token"):
        headers["Authorization"] = f"Bearer {payload['station_token']}"

    req = Request(url, data=data, headers=headers, method="POST")
    ctx = create_ssl_context(no_check_cert)

    try:
        with urlopen(req, timeout=CHECKIN_TIMEOUT, context=ctx) as response:
            body = response.read().decode("utf-8")
            return json.loads(body)
    except HTTPError as e:
        log(f"Erro HTTP {e.code}: {e.reason}", "ERROR")
        try:
            error_body = e.read().decode("utf-8")
            parsed = json.loads(error_body)
            log(f"Mensagem do servidor: {parsed.get('error', error_body)}", "ERROR")
        except Exception:
            pass
        return None
    except URLError as e:
        log(f"Erro de conexão: {e.reason}", "WARNING")
        return None
    except json.JSONDecodeError:
        log("Resposta inválida do servidor (JSON inválido)", "ERROR")
        return None


def download_bundle(server_url, bundle_id, station_token, no_check_cert=False):
    """Baixa um bundle de configuração do servidor."""
    url = f"{server_url}/api/?action=bundle-by-id&id={bundle_id}"
    headers = {"User-Agent": "SeederLinux-Agent/1.2"}
    if station_token:
        headers["Authorization"] = f"Bearer {station_token}"

    req = Request(url, headers=headers, method="GET")
    ctx = create_ssl_context(no_check_cert)

    try:
        with urlopen(req, timeout=DOWNLOAD_TIMEOUT, context=ctx) as response:
            return response.read()
    except HTTPError as e:
        log(f"Erro HTTP {e.code} ao baixar bundle: {e.reason}", "ERROR")
        return None
    except URLError as e:
        log(f"Erro de conexão ao baixar bundle: {e.reason}", "ERROR")
        return None


def execute_bundle(bundle_path):
    """Executa o bundle baixado."""
    try:
        os.chmod(bundle_path, 0o755)
        log(f"Executando bundle: {bundle_path}")
        result = subprocess.run(
            ["bash", bundle_path],
            capture_output=True,
            text=True,
            timeout=1800,
        )
        if result.returncode == 0:
            log("Bundle executado com sucesso")
        else:
            log(f"Bundle executado com erros (código {result.returncode})", "ERROR")
            if result.stderr:
                log(f"Erros: {result.stderr[:500]}", "ERROR")
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        log("Execução do bundle excedeu 30 minutos", "ERROR")
        return False
    except Exception as e:
        log(f"Erro ao executar bundle: {e}", "ERROR")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="SeederLinux Lite - Agente de Provisionamento",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos:
  Primeiro check-in (registra estação na OM):
    sudo seeder-agent --org COMARA

  Check-ins seguintes (token já salvo):
    sudo seeder-agent

  Dry-run (apenas coleta informações):
    sudo seeder-agent --dry-run

  Com servidor customizado:
    sudo seeder-agent --org COMARA --server https://seeder.om.local
        """,
    )
    parser.add_argument("--org", "-o", metavar="ACRONIMO",
                        help="Sigla da organização (obrigatório no primeiro check-in)")
    parser.add_argument("--server", "-s", metavar="URL",
                        help="URL do servidor SeederLinux (sobrescreve agent.conf)")
    parser.add_argument("--no-check-certificate", "-k", action="store_true",
                        help="Desabilitar verificação de certificado SSL")
    parser.add_argument("--dry-run", action="store_true",
                        help="Apenas coleta informações, sem check-in")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Saída detalhada")
    parser.add_argument("--version", action="version", version="SeederLinux Agent 1.2.0")
    args = parser.parse_args()

    # Verificar root
    if os.geteuid() != 0:
        log("ERRO: Este script deve ser executado como root (sudo).", "ERROR")
        sys.exit(1)

    log("=" * 60)
    log("SeederLinux Agent 1.2.0 - Iniciando")

    # Carregar configuração
    config = load_config()
    server_url = args.server or config["url"]
    no_check_cert = args.no_check_certificate or config["no_check_certificate"]

    log(f"Servidor: {server_url}")

    # Coletar informações do sistema
    system_info = collect_system_info()
    log(f"Hostname: {system_info['hostname']}")
    log(f"IP: {system_info['ip_address']}")
    log(f"SO: {system_info['os_name']} {system_info['os_version']}")

    if args.dry_run:
        log("Modo dry-run — pulando check-in")
        if args.verbose:
            log(f"Dados coletados: {json.dumps(system_info, indent=2)}")
        return 0

    # Verificar token existente
    station_token = load_token()
    is_first_run = station_token is None

    if is_first_run and not args.org:
        log("ERRO: Primeiro check-in requer --org <ACRONIMO>", "ERROR")
        log("Exemplo: sudo seeder-agent --org COMARA", "ERROR")
        return 1

    # Montar payload
    payload = system_info.copy()
    if is_first_run:
        payload["organization_acronym"] = args.org.upper()
        log(f"Primeiro check-in — registrando na organização: {args.org.upper()}")
    else:
        payload["station_token"] = station_token
        log(f"Token encontrado: {station_token[:8]}...")

    # Enviar check-in
    log("Enviando check-in...")
    response = checkin(server_url, payload, no_check_cert)

    if response is None:
        log("Check-in falhou — rede pode estar indisponível", "WARNING")
        return 0  # Não considera erro para não quebrar o cron

    if not response.get("success"):
        log(f"Check-in rejeitado: {response.get('error', 'Erro desconhecido')}", "ERROR")
        return 1

    data = response.get("data", {})
    log(f"Check-in OK. Station ID: {data.get('station_id', 'N/A')}")

    # Salvar token se servidor retornou (primeiro check-in)
    returned_token = data.get("station_token")
    if returned_token:
        save_token(returned_token)
        station_token = returned_token

    # Verificar se há atualização
    update_available = data.get("update_available", False)
    bundle_id = data.get("latest_bundle_id")

    if not update_available:
        log("Sistema atualizado. Nenhuma ação necessária.")
        return 0

    if not bundle_id:
        log("Atualização sinalizada mas sem bundle ID", "WARNING")
        return 0

    # Baixar bundle
    log(f"Atualização disponível! Baixando bundle ID: {bundle_id}")
    bundle_content = download_bundle(server_url, bundle_id, station_token, no_check_cert)

    if bundle_content is None:
        log("Falha ao baixar bundle", "ERROR")
        return 1

    # Salvar bundle
    try:
        os.makedirs(BUNDLE_CACHE_DIR, exist_ok=True)
        with open(BUNDLE_FILE, "wb") as f:
            f.write(bundle_content)
        log(f"Bundle salvo em {BUNDLE_FILE} ({len(bundle_content)} bytes)")
    except (IOError, PermissionError) as e:
        log(f"Erro ao salvar bundle: {e}", "ERROR")
        return 1

    # Executar bundle
    success = execute_bundle(BUNDLE_FILE)
    if success:
        log("Provisionamento concluído com sucesso")
        return 0
    else:
        log("Provisionamento concluído com erros", "ERROR")
        return 1


if __name__ == "__main__":
    try:
        exit_code = main()
    except KeyboardInterrupt:
        log("Agente interrompido pelo usuário", "WARNING")
        exit_code = 0
    except Exception as e:
        log(f"Erro inesperado: {e}", "ERROR")
        exit_code = 1
    sys.exit(exit_code)
