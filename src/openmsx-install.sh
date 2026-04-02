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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Comando obrigatorio nao encontrado: $1"
  fi
}

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  error "Este script precisa de privilegios administrativos. Execute como root ou instale o sudo."
}

is_flatpak_available() {
  command -v flatpak >/dev/null 2>&1
}

install_flatpak_if_needed() {
  if is_flatpak_available; then
    log "Flatpak ja esta instalado"
    return 0
  fi

  log "Flatpak nao encontrado. Tentando instalar..."

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${ID:-}" in
      debian|ubuntu)
        require_command apt-get
        run_root apt-get update
        run_root apt-get install -y flatpak
        ;;
      fedora|rhel|centos)
        require_command dnf
        run_root dnf install -y flatpak
        ;;
      arch)
        require_command pacman
        run_root pacman -S flatpak
        ;;
      opensuse*)
        require_command zypper
        run_root zypper install flatpak
        ;;
      *)
        error "Nao foi possivel instalar flatpak automaticamente nesta distribuicao. Instale manualmente e tente novamente."
        ;;
    esac
  else
    error "Nao foi possivel detectar a distribuicao. Instale flatpak manualmente."
  fi

  log "Flatpak instalado com sucesso"
}

add_flathub_remote() {
  if ! flatpak remotes | grep -q flathub; then
    log "Adicionando repositorio flathub..."
    run_root flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}

install_packages_via_flatpak() {
  install_flatpak_if_needed
  add_flathub_remote

  log "Instalando OpenMSX via Flatpak (ultima versao)"
  run_root flatpak install -y --or-update flathub org.openmsx.openMSX
}

ensure_media_dir() {
  local media_dir="${HOME}/MSX/media"
  mkdir -p "${media_dir}"
  log "Diretorio de midias pronto em ${media_dir}"
}

print_next_steps() {
  cat <<'EOF'

Instalacao concluida.

Proximos passos:
1. Ajuste as configuracoes em src/msxair.conf
2. Execute src/launch-msxair.sh para abrir o emulador
3. Se quiser autostart em login, execute src/setup-autostart.sh
EOF
}

main() {
  install_packages_via_flatpak
  ensure_media_dir
  print_next_steps
}

main "$@"
