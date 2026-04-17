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

# Valida e instala dependências necessárias para rodar o container
validate_and_install_dependencies() {
  echo "Validando dependências necessárias para Docker..."
  echo ""
  
  # Lista de dependências obrigatórias (binários/comandos)
  local required_commands=(
    "docker:Docker"
  )
  
  # Lista de dependências de bibliotecas com alternativas
  # Formato: "pacote_principal|alternativa1|alternativa2:Descrição"
  local required_libs=(
    "libgl1-mesa-glx|libgl1:OpenGL Libraries"
    "libva2|libva1:Video Acceleration Library"
    "libasound2|libasound2t64:ALSA Audio Libraries"
    "libxext6:X11 Extensions"
    "libxrender1:X11 Rendering"
    "libtcl8.6|libtcl8.7|libtcl9.0:Tcl Library (OpenMSX)"
    "libtk8.6|libtk8.7|libtk9.0:Tk Library (OpenMSX)"
  )
  
  # Lista de dependências opcionais por display server
  local x11_deps=("x11-utils:X11 Utilities (xhost)")
  
  local missing_commands=()
  local missing_libs=()
  local packages_to_install=()
  
  # Função auxiliar para verificar se um pacote está instalado
  check_package_installed() {
    local packages="$1"
    local IFS='|'
    for pkg in $packages; do
      # Tenta dpkg-query com padrão mais flexível (suporta arquitetura)
      if dpkg-query -W "$pkg*" 2>/dev/null | grep -q "install"; then
        return 0
      fi
      # Fallback: tenta dpkg-query padrão
      if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        return 0
      fi
      # Fallback adicional: tenta com dpkg -l
      if dpkg -l 2>/dev/null | grep "^ii" | grep -q "$pkg"; then
        return 0
      fi
    done
    return 1
  }
  
  # Função auxiliar para obter o primeiro pacote disponível
  get_available_package() {
    local packages="$1"
    local IFS='|'
    for pkg in $packages; do
      # Tenta apt-cache policy que é mais confiável
      if apt-cache policy "$pkg" 2>/dev/null | grep -q "Candidate:"; then
        echo "$pkg"
        return 0
      fi
      # Fallback: tenta apt-cache search
      if apt-cache search "^$pkg$" 2>/dev/null | grep -q "^$pkg"; then
        echo "$pkg"
        return 0
      fi
    done
    return 1
  }
  
  # Verifica binários obrigatórios
  for cmd_entry in "${required_commands[@]}"; do
    IFS=':' read -r cmd_name cmd_label <<< "$cmd_entry"
    if ! command -v "$cmd_name" &>/dev/null; then
      missing_commands+=("$cmd_name:$cmd_label")
    else
      echo "✓ $cmd_label encontrado"
    fi
  done
  
  # Verifica bibliotecas
  for lib_entry in "${required_libs[@]}"; do
    IFS=':' read -r lib_packages lib_label <<< "$lib_entry"
    
    if check_package_installed "$lib_packages"; then
      echo "✓ $lib_label instalada"
    else
      # Tenta encontrar um pacote disponível
      if available_pkg=$(get_available_package "$lib_packages" 2>/dev/null); then
        echo "  ⓘ $lib_label não encontrada, tentará instalar: $available_pkg"
        packages_to_install+=("$available_pkg")
      else
        echo "  ⚠ $lib_label - nenhum pacote disponível encontrado"
        # Não adiciona como erro, continuará mesmo assim
      fi
    fi
  done
  
  # Verifica X11 se estiver em X11
  if [[ "${DISPLAY_SERVER:-unknown}" == "x11" ]]; then
    for lib_entry in "${x11_deps[@]}"; do
      IFS=':' read -r lib_packages lib_label <<< "$lib_entry"
      
      if check_package_installed "$lib_packages"; then
        echo "✓ $lib_label instalada"
      else
        if available_pkg=$(get_available_package "$lib_packages" 2>/dev/null); then
          echo "  ⓘ $lib_label não encontrada, tentará instalar: $available_pkg"
          packages_to_install+=("$available_pkg")
        else
          echo "  ⚠ $lib_label - nenhum pacote disponível encontrado"
        fi
      fi
    done
  fi
  
  echo ""
  
  # Se houver dependências faltando obrigatórias, aborta
  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    echo "Erro: Dependências obrigatórias faltando:"
    for cmd_entry in "${missing_commands[@]}"; do
      IFS=':' read -r cmd_name cmd_label <<< "$cmd_entry"
      echo "  ✗ $cmd_label ($cmd_name)"
    done
    echo ""
    echo "Por favor, instale as dependências obrigatórias e execute novamente."
    exit 1
  fi
  
  # Se houver pacotes para instalar, tenta instalar
  if [[ ${#packages_to_install[@]} -gt 0 ]]; then
    echo "Tentando instalar dependências disponíveis..."
    echo ""
    
    if command -v sudo &>/dev/null; then
      # Tenta instalar cada pacote individualmente para não abortar se um falhar
      local installed_count=0
      local failed_count=0
      
      for pkg in "${packages_to_install[@]}"; do
        # Captura a saída de instalação
        local install_output
        install_output=$(sudo apt-get install -y --no-install-recommends "$pkg" 2>&1)
        local install_exit=$?
        
        # Verifica sucesso: exit code 0 e (já estava instalado OU foi instalado agora)
        if [[ $install_exit -eq 0 ]] && (echo "$install_output" | grep -qE "already the newest|already installed|Setting up"); then
          echo "  ✓ $pkg OK"
          ((installed_count++))
        else
          echo "  ⚠ Falha ao instalar $pkg (pode estar indisponível ou erro)"
          ((failed_count++))
        fi
      done
      
      echo ""
      if [[ $installed_count -gt 0 ]]; then
        echo "✓ $installed_count pacote(s) instalado com sucesso!"
      fi
      if [[ $failed_count -gt 0 ]]; then
        echo "⚠ Aviso: $failed_count pacote(s) não puderam ser instalados."
      fi
      echo ""
    else
      echo "Aviso: sudo não encontrado. Não é possível instalar as dependências automaticamente."
      echo "Tente instalar manualmente com:"
      for pkg in "${packages_to_install[@]}"; do
        echo "  apt-get install $pkg"
      done
      echo ""
    fi
  else
    echo "✓ Validação de dependências concluída!"
    echo ""
  fi
}

echo ""
# Detecta e aplica as configurações corretas
DISPLAY_SERVER=$(detect_display_server)

echo "Detectado: $DISPLAY_SERVER"
echo ""

# Valida e instala dependências necessárias
validate_and_install_dependencies

# Inicializa o array com argumentos básicos
DOCKER_RUN_ARGS=(--rm -it --privileged)

# Adiciona variáveis de environment para GPU rendering
DOCKER_RUN_ARGS+=(-e "LIBGL_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri:/usr/lib/aarch64-linux-gnu/dri")
DOCKER_RUN_ARGS+=(-e "LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri:/usr/lib/aarch64-linux-gnu/dri")
DOCKER_RUN_ARGS+=(-e "LIBVA_DISPLAY_DRM=/dev/dri/card0")

# Adiciona variáveis de environment para áudio ALSA
DOCKER_RUN_ARGS+=(-e "ALSA_CARD=0")
DOCKER_RUN_ARGS+=(-e "SDL_AUDIODRIVER=alsa")

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

# Adiciona volumes de mídia e ROMs
DOCKER_RUN_ARGS+=(-v "${HOME}/roms/msx":/root/roms/msx)

# Monta o diretório de imagens HDD (para Sunrise IDE com Nextor)
if [[ -d "${HOME}/MSX/media" ]]; then
  DOCKER_RUN_ARGS+=(-v "${HOME}/MSX/media":/root/MSX/media)
fi

# Obtém o diretório do script para montar os system ROMs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "${SCRIPT_DIR}/src/systemroms" ]]; then
  DOCKER_RUN_ARGS+=(-v "${SCRIPT_DIR}/src/systemroms":/opt/msxair/src/systemroms:ro)
fi

# Monta arquivo de configuração do OpenMSX
if [[ -f "${SCRIPT_DIR}/docker/openmsx.rc" ]]; then
  DOCKER_RUN_ARGS+=(-v "${SCRIPT_DIR}/docker/openmsx.rc":/root/.openmsx/openmsx.rc:ro)
fi

echo "Executando no docker com: $DISPLAY_SERVER"
echo "Argumentos do Docker: ${DOCKER_RUN_ARGS[@]}"

# Executa o container
docker run ${DOCKER_RUN_ARGS[@]} msxair:bookworm 