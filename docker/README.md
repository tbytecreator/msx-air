# Docker da base MSX Air

## Base

A imagem usa Debian Bookworm (`debian:bookworm`) como solicitado.

O openMSX 22.0 e compilado a partir da release oficial, cuja integridade e
verificada por SHA-256. A compilacao ocorre em uma etapa separada da imagem
final. A instalacao nativa ou via Flatpak no host nao e alterada.

## Internet no MSX (TCP/IP UNAPI)

No container, a extensao `smxwifi` e a BIOS UNAPI de Oduvaldo Pavan sao
ativadas automaticamente. O openMSX emula a interface e o ESP32 e usa os
sockets da rede do container; nao e necessario um ESP fisico, TAP, rede
`--host` ou configuracao de Wi-Fi no MSX. A rede bridge padrao do Docker
permite conexoes de saida atraves do host. TLS usa `libssl3` e os certificados
do container. A emulacao nao oferece SSH UNAPI.

A BIOS e o HGET 1.3 sao baixados do repositorio de Oduvaldo em revisoes fixas
com SHA-256 verificado. Em HDDs novos, o cliente fica em `A:\UNAPI\HGET.COM`:

```text
A:\UNAPI\HGET https://example.com/ /l:EXAMPLE.HTM
```

O HGET 1.3 pode ficar repetindo a barra de progresso em respostas muito pequenas
(por exemplo, 16 bytes); use outro cliente UNAPI para esses arquivos.

Um HDD existente nao e alterado pela atualizacao e nao recebe o HGET
automaticamente. Para importa-lo na raiz do HDD do host, encerre o emulador
e use o importador existente:

```bash
( set -o noclobber; docker run --rm msxair:bookworm cat /opt/msxair/src/hdd-software/UNAPI/HGET.COM > HGET.COM ) \
  && ./src/importar-hdd.sh HGET.COM
```

O comando nao sobrescreve `HGET.COM` no diretorio atual; escolha outro local
se o arquivo ja existir. O importador nao sobrescreve arquivos e cria um backup. Depois, use
`A:\HGET` no MSX. O arquivo `HGET.COM` no diretorio atual pode ser removido
apos a importacao.

Para executar sem UNAPI, por exemplo para liberar o slot de uma ROM
configurada em `AUTOSTART_ROM`, use `MSXAIR_UNAPI=0 ./docker-run.sh` ou
`docker run -e MSXAIR_UNAPI=0 ...`. O launcher recusa iniciar com UNAPI e
`AUTOSTART_ROM` simultaneos para evitar conflito de slots. A execucao nativa
continua sem UNAPI por padrao.

Conexoes de entrada exigem publicacao de portas no Docker e regras adequadas
no firewall; elas nao sao abertas automaticamente. Nao desative o firewall
para habilitar a rede.

Durante o build, o conteudo de `src/systemroms` e copiado para `/usr/share/openmsx/systemroms`, que corresponde ao file pool `share/systemroms` documentado pelo openMSX no Linux.

Durante o build, uma imagem de disco rigido (HDD) com Nextor 2.1.0 e gerada automaticamente em `/root/MSX/media/msxair-hdd.dsk` (96MB, 3 particoes FAT16). Isso permite que o emulador inicie com a extensao Sunrise IDE funcional.

## Build

Na raiz do projeto:

```bash
sudo docker build -f docker/Dockerfile -t msxair:bookworm .
```

Para verificar a versao e a inicializacao da maquina com Nextor sem abrir uma
janela, execute `bash tests/test-docker-openmsx.sh`. O teste usa um container
temporario e nao modifica o HDD do host.

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

## Importar arquivos para o HDD

No host, com o openMSX e os containers que usam o HDD encerrados:

```bash
# Debian/Ubuntu: instale as dependencias do importador no host.
sudo apt-get install bash coreutils mtools python3 util-linux
./src/importar-hdd.sh ~/Downloads/JOGO.ROM ~/Downloads/LEIA.TXT
```

O comando usa `~/MSX/media/msxair-hdd.dsk`, importa para a raiz da primeira
particao FAT16 e preserva um backup `msxair-hdd.dsk.backup.*` no mesmo
diretorio. Exige nomes MSX-DOS 8.3 (letras, numeros, `_` e `-` no nome;
letras, numeros e `_` na extensao); arquivos existentes nao sao sobrescritos.
Tambem requer `python3`, `flock` e `realpath` no host. Os arquivos no diretorio
do host nao entram automaticamente na imagem: e necessario importá-los.

Se o HDD existir somente em um container sem `--rm`, encerre o openMSX e copie
a imagem desse container antes de removê-lo. Um container iniciado com `--rm`
é removido ao encerrar; copiar seu HDD enquanto o openMSX está ativo pode
produzir uma cópia inconsistente. Para inicializar um HDD novo a partir da
imagem Docker ja construida:

```bash
mkdir -p "$HOME/MSX/media"
if [ -e "$HOME/MSX/media/msxair-hdd.dsk" ]; then
  echo "HDD ja existe; nao sera sobrescrito."
else
  container=$(docker create msxair:bookworm)
  docker cp "$container:/root/MSX/media/msxair-hdd.dsk" "$HOME/MSX/media/msxair-hdd.dsk"
  docker rm "$container"
fi
```

Depois use `./docker-run.sh`; ele monta o diretorio do host. Os launchers
atuais e o importador coordenam o acesso por bloqueio. Esse bloqueio nao
protege contra containers antigos, comandos Docker diretos, outras instancias
do openMSX ou ferramentas que nao o respeitem: encerre-os antes de importar
e nao os inicie durante a importacao.

> **Nota de seguranca:** `xhost +local:docker` concede acesso ao display apenas para processos locais via socket Unix. Revogue apos os testes com `xhost -local:docker`.
