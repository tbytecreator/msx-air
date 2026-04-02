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
SYSTEMROMS_SRC="${SCRIPT_DIR}/systemroms"

if [[ ! -d "${SYSTEMROMS_SRC}" ]]; then
  error "Diretorio de system ROMs nao encontrado: ${SYSTEMROMS_SRC}"
fi

# Detecta o local de destino baseado no modo de instalacao do OpenMSX
if command -v openmsx >/dev/null 2>&1; then
  log "openMSX instalado nativamente detectado"
  
  # Tenta encontrar o diretorio de systemroms do OpenMSX
  # Primeiro tenta em ~/.local/share/openmsx/systemroms (instalacao de usuario Flatpak/AppImage)
  # Depois em ~/.openmsx/systemroms (instalacao portavel)
  # Depois tenta descobrir via openmsx -help
  
  SYSTEMROMS_DEST=""
  
  if [[ -d "${HOME}/.local/share/openmsx/systemroms" ]]; then
    SYSTEMROMS_DEST="${HOME}/.local/share/openmsx/systemroms"
  elif [[ -d "${HOME}/.openmsx/systemroms" ]]; then
    SYSTEMROMS_DEST="${HOME}/.openmsx/systemroms"
  else
    # Tenta criar no local padrao ~/.local/share/openmsx/systemroms
    SYSTEMROMS_DEST="${HOME}/.local/share/openmsx/systemroms"
  fi
  
  log "Local de destino: ${SYSTEMROMS_DEST}"
  
  mkdir -p "${SYSTEMROMS_DEST}"
  
  log "Copiando system ROMs de ${SYSTEMROMS_SRC} para ${SYSTEMROMS_DEST}"
  cp -av "${SYSTEMROMS_SRC}"/* "${SYSTEMROMS_DEST}/"
  
  log "System ROMs copiadas com sucesso!"
  
elif command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q "org.openmsx.openMSX"; then
  log "openMSX instalado via Flatpak detectado"
  
  # Para Flatpak, as ROMs devem estar em ~/.openMSX/share/systemroms
  # Veja: https://flathub.org/apps/org.openmsx.openMSX
  SYSTEMROMS_DEST="${HOME}/.openMSX/share/systemroms"
  
  log "Local de destino: ${SYSTEMROMS_DEST}"
  
  mkdir -p "${SYSTEMROMS_DEST}"
  
  log "Copiando system ROMs de ${SYSTEMROMS_SRC} para ${SYSTEMROMS_DEST}"
  cp -av "${SYSTEMROMS_SRC}"/* "${SYSTEMROMS_DEST}/"
  
  log "System ROMs copiadas com sucesso!"
  
else
  error "openMSX nao encontrado. Execute ./openmsx-install.sh primeiro."
fi
