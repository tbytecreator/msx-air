#!/usr/bin/env bash
set -euo pipefail

image="${1:-msxair:bookworm}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker run --rm -i \
  -e SDL_VIDEODRIVER=offscreen \
  -e SDL_AUDIODRIVER=dummy \
  -v "$repo/src/init-fullscreen.tcl:/tmp/msxair-init.tcl:ro" \
  "$image" bash -s <<'SH'
set -euo pipefail

cp /tmp/msxair-init.tcl /opt/msxair/src/init-fullscreen.tcl
cat >> /opt/msxair/src/init-fullscreen.tcl <<'TCL'
after realtime 3 { exit }
TCL

ini=/root/.openMSX/share/imgui.ini
rm -f "$ini"
timeout 90 /opt/msxair/src/launch-msxair.sh

python3 - "$ini" <<'PY'
import configparser
import sys

config = configparser.ConfigParser()
config.read(sys.argv[1])
for section, key in (
    ("machine", "showQuickSetupEditor"),
    ("reverse bar", "show"),
    ("OSD icons", "show"),
):
    assert config[f"openmsx][{section}"][key] == "0", (section, key)
PY

cat > "$ini" <<'INI'
[openmsx][machine]
hideNonWorkingMachines=1
showQuickSetupEditor=1

[openmsx][reverse bar]
show=1

[openmsx][OSD icons]
show=1

[openmsx][console]
show=1

[openmsx][debugger]
showControl=1
showChanges=1
disassemblyViewers=1
hexEditor.Main RAM=1

[openmsx][Disassembly]
show=1

[openmsx][Main RAM]
open=1

[openmsx][manager]
mainMenuBarUndocked=1
mainMenuBarFade=0
statusBarVisible=1
INI
timeout 90 /opt/msxair/src/launch-msxair.sh

python3 - "$ini" <<'PY'
import configparser
import sys

config = configparser.ConfigParser()
config.read(sys.argv[1])
for section, key in (
    ("machine", "showQuickSetupEditor"),
    ("reverse bar", "show"),
    ("OSD icons", "show"),
    ("console", "show"),
    ("debugger", "showControl"),
    ("manager", "mainMenuBarUndocked"),
    ("manager", "statusBarVisible"),
):
    assert config[f"openmsx][{section}"][key] == "0", (section, key)
assert config["openmsx][machine"]["hideNonWorkingMachines"] == "1"
assert config["openmsx][debugger"]["showChanges"] == "1"
assert config["openmsx][debugger"]["disassemblyViewers"] == "0"
assert "hexEditor.Main RAM" not in config["openmsx][debugger"]
assert config["openmsx][manager"]["mainMenuBarFade"] == "1"
PY
echo "Inicializacao sem overlays verificada."
SH
