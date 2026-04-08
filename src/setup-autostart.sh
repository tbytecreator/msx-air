#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SERVICE_DIR}/msxair-openmsx.service"
LAUNCHER="${SCRIPT_DIR}/launch-msxair.sh"
COPY_ROMS_SCRIPT="${SCRIPT_DIR}/copy-systemroms.sh"

if [[ ! -x "${LAUNCHER}" ]]; then
  echo "[INFO] Ajustando permissao de execucao para ${LAUNCHER}"
  chmod +x "${LAUNCHER}"
fi

# Verifica se as system ROMs ja estao instaladas
check_system_roms_installed() {
  local roms_dir=""
  
  if [[ -d "/usr/share/openmsx/systemroms" ]] && [[ -n "$(find /usr/share/openmsx/systemroms -name "*.rom" -print -quit 2>/dev/null)" ]]; then
    roms_dir="/usr/share/openmsx/systemroms"
  elif [[ -d "${HOME}/.local/share/openmsx/systemroms" ]] && [[ -n "$(find ${HOME}/.local/share/openmsx/systemroms -name "*.rom" -print -quit 2>/dev/null)" ]]; then
    roms_dir="${HOME}/.local/share/openmsx/systemroms"
  elif [[ -d "${HOME}/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms" ]] && [[ -n "$(find ${HOME}/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms -name "*.rom" -print -quit 2>/dev/null)" ]]; then
    roms_dir="${HOME}/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms"
  fi
  
  if [[ -n "${roms_dir}" ]]; then
    echo "[INFO] System ROMs encontrados em: ${roms_dir}"
    return 0
  else
    return 1
  fi
}

# Se as ROMs não estão instaladas, tenta instalar
if ! check_system_roms_installed; then
  echo "[INFO] System ROMs nao encontrados. Preparando..."
  
  if [[ -f "${COPY_ROMS_SCRIPT}" ]]; then
    if ! bash "${COPY_ROMS_SCRIPT}"; then
      echo "[WARN] Falha ao preparar system ROMs com copy-systemroms.sh"
      echo "[WARN] As ROMs podem estar indisponíveis no momento. Continuando mesmo assim..."
    fi
  else
    echo "[WARN] Script copy-systemroms.sh nao encontrado em: ${COPY_ROMS_SCRIPT}"
    echo "[WARN] Execute manualmente: ${SCRIPT_DIR}/copy-systemroms.sh"
  fi
else
  echo "[INFO] System ROMs ja estao instaladas. Pulando copia."
fi

mkdir -p "${SERVICE_DIR}"

cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=MSX Air openMSX launcher
After=graphical-session.target

[Service]
Type=simple
WorkingDirectory=${PROJECT_ROOT}
ExecStart=${LAUNCHER}
Restart=on-failure

[Install]
WantedBy=default.target
EOF

echo "[INFO] Service criada em ${SERVICE_FILE}"

if ! command -v systemctl >/dev/null 2>&1; then
  echo "[WARN] systemctl nao encontrado."
  echo "[WARN] A unit foi criada, mas nao pode ser habilitada automaticamente."
  echo "[INFO] Execute o launcher manualmente: ${LAUNCHER}"
  exit 0
fi

if ! systemctl --user show-environment >/dev/null 2>&1; then
  echo "[WARN] systemd --user indisponivel nesta sessao (ex.: container sem user bus)."
  echo "[WARN] A unit foi criada em ${SERVICE_FILE}, mas nao foi habilitada."
  echo "[INFO] Em ambiente desktop com systemd de usuario ativo, rode:"
  echo "[INFO]   systemctl --user daemon-reload"
  echo "[INFO]   systemctl --user enable --now msxair-openmsx.service"
  echo "[INFO] No container, use execucao manual: ${LAUNCHER}"
  exit 0
fi

echo "[INFO] Ativando service no systemd de usuario"
systemctl --user daemon-reload
systemctl --user enable msxair-openmsx.service

echo "[INFO] Concluido. Reinicie a sessao ou rode: systemctl --user start msxair-openmsx.service"
