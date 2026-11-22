#!/usr/bin/env bash
set -euo pipefail

image="${1:-msxair:bookworm}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for cmd in flatpak docker mcopy python3; do
  command -v "$cmd" >/dev/null || { echo "Dependencia ausente: $cmd" >&2; exit 1; }
done
flatpak info org.openmsx.openMSX >/dev/null

test_dir=$(mktemp -d)
container=""
server=""
cleanup() {
  if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi
  if [[ -n "$container" ]]; then docker rm "$container" >/dev/null; fi
  rm -rf -- "$test_dir"
}
trap cleanup EXIT

home="$test_dir/home"
project="$test_dir/project"
mkdir -p "$home/MSX/media" "$home/.openMSX/share/systemroms/machines" "$project"
cp "$repo/src/launch-msxair.sh" "$repo/src/msxair.conf" "$repo/src/init-fullscreen.tcl" \
  "$repo/src/nextor-ide.xml" "$project/"
ln -s "$repo/src/systemroms" "$project/systemroms"
cp -a "$repo/src/systemroms/machines/panasonic" "$home/.openMSX/share/systemroms/machines/"
cp "$repo/src/systemroms/extensions/Nextor-2.1.4.SunriseIDE.blueMSX.rom" "$home/.openMSX/share/systemroms/"

container=$(docker create "$image")
docker cp "$container:/root/MSX/media/msxair-hdd.dsk" "$home/MSX/media/msxair-hdd.dsk"
docker rm "$container" >/dev/null
container=""

python3 - "$test_dir" <<'PY' &
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import sys

os.chdir(sys.argv[1])
server = ThreadingHTTPServer(("127.0.0.1", 0), SimpleHTTPRequestHandler)
Path("port").write_text(str(server.server_port))
server.serve_forever()
PY
server=$!
for _ in {1..50}; do
  [[ -s "$test_dir/port" ]] && break
  kill -0 "$server"
  sleep 0.1
done
[[ -s "$test_dir/port" ]] || { echo "Servidor HTTP nao iniciou." >&2; exit 1; }
port=$(<"$test_dir/port")
python3 - "$test_dir/expected.txt" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(b"MSXAIR-FLATPAK-UNAPI\n" * 256)
PY

cat >> "$project/init-fullscreen.tcl" <<TCL
set throttle off
after time 20 {
    set throttle on
    type_via_keybuf "HGET http://localhost:${port}/expected.txt /l:A:\\\\RESULT.TXT\\r"
}
after time 40 { type_via_keybuf "TCPIP S > A:\\\\STATUS.TXT\\r" }
after time 50 { exit }
TCL

env -u MSXAIR_UNAPI HOME="$home" SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy \
  timeout 90 bash "$project/launch-msxair.sh"
offset=$(python3 - "$home/MSX/media/msxair-hdd.dsk" <<'PY'
import struct
import sys
with open(sys.argv[1], "rb") as image:
    print(struct.unpack_from("<I", image.read(512), 454)[0] * 512)
PY
)
mcopy -i "$home/MSX/media/msxair-hdd.dsk@@$offset" ::/RESULT.TXT "$test_dir/result.txt"
mcopy -i "$home/MSX/media/msxair-hdd.dsk@@$offset" ::/STATUS.TXT "$test_dir/status.txt"
cmp "$test_dir/expected.txt" "$test_dir/result.txt"
grep -F 'Network state: OPEN' "$test_dir/status.txt"
echo "UNAPI Flatpak e download HTTP verificados."
