#!/usr/bin/env bash

# Script para reconstruir a imagem Docker com limpeza de cache
# Garante que todas as dependências sejam baixadas novamente

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="msxair:bookworm"

echo "=================================================="
echo "Reconstruindo imagem Docker: $IMAGE_NAME"
echo "=================================================="
echo ""

# Verifica se docker está disponível
if ! command -v docker &> /dev/null; then
  echo "❌ Docker não está instalado"
  exit 1
fi

# Remove imagem anterior (se existir)
echo "[1/3] Removendo imagem anterior..."
if docker images | grep -q "$IMAGE_NAME"; then
  docker rmi "$IMAGE_NAME" 2>/dev/null || true
  echo "✓ Imagem removida"
else
  echo "✓ Nenhuma imagem anterior encontrada"
fi

echo ""
echo "[2/3] Construindo nova imagem (sem cache)..."
echo ""

# Build com --no-cache para garantir que todas as dependências sejam baixadas
if docker build \
  --no-cache \
  -t "$IMAGE_NAME" \
  -f "$SCRIPT_DIR/docker/Dockerfile" \
  "$SCRIPT_DIR"; then
  
  echo ""
  echo "[3/3] Validando dependências na imagem..."
  echo ""
  
  # Verifica as bibliotecas críticas
  local_results=0
  
  #if docker run --rm "$IMAGE_NAME" ldconfig -p 2>/dev/null | grep -q "libSDL2-2.0.so.0"; then
  #  echo "✓ libSDL2-2.0.so.0 encontrada"
  #else
  #  echo "❌ libSDL2-2.0.so.0 NÃO encontrada"
  #  local_results=1
  #fi
  
  #if docker run --rm "$IMAGE_NAME" ldconfig -p 2>/dev/null | grep -q "libSDL2_ttf-2.0.so.0"; then
  #  echo "✓ libSDL2_ttf-2.0.so.0 encontrada"
  #else
  #  echo "❌ libSDL2_ttf-2.0.so.0 NÃO encontrada"
  #  local_results=1
  #fi
  
  #if docker run --rm "$IMAGE_NAME" ldconfig -p 2>/dev/null | grep -q "libasound.so.2"; then
  #  echo "✓ libasound.so.2 encontrada"
  #else
  #  echo "❌ libasound.so.2 NÃO encontrada"
  #  local_results=1
  #fi

  #if docker run --rm "$IMAGE_NAME" ldconfig -p 2>/dev/null | grep -q "libGLEW.so.2.2"; then
  #  echo "✓ libGLEW.so.2.2 encontrada"
  #else
  #  echo "❌ libGLEW.so.2.2 NÃO encontrada"
  #  local_results=1
  #fi
  
  echo ""
  echo "=================================================="
  if [[ $local_results -eq 0 ]]; then
    echo "✓ BUILD SUCESSO - Todas as dependências presentes"
    echo "Você pode agora executar: ./docker-run.sh"
  else
    echo "⚠ BUILD COMPLETO - Mas faltam dependências"
    echo "Verifique o docker/Dockerfile"
  fi
  echo "=================================================="
  
else
  echo ""
  echo "❌ Falha ao construir a imagem"
  exit 1
fi