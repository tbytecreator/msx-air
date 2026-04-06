#!/usr/bin/env bash

# Script para publicar a imagem Docker no Docker Hub
# Publica para: tbytecreator/msxair

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_IMAGE="msxair:bookworm"
REGISTRY_IMAGE="tbytecreator/msxair"
TAG="${1:-latest}"

echo "=================================================="
echo "Login no Docker Hub                               "
echo "=================================================="
echo ""

docker login

echo "=================================================="
echo "Publicando imagem Docker: $REGISTRY_IMAGE:$TAG"
echo "=================================================="
echo ""

# Verifica se docker está disponível
if ! command -v docker &> /dev/null; then
  echo "❌ Docker não está instalado"
  exit 1
fi

# Verifica se a imagem local existe
if ! docker image inspect "$LOCAL_IMAGE" &>/dev/null; then
  echo "❌ Imagem local '$LOCAL_IMAGE' não encontrada"
  echo "Execute './docker-build.sh' para construir a imagem primeiro"
  exit 1
fi

echo "[1/3] Criando tag para o Docker Hub..."
docker tag "$LOCAL_IMAGE" "$REGISTRY_IMAGE:$TAG"
echo "✓ Tag criada: $REGISTRY_IMAGE:$TAG"
echo ""

# Se a tag não for "latest", também tag como latest
if [ "$TAG" != "latest" ]; then
  echo "[2/3] Criando tag 'latest'..."
  docker tag "$LOCAL_IMAGE" "$REGISTRY_IMAGE:latest"
  echo "✓ Tag criada: $REGISTRY_IMAGE:latest"
  echo ""
  PUSH_COUNT=2
  CURRENT_STEP=3
else
  PUSH_COUNT=1
  CURRENT_STEP=2
fi

echo "[$CURRENT_STEP/$((CURRENT_STEP))] Publicando imagem no Docker Hub..."
docker push "$REGISTRY_IMAGE:$TAG"
echo "✓ Publicada: $REGISTRY_IMAGE:$TAG"

if [ "$TAG" != "latest" ]; then
  docker push "$REGISTRY_IMAGE:latest"
  echo "✓ Publicada: $REGISTRY_IMAGE:latest"
fi

echo ""
echo "=================================================="
echo "✓ Publicação concluída com sucesso!"
echo "=================================================="
echo ""
echo "Imagens disponíveis:"
docker images | grep "$REGISTRY_IMAGE" || echo "Nenhuma imagem encontrada"