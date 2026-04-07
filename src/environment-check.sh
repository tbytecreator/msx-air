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

check_environment() {
  local in_container=0
  local openmsx_available=0
  local docker_available=0
  local flatpak_available=0
  
  log "Verificando ambiente do sistema..."
  
  # Detecta se esta em um container
  if [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]]; then
    in_container=1
    warn "Ambiente containerizado detectado"
  fi
  
  # Verifica OpenMSX
  if command -v openmsx >/dev/null 2>&1; then
    openmsx_available=1
    log "✓ OpenMSX local disponivel"
  else
    warn "✗ OpenMSX local nao disponivel"
  fi
  
  # Verifica Docker
  if command -v docker >/dev/null 2>&1; then
    docker_available=1
    log "✓ Docker disponivel"
  else
    warn "✗ Docker nao disponivel"
  fi
  
  # Verifica Flatpak
  if command -v flatpak >/dev/null 2>&1; then
    flatpak_available=1
    log "✓ Flatpak disponivel"
  else
    warn "✗ Flatpak nao disponivel"
  fi
  
  # Testa apt-get
  if command -v apt-get >/dev/null 2>&1; then
    if apt-get --version >/dev/null 2>&1; then
      log "✓ apt-get funcional"
    else
      warn "✗ apt-get indisponivel (problemas com bibliotecas)"
    fi
  else
    warn "✗ apt-get nao encontrado"
  fi
  
  # Oferece recomendacao
  echo ""
  log "===== RECOMENDACOES ====="
  
  if [[ ${in_container} -eq 1 ]]; then
    if [[ ${openmsx_available} -eq 1 ]]; then
      log "Voce esta em um container COM OpenMSX instalado"
      log "Execute: launch-msxair.sh"
    else
      log "Voce esta em um container SEM OpenMSX"
      log "Opcoes:"
      log "1. Reinstale o container com: docker-run.sh"
      log "2. Tente instalar em tempo de execucao com: openmsx-install.sh"
    fi
  else
    if [[ ${openmsx_available} -eq 1 ]]; then
      log "OpenMSX esta instalado localmente"
      log "Execute: launch-msxair.sh"
    elif [[ ${docker_available} -eq 1 ]]; then
      log "Docker esta disponivel (recomendado)"
      log "Execute: docker-run.sh"
    elif [[ ${flatpak_available} -eq 1 ]]; then
      log "Flatpak esta disponivel"
      log "Execute: openmsx-install.sh"
    else
      error "Nenhum metodo de instalacao disponivel"
    fi
  fi
  
  echo ""
}

main() {
  check_environment
}

main "$@"
