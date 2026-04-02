#!/usr/bin/env bash

set -euo pipefail

# Detecta o ambiente gráfico em uso
detect_display_server() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "wayland"
  elif [[ -n "${DISPLAY:-}" ]]; then
    echo "x11"
  else
    echo "unknown"
  fi
}

# Encontra o caminho do socket Wayland
find_wayland_socket() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  
  # Tenta vários nomes comuns de socket Wayland
  for socket_name in wayland-0 wayland-1 wayland; do
    if [[ -e "$runtime_dir/$socket_name" ]]; then
      echo "$runtime_dir/$socket_name"
      return 0
    fi
  done
  
  # Fallback para tentativa no /tmp
  if [[ -e /tmp/wayland-0 ]]; then
    echo "/tmp/wayland-0"
    return 0
  fi
  
  return 1
}

# Obtém configurações específicas do ambiente para GPU
get_gpu_args() {
  # /dev/dri não está disponível em todos os ambientes (ex: Crostini no Chromebook).
  # O mapeamento é feito condicionalmente para evitar erro no docker run.
  if [[ -e /dev/dri ]]; then
    echo "--device /dev/dri"
  fi
}

# Obtém configurações específicas do ambiente para áudio
get_audio_args() {
  # /dev/snd: mapeia dispositivos ALSA do host para o container.
  if [[ -d /dev/snd ]]; then
    echo "--device /dev/snd"
  fi
}

# Obtém configurações específicas para X11
get_x11_args() {
  # X11: requer permissões e socket Unix
  if command -v xhost &> /dev/null; then
    xhost +local:docker &>/dev/null || true
  fi
  
  echo "-e DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix:ro"
}

# Obtém configurações específicas para Wayland
get_wayland_args() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local wayland_display="${WAYLAND_DISPLAY:-wayland-0}"
  
  if wayland_socket=$(find_wayland_socket); then
    # Socket encontrado, passa as variáveis de ambiente e monta os sockets necessários
    echo "-e WAYLAND_DISPLAY=${wayland_display} -e XDG_RUNTIME_DIR=/run/user/runtime -v ${runtime_dir}:/run/user/runtime:ro"
    return 0
  else
    echo "Aviso: socket Wayland não encontrado" >&2
    return 1
  fi
}

# Obtém mapeamentos de bibliotecas GPU compartilhadas
get_gpu_libs_args() {
  local lib_args=""
  
  # Mapeia bibliotecas OpenGL do host (necessário para EGL/GPU-accelerated rendering)
  local lib_dirs=(
    "/usr/lib/x86_64-linux-gnu"
    "/usr/lib/aarch64-linux-gnu"
    "/lib/x86_64-linux-gnu"
    "/lib/aarch64-linux-gnu"
  )
  
  for lib_dir in "${lib_dirs[@]}"; do
    if [[ -d "$lib_dir" ]]; then
      # Verifica se existem bibliotecas OpenGL/EGL
      if ls "$lib_dir"/libGL.so* "$lib_dir"/libEGL.so* "$lib_dir"/libGLX.so* 2>/dev/null | head -1 &>/dev/null; then
        echo "-v ${lib_dir}:${lib_dir}:ro"
      fi
    fi
  done
}
# Sessao de verificacao de dependencias do container
echo "[DEPENDENCIES] Verificando bibliotecas necessarias..."
echo ""
if ! docker run --rm msxair:bookworm ldconfig -p 2>/dev/null | grep -q "libSDL2-2.0.so.0"; then
  echo "[WARN] libSDL2 nao encontrada no container"
  echo "[INFO] Reconstruir:  docker build -t msxair:bookworm -f docker/Dockerfile ."
  echo ""
fi

if ! docker run --rm msxair:bookworm ldconfig -p 2>/dev/null | grep -q "libSDL2_ttf"; then
  echo "[WARN] libSDL2_ttf nao encontrada no container"
  echo "[INFO] Reconstruir: docker build -t msxair:bookworm -f docker/Dockerfile ."
  echo ""
fi

echo "[OK] Verificacao completada"
echo ""
# Detecta e aplica as configurações corretas
DISPLAY_SERVER=$(detect_display_server)

echo "Detectado: $DISPLAY_SERVER"

# Inicializa o array com argumentos básicos
DOCKER_RUN_ARGS=(--rm -it)

# Adiciona variáveis de environment para GPU rendering
DOCKER_RUN_ARGS+=(-e "LIBGL_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri:/usr/lib/aarch64-linux-gnu/dri")
DOCKER_RUN_ARGS+=(-e "LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri:/usr/lib/aarch64-linux-gnu/dri")
DOCKER_RUN_ARGS+=(-e "LIBVA_DISPLAY_DRM=/dev/dri/card0")

# Configurações específicas por display server
case "$DISPLAY_SERVER" in
  x11)
    display_args=$(get_x11_args)
    # Usa eval com aspas duplas para garantir expansão correta
    eval "DOCKER_RUN_ARGS+=(${display_args})"
    ;;
  wayland)
    if wayland_args=$(get_wayland_args); then
      eval "DOCKER_RUN_ARGS+=(${wayland_args})"
    else
      echo "Aviso: Wayland indisponível, tentando X11..."
      if [[ -n "${DISPLAY:-}" ]]; then
        display_args=$(get_x11_args)
        eval "DOCKER_RUN_ARGS+=(${display_args})"
        DISPLAY_SERVER="x11"
      else
        echo "Erro: Nenhum servidor gráfico disponível"
        exit 1
      fi
    fi
    ;;
  *)
    echo "Aviso: ambiente gráfico desconhecido. Tentando X11..."
    if [[ -n "${DISPLAY:-}" ]]; then
      display_args=$(get_x11_args)
      eval "DOCKER_RUN_ARGS+=(${display_args})"
      DISPLAY_SERVER="x11"
    elif [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
      echo "Tentando Wayland..."
      if wayland_args=$(get_wayland_args); then
        eval "DOCKER_RUN_ARGS+=(${wayland_args})"
        DISPLAY_SERVER="wayland"
      else
        echo "Erro: Nenhum servidor gráfico disponível"
        exit 1
      fi
    else
      echo "Erro: Nenhum servidor gráfico detectado"
      exit 1
    fi
    ;;
esac

# Coleta argumentos para GPU e áudio
gpu_args=$(get_gpu_args)
if [[ -n "$gpu_args" ]]; then
  DOCKER_RUN_ARGS+=($gpu_args)
fi

# Mapeia bibliotecas GPU do host (necessário para EGL/OpenGL funcionar)
gpu_libs=$(get_gpu_libs_args)
if [[ -n "$gpu_libs" ]]; then
  while read -r lib_arg; do
    if [[ -n "$lib_arg" ]]; then
      DOCKER_RUN_ARGS+=($lib_arg)
    fi
  done <<< "$gpu_libs"
fi

audio_args=$(get_audio_args)
if [[ -n "$audio_args" ]]; then
  DOCKER_RUN_ARGS+=($audio_args)
fi

# Adiciona volume de mídia
DOCKER_RUN_ARGS+=(-v "${HOME}/roms/msx":/root/roms/msx)

echo "Executando no docker com: $DISPLAY_SERVER"
echo "Argumentos do Docker: ${DOCKER_RUN_ARGS[@]}"

# Executa o container
docker run ${DOCKER_RUN_ARGS[@]} msxair:bookworm 