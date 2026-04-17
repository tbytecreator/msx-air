#!/usr/bin/env bash
#
# create-hdd-image.sh
# Cria uma imagem de HDD com Nextor 2.1.0 para uso com a extensão Sunrise IDE
# no OpenMSX (projeto MSX Air).
#
# A imagem é criada com 3 partições FAT16 de 32MB cada e contém:
#   - NEXTOR.SYS + COMMAND2.COM (boot do Nextor)
#   - MSXDOS.SYS + COMMAND.COM  (compatibilidade MSX-DOS 1)
#   - Ferramentas Nextor no diretório TOOLS/
#   - AUTOEXEC.BAT com PATH configurado
#
# Dependências:
#   - openMSX (nativo ou via Flatpak)
#   - curl e 7z (para download das ferramentas se necessário)
#
# Uso:
#   ./create-hdd-image.sh [caminho-saida.dsk]
#
# Se nenhum caminho for informado, a imagem será salva em:
#   ~/MSX/media/msxair-hdd.dsk
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Parâmetros ---
HDD_IMAGE="${1:-${HOME}/MSX/media/msxair-hdd.dsk}"
NEXTOR_TOOLS_DIR="${SCRIPT_DIR}/nextor-boot-files"
NEXTOR_TOOLS_URL="https://github.com/Konamiman/Nextor/releases/download/v2.1.0/tools.dsk.zip"
NEXTOR_ROM_URL="https://github.com/Konamiman/Nextor/releases/download/v2.1.0/Nextor-2.1.0.SunriseIDE.emulators.ROM"
TCL_SCRIPT="${SCRIPT_DIR}/create-hdd.tcl"

# --- Detecta openMSX ---
detect_openmsx() {
  if command -v openmsx >/dev/null 2>&1; then
    echo "openmsx"
  elif command -v flatpak >/dev/null 2>&1 && flatpak info org.openmsx.openMSX >/dev/null 2>&1; then
    echo "flatpak run org.openmsx.openMSX"
  else
    echo ""
  fi
}

OPENMSX_CMD="$(detect_openmsx)"

if [[ -z "${OPENMSX_CMD}" ]]; then
  echo "[ERRO] openMSX nao encontrado. Instale o openMSX ou execute openmsx-install.sh" >&2
  exit 1
fi

echo "[INFO] openMSX detectado: ${OPENMSX_CMD}"

# --- Verifica se a imagem já existe ---
if [[ -f "${HDD_IMAGE}" ]]; then
  echo "[AVISO] A imagem HDD já existe: ${HDD_IMAGE}"
  read -rp "Deseja sobrescrever? (s/N): " resposta
  if [[ "${resposta}" != "s" && "${resposta}" != "S" ]]; then
    echo "[INFO] Operação cancelada."
    exit 0
  fi
  rm -f "${HDD_IMAGE}"
fi

mkdir -p "$(dirname "${HDD_IMAGE}")"

