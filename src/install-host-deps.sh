#!/usr/bin/env bash

# Script para instalar dependencias do openmsx no host Linux (Debian/Ubuntu)

set -euo pipefail

echo "=========================================="
echo "Instalando dependencias do OpenMSX"
echo "=========================================="
echo ""

# Verifica se está rodando em Debian/Ubuntu
if ! command -v apt-get &> /dev/null; then
  echo "❌ Sistema nao suportado (requer apt-get)"
  echo "Este script funciona apenas em Debian/Ubuntu e derivados"
  exit 1
fi

# Lista de dependencias criticas
declare -a REQUIRED_LIBS=(
  "libsdl2-2.0-0"         # SDL2 library
  "libsdl2-ttf-2.0-0"     # TrueType Font support
  "libsdl2-image-2.0-0"   # Image loading support
  "libsdl2-gfx-1.0-0"     # Graphics support
  "libasound2"            # ALSA audio
  "libgl1-mesa-glx"       # OpenGL
)

echo "[1/2] Atualizando package lists..."
sudo apt-get update -qq

echo "[2/2] Instalando bibliotecas SDL2..."
sudo apt-get install -y --no-install-recommends "${REQUIRED_LIBS[@]}"

echo ""
echo "=========================================="
echo "✓ Instalacao completa!"
echo "=========================================="
echo ""
echo "Voce pode agora executar:"
echo "  ./src/launch-msxair.sh"
echo ""
