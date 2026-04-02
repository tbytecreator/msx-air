# Docker

## Objetivo

Fornecer um ambiente de testes em container para a base do projeto MSX Air usando Debian Bookworm, com suporte completo a interface grafica (X11) e audio (ALSA).

## Arquivos relacionados

- `docker/Dockerfile` — definicao da imagem
- `docker/README.md` — instrucoes detalhadas de build e execucao
- `dockerrun.sh` — script recomendado para execucao com deteccao automatica de dispositivos

## O que o Dockerfile faz

1. Usa `debian:bookworm` como imagem base
2. Instala `openmsx`, `alsa-utils`, `libasound2` e `libasound2-plugins`
3. Alinha o GID do grupo `audio` com o host (GID 29) para acesso correto a `/dev/snd/seq` e `/dev/snd/timer`
4. Adiciona `root` ao grupo `audio`
5. Copia `src/`, `docs/`, `msxair.md` e `openmsx-install.sh` para `/opt/msxair`
6. Copia o conteudo de `src/systemroms` para o file pool de system ROMs do openMSX em `/usr/share/openmsx/systemroms`
7. Ajusta permissoes de execucao dos scripts
8. Cria o diretorio `/root/MSX/media`
9. Valida sintaxe Bash de todos os scripts durante o build

## Como construir

```bash
docker build -f docker/Dockerfile -t msxair:bookworm .
```

## Como executar

Use o script wrapper na raiz do projeto:

```bash
./dockerrun.sh
```

O `dockerrun.sh` detecta automaticamente e mapeia:

| Dispositivo/caminho   | Finalidade                    | Comportamento se ausente  |
|-----------------------|-------------------------------|---------------------------|
| `/dev/dri`            | Aceleracao grafica            | Software rendering        |
| `/dev/snd`            | Dispositivos ALSA de audio    | Sem audio                 |
| `/tmp/.X11-unix`      | Interface grafica X11         | Sem janela                |
| `~/roms/msx`          | ROMs e DSKs do usuario        | Diretorio vazio           |

Depois de entrar no container:

```bash
cd /opt/msxair
./src/launch-msxair.sh
```

## Particularidades do Chromebook / Crostini

- `/dev/dri` nao e exposto ao Linux guest no Crostini: o openMSX usa software rendering automaticamente
- `/dev/snd` existe como dispositivo VirtIO: o audio funciona normalmente com os mapeamentos do `dockerrun.sh`
- O GID do grupo `audio` no Crostini e 29: o Dockerfile ja alinha esse valor