# --- Prepara os arquivos de boot do Nextor ---
prepare_nextor_files() {
  if [[ -f "${NEXTOR_TOOLS_DIR}/NEXTOR.SYS" && -f "${NEXTOR_TOOLS_DIR}/COMMAND2.COM" ]]; then
    echo "[INFO] Arquivos de boot do Nextor já disponíveis em ${NEXTOR_TOOLS_DIR}"
    return 0
  fi

  echo "[INFO] Baixando ferramentas do Nextor v2.1.0..."
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap "rm -rf '${tmp_dir}'" EXIT

  curl -sL -o "${tmp_dir}/tools.dsk.zip" "${NEXTOR_TOOLS_URL}"

  # O arquivo do Nextor é na verdade um 7z disfarçado de zip
  if command -v 7z >/dev/null 2>&1; then
    7z x -y -o"${tmp_dir}" "${tmp_dir}/tools.dsk.zip" >/dev/null 2>&1
  elif command -v 7zz >/dev/null 2>&1; then
    7zz x -y -o"${tmp_dir}" "${tmp_dir}/tools.dsk.zip" >/dev/null 2>&1
  else
    echo "[ERRO] 7z nao encontrado. Instale com: sudo apt install p7zip-full" >&2
    exit 1
  fi

  local dsk_file
  dsk_file="$(find "${tmp_dir}" -name '*.dsk' -type f | head -1)"

  if [[ -z "${dsk_file}" ]]; then
    echo "[ERRO] Disco de ferramentas Nextor nao encontrado no arquivo baixado" >&2
    exit 1
  fi

  echo "[INFO] Extraindo arquivos do disco de ferramentas Nextor..."
  mkdir -p "${NEXTOR_TOOLS_DIR}"

  # Extrai os arquivos da imagem FAT12 usando Python
  python3 - "${dsk_file}" "${NEXTOR_TOOLS_DIR}" <<'PYEOF'
import struct, os, sys

dsk_path = sys.argv[1]
out_dir = sys.argv[2]

with open(dsk_path, 'rb') as f:
    data = f.read()

bps = struct.unpack_from('<H', data, 11)[0]
spc = data[13]
reserved = struct.unpack_from('<H', data, 14)[0]
nfats = data[16]
root_entries = struct.unpack_from('<H', data, 17)[0]
spf = struct.unpack_from('<H', data, 22)[0]

root_offset = (reserved + nfats * spf) * bps
data_offset = root_offset + root_entries * 32

for i in range(root_entries):
    eo = root_offset + i * 32
    name = data[eo:eo+8]
    ext = data[eo+8:eo+11]
    attr = data[eo+11]

    if name[0] == 0x00:
        break
    if name[0] == 0xE5 or (attr & 0x08) or (attr & 0x10):
        continue

    fname = name.decode('ascii', errors='replace').strip()
    fext = ext.decode('ascii', errors='replace').strip()
    fullname = f'{fname}.{fext}' if fext else fname

    cluster = struct.unpack_from('<H', data, eo+26)[0]
    fsize = struct.unpack_from('<I', data, eo+28)[0]

    fdata = bytearray()
    remaining = fsize
    while cluster >= 2 and cluster < 0xFF0 and remaining > 0:
        co = data_offset + (cluster - 2) * spc * bps
        chunk = min(remaining, spc * bps)
        fdata.extend(data[co:co+chunk])
        remaining -= chunk
        fat_offset = reserved * bps
        if cluster % 2 == 0:
            fe = struct.unpack_from('<H', data, fat_offset + cluster * 3 // 2)[0] & 0xFFF
        else:
            fe = struct.unpack_from('<H', data, fat_offset + cluster * 3 // 2)[0] >> 4
        cluster = fe

    out_path = os.path.join(out_dir, fullname)
    with open(out_path, 'wb') as out:
        out.write(fdata[:fsize])
    print(f'  -> {fullname} ({fsize} bytes)')

PYEOF

  echo "[INFO] Arquivos de boot extraidos para ${NEXTOR_TOOLS_DIR}"
}

# --- Instala a ROM do Nextor 2.1.0 para emuladores (se necessário) ---
install_nextor_rom() {
  local rom_dest="${SCRIPT_DIR}/systemroms/extensions/Nextor-2.1.0.SunriseIDE.emulators.rom"
  if [[ -f "${rom_dest}" ]]; then
    echo "[INFO] ROM Nextor 2.1.0 para emuladores já instalada."
    return 0
  fi

  echo "[INFO] Baixando ROM Nextor 2.1.0 para emuladores..."
  curl -sL -o "${rom_dest}" "${NEXTOR_ROM_URL}"
  echo "[INFO] ROM instalada em ${rom_dest}"
}

# --- Cria a imagem HDD usando o openMSX ---
create_hdd_image() {
  echo ""
  echo "============================================"
  echo " Criando imagem HDD: ${HDD_IMAGE}"
  echo " 3 particoes de 32MB (FAT16, formato Nextor)"
  echo "============================================"
  echo ""

  # Exporta variáveis para o script Tcl
  export HDD_IMAGE
  export NEXTOR_DIR="${NEXTOR_TOOLS_DIR}"

  # Para Flatpak, precisamos garantir acesso aos caminhos
  if [[ "${OPENMSX_CMD}" == *"flatpak"* ]]; then
    local tcl_copy="${HOME}/.var/app/org.openmsx.openMSX/data/create-hdd.tcl"
    cp "${TCL_SCRIPT}" "${tcl_copy}"
    ${OPENMSX_CMD} -machine C-BIOS_MSX2+ -script "${tcl_copy}" 2>&1 || true
    rm -f "${tcl_copy}"
  else
    ${OPENMSX_CMD} -machine C-BIOS_MSX2+ -script "${TCL_SCRIPT}" 2>&1 || true
  fi

  if [[ -f "${HDD_IMAGE}" ]]; then
    local size
    size=$(stat -c%s "${HDD_IMAGE}" 2>/dev/null || stat -f%z "${HDD_IMAGE}" 2>/dev/null)
    local size_mb=$((size / 1024 / 1024))
    echo ""
    echo "[OK] Imagem HDD criada com sucesso!"
    echo "     Arquivo: ${HDD_IMAGE}"
    echo "     Tamanho: ${size_mb} MB"
    echo ""
    echo "Para usar com o MSX Air:"
    echo "  1. Execute: ./launch-msxair.sh"
    echo "  2. A extensao IDE ja esta configurada no msxair.conf"
    echo "  3. O Nextor iniciara automaticamente com NEXTOR.SYS"
    echo ""
  else
    echo "[ERRO] Falha ao criar a imagem HDD." >&2
    echo "       Verifique se o openMSX esta funcionando corretamente." >&2
    exit 1
  fi
}

# --- Main ---
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  MSX Air - Criador de Imagem HDD Nextor ║"
echo "╠══════════════════════════════════════════╣"
echo "║ Nextor 2.1.0 + Sunrise IDE              ║"
echo "║ 3 particoes FAT16 x 32MB = 96MB         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

prepare_nextor_files
install_nextor_rom
create_hdd_image
