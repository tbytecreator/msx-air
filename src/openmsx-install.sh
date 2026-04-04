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

is_openmsx_installed() {
  command -v openMSX >/dev/null 2>&1
}

get_openmsx_version() {
  openMSX --version 2>/dev/null | head -n1 || echo "unknown"
}

verify_openmsx() {
  if is_openmsx_installed; then
    log "OpenMSX ja esta instalado: $(get_openmsx_version)"
    return 0
  fi
  return 1
}

is_flatpak_installed() {
  command -v flatpak >/dev/null 2>&1
}

setup_flathub_remote() {
  if ! flatpak remotes 2>/dev/null | grep -q flathub; then
    log "Adicionando repositorio flathub..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null
  fi
}

try_install_via_flatpak() {
  if ! is_flatpak_installed; then
    warn "Flatpak nao esta disponivel, tentando apt..."
    return 1
  fi

  log "Tentando instalar OpenMSX via Flatpak..."
  
  if ! setup_flathub_remote 2>/dev/null; then
    warn "Falha ao configurar flathub remote"
    return 1
  fi

  if ! flatpak install -y --or-update flathub org.openmsx.openMSX 2>&1; then
    warn "Falha na instalacao via Flatpak (ambiente pode ser restrito)"
    return 1
  fi

  log "OpenMSX instalado com sucesso via Flatpak"
  return 0
}

try_install_via_apt() {
  log "Tentando instalar OpenMSX via apt..."
  
  if ! apt-get update 2>&1; then
    warn "Falha ao atualizar cache de apt"
    return 1
  fi

  if ! apt-get install -y openmsx 2>&1; then
    warn "Falha na instalacao via apt"
    return 1
  fi

  log "OpenMSX instalado com sucesso via apt"
  return 0
}

install_openmsx() {
  # Verifica se ja esta instalado
  if verify_openmsx; then
    return 0
  fi

  warn "OpenMSX nao esta instalado"
  
  # Tenta Flatpak primeiro
  if try_install_via_flatpak; then
    return 0
  fi

  # Se Flatpak falhou, tenta apt
  if try_install_via_apt; then
    return 0
  fi

  # Ambas as tentativas falharam
  error "Nao foi possivel instalar OpenMSX via Flatpak nem via apt"
}

ensure_media_dir() {
  local media_dir="${HOME}/MSX/media"
  mkdir -p "${media_dir}"
  log "Diretorio de midias pronto em ${media_dir}"
}

print_next_steps() {
  cat <<'EOF'

Instalacao/verificacao do OpenMSX concluida.

Proximos passos:
1. Ajuste as configuracoes em src/msxair.conf
2. Execute src/launch-msxair.sh para abrir o emulador
3. Se quiser autostart em login, execute src/setup-autostart.sh
EOF
}

main() {
  install_openmsx
  ensure_media_dir
  print_next_steps
}

main "$@"
