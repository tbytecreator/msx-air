#!/usr/bin/env bash

set -euo pipefail

# Se o usuario passar um comando (ex: bash), executa esse comando.
if [[ $# -gt 0 ]]; then
  exec "$@"
fi

# Sem comando explicito, inicia o launcher principal do projeto.
exec /opt/msxair/src/launch-msxair.sh
