# Docker da base MSX Air

## Base

A imagem usa Debian Bookworm (`debian:bookworm`) como solicitado.

Durante o build, o conteudo de `src/systemroms` e copiado para `/usr/share/openmsx/systemroms`, que corresponde ao file pool `share/systemroms` documentado pelo openMSX no Linux.

## Build

Na raiz do projeto:

```bash
sudo docker build -f docker/Dockerfile -t msxair:bookworm .
```

## Execucao para testes

Comportamento padrao: ao iniciar o container sem comando adicional, o entrypoint executa automaticamente `/opt/msxair/src/launch-msxair.sh`.

Para abrir shell no container sem interface grafica (apenas validacao de scripts), passe `bash` como comando:

```bash
docker run --rm -it msxair:bookworm bash
```

## Execucao com interface grafica (openMSX)

Para abrir a janela do emulador e necessario encaminhar o display X11 do host para o container.

### Linux com X11

```bash
xhost +local:docker

# Em ambientes sem /dev/dri (ex: Crostini no Chromebook), omita a linha --device /dev/dri.
# O openMSX usara software rendering automaticamente.
docker run --rm -it \
  -e DISPLAY="${DISPLAY}" \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  --device /dev/dri \
  -v "${HOME}/MSX/media":/root/MSX/media \
  msxair:bookworm
```

> **Chromebook / Crostini**: o dispositivo `/dev/dri` nao e exposto ao container Linux. Omita `--device /dev/dri`. O emulador usara renderizacao por software (SDL2 sem DRI) sem outros problemas.

Use o script `dockerrun.sh` na raiz do projeto: ele detecta automaticamente se `/dev/dri` esta disponivel e aplica o argumento apenas quando necessario.

> **Importante (erro OCI em /proc/asound):** nao monte `/proc/asound` no container. O Docker/runc bloqueia mounts dentro de `/proc` por seguranca e retorna erro de inicializacao. O script `dockerrun.sh` ja usa apenas `/dev/snd`, que e o mapeamento correto para ALSA.

### Linux com Wayland (via XWayland)

```bash
xhost +local:docker

docker run --rm -it \
  -e DISPLAY="${DISPLAY}" \
  -e WAYLAND_DISPLAY="${WAYLAND_DISPLAY}" \
  -e XDG_RUNTIME_DIR=/tmp \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:/tmp/${WAYLAND_DISPLAY}":ro \
  --device /dev/dri \
  -v "${HOME}/MSX/media":/root/MSX/media \
  msxair:bookworm
```

Dentro do container, execute o emulador:

```bash
cd /opt/msxair
./src/launch-msxair.sh
```

Os arquivos do projeto ficam em `/opt/msxair` e as midias ROM/DSK em `/root/MSX/media`.

> **Nota de seguranca:** `xhost +local:docker` concede acesso ao display apenas para processos locais via socket Unix. Revogue apos os testes com `xhost -local:docker`.
