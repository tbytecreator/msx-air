#!/usr/bin/env bash

set -euo pipefail

log() {
  printf '[INFO] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1" >&2
}

error() {
  printf '[ERROR] %s\n' "$1" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Lista de scripts a executar em ordem
declare -a SETUP_SCRIPTS=(
  "install-host-deps.sh"
  "openmsx-install.sh"
  "nooverview-install.sh"
  "copy-systemroms.sh"
  "setup-autostart.sh"
)

log "======================================"
log "Iniciando configuracao do MSX Air 2026"
log "======================================"
log ""

# Executa cada script em sequência
for script in "${SETUP_SCRIPTS[@]}"; do
  script_path="${SCRIPT_DIR}/${script}"
  
  if [[ ! -f "${script_path}" ]]; then
    error "Script nao encontrado: ${script_path}"
  fi
  
  if [[ ! -x "${script_path}" ]]; then
    warn "Script nao tem permissao de execucao, corrigindo: ${script}"
    chmod +x "${script_path}"
  fi
  
  log ""
  log "======================================"
  log "Executando: ${script}"
  log "======================================"
  log ""
  
  if ! bash "${script_path}"; then
    error "Falha na execucao de ${script}. Abortando configuracao."
  fi
  
  log ""
  log "✓ ${script} concluido com sucesso"
  log ""
done

log "======================================"
log "Configuracao do MSX Air 2026 completa!"
log "======================================"
log ""
log "Proximos passos:"
log "1. Execute: ./src/launch-msxair.sh"
log "2. O emulador deve iniciar em tela cheia"
log "3. Aproveite o MSX Turbo-R emulado!"
