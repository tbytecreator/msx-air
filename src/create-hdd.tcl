# create-hdd.tcl - Script Tcl para openMSX
# Cria uma imagem de HDD particionada com Nextor para uso com Sunrise IDE.
#
# Uso (via openMSX):
#   openmsx -machine C-BIOS_MSX2+ -ext ide -script create-hdd.tcl
#
# O script espera as seguintes variáveis de ambiente (via -setting ou defaults):
#   HDD_IMAGE  - caminho completo para a imagem HDD de saída
#   NEXTOR_DIR - diretório com os arquivos Nextor (NEXTOR.SYS, COMMAND2.COM, etc.)
#
# A imagem será criada com:
#   - Partição 1: 32MB (boot, com NEXTOR.SYS + COMMAND2.COM + ferramentas)
#   - Partição 2: 32MB (uso geral)
#   - Partição 3: 32MB (uso geral)

after time 2 {

    set hdd_image $env(HDD_IMAGE)
    set nextor_dir $env(NEXTOR_DIR)

    puts "==========================================="
    puts " MSX Air - Criando imagem HDD com Nextor"
    puts "==========================================="
    puts ""
    puts "Imagem HDD: $hdd_image"
    puts "Diretorio Nextor: $nextor_dir"
    puts ""

    # Desliga a máquina emulada (necessário para o diskmanipulator)
    set power off

    # Cria a imagem HDD com 3 partições de 32MB, formato Nextor (FAT16)
    puts "\[1/4\] Criando imagem HDD com 3 particoes de 32MB (Nextor)..."
    diskmanipulator create $hdd_image -nextor 32M 32M 32M
    puts "  -> Imagem criada com sucesso."

    # Associa a imagem ao drive IDE master
    hda $hdd_image

    # Importa os arquivos de boot do Nextor na partição 1
    puts "\[2/4\] Importando arquivos de boot Nextor na particao 1..."

    set boot_files {NEXTOR.SYS COMMAND2.COM MSXDOS.SYS COMMAND.COM}

    foreach f $boot_files {
        set fpath "$nextor_dir/$f"
        if {[file exists $fpath]} {
            puts "  -> Importando $f"
            diskmanipulator import hda1 $fpath
        } else {
            puts "  -> AVISO: $f nao encontrado em $nextor_dir"
        }
    }

    # Importa as ferramentas Nextor na partição 1 (subdiretório TOOLS)
    puts "\[3/4\] Importando ferramentas Nextor na particao 1..."
    diskmanipulator mkdir hda1 TOOLS

    diskmanipulator chdir hda1 /TOOLS

    set tool_files {
        DELALL.COM DEVINFO.COM DRIVERS.COM DRVINFO.COM
        FASTOUT.COM LOCK.COM MAPDRV.COM EMUFILE.COM
        RALLOC.COM Z80MODE.COM NSYSVER.COM NEXBOOT.COM
        CONCLUS.COM
    }

    foreach f $tool_files {
        set fpath "$nextor_dir/$f"
        if {[file exists $fpath]} {
            puts "  -> Importando $f"
            diskmanipulator import hda1 $fpath
        }
    }

    # Volta ao diretório raiz
    diskmanipulator chdir hda1 /

    # Cria um AUTOEXEC.BAT simples na partição 1
    puts "\[4/4\] Criando AUTOEXEC.BAT..."
    set autoexec_path "$nextor_dir/../AUTOEXEC.BAT"
    set fd [open $autoexec_path w]
    puts $fd "ECHO."
    puts $fd "ECHO  ** MSX Air - Nextor 2.1.0 **"
    puts $fd "ECHO  ** Bem-vindo ao disco rigido virtual **"
    puts $fd "ECHO."
    puts $fd "SET PATH=A:\\TOOLS"
    close $fd

    diskmanipulator import hda1 $autoexec_path

    # Remove o arquivo temporário
    file delete $autoexec_path

    puts ""
    puts "==========================================="
    puts " Imagem HDD criada com sucesso!"
    puts " Arquivo: $hdd_image"
    puts "==========================================="
    puts ""

    exit
}
