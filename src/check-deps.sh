#!/usr/bin/env bash

# Script de verificacao de dependencias do host
# Verifica se todas as bibliotecas necessarias para rodar openmsx estao presentes

set -euo pipefail

echo "[DEPS CHECK] Validando dependencias do host..."
echo ""

# Lista de bibliotecas criticas necessarias para openmsx
declare -a REQUIRED_LIBS=(
  "libSDL2-2.0.so.0"
  "libSDL2_ttf-2.0.so.0"
  "libSDL2_image-2.0.so.0"
  "libX11.so.6"
  "libxcb.so.1"
  "libasound.so.2"
  "libGL.so.1"
  "libEGL.so.1"
  "libxml2.so.2"
  "libz.so.1"
)

missing_count=0
present_count=0

# Verifica cada biblioteca no host
for lib in "${REQUIRED_LIBS[@]}"; do
  if ls /lib/x86_64-linux-gnu/"$lib"* 2>/dev/null | head -1 &>/dev/null; then
    echo "[OK] $lib"
    ((present_count++))
  else
    echo "[MISSING] $lib"
    ((missing_count++))
  fi
done

echo ""
echo "========================================="
echo "Presente: $present_count / ${#REQUIRED_LIBS[@]}"
echo "Faltando: $missing_count / ${#REQUIRED_LIBS[@]}"
echo "========================================="

if [[ $missing_count -gt 0 ]]; then
  echo ""
  echo "SOLUCAO: Instalar as dependencias faltando"
  echo "  ./src/install-host-deps.sh"
  echo ""
  echo "Ou manualmente:"
  echo "  sudo apt-get install -y libsdl2-2.0-0 libsdl2-ttf-2.0-0 libsdl2-image-2.0-0"
  echo ""
  exit 1
else
  echo "✓ Todas as dependencias estao presentes!"
  exit 0
fi
