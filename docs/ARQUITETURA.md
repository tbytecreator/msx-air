# Arquitetura

## Estrutura de arquivos

```text
.
├── docker/
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── README.md
├── docs/
│   ├── ARQUITETURA.md
│   ├── DOCKER.md
│   ├── IMPLEMENTACAO.md
│   ├── README.md
│   └── USO-RAPIDO.md
├── src/
│   ├── check-deps.sh
│   ├── copy-systemroms.sh
│   ├── create-hdd-image.sh
│   ├── create-hdd.tcl
│   ├── create-nextor-hdd.py
│   ├── download-nextor-latest.sh
│   ├── init-fullscreen.tcl
│   ├── install-host-deps.sh
│   ├── openmsx-install.sh
│   ├── nooverview-install.sh
│   ├── launch-msxair.sh
│   ├── msxair.conf
│   ├── msxair-setup.sh
│   ├── setup-autostart.sh
│   ├── nextor-boot-files/
│   │   ├── NEXTOR.SYS      (v2.1.3, atualizado por download-nextor-latest.sh)
│   │   ├── COMMAND2.COM
│   │   ├── MSXDOS.SYS
│   │   ├── COMMAND.COM
│   │   ├── EPTCFT.COM      (v2.1.2, novo)
│   │   ├── MAPDRV.COM      (v2.1.2, atualizado)
│   │   └── ... (demais ferramentas Nextor v2.1.0)
│   └── systemroms/
│       ├── machines/
│       └── extensions/
│           └── Nextor-2.1.4.SunriseIDE.blueMSX.rom  (baixado por download-nextor-latest.sh)
├── docker-build.sh
├── docker-run.sh
├── msxair.md
└── openmsx-install.sh
```

## Responsabilidades

- `src/check-deps.sh` ⭐
  - **Novo**: Script de verificação de dependências do host
  - Valida presença de bibliotecas SDL2, ALSA, OpenGL necessárias
  - Oferece instruções de instalação se algo faltar
  - Útil para diagnosticar problemas de execução

- `src/msxair-setup.sh` ⭐
  - **Novo**: Script de setup unificado que executa todos os passos em ordem
  - Executa em sequência: `openmsx-install.sh` → `nooverview-install.sh` → `download-nextor-latest.sh` → `copy-systemroms.sh` → `setup-autostart.sh`
  - `download-nextor-latest.sh` é tratado como passo opcional (falha de rede nao aborta o setup)
  - Apos os scripts de setup, reconstroi automaticamente a imagem Docker se `docker` estiver disponivel
  - Ao final, chama `launch-msxair.sh` para iniciar o emulador
  - Valida permissões e existência dos scripts
  - Para imediatamente se algum passo critico falhar
  - Mensagens de progresso com barras visuais

- `src/install-openmsx.sh`
  - Oferece opcoes: instalacao nativa (APT) ou Flatpak
  - Instala `openmsx` e `openmsx-systemroms` conforme escolhido
  - Cria diretorio padrao de midia em `$HOME/MSX/media`

- `src/nooverview-install.sh` ⭐
  - **Novo**: Instala extensao GNOME "No Overview at startup" (melhora UX)
  - Instala `gnome-tweaks` e `gnome-shell-extensions`
  - Clona e ativa a extensao do repositorio GitHub
  - Gracefully falha em ambientes nao-GNOME
  - Setup opcional: pode ser pulado se necessario

- `src/copy-systemroms.sh` ⭐
  - **Novo**: Copia system ROMs de `src/systemroms/` para local correto
  - Detecta automaticamente: instalacao nativa vs Flatpak
  - Cria diretorio de destino se nao existir
  - Nativo: `~/.local/share/openmsx/systemroms`, `/usr/share/openmsx/systemroms` (global APT), ou `~/.openmsx/systemroms` (legado)
  - Flatpak: `~/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms`

- `src/init-fullscreen.tcl` ⭐
  - **Novo**: Script Tcl com comando `set fullscreen on`
  - Carregado via `-script` ao iniciar openMSX
  - Ativa tela cheia automaticamente no startup
  - Para Flatpak: copiado automaticamente para `~/.var/app/org.openmsx.openMSX/data/` para acesso dentro do sandbox
  - Para nativo: usado direto do diretorio `src/`

- `src/msxair.conf`
  - Centraliza parametros de execucao
  - Define maquina Turbo-R (Panasonic_FS-A1GT) e extensoes desejadas
  - Extensao IDE: `nextor-ide` (extensao customizada que carrega o ROM Nextor)
  - Permite informar ROM/DSK de autostart
  - Suporte a comando de preparacao de rede (WIFI_PRE_START_CMD)

