#!/usr/bin/env bash

# Script para garantir que as ROMs estejam disponíveis para o OpenMSX

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
COPY_ROMS_SCRIPT="${SCRIPT_DIR}/copy-systemroms.sh"

# Verifica se está em um container
if [[ ! -f /.dockerenv ]] && [[ ! -f /run/.containerenv ]]; then
  # Não está em container, tenta chamar copy-systemroms.sh para preparar ROMs
  if [[ -f "${COPY_ROMS_SCRIPT}" ]]; then
    log "Preparando system ROMs em ambiente nativo..."
    bash "${COPY_ROMS_SCRIPT}" || {
      warn "Falha ao preparar ROMs. Continuando mesmo assim..."
      exit 0
    }
  else
    warn "Script copy-systemroms.sh nao encontrado em: ${COPY_ROMS_SCRIPT}"
  fi
  exit 0
fi

log "Preparando system ROMs no container..."

# Caminhos esperados
SYSTEMROMS_CONTAINER="/opt/msxair/src/systemroms"
SYSTEMROMS_OPENMSX_HOME="/root/.local/share/openmsx/systemroms"
SYSTEMROMS_OPENMSX_USR="/usr/share/openmsx/systemroms"

# Verifica se as ROMs existem no container
if [[ ! -d "${SYSTEMROMS_CONTAINER}" ]]; then
  warn "System ROMs não encontrado em: ${SYSTEMROMS_CONTAINER}"
  exit 1
fi

# Cria diretório de destino
mkdir -p "$(dirname "${SYSTEMROMS_OPENMSX_HOME}")"
mkdir -p "$(dirname "${SYSTEMROMS_OPENMSX_USR}")"

# Função para garantir link simbólico
ensure_symlink() {
  local target="$1"
  local link_path="$2"
  
  # Se já existe link simbólico correto, ok
  if [[ -L "${link_path}" ]] && [[ "$(readlink "${link_path}")" == "${target}" ]]; then
    log "✓ Link simbólico já existe: ${link_path} -> ${target}"
    return 0
  fi
  
  # Se existe diretório vazio, remove
  if [[ -d "${link_path}" ]] && [[ ! -L "${link_path}" ]]; then
    if [[ $(find "${link_path}" -maxdepth 1 -type f 2>/dev/null | wc -l) -eq 0 ]]; then
      log "  Removendo diretório vazio: ${link_path}"
      rmdir "${link_path}" 2>/dev/null || true
    else
      log "  Diretório com conteúdo já existe: ${link_path}"
      return 0
    fi
  fi
  
  # Remove link antigo se existir
  if [[ -L "${link_path}" ]]; then
    rm "${link_path}"
  fi
  
  # Cria novo link simbólico
  log "  Criando link simbólico: ${link_path} -> ${target}"
  ln -sf "${target}" "${link_path}"
  log "  ✓ Link criado"
}

# Garante link em /root/.local/share/openmsx/systemroms
ensure_symlink "${SYSTEMROMS_CONTAINER}" "${SYSTEMROMS_OPENMSX_HOME}"

# Garante link em /usr/share/openmsx/systemroms (caminho padrão do OpenMSX)
ensure_symlink "${SYSTEMROMS_CONTAINER}" "${SYSTEMROMS_OPENMSX_USR}"

# Valida que temos ROMs disponíveis
if [[ -d "${SYSTEMROMS_OPENMSX_USR}/machines/panasonic" ]]; then
  local rom_count
  rom_count=$(find "${SYSTEMROMS_OPENMSX_USR}/machines/panasonic" -name "*.rom" 2>/dev/null | wc -l)
  log "✓ Encontrado $rom_count arquivo(s) ROM em machines/panasonic"
fi

log "✓ System ROMs preparadas com sucesso!"

