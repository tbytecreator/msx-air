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
│   ├── init-fullscreen.tcl
│   ├── install-host-deps.sh
│   ├── openmsx-install.sh
│   ├── nooverview-install.sh
│   ├── launch-msxair.sh
│   ├── msxair.conf
│   ├── msxair-setup.sh
│   ├── setup-autostart.sh
│   ├── nextor-boot-files/
│   │   ├── NEXTOR.SYS
│   │   ├── COMMAND2.COM
│   │   ├── MSXDOS.SYS
│   │   ├── COMMAND.COM
│   │   └── ... (ferramentas Nextor)
│   └── systemroms/
│       ├── machines/
│       └── extensions/
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
  - Executa em sequência: `install-host-deps.sh` → `openmsx-install.sh` → `nooverview-install.sh` → `copy-systemroms.sh` → `setup-autostart.sh`
  - Válida permissões e existência dos scripts
  - Para imediatamente se algum passo falhar
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
  - Permite informar ROM/DSK de autostart
  - Suporte a comando de preparacao de rede (WIFI_PRE_START_CMD)

- `src/create-nextor-hdd.py` ⭐
  - **Novo**: Script Python que gera imagem HDD compativel com Sunrise IDE
  - Cria MBR com tabela de particoes padrao (compativel com Nextor)
  - 3 particoes FAT16 de 32MB cada (96MB total)
  - Particao 1: NEXTOR.SYS, COMMAND2.COM, MSXDOS.SYS, COMMAND.COM + TOOLS/
  - Particoes 2 e 3: vazias para uso geral
  - Nao depende do openMSX (gera imagem diretamente via Python)
  - Uso: `python3 create-nextor-hdd.py [caminho-saida] [dir-nextor-files]`

- `src/create-hdd-image.sh` ⭐
  - **Novo**: Script shell wrapper para criacao de HDD
  - Detecta openMSX (nativo ou Flatpak)
  - Baixa ferramentas Nextor v2.1.0 se necessario
  - Instala ROM Nextor para emuladores
  - Chama openMSX com script Tcl para criar a imagem

- `src/create-hdd.tcl` ⭐
  - **Novo**: Script Tcl para criacao de HDD via openMSX (diskmanipulator)
  - Cria 3 particoes de 32MB no formato Nextor
  - Importa arquivos de boot e ferramentas nas particoes

- `src/nextor-boot-files/` ⭐
  - **Novo**: Diretorio com arquivos de boot do Nextor 2.1.0
  - NEXTOR.SYS, COMMAND2.COM, MSXDOS.SYS, COMMAND.COM
  - 13 ferramentas Nextor (MAPDRV, EMUFILE, DEVINFO, etc.)

- `src/launch-msxair.sh`
  - Le o arquivo de configuracao
  - Carrega script de fullscreen via `-script init-fullscreen.tcl`
  - Garante existencia do diretorio de midia
  - Cria imagem HDD automaticamente se extensao IDE ativa e imagem nao existir
  - Monta os argumentos do openMSX com `-hda` para disco rigido IDE
  - Inicia o emulador

- `src/setup-autostart.sh`
  - Cria service de usuario no systemd para iniciar no login
  - Nao falha em containers sem systemd --user

- `docker/Dockerfile`
  - Imagem baseada em `debian:bookworm`
  - Instala openMSX, alsa-utils, libasound2, libasound2-plugins e python3
  - Alinha GID do grupo audio com o host (GID 29) para acesso correto a /dev/snd
  - Copia `src/`, `docs/` e scripts raiz para `/opt/msxair`
  - Gera imagem HDD com Nextor durante o build (via create-nextor-hdd.py)

- `dockerrun.sh`
  - Script de execucao do container com deteccao automatica de dispositivos
  - Mapeia X11/Unix socket para interface grafica
  - Mapeia `/dev/snd` e `/proc/asound` condicionalmente para audio ALSA
  - Mapeia `/dev/dri` condicionalmente para aceleracao grafica
  - Monta volume `$HOME/roms/msx` para ROMs e DSKs
  - Monta volume `$HOME/MSX/media` para imagem HDD do Sunrise IDE
