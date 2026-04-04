#!/usr/bin/env bash

# Script de verificacao de dependencias do host
# Verifica se todas as bibliotecas necessarias para rodar openmsx estao presentes

echo "[DEPS CHECK] Validando dependencias do host..."
echo ""

# Lista de bibliotecas criticas necessarias para openmsx
REQUIRED_LIBS=(
  "libSDL2-2.0.so.0"
  "libSDL2_ttf-2.0.so.0"
  "libSDL2_image-2.0.so.0"
  "libX11.so.6"
  "libxcb.so.1"
  "libasound.so.2"
  "libGL.so.1"
  "libEGL.so.1"
  "libGLEW.so.2.2"
  "libxml2.so.2"
  "libz.so.1"
)

missing_count=0
present_count=0
total_count=${#REQUIRED_LIBS[@]}

# Verifica cada biblioteca no host
for lib in "${REQUIRED_LIBS[@]}"; do
  if ls /lib/x86_64-linux-gnu/"$lib"* >/dev/null 2>&1; then
    echo "[OK] $lib"
    present_count=$((present_count + 1))
  else
    echo "[MISSING] $lib"
    missing_count=$((missing_count + 1))
  fi
done

echo ""
echo "========================================="
echo "Presente: $present_count / $total_count"
echo "Faltando: $missing_count / $total_count"
echo "========================================="

if [ "$missing_count" -gt 0 ]; then
  echo ""
  echo "SOLUCAO: Instalar as dependencias faltando"
  echo "  ./src/install-host-deps.sh"
  echo ""
  echo "Ou manualmente:"
  echo "  sudo apt-get install -y libsdl2-2.0-0 libsdl2-ttf-2.0-0 libsdl2-image-2.0-0 libglew2.2"
  echo ""
  exit 1
else
  echo "✓ Todas as dependencias estao presentes!"
  exit 0
fi
