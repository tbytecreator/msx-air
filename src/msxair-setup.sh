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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Lista de scripts a executar em ordem (sem launch — executado apos o build Docker)
declare -a SETUP_SCRIPTS=(
  "openmsx-install.sh"
  "nooverview-install.sh"
  "download-nextor-latest.sh"
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
    # download-nextor-latest.sh e opcional — falha nao deve interromper o setup
    if [[ "${script}" == "download-nextor-latest.sh" ]]; then
      warn "Download do Nextor mais recente falhou. Continuando com arquivos existentes."
    else
      error "Falha na execucao de ${script}. Abortando configuracao."
    fi
  fi
  
  log ""
  log "✓ ${script} concluido com sucesso"
  log ""
done

log "======================================"
log "Configuracao do MSX Air 2026 completa!"
log "======================================"
log ""

# Reconstroi a imagem Docker automaticamente se Docker estiver disponivel
if command -v docker >/dev/null 2>&1 && [[ -f "${PROJECT_ROOT}/docker-build.sh" ]]; then
  log "======================================"
  log "Reconstruindo imagem Docker..."
  log "======================================"
  log ""
  if bash "${PROJECT_ROOT}/docker-build.sh"; then
    log ""
    log "✓ Imagem Docker reconstruida com sucesso"
  else
    warn "Falha ao reconstruir imagem Docker. O setup nativo continua valido."
  fi
  log ""
fi

log "Iniciando emulador..."
bash "${SCRIPT_DIR}/launch-msxair.sh"

