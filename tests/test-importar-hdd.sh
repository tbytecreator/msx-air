#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp=$(mktemp -d)
launcher_pid=""
cleanup() {
  if [[ -n "$launcher_pid" ]]; then
    kill "$launcher_pid" 2>/dev/null || true
    wait "$launcher_pid" 2>/dev/null || true
  fi
  rm -rf -- "$tmp"
}
trap cleanup EXIT
export HOME="$tmp/home"
mkdir -p "$HOME/MSX/media" "$tmp/files" "$tmp/bin"
image="$HOME/MSX/media/msxair-hdd.dsk"

python3 "$ROOT/src/create-nextor-hdd.py" "$image" "$ROOT/src/nextor-boot-files" >/dev/null
offset=$(python3 - "$image" <<'PY'
import struct
import sys
with open(sys.argv[1], "rb") as f:
    f.seek(454)
    print(struct.unpack("<I", f.read(4))[0] * 512)
PY
)
printf 'teste MSX\n' > "$tmp/files/JOGO.ROM"
original=$(sha256sum "$image" | cut -d' ' -f1)
bash "$ROOT/src/importar-hdd.sh" "$tmp/files/JOGO.ROM"
mcopy -i "$image@@$offset" ::/JOGO.ROM "$tmp/export.rom"
cmp "$tmp/files/JOGO.ROM" "$tmp/export.rom"
backups=("$image".backup.*)
[[ ${#backups[@]} -eq 1 ]]
[[ $(sha256sum "${backups[0]}" | cut -d' ' -f1) == "$original" ]]

after=$(sha256sum "$image" | cut -d' ' -f1)
if bash "$ROOT/src/importar-hdd.sh" "$tmp/files/JOGO.ROM"; then
  echo "Conflito deveria falhar" >&2
  exit 1
fi
printf x > "$tmp/files/nome-longo.rom"
if bash "$ROOT/src/importar-hdd.sh" "$tmp/files/nome-longo.rom"; then
  echo "Nome invalido deveria falhar" >&2
  exit 1
fi
printf y > "$tmp/files/NOVO.TXT"
exec 8>"$HOME/MSX/media/.msxair-hdd.lock"
flock -s 8
if bash "$ROOT/src/importar-hdd.sh" "$tmp/files/NOVO.TXT"; then
  echo "Importacao com HDD bloqueado deveria falhar" >&2
  exit 1
fi
flock -u 8
exec 8>&-
[[ $(sha256sum "$image" | cut -d' ' -f1) == "$after" ]]

printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/bin/mcopy"
chmod +x "$tmp/bin/mcopy"
if PATH="$tmp/bin:$PATH" bash "$ROOT/src/importar-hdd.sh" "$tmp/files/NOVO.TXT"; then
  echo "Falha de copia deveria falhar" >&2
  exit 1
fi
[[ $(sha256sum "$image" | cut -d' ' -f1) == "$after" ]]
if mdir -i "$image@@$offset" ::/NOVO.TXT >/dev/null 2>&1; then
  echo "Arquivo nao deveria existir apos falha" >&2
  exit 1
fi

mkdir -p "$tmp/launcher" "$tmp/openmsx-bin"
cp "$ROOT/src/launch-msxair.sh" "$tmp/launcher/"
cat > "$tmp/launcher/msxair.conf" <<'EOF'
MEDIA_DIR="${HOME}/roms/msx"
MACHINE="teste"
EXTENSIONS=("nextor-ide")
WIFI_PRE_START_CMD=""
AUTOSTART_ROM=""
AUTOSTART_DSK=""
EOF
cat > "$tmp/openmsx-bin/openmsx" <<'EOF'
#!/usr/bin/env bash
touch "$TEST_SIGNAL_DIR/started"
while [[ ! -e "$TEST_SIGNAL_DIR/stop" ]]; do sleep 0.1; done
EOF
chmod +x "$tmp/openmsx-bin/openmsx"
export TEST_SIGNAL_DIR="$tmp"
PATH="$tmp/openmsx-bin:$PATH" bash "$tmp/launcher/launch-msxair.sh" >"$tmp/launcher.log" 2>&1 &
launcher_pid=$!
for _ in {1..100}; do
  [[ -e "$tmp/started" ]] && break
  if ! kill -0 "$launcher_pid" 2>/dev/null; then break; fi
  sleep 0.1
done
if [[ ! -e "$tmp/started" ]]; then
  cat "$tmp/launcher.log" >&2
  echo "Launcher nao iniciou" >&2
  exit 1
fi
if bash "$ROOT/src/importar-hdd.sh" "$tmp/files/NOVO.TXT"; then
  echo "Importacao com launcher ativo deveria falhar" >&2
  exit 1
fi
touch "$tmp/stop"
wait "$launcher_pid"
launcher_pid=""
bash "$ROOT/src/importar-hdd.sh" "$tmp/files/NOVO.TXT"
mcopy -i "$image@@$offset" ::/NOVO.TXT "$tmp/export.txt"
cmp "$tmp/files/NOVO.TXT" "$tmp/export.txt"

mkdir -p "$tmp/docker-bin"
cat > "$tmp/docker-bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
echo "install ok installed"
EOF
cat > "$tmp/docker-bin/xhost" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$tmp/docker-bin/docker" <<'EOF'
#!/usr/bin/env bash
touch "$TEST_SIGNAL_DIR/docker-started"
while [[ ! -e "$TEST_SIGNAL_DIR/docker-stop" ]]; do sleep 0.1; done
EOF
chmod +x "$tmp/docker-bin/"*
PATH="$tmp/docker-bin:$PATH" DISPLAY=:123 WAYLAND_DISPLAY= \
  bash "$ROOT/docker-run.sh" >"$tmp/docker.log" 2>&1 &
launcher_pid=$!
for _ in {1..100}; do
  [[ -e "$tmp/docker-started" ]] && break
  if ! kill -0 "$launcher_pid" 2>/dev/null; then break; fi
  sleep 0.1
done
if [[ ! -e "$tmp/docker-started" ]]; then
  cat "$tmp/docker.log" >&2
  echo "Launcher Docker nao iniciou" >&2
  exit 1
fi
printf z > "$tmp/files/OUTRO.TXT"
if bash "$ROOT/src/importar-hdd.sh" "$tmp/files/OUTRO.TXT"; then
  echo "Importacao com launcher Docker ativo deveria falhar" >&2
  exit 1
fi
touch "$tmp/docker-stop"
wait "$launcher_pid"
launcher_pid=""

echo "Testes de importacao concluidos."
