#!/usr/bin/env bash

# Script para instalar Gnome Tweaks, Gnome Extensions e a extensão "No Overview at startup"

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
    error "Comando obrigatório não encontrado: $1"
  fi
}

run_as_sudo() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  error "Este script precisa de privilégios administrativos. Execute como root ou instale o sudo."
}

echo "=========================================="
echo "Instalando Gnome Tweaks e Extensões"
echo "=========================================="
echo ""

# Verifica se está rodando em Debian/Ubuntu
if ! command -v apt-get &> /dev/null; then
  error "Sistema não suportado (requer apt-get). Este script funciona apenas em Debian/Ubuntu e derivados"
fi

# Verifica se está em um ambiente GNOME
if [[ -z "${GNOME_DESKTOP_SESSION_ID:-}" ]] && [[ -z "${XDG_CURRENT_DESKTOP:-}" ]]; then
  warn "GNOME Desktop não detectado. Prosseguindo mesmo assim..."
fi

log "Atualizando package lists..."
run_as_sudo apt-get update -qq

log "Instalando Gnome Tweaks..."
run_as_sudo apt-get install -y --no-install-recommends gnome-tweaks

log "Instalando Gnome Extensions..."
run_as_sudo apt-get install -y --no-install-recommends gnome-shell-extensions

log "Instalando dependências para gerenciador de extensões..."
run_as_sudo apt-get install -y --no-install-recommends gnome-shell-extension-manager

log "Instalando extensão 'No Overview at startup'..."

# ID da extensão no site de extensões do GNOME
EXTENSION_ID="no-overview@fthx"
EXTENSION_URL="https://github.com/fthx/no-overview"
GNOME_EXTENSIONS_DIR="${HOME}/.local/share/gnome-shell/extensions"

# Tenta instalar usando git
if command -v git >/dev/null 2>&1; then
  if [[ ! -d "${GNOME_EXTENSIONS_DIR}/${EXTENSION_ID}" ]]; then
    log "Clonando extensão do repositório..."
    mkdir -p "${GNOME_EXTENSIONS_DIR}"
    git clone "${EXTENSION_URL}.git" "${GNOME_EXTENSIONS_DIR}/${EXTENSION_ID}" 2>/dev/null || \
      warn "Falha ao clonar extensão. Você pode instalar manualmente pelo gerenciador."
  else
    log "Extensão já está instalada"
  fi
else
  warn "Git não encontrado. Você pode instalar manualmente pelo gerenciador de extensões."
fi

# Tenta ativar a extensão se gnome-extensions estiver disponível
if command -v gnome-extensions >/dev/null 2>&1; then
  log "Ativando extensão..."
  gnome-extensions enable "${EXTENSION_ID}" 2>/dev/null || \
    warn "Não foi possível ativar automaticamente. Ative pelo gerenciador de extensões."
fi

echo ""
echo "=========================================="
echo "✓ Instalação completa!"
echo "=========================================="
echo ""
echo "Informações:"
echo "  • Extensão 'No Overview at startup' foi instalada"
echo "  • As extensões geralmente requerem reinicialização do GNOME Shell"
echo "  • Para reiniciar: pressione Alt+F2, digite 'r' e confirme"
echo "  • Ou faça logout e login novamente"
echo ""
