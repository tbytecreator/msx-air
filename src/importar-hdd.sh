#!/usr/bin/env bash

set -euo pipefail

HDD_IMAGE="${HOME}/MSX/media/msxair-hdd.dsk"

if [[ $# -eq 0 ]]; then
  echo "Uso: $0 arquivo [arquivo ...]" >&2
  echo "Importa arquivos 8.3 para a raiz da primeira particao do HDD." >&2
  exit 1
fi

for cmd in python3 flock mdir mcopy realpath; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERRO] Dependencia nao encontrada: $cmd (mcopy e mdir pertencem ao pacote mtools)." >&2
    exit 1
  fi
done

if [[ ! -f "$HDD_IMAGE" || -L "$HDD_IMAGE" ]]; then
  echo "[ERRO] HDD inexistente ou link simbolico: $HDD_IMAGE" >&2
  echo "[ERRO] Preserve ou crie a imagem no host antes de importar." >&2
  exit 1
fi

exec 9>"${HOME}/MSX/media/.msxair-hdd.lock"
if ! flock -n -x 9; then
  echo "[ERRO] HDD em uso pelo MSX Air ou por outra importacao. Feche o emulador." >&2
  exit 1
fi

sources=()
names=()
for file in "$@"; do
  if [[ ! -f "$file" || ! -r "$file" ]]; then
    echo "[ERRO] Arquivo inexistente ou ilegivel: $file" >&2
    exit 1
  fi
  name="${file##*/}"
  if [[ ! "$name" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]{0,7}(\.[a-zA-Z0-9_]{1,3})?$ ]]; then
    echo "[ERRO] Nome incompativel com MSX-DOS 8.3: $name" >&2
    exit 1
  fi
  name="${name^^}"
  for previous in "${names[@]}"; do
    if [[ "$name" == "$previous" ]]; then
      echo "[ERRO] Nome duplicado na importacao: $name" >&2
      exit 1
    fi
  done
  if [[ "$file" -ef "$HDD_IMAGE" ]]; then
    echo "[ERRO] A imagem HDD nao pode ser importada para si mesma." >&2
    exit 1
  fi
  sources+=("$(realpath -e -- "$file")")
  names+=("$name")
done

offset=$(python3 - "$HDD_IMAGE" <<'PY'
import os
import struct
import sys

with open(sys.argv[1], "rb") as image:
    mbr = image.read(512)
    if len(mbr) != 512 or mbr[510:512] != b"\x55\xaa":
        sys.exit("[ERRO] MBR invalido na imagem HDD.")
    entry = mbr[446:462]
    start, size = struct.unpack_from("<II", entry, 8)
    if entry[4] not in (0x04, 0x06, 0x0e) or not start or not size:
        sys.exit("[ERRO] Primeira particao FAT16 inexistente ou invalida.")
    if (start + size) * 512 > os.fstat(image.fileno()).st_size:
        sys.exit("[ERRO] Primeira particao ultrapassa o tamanho da imagem.")
    print(start * 512)
PY
)

disk="${HDD_IMAGE}@@${offset}"
if ! mdir -i "$disk" ::/ >/dev/null; then
  echo "[ERRO] Nao foi possivel ler a primeira particao do HDD." >&2
  exit 1
fi
for name in "${names[@]}"; do
  if mdir -i "$disk" "::/${name}" >/dev/null 2>&1; then
    echo "[ERRO] Arquivo ou diretorio ja existe no HDD: $name" >&2
    exit 1
  fi
done

backup=$(mktemp "${HDD_IMAGE}.backup.XXXXXXXX")
if ! cp -p -- "$HDD_IMAGE" "$backup"; then
  rm -f -- "$backup"
  echo "[ERRO] Nao foi possivel criar o backup; HDD nao alterado." >&2
  exit 1
fi
echo "[INFO] Backup criado: $backup"

work=$(mktemp "${HDD_IMAGE}.import.XXXXXXXX")
trap 'rm -f -- "$work"' EXIT
cp -p -- "$HDD_IMAGE" "$work"
for i in "${!sources[@]}"; do
  if ! mcopy -n -i "${work}@@${offset}" "${sources[$i]}" "::/${names[$i]}"; then
    echo "[ERRO] Falha ao importar ${names[$i]}; HDD original nao alterado." >&2
    exit 1
  fi
done

mv -f -- "$work" "$HDD_IMAGE"
echo "[OK] Importados para a raiz da primeira particao: ${names[*]}"
