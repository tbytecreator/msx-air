#!/usr/bin/env bash
set -euo pipefail

image="${1:-msxair:bookworm}"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for cmd in docker mcopy python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Dependencia nao encontrada: $cmd" >&2
    exit 1
  fi
done

if output=$(docker run --rm -e MSXAIR_UNAPI=invalid "$image" /opt/msxair/src/launch-msxair.sh 2>&1); then
  echo "Configuracao UNAPI invalida foi aceita." >&2
  exit 1
fi
grep -F 'MSXAIR_UNAPI deve ser 0 ou 1' <<< "$output"

if output=$(docker run --rm -e MSXAIR_UNAPI=1 "$image" bash -c \
  'printf "\nAUTOSTART_ROM=game.rom\n" >> /opt/msxair/src/msxair.conf; exec /opt/msxair/src/launch-msxair.sh' 2>&1); then
  echo "UNAPI e AUTOSTART_ROM foram aceitos simultaneamente." >&2
  exit 1
fi
grep -F 'UNAPI pode ocupar o slot de AUTOSTART_ROM' <<< "$output"

test_dir=$(mktemp -d)
trap 'rm -f -- "$test_dir/expected.txt" "$test_dir/result.txt" "$test_dir/status.txt" "$test_dir/hdd.dsk" "$test_dir/installed"; rmdir -- "$test_dir"' EXIT
python3 - "$test_dir/expected.txt" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(b"MSXAIR-UNAPI-OK\n" * 256)
PY

docker run --rm -i \
  -e SDL_VIDEODRIVER=offscreen \
  -e SDL_AUDIODRIVER=dummy \
  -v "$repo_dir/src/systemroms:/opt/msxair/src/systemroms:ro" \
  -v "$test_dir:/test" \
  "$image" bash -s <<'SH'
set -euo pipefail

python3 -m http.server 18888 --bind 127.0.0.1 --directory /test >/tmp/http.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
sleep 1
python3 -c 'import socket; socket.create_connection(("127.0.0.1", 18888), timeout=3).close()'

cat >> /opt/msxair/src/init-fullscreen.tcl <<'TCL'
set throttle off
after time 20 {
    set throttle on
    type_via_keybuf "HGET http://localhost:18888/expected.txt /l:A:\\RESULT.TXT\r"
}
after time 40 { type_via_keybuf "TCPIP S > A:\\STATUS.TXT\r" }
after time 50 { exit }
TCL

timeout 90 /opt/msxair/src/launch-msxair.sh
grep -F '"GET /expected.txt HTTP/1.1" 200' /tmp/http.log
cp /root/MSX/media/msxair-hdd.dsk /test/hdd.dsk
SH

offset=$(python3 - "$test_dir/hdd.dsk" <<'PY'
import struct
import sys
with open(sys.argv[1], "rb") as image:
    mbr = image.read(512)
print(struct.unpack_from("<I", mbr, 454)[0] * 512)
PY
)
mcopy -i "$test_dir/hdd.dsk@@$offset" ::/RESULT.TXT "$test_dir/result.txt"
cmp "$test_dir/expected.txt" "$test_dir/result.txt"
mcopy -i "$test_dir/hdd.dsk@@$offset" ::/STATUS.TXT "$test_dir/status.txt"
grep -F 'Network state: OPEN' "$test_dir/status.txt"
for file in CHKSSH.COM HGET.COM HUB.COM HUBG.COM INSTAGR8.COM SNTP.COM \
  SSH.COM TCPIP.COM TELNET.COM TELNETF.COM TELNET.ROM TFTP.COM WAITWIFI.COM; do
  [[ -f "$repo_dir/src/hdd-software/UNAPI/$file" ]]
done
[[ -f "$repo_dir/src/hdd-software/FILEHUNT/FH.COM" ]]
for dir in UNAPI UNAPI/DOCS FILEHUNT; do
  for source in "$repo_dir/src/hdd-software/$dir/"*; do
    [[ -f "$source" ]] || continue
    mcopy -o -i "$test_dir/hdd.dsk@@$offset" "::/$dir/${source##*/}" "$test_dir/installed"
    cmp "$source" "$test_dir/installed"
  done
done
echo "Download HTTP via UNAPI concluido e verificado."
echo "Programas e documentacao UNAPI e File-Hunter verificados no HDD."
