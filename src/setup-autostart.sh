#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SERVICE_DIR}/msxair-openmsx.service"
LAUNCHER="${SCRIPT_DIR}/launch-msxair.sh"

if [[ ! -x "${LAUNCHER}" ]]; then
  echo "[INFO] Ajustando permissao de execucao para ${LAUNCHER}"
  chmod +x "${LAUNCHER}"
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
