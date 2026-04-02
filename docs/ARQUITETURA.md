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
│   ├── init-fullscreen.tcl
│   ├── install-host-deps.sh
│   ├── openmsx-install.sh
│   ├── nooverview-install.sh
│   ├── launch-msxair.sh
│   ├── msxair.conf
│   ├── msxair-setup.sh
│   ├── setup-autostart.sh
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
  - Cria diretory de destino se nao existir
  - Nativo: `~/.local/share/openmsx/systemroms` ou `~/.openmsx/systemroms`
  - Flatpak: `~/.openMSX/share/systemroms`

- `src/init-fullscreen.tcl` ⭐
  - **Novo**: Script Tcl com comando `set fullscreen on`
  - Carregado via `-script` ao iniciar openMSX
  - Ativa tela cheia automaticamente no startup

- `src/msxair.conf`
  - Centraliza parametros de execucao
  - Define maquina Turbo-R (Panasonic_FS-A1GT) e extensoes desejadas
  - Permite informar ROM/DSK de autostart
  - Suporte a comando de preparacao de rede (WIFI_PRE_START_CMD)

- `src/launch-msxair.sh`
  - Le o arquivo de configuracao
  - Carrega script de fullscreen via `-script init-fullscreen.tcl`
  - Garante existencia do diretorio de midia
  - Monta os argumentos do openMSX e inicia o emulador

- `src/setup-autostart.sh`
  - Cria service de usuario no systemd para iniciar no login
  - Nao falha em containers sem systemd --user

- `docker/Dockerfile`
  - Imagem baseada em `debian:bookworm`
  - Instala openMSX, alsa-utils, libasound2 e libasound2-plugins
  - Alinha GID do grupo audio com o host (GID 29) para acesso correto a /dev/snd
  - Copia `src/`, `docs/` e scripts raiz para `/opt/msxair`

- `dockerrun.sh`
  - Script de execucao do container com deteccao automatica de dispositivos
  - Mapeia X11/Unix socket para interface grafica
  - Mapeia `/dev/snd` e `/proc/asound` condicionalmente para audio ALSA
  - Mapeia `/dev/dri` condicionalmente para aceleracao grafica
  - Monta volume `$HOME/MSX/media` para ROMs e DSKs
