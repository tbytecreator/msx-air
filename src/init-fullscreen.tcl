# Script de inicialização do openMSX para ativar tela cheia
set fullscreen on

# FS-A1GT tem drive de disquete interno mapeado como A:.
# Sem disquete, o Nextor exibe "not ready reading drive A:".
# Montamos um disco FAT12 vazio: Nextor lê A: sem erro,
# não encontra COMMAND2.COM ali e faz boot pelo HDD (drive C:).
set _ef "/tmp/msxair-empty-floppy.dsk"
if {![file exists $_ef]} {
    diskmanipulator create $_ef 720K
}
catch {diska $_ef}
unset _ef
