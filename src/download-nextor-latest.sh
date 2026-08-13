#!/usr/bin/env bash
#
# download-nextor-latest.sh
# Baixa os arquivos mais recentes do Nextor para uso com Sunrise IDE no openMSX.
#
# Versoes baixadas:
#   - Nextor-2.1.4.SunriseIDE.blueMSX.ROM  -> systemroms/extensions/ (ROM para openMSX)
#   - NEXTOR.SYS          (v2.1.3)          -> nextor-boot-files/
#   - MAPDRV.COM          (v2.1.2)          -> nextor-boot-files/
#   - EPTCFT.COM          (v2.1.2, novo)    -> nextor-boot-files/
#
# Os demais arquivos (COMMAND2.COM, DEVINFO.COM, etc.) permanecem na versao 2.1.0,
# que e a ultima versao publicada para essas ferramentas.
#
# Uso:
#   ./src/download-nextor-latest.sh [--force]
#
# --force: sobrescreve arquivos existentes mesmo se ja presentes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEXTOR_DIR="${SCRIPT_DIR}/nextor-boot-files"
ROMS_DIR="${SCRIPT_DIR}/systemroms/extensions"
FORCE="${1:-}"

NEXTOR_ROM_VERSION="2.1.4"
NEXTOR_SYS_VERSION="2.1.3"
NEXTOR_TOOLS_VERSION="2.1.2"

NEXTOR_BASE_URL="https://github.com/Konamiman/Nextor/releases/download"

NEXTOR_ROM_URL="${NEXTOR_BASE_URL}/v${NEXTOR_ROM_VERSION}/Nextor-${NEXTOR_ROM_VERSION}.SunriseIDE.blueMSX.ROM"
NEXTOR_SYS_URL="${NEXTOR_BASE_URL}/v${NEXTOR_SYS_VERSION}/NEXTOR.SYS"
MAPDRV_URL="${NEXTOR_BASE_URL}/v${NEXTOR_TOOLS_VERSION}/MAPDRV.COM"
EPTCFT_URL="${NEXTOR_BASE_URL}/v${NEXTOR_TOOLS_VERSION}/EPTCFT.COM"

log()  { printf '[INFO] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1" >&2; }

# Verifica dependencia de curl
if ! command -v curl >/dev/null 2>&1; then
  warn "curl nao encontrado. Instale com: sudo apt install curl"
  exit 1
fi

# Baixa um arquivo se necessario (ou forcado)
download_file() {
  local url="$1"
  local dest="$2"
  local label="$3"

  if [[ -f "${dest}" && "${FORCE}" != "--force" ]]; then
    log "${label}: ja presente em $(basename "${dest}")"
    return 0
  fi

  log "Baixando ${label}..."
  if curl -sL --fail -o "${dest}" "${url}"; then
    local sz
    sz=$(stat -c%s "${dest}" 2>/dev/null || stat -f%z "${dest}" 2>/dev/null || echo "?")
    log "  -> $(basename "${dest}") (${sz} bytes)"
  else
    warn "  -> Falha ao baixar ${label}"
    warn "     URL: ${url}"
    return 1
  fi
}

log "=================================================="
log " MSX Air - Nextor ${NEXTOR_ROM_VERSION} para openMSX"
log "=================================================="
log ""

mkdir -p "${NEXTOR_DIR}" "${ROMS_DIR}"

errors=0

# ROM do Nextor 2.1.4 para emuladores (Sunrise IDE, variante blueMSX/openMSX)
download_file "${NEXTOR_ROM_URL}" \
  "${ROMS_DIR}/Nextor-${NEXTOR_ROM_VERSION}.SunriseIDE.blueMSX.rom" \
  "ROM Nextor ${NEXTOR_ROM_VERSION} (SunriseIDE/openMSX)" || ((errors++)) || true

# NEXTOR.SYS v2.1.3 — kernel Nextor mais recente
download_file "${NEXTOR_SYS_URL}" \
  "${NEXTOR_DIR}/NEXTOR.SYS" \
  "NEXTOR.SYS v${NEXTOR_SYS_VERSION}" || ((errors++)) || true

# MAPDRV.COM v2.1.2 — versao atualizada
download_file "${MAPDRV_URL}" \
  "${NEXTOR_DIR}/MAPDRV.COM" \
  "MAPDRV.COM v${NEXTOR_TOOLS_VERSION}" || ((errors++)) || true

# EPTCFT.COM v2.1.2 — ferramenta nova (corrige tipos de particao estendida)
download_file "${EPTCFT_URL}" \
  "${NEXTOR_DIR}/EPTCFT.COM" \
  "EPTCFT.COM v${NEXTOR_TOOLS_VERSION}" || ((errors++)) || true

log ""
if [[ "${errors}" -eq 0 ]]; then
  log "Todos os arquivos do Nextor ${NEXTOR_ROM_VERSION} atualizados com sucesso."
  log ""
  log "  ROM para openMSX : systemroms/extensions/Nextor-${NEXTOR_ROM_VERSION}.SunriseIDE.blueMSX.rom"
  log "  NEXTOR.SYS       : nextor-boot-files/NEXTOR.SYS  (v${NEXTOR_SYS_VERSION})"
  log "  MAPDRV.COM       : nextor-boot-files/MAPDRV.COM   (v${NEXTOR_TOOLS_VERSION})"
  log "  EPTCFT.COM       : nextor-boot-files/EPTCFT.COM   (v${NEXTOR_TOOLS_VERSION}, novo)"
else
  warn "${errors} arquivo(s) nao puderam ser baixados (sem internet?)."
  warn "Os arquivos existentes serao usados. Execute novamente para tentar novamente."
fi
