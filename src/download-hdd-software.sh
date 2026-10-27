#!/usr/bin/env bash
#
# download-hdd-software.sh
# Baixa os softwares que acompanham o HD MSX para hdd-software/:
#   - TED (editor de textos MSX2, riesvriend/msx2026; manual em ingles) -> hdd-software/TED
#   - SofaRun (ultima versao, louthrax.com)            -> hdd-software/SOFARUN
#
# Uso: ./download-hdd-software.sh [--force]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${SCRIPT_DIR}/hdd-software"
FORCE="${1:-}"

TED_URL="https://raw.githubusercontent.com/riesvriend/msx2026/main/dist/ted-run.zip"
SOFARUN_URL="https://www.louthrax.com/mgr/downloads/download.php?file=sofarun.zip"

command -v unzip >/dev/null 2>&1 || { echo "[ERRO] unzip nao encontrado (apt install unzip)" >&2; exit 1; }

fetch() {
  local name="$1" url="$2" check="$3"
  local dir="${DEST}/${name}"
  if [[ -f "${dir}/${check}" && "${FORCE}" != "--force" ]]; then
    echo "[INFO] ${name} ja disponivel em ${dir}"
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  echo "[INFO] Baixando ${name}..."
  if ! curl -sL --fail -o "${tmp}/pkg.zip" "${url}"; then
    echo "[ERRO] Falha ao baixar ${name} (${url})" >&2
    rm -rf "${tmp}"
    return 1
  fi
  rm -rf "${dir}"
  mkdir -p "${dir}"
  unzip -q -o "${tmp}/pkg.zip" -d "${dir}"
  rm -rf "${tmp}"
  echo "[INFO] ${name} instalado em ${dir}"
}

mkdir -p "${DEST}"
fetch TED "${TED_URL}" TED.COM
# MSXDOS.SYS/COMMAND.COM do pacote TED sao redundantes: o HD ja os possui.
# TED26.DOC (manual) e LEES.MIJ (texto de exemplo) estao em holandes; so o manual
# em ingles (TED26ENG.DOC) e mantido.
rm -f "${DEST}/TED/MSXDOS.SYS" "${DEST}/TED/COMMAND.COM" \
      "${DEST}/TED/TED26.DOC" "${DEST}/TED/LEES.MIJ"
# O TED.COM do pacote tem interface em holandes; usa o build em ingles (ted-en/).
cp -f "${SCRIPT_DIR}/ted-en/TED.COM" "${DEST}/TED/TED.COM"
fetch SOFARUN "${SOFARUN_URL}" SR.COM