- `src/create-nextor-hdd.py` ⭐
  - **Novo**: Script Python que gera imagem HDD compativel com Sunrise IDE
  - Cria MBR com tabela de particoes padrao (compativel com Nextor)
  - 3 particoes FAT16 de 32MB cada (96MB total)
  - Particao 1: NEXTOR.SYS, COMMAND2.COM, MSXDOS.SYS, COMMAND.COM + TOOLS/
  - TOOLS/ inclui 14 ferramentas: MAPDRV, EPTCFT (v2.1.2), EMUFILE, DEVINFO, etc.
  - AUTOEXEC.BAT configura PATH e exibe versao via `NSYSVER`
  - Particoes 2 e 3: vazias para uso geral
  - Nao depende do openMSX (gera imagem diretamente via Python)
  - Uso: `python3 create-nextor-hdd.py [caminho-saida] [dir-nextor-files]`

- `src/create-hdd-image.sh` ⭐
  - **Novo**: Script shell wrapper para criacao de HDD via openMSX (diskmanipulator)
  - Detecta openMSX (nativo ou Flatpak)
  - Baixa ferramentas Nextor v2.1.0 (base tools, sem alteracoes desde 2.1.0)
  - Baixa e instala ROM `Nextor-2.1.4.SunriseIDE.blueMSX.rom` em `systemroms/extensions/`
  - Chama openMSX com `create-hdd.tcl` para criar a imagem via diskmanipulator

- `src/create-hdd.tcl` ⭐
  - **Novo**: Script Tcl para criacao de HDD via openMSX (diskmanipulator)
  - Cria 3 particoes de 32MB no formato Nextor
  - Importa arquivos de boot e ferramentas nas particoes

- `src/nextor-ide.xml` ⭐
  - **Novo**: Extensao openMSX customizada para Sunrise IDE com Nextor
  - O `ide.xml` padrao do openMSX 20.0 so aceita SHA1 do Sunrise IDE classico (sem Nextor)
  - Este XML lista os SHA1 dos ROMs Nextor 2.0, 2.0.1, 2.1.0 e 2.1.4 para openMSX
  - Instalado em `/usr/share/openmsx/extensions/` no container e em `~/.openMSX/share/extensions/` para Flatpak

- `src/download-nextor-latest.sh` ⭐
  - **Novo**: Baixa os arquivos mais recentes do Nextor (2.1.4) do GitHub
  - `Nextor-2.1.4.SunriseIDE.blueMSX.rom` → `systemroms/extensions/` (ROM para openMSX)
  - `NEXTOR.SYS` v2.1.3 → `nextor-boot-files/` (kernel Nextor mais recente)
  - `MAPDRV.COM` e `EPTCFT.COM` v2.1.2 → `nextor-boot-files/`
  - Suporta `--force` para re-download; nao-fatal se sem internet
  - Chamado automaticamente por `launch-msxair.sh` e `msxair-setup.sh`

- `src/nextor-boot-files/` ⭐
  - **Novo**: Diretorio com arquivos de boot do Nextor
  - NEXTOR.SYS (v2.1.0 no repo; v2.1.3 apos `download-nextor-latest.sh`)
  - COMMAND2.COM, MSXDOS.SYS, COMMAND.COM (v2.1.0)
  - 14 ferramentas: MAPDRV e EPTCFT (v2.1.2), demais v2.1.0

- `src/launch-msxair.sh`
  - Le o arquivo de configuracao
  - Carrega script de fullscreen via `-script init-fullscreen.tcl`
  - Garante existencia do diretorio de midia
  - Cria imagem HDD automaticamente se extensao IDE ativa e imagem nao existir
  - Cria `~/MSX/media/msxair-empty-floppy.dsk` (FAT12 720KB) antes do boot para evitar "not ready reading drive A:" do FS-A1GT
  - Monta os argumentos do openMSX com `-hda` (disco rigido) e `-diska` (floppy vazio)
  - Inicia o emulador

- `src/setup-autostart.sh`
  - Cria service de usuario no systemd para iniciar no login
  - Nao falha em containers sem systemd --user

- `docker/Dockerfile`
  - Imagem baseada em `debian:bookworm`
  - Instala openMSX, alsa-utils, libasound2, libasound2-plugins e python3
  - Alinha GID do grupo audio com o host (GID 29) para acesso correto a /dev/snd
  - Copia `src/`, `docs/` e scripts raiz para `/opt/msxair`
  - Instala `nextor-ide.xml` em `/usr/share/openmsx/extensions/` para que o openMSX carregue o ROM Nextor
  - Gera imagem HDD com Nextor durante o build (via create-nextor-hdd.py)

- `dockerrun.sh`
  - Script de execucao do container com deteccao automatica de dispositivos
  - Mapeia X11/Unix socket para interface grafica
  - Mapeia `/dev/snd` e `/proc/asound` condicionalmente para audio ALSA
  - Mapeia `/dev/dri` condicionalmente para aceleracao grafica
  - Monta volume `$HOME/roms/msx` para ROMs e DSKs
  - Monta volume `$HOME/MSX/media` para imagem HDD do Sunrise IDE
