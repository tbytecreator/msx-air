# TED com interface em ingles

`TED.COM` e o editor TED (riesvriend/msx2026) compilado com a interface em ingles.
O upstream so traz a interface em holandes/alemao no binario (o manual em ingles e `TED26ENG.DOC`).

- `ted-english.patch`: diff (formato `diff -u`) sobre os fontes `OFFSET.MAC`, `MAIN.MAC`, `SUBTED.MAC` e `TEDSTR.MAC` do upstream.
  Adiciona o idioma `engels` (`taal equ engels`), a tecla "sim" `Y` (`yesKey`) e a tecla `R` (record length) no dialogo de sort.
- `gen_en.py`: gera o bloco ingles de `TEDSTR.MAC` (textos e teclas de atalho).
- Build: Nestor80 (`N80`) e `LK80`:
  `N80 ENTRY.MAC SUBTED.MAC GETPUT.MAC TEDSTR.MAC MAIN.MAC` e
  `LK80 -c 0100h -o TED.COM ENTRY.REL SUBTED.REL GETPUT.REL TEDSTR.REL MAIN.REL`.

Nao testado em emulador. `download-hdd-software.sh` substitui o `TED.COM` baixado por este.
