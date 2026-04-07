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

is_in_container() {
  # Detecta se esta executando em um container
  [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] || [[ -n "${DOCKER_CONTAINER:-}" ]]
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
  
  # Verifica se apt-get esta disponivel
  if ! command -v apt-get >/dev/null 2>&1; then
    warn "apt-get nao esta disponivel no sistema"
    return 1
  fi
  
  # Testa se apt-get pode ser executado
  if ! apt-get --version >/dev/null 2>&1; then
    local apt_error
    apt_error=$(apt-get --version 2>&1 || true)
    if echo "${apt_error}" | grep -q "cannot open shared object file"; then
      warn "apt-get tem problemas com bibliotecas compartilhadas no ambiente atual"
      warn "Isso geralmente indica um ambiente containerizado ou restrito"
      return 1
    fi
    warn "apt-get nao pode ser executado: ${apt_error}"
    return 1
  fi
  
  # Determina se precisa usar sudo
  local apt_cmd="apt-get"
  if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      apt_cmd="sudo apt-get"
    else
      warn "Nao e possivel usar apt-get sem permissoes de root e sudo nao esta disponivel"
      return 1
    fi
  fi
  
  if ! ${apt_cmd} update 2>&1; then
    warn "Falha ao atualizar cache de apt"
    return 1
  fi

  if ! ${apt_cmd} install -y openmsx 2>&1; then
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

  # Se estiver rodando em um container, assume que OpenMSX ja foi instalado no Dockerfile
  if is_in_container; then
    log "Executando dentro de um container Docker"
    log "OpenMSX deve ter sido instalado durante a construcao da imagem (Dockerfile)"
    warn "OpenMSX nao sera instalado novamente neste processo"
    log "Continuando sem paralizar..."
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

  # Ambas as tentativas falharam - oferece alternativas
  warn "Nao foi possivel instalar OpenMSX via Flatpak nem via apt"
  cat <<'EOF'

===== OPCOES PARA USAR OPENMSX =====

** RECOMENDADO PARA ESTE AMBIENTE **
1. Docker (melhor para ambientes restringidos):
   ./docker-run.sh
   (Nao requer instalacao previa de OpenMSX)

ALTERNATIVAS:
2. Instalacao manual via Flatpak:
   flatpak install flathub org.openmsx.openMSX

3. Instalacao nativa por distribuicao:
   - Ubuntu/Debian: sudo apt-get install openmsx
   - Fedora: sudo dnf install openmsx
   - Arch: sudo pacman -S openmsx
   - Gentoo: emerge openmsx

4. Pacotes pre-compilados:
   https://openmsx.org/download

5. Compilacao do codigo-fonte:
   https://github.com/openMSX/openMSX

======================================

DIAGNOSTICO:
- Este ambiente pode ser um container ou estar restringido
- apt-get teve problemas ao carregar suas bibliotecas
- Docker eh a opcao mais confiavel neste caso

EOF
  error "Por favor, use uma das opcoes acima"
}

ensure_media_dir() {
  local media_dir="${HOME}/MSX/media"
  mkdir -p "${media_dir}"
  log "Diretorio de midias pronto em ${media_dir}"
}

main() {
  install_openmsx
  ensure_media_dir
}

main "$@"