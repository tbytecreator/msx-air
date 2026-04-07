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

# Funcao para detectar se esta executando em um container Docker
is_in_container() {
  [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] || [[ -n "${DOCKER_CONTAINER:-}" ]]
}

# Detecta o local de destino baseado no modo de instalacao do OpenMSX
if is_in_container; then
  log "Executando dentro de um container Docker"
  
  # Em um container, as ROMs ja estao montadas em /opt/msxair/src/systemroms
  # Se estivermos dentro do container durante setup, vamos configurar o link para o OpenMSX
  SYSTEMROMS_CONTAINER="/opt/msxair/src/systemroms"
  SYSTEMROMS_OPENMSX_DEFAULT="/root/.local/share/openmsx/systemroms"
  
  log "System ROMs disponibles em: ${SYSTEMROMS_CONTAINER}"
  
  # Criar link simbolico para facilitar acesso do OpenMSX
  if [[ -d "${SYSTEMROMS_CONTAINER}" ]]; then
    mkdir -p "$(dirname "${SYSTEMROMS_OPENMSX_DEFAULT}")"
    if [[ ! -L "${SYSTEMROMS_OPENMSX_DEFAULT}" ]] && [[ ! -d "${SYSTEMROMS_OPENMSX_DEFAULT}" ]]; then
      log "Criando link simbolico: ${SYSTEMROMS_OPENMSX_DEFAULT} -> ${SYSTEMROMS_CONTAINER}"
      ln -s "${SYSTEMROMS_CONTAINER}" "${SYSTEMROMS_OPENMSX_DEFAULT}"
      log "Link simbolico criado com sucesso!"
    else
      log "Directory ja existe: ${SYSTEMROMS_OPENMSX_DEFAULT}"
    fi
  else
    warn "System ROMs nao encontrado no container em: ${SYSTEMROMS_CONTAINER}"
  fi
  
elif command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q "org.openmsx.openMSX"; then
  log "openMSX instalado via Flatpak detectado"
  
  # Para Flatpak, as ROMs devem estar em ~/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms
  # Este eh o sandbox de dados do Flatpak para OpenMSX
  # Ref: https://flathub.org/apps/org.openmsx.openMSX
  SYSTEMROMS_DEST="${HOME}/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms"
  
  log "Local de destino (Flatpak): ${SYSTEMROMS_DEST}"
  
  mkdir -p "${SYSTEMROMS_DEST}"
  
  log "Copiando system ROMs de ${SYSTEMROMS_SRC} para ${SYSTEMROMS_DEST}"
  cp -av "${SYSTEMROMS_SRC}"/* "${SYSTEMROMS_DEST}/"
  
  log "System ROMs copiadas com sucesso!"
  
elif command -v openmsx >/dev/null 2>&1; then
  log "openMSX instalado nativamente detectado"
  
  # Para instalacao nativa (APT ou similar), procura pelos diretorios padrao
  # Ordem de preferencia:
  # 1. ~/.local/share/openmsx/systemroms (instalacao de usuario, XDG)
  # 2. /usr/share/openmsx/systemroms (instalacao global via apt/pacote)
  # 3. ~/.openmsx/systemroms (instalacao portatil/legado)
  
  SYSTEMROMS_DEST=""
  
  if [[ -d "${HOME}/.local/share/openmsx/systemroms" ]]; then
    SYSTEMROMS_DEST="${HOME}/.local/share/openmsx/systemroms"
    log "Encontrado: ~/.local/share/openmsx/systemroms (usuario XDG)"
  elif [[ -d "/usr/share/openmsx/systemroms" ]]; then
    # Verificar se temos permissao de escrita
    if [[ -w "/usr/share/openmsx/systemroms" ]]; then
      SYSTEMROMS_DEST="/usr/share/openmsx/systemroms"
      log "Encontrado: /usr/share/openmsx/systemroms (global, com permissao)"
    else
      # Se nao temos permissao global, usar ~/.local/share/openmsx/systemroms
      SYSTEMROMS_DEST="${HOME}/.local/share/openmsx/systemroms"
      warn "Sistema tem /usr/share/openmsx/systemroms mas sem permissao. Usando ~/.local/share/openmsx/systemroms"
    fi
  elif [[ -d "${HOME}/.openmsx/systemroms" ]]; then
    SYSTEMROMS_DEST="${HOME}/.openmsx/systemroms"
    log "Encontrado: ~/.openmsx/systemroms (legado/portatil)"
  else
    # Criar no local padrao XDG
    SYSTEMROMS_DEST="${HOME}/.local/share/openmsx/systemroms"
    log "Nenhum diretorio existente. Criando: ${SYSTEMROMS_DEST}"
  fi
  
  log "Local de destino (nativo): ${SYSTEMROMS_DEST}"
  
  mkdir -p "${SYSTEMROMS_DEST}"
  
  log "Copiando system ROMs de ${SYSTEMROMS_SRC} para ${SYSTEMROMS_DEST}"
  cp -av "${SYSTEMROMS_SRC}"/* "${SYSTEMROMS_DEST}/"
  
  log "System ROMs copiadas com sucesso!"
  
else
  error "openMSX nao encontrado. Execute ./openmsx-install.sh primeiro."
fi
