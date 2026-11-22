# Manual de uso do MSX Air

Este manual apresenta a execução do MSX Air no Linux, de forma nativa ou via
Docker, e a inclusão de arquivos no HDD virtual. Execute os comandos abaixo na
raiz do projeto, salvo indicação contrária.

## 1. Preparação

O MSX Air usa o openMSX e ROMs de sistema compatíveis com a máquina configurada.
Disponibilize as ROMs necessárias em `src/systemroms`; a instalação do emulador
não garante a disponibilidade dessas ROMs.

### Execução nativa

No Debian/Ubuntu, verifique ou instale as dependências do host e execute o setup:

```bash
sudo ./src/install-host-deps.sh
./src/msxair-setup.sh
```

O setup prepara o openMSX, as ROMs e o início automático, tenta atualizar os
arquivos Nextor, reconstrói a imagem Docker se o Docker estiver disponível e
inicia o emulador. Alguns passos podem exigir rede ou privilégios administrativos.
Para mais detalhes, consulte [Uso rápido](USO-RAPIDO.md).

### Execução via Docker

Instale e inicie o Docker e disponha de uma sessão gráfica X11 ou Wayland no
host. Para construir a imagem pela primeira vez:

```bash
docker build -f docker/Dockerfile -t msxair:bookworm .
```

O container contém um HDD inicial. Para preservá-lo e permitir importações,
prepare `~/MSX/media/msxair-hdd.dsk` no host **antes de iniciar** o container.
Se já existir um HDD nesse local, mantenha-o: não o substitua pelo HDD inicial.
O procedimento para copiar o HDD inicial da imagem está no
[guia Docker](../docker/README.md#importar-arquivos-para-o-hdd).

Se o HDD existir apenas em um container, preserve os dados antes de removê-lo.
Com `--rm`, o container é removido ao encerrar; copiar o HDD enquanto o openMSX
está em execução pode gerar uma cópia inconsistente.

## 2. Configuração e início

Na instalação nativa, ajuste `src/msxair.conf` conforme necessário:

- `MACHINE`: máquina emulada; o padrão é `Panasonic_FS-A1GT`.
- `EXTENSIONS`: extensões do openMSX, incluindo `nextor-ide` para o HDD.
- `MEDIA_DIR`: diretório de mídias no host, por padrão `~/roms/msx`.
- `AUTOSTART_ROM` e `AUTOSTART_DSK`: caminhos opcionais para carregar uma ROM
  ou um disquete ao iniciar.
- `WIFI_PRE_START_CMD`: comando opcional executado antes do emulador.

O launcher nativo ativa TCP/IP UNAPI por padrao e requer openMSX 22 ou superior.
Para liberar o slot para `AUTOSTART_ROM`, inicie com
`MSXAIR_UNAPI=0 ./src/launch-msxair.sh`. Consulte o
[guia de rede](../docker/README.md#internet-no-msx-tcpip-unapi).

Inicie a instalação nativa:

```bash
./src/launch-msxair.sh
```

Ou inicie o container:

```bash
./docker-run.sh
```

O script Docker monta `~/MSX/media` se o diretório existir, além de montar
`~/roms/msx` para mídias. Se `~/MSX/media` não existir no host, o HDD fica no
container temporário e suas alterações são perdidas ao encerrar. A configuração
`src/msxair.conf` é copiada para a imagem durante o build: alterações no host
não são aplicadas automaticamente ao container existente.

O openMSX inicia em tela cheia; use F11 para alternar. Com `nextor-ide`
habilitada, o launcher utiliza `~/MSX/media/msxair-hdd.dsk`. Se o arquivo não
existir, tenta criar um HDD novo. Identifique a unidade correspondente à primeira
partição no Nextor e use `DIR` para listar seus arquivos.

## 3. Importar arquivos para o HDD

O importador é executado **no host**, sem recompilar ou reconstruir a imagem
Docker. No Debian/Ubuntu, `sudo ./src/install-host-deps.sh` instala as
dependências do importador e do openMSX. Para instalar apenas os pacotes
necessários ao importador:

```bash
sudo apt-get install bash coreutils mtools python3 util-linux
```

1. Encerre o openMSX e todos os containers ou ferramentas que estejam usando o
   HDD. Não os inicie durante a importação.
2. Confira se a imagem desejada está em `~/MSX/media/msxair-hdd.dsk`.
3. Execute, por exemplo:

   ```bash
   ./src/importar-hdd.sh ~/Downloads/JOGO.ROM ~/Downloads/LEIA.TXT
   ```

4. Inicie novamente o MSX Air e liste a raiz da primeira partição no Nextor.

Os arquivos são importados para a raiz da primeira partição FAT16. A operação
não sobrescreve arquivos ou diretórios existentes e aceita apenas arquivos
regulares com nomes 8.3: nome de até oito caracteres e extensão opcional de
até três. Use letras, números ou `_`; `-` também é permitido no nome, mas não
na extensão. Nomes são gravados em maiúsculas. Renomeie arquivos incompatíveis
ou conflitantes antes de importá-los.

O script salva um backup `msxair-hdd.dsk.backup.*` no mesmo diretório e só
substitui o HDD após concluir todas as cópias. Para restaurar um backup, feche
o emulador, preserve a imagem atual e copie o backup desejado sobre
`msxair-hdd.dsk`.

Os launchers atuais e o importador usam um bloqueio cooperativo. Containers
antigos, comandos Docker diretos e outras ferramentas podem não respeitá-lo;
por isso, feche-os manualmente antes da importação. Copiar um arquivo para o
diretório `~/MSX/media` não o coloca automaticamente dentro do HDD.

## 4. Início automático nativo

Em uma sessão gráfica com systemd de usuário:

```bash
./src/setup-autostart.sh
systemctl --user start msxair-openmsx.service
```

Para verificar ou desativar:

```bash
systemctl --user status msxair-openmsx.service
systemctl --user disable --now msxair-openmsx.service
```

## 5. Problemas comuns

- **HDD inexistente:** verifique `~/MSX/media/msxair-hdd.dsk`; para Docker,
  prepare a imagem no host conforme o [guia Docker](../docker/README.md).
- **HDD em uso:** encerre as sessões do openMSX e containers; aguarde outra
  importação terminar antes de tentar novamente.
- **Nome inválido ou já existente:** renomeie o arquivo para um nome 8.3
  diferente e repita a importação.
- **Dependência ausente:** execute `sudo ./src/install-host-deps.sh` ou instale
  os pacotes listados na seção de importação.
- **Erro de ROM ou vídeo:** confira as ROMs da máquina, os logs do launcher e
  as instruções de display no [guia Docker](../docker/README.md).
