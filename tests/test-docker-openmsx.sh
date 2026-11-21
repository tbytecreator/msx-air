#!/usr/bin/env bash
set -euo pipefail

image="${1:-msxair:bookworm}"

docker run --rm -i \
  -e SDL_VIDEODRIVER=offscreen \
  -e SDL_AUDIODRIVER=dummy \
  "$image" bash -s <<'SH'
set -euo pipefail

openmsx -v | grep -Fx 'openMSX 22.0'
if ldd /usr/bin/openmsx | grep -q 'not found'; then
  echo "Bibliotecas do openMSX ausentes" >&2
  exit 1
fi
for extension in programmabledevice smxwifi nextor-ide; do
  test -f "/usr/share/openmsx/extensions/${extension}.xml"
done

cat >> /opt/msxair/src/init-fullscreen.tcl <<'TCL'
after time 8 {
    set f [open /tmp/msxair-boot-check w]
    puts $f "machine=[machine_info config_name]"
    puts $f "extensions=[list_extensions]"
    puts $f "hdd=[hda]"
    puts $f "floppy=[diska]"
    close $f
    exit
}
TCL

timeout 90 /opt/msxair/src/launch-msxair.sh
grep -Fx 'machine=Panasonic_FS-A1GT' /tmp/msxair-boot-check
grep -Fx 'extensions=nextor-ide' /tmp/msxair-boot-check
grep -Fx 'hdd=hda: /root/MSX/media/msxair-hdd.dsk' /tmp/msxair-boot-check
grep -Fx 'floppy=diska: /root/MSX/media/msxair-empty-floppy.dsk' /tmp/msxair-boot-check
SH
