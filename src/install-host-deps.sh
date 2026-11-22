#!/usr/bin/env bash

# Script para instalar dependencias do openMSX e do importador de HDD no host Linux (Debian/Ubuntu)

set -euo pipefail

echo "=========================================="
echo "Instalando dependencias do MSX Air"
echo "=========================================="
echo ""

# Verifica se está rodando em Debian/Ubuntu
if ! command -v apt-get &> /dev/null; then
  echo "❌ Sistema nao suportado (requer apt-get)"
  echo "Este script funciona apenas em Debian/Ubuntu e derivados"
  exit 1
fi

# Lista de dependencias criticas.
# Alguns pacotes mudaram de nome entre Debian/Ubuntu; use as alternativas
# abaixo para que o mesmo script funcione em distribuicoes antigas e novas.
declare -a REQUIRED_LIBS=(
  "libsdl2-2.0-0"         # SDL2 library
  "libsdl2-ttf-2.0-0"     # TrueType Font support
  "libsdl2-image-2.0-0"   # Image loading support
  "libsdl2-gfx-1.0-0"     # Graphics support
  "libasound2|libasound2t64" # ALSA audio
  "libgl1-mesa-glx|libgl1"   # OpenGL
  "libegl1"               # EGL
  "libglew2.2"            # OpenGL Extension Wrangler
  "bash"                  # Interpretador dos scripts
  "coreutils"             # realpath, mktemp, cp, mv e rm
  "mtools"                # mcopy e mdir
  "python3"               # Leitura da tabela de particoes
  "util-linux"            # flock
)

package_available() {
  local package="$1"
  local candidate

  candidate=$(apt-cache policy "$package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

echo "[1/2] Atualizando package lists..."
apt update -qq

declare -a PACKAGES_TO_INSTALL=()
declare -a missing_required=()

for package_group in "${REQUIRED_LIBS[@]}"; do
  selected=""
  IFS='|' read -r -a alternatives <<< "$package_group"

  for package in "${alternatives[@]}"; do
    if package_available "$package"; then
      selected="$package"
      break
    fi
  done

  if [[ -n "$selected" ]]; then
    PACKAGES_TO_INSTALL+=("$selected")
  else
    missing_required+=("${alternatives[0]}")
  fi
done

if [[ ${#missing_required[@]} -gt 0 ]]; then
  echo "❌ Pacotes nao encontrados nos repositorios atuais:"
  printf '  - %s\n' "${missing_required[@]}"
  exit 1
fi

echo "[2/2] Instalando dependencias do OpenMSX e do importador de HDD..."
apt install -y --no-install-recommends "${PACKAGES_TO_INSTALL[@]}"

echo ""
echo "=========================================="
echo "✓ Instalacao completa!"
echo "=========================================="
echo ""
echo "Voce pode agora executar:"
echo "  ./src/launch-msxair.sh"
echo "  ./src/importar-hdd.sh arquivo"
echo ""
