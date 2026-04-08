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

# Garante que as system ROMs estão acessíveis (especialmente importante em container)
if [[ -f "${SCRIPT_DIR}/ensure-systemroms.sh" ]]; then
  bash "${SCRIPT_DIR}/ensure-systemroms.sh" || true
fi

# Valida disponibilidade de ROMs do sistema
validate_system_roms() {
  echo "[INFO] Validando disponibilidade de system ROMs..."
  
  # Procura pelos diretórios de ROMs em ordem de preferência
  local roms_dir=""
  
  if [[ -d "/usr/share/openmsx/systemroms" ]]; then
    roms_dir="/usr/share/openmsx/systemroms"
  elif [[ -d "${HOME}/.local/share/openmsx/systemroms" ]]; then
    roms_dir="${HOME}/.local/share/openmsx/systemroms"
  elif [[ -d "${HOME}/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms" ]]; then
    roms_dir="${HOME}/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms"
  else
    echo "[WARN] Nenhum diretório de system ROMs encontrado"
    return 1
  fi
  
  if [[ ! -d "${roms_dir}" ]]; then
    return 1
  fi
  
  # Extrai o name da máquina (ex: Panasonic_FS-A1GT -> panasonic)
  local machine_vendor
  machine_vendor=$(echo "${MACHINE}" | cut -d'_' -f1 | tr '[:upper:]' '[:lower:]')
  
  # Verifica se há ROMs para o fabricante da máquina
  if ! find "${roms_dir}/machines" -type d -iname "${machine_vendor}" >/dev/null 2>&1; then
    echo "[WARN] Diretório de ROMs para '${machine_vendor}' nao encontrado em ${roms_dir}/machines"
    echo "[WARN] ROMs disponíveis: $(ls -1 ${roms_dir}/machines 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
    return 1
  fi
  
  local rom_count
  rom_count=$(find "${roms_dir}/machines" -type d -iname "${machine_vendor}" -exec find {} -maxdepth 1 -name "*.rom" \; 2>/dev/null | wc -l)
  echo "[INFO] ✓ Encontrado $rom_count arquivo(s) ROM para ${machine_vendor}"
  return 0
}

# Valida ROMs, mas continua mesmo se falhar (openMSX pode ter fallback)
if ! validate_system_roms; then
  echo "[WARN] Verificacao de ROMs inconclusa. O openMSX pode nao conseguir iniciar."
  echo "[WARN] Execute: ${SCRIPT_DIR}/copy-systemroms.sh"
fi

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
  local hdd_image="${HOME}/MSX/media/msxair-hdd.dsk"
  mkdir -p "$(dirname "${hdd_image}")"
  
  if [[ ! -f "${hdd_image}" ]]; then
    echo "[INFO] Preparando imagem de disco para Sunrise IDE..."
    
    # Cria a imagem de disco com 3 partições de 32MB cada
    if command -v diskmanipulator >/dev/null 2>&1; then
      echo "[INFO] Criando imagem de disco: ${hdd_image}"
      diskmanipulator create "${hdd_image}" 32M 32M 32M
      
      # Monta a primeira partição
      echo "[INFO] Montando disco rígido virtual"
      diskmanipulator mount "${hdd_image}"
      
      # Instala Nextor na primeira partição
      echo "[INFO] Instalando Nextor na primeira partição"
      # Procura pelo arquivo Nextor ROM
      local nextor_rom=""
      for rom_path in "${SCRIPT_DIR}/systemroms/extensions/"Nextor*.rom "${SCRIPT_DIR}/systemroms/extensions/"Nextor*.SunriseIDE.rom; do
        if [[ -f "${rom_path}" ]]; then
          nextor_rom="${rom_path}"
          break
        fi
      done
      
      if [[ -n "${nextor_rom}" ]]; then
        echo "[INFO] Encontrado Nextor: ${nextor_rom}"
        # Formata a primeira partição com Nextor
        diskmanipulator format "${hdd_image}:1" /X "${nextor_rom}" 2>/dev/null || echo "[WARN] Nao foi possivel formatar com Nextor"
      else
        echo "[WARN] Arquivo Nextor ROM nao encontrado. Formatando com FAT12"
        diskmanipulator format "${hdd_image}:1" /X 2>/dev/null || echo "[WARN] Nao foi possivel formatar o disco"
      fi
      
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
  args+=( -cartridge "hda:${HOME}/MSX/media/msxair-hdd.dsk" )
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
