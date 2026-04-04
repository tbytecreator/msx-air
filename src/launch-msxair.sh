#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/msxair.conf"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "[ERROR] Arquivo de configuracao nao encontrado: ${CONFIG_FILE}" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

if ! command -v openmsx >/dev/null 2>&1; then
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "[ERROR] openMSX nao encontrado e Flatpak nao esta instalado." >&2
    exit 1
  fi
  
  if ! flatpak info org.openmsx.openMSX >/dev/null 2>&1; then
    echo "[ERROR] openMSX nao esta instalado via Flatpak. Execute: ./openmsx-install.sh" >&2
    exit 1
  fi
  
  OPENMSX_CMD="flatpak run org.openmsx.openMSX"
else
  OPENMSX_CMD="openmsx"
fi

mkdir -p "${MEDIA_DIR}"

# Preparacao da imagem de disco para Sunrise IDE
setup_sunrise_ide() {
  local hdd_image="/tmp/msxair-hdd.dsk"
  
  if [[ ! -f "${hdd_image}" ]]; then
    echo "[INFO] Preparando imagem de disco para Sunrise IDE..."
    
    # Cria a imagem de disco com 3 partições de 32MB cada
    if command -v diskmanipulator >/dev/null 2>&1; then
      echo "[INFO] Criando imagem de disco: ${hdd_image}"
      diskmanipulator create "${hdd_image}" 32M 32M 32M
      
      # Monta a primeira partição
      echo "[INFO] Montando disco rígido virtual"
      diskmanipulator mount "${hdd_image}"
      
      # Importa os diretórios nas partições (se existirem)
      if [[ -d "${HOME}/msxdostools/" ]]; then
        echo "[INFO] Importando msxdostools para hda1"
        diskmanipulator import "${hdd_image}:1" "${HOME}/msxdostools/" 2>/dev/null || true
      fi
      
      if [[ -d "${HOME}/msxdemos/" ]]; then
        echo "[INFO] Importando msxdemos para hda2"
        diskmanipulator import "${hdd_image}:2" "${HOME}/msxdemos/" 2>/dev/null || true
      fi
      
      if [[ -d "${HOME}/msxdrawings/" ]]; then
        echo "[INFO] Importando msxdrawings para hda3"
        diskmanipulator import "${hdd_image}:3" "${HOME}/msxdrawings/" 2>/dev/null || true
      fi
    else
      echo "[WARN] diskmanipulator nao encontrado. Pulando configuracao de disco"
    fi
  else
    echo "[INFO] Imagem de disco ja existe: ${hdd_image}"
  fi
}

if [[ -n "${WIFI_PRE_START_CMD}" ]]; then
  echo "[INFO] Executando preparacao de rede no host"
  eval "${WIFI_PRE_START_CMD}"
fi

# Configura Sunrise IDE se extensao estiver ativa
if [[ "${EXTENSIONS[@]}" =~ "IDE" ]]; then
  setup_sunrise_ide
fi

# Prepara o script Tcl: para Flatpak, copia para local acessivel
TCL_SCRIPT="${SCRIPT_DIR}/init-fullscreen.tcl"

if [[ "${OPENMSX_CMD}" == *"flatpak"* ]]; then
  # Para Flatpak, copiar o arquivo TCL para o sandbox de dados para garantir acesso
  # O Flatpak tem acesso a ~/.var/app/org.openmsx.openMSX/data/
  FLATPAK_DATA_DIR="${HOME}/.var/app/org.openmsx.openMSX/data"
  mkdir -p "${FLATPAK_DATA_DIR}"
  
  # Copia o arquivo TCL para o sandbox
  if [[ -f "${TCL_SCRIPT}" ]]; then
    cp -f "${TCL_SCRIPT}" "${FLATPAK_DATA_DIR}/init-fullscreen.tcl"
    TCL_SCRIPT="${FLATPAK_DATA_DIR}/init-fullscreen.tcl"
    echo "[INFO] Script TCL copiado para sandbox Flatpak: ${TCL_SCRIPT}"
  else
    echo "[WARN] Script TCL nao encontrado: ${TCL_SCRIPT}. Iniciando sem fullscreen automatico."
    TCL_SCRIPT=""
  fi
else
  # Para nativo, usar o arquivo TCL direto
  if [[ ! -f "${TCL_SCRIPT}" ]]; then
    echo "[WARN] Script TCL nao encontrado: ${TCL_SCRIPT}. Iniciando sem fullscreen automatico."
    TCL_SCRIPT=""
  fi
fi

# Monta os argumentos do OpenMSX
args=()
if [[ -n "${TCL_SCRIPT}" ]]; then
  args+=( -script "${TCL_SCRIPT}" )
fi
args+=( -machine "${MACHINE}" )

for ext in "${EXTENSIONS[@]}"; do
  args+=( -ext "${ext}" )
done

# Adiciona disco rígido IDE se extensao estiver ativa
if [[ "${EXTENSIONS[@]}" =~ "IDE" ]]; then
  args+=( -cartridge "hda:/tmp/msxair-hdd.dsk" )
fi

if [[ -n "${AUTOSTART_ROM}" ]]; then
  args+=( -cart "${AUTOSTART_ROM}" )
fi

if [[ -n "${AUTOSTART_DSK}" ]]; then
  args+=( -diska "${AUTOSTART_DSK}" )
fi

echo "[INFO] Iniciando openMSX em tela cheia com maquina ${MACHINE}"
echo "[INFO] Iniciando ${OPENMSX_CMD} ${args[*]}"
exec ${OPENMSX_CMD} "${args[@]}"
