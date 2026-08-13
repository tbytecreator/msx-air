# Historico de Implementacao

## Fase 1 — Base do projeto

Com base no arquivo `msxair.md`, foi criada a estrutura inicial:

- Pasta `src/` com todos os scripts de instalacao, execucao e autostart
- Pasta `docs/` com documentacao de arquitetura, uso e implementacao

### Arquivos criados

1. `src/install-openmsx.sh` — instala openmsx e openmsx-systemroms via APT
2. `src/launch-msxair.sh` — inicializa openMSX com maquina e extensoes configuradas
3. `src/msxair.conf` — centralizacao de todos os parametros de execucao
4. `src/setup-autostart.sh` — cria e habilita unit systemd --user para autostart

### Mapeamento dos requisitos do `msxair.md`

| Requisito                         | Solucao                                                   |
|-----------------------------------|-----------------------------------------------------------|
| Debian + openMSX + ROMs           | `src/install-openmsx.sh`                                  |
| Autostart ao iniciar o SO         | `src/setup-autostart.sh` (systemd --user)                 |
| Turbo-R com perifericos           | `src/msxair.conf` + `src/launch-msxair.sh`                |
| SD mapper, FM, SCC, V9990         | Variavel `EXTENSIONS` em `src/msxair.conf`                |
| Diretorio configuravel de ROM/DSK | Variavel `MEDIA_DIR` em `src/msxair.conf`                 |
| Conexao Wi-Fi                     | Variavel `WIFI_PRE_START_CMD` (comando de host pre-start) |

---

## Fase 2 — Container Docker

Criada infraestrutura Docker para testes da base em ambiente isolado.

### Arquivos docker criados

1. `docker/Dockerfile` — imagem baseada em `debian:bookworm`
2. `docker/README.md` — instrucoes de build e execucao
3. `dockerrun.sh` — script de execucao com deteccao automatica de dispositivos

### O que o Dockerfile faz

- Instala `openmsx`, `alsa-utils`, `libasound2`, `libasound2-plugins`
- Alinha GID do grupo `audio` com o host (GID 29)
- Adiciona `root` ao grupo `audio`
- Copia `src/`, `docs/` e scripts raiz para `/opt/msxair`
- Valida sintaxe Bash de todos os scripts durante o build

---

## Fase 3 — Correcoes de dispositivos no container

### Problema: --device /dev/dri

- **Causa**: o ambiente Crostini (Chromebook) nao expoe `/dev/dri` ao Linux guest
- **Solucao**: `dockerrun.sh` verifica a existencia do caminho antes de incluir o argumento; sem DRI, o openMSX usa software rendering via SDL2

### Problema: ALSA — "cannot find card '0'"

Erros observados:

```ascii
ALSA lib confmisc.c:855:(parse_card) cannot find card '0'
ALSA lib conf.c:5180:(_snd_config_evaluate) ... No such file or directory
ALSA lib pcm.c:2666:(snd_pcm_open_noupdate) Unknown PCM default
```

- **Causa 1**: libs ALSA ausentes no container — resolvido instalando `libasound2` e `libasound2-plugins` no Dockerfile
- **Causa 2**: `/dev/snd` nao mapeado — resolvido com `--device /dev/snd` condicional em `dockerrun.sh`
- **Causa 3**: `/proc/asound` nao montado — as libs ALSA usam esse caminho para enumerar os cards; resolvido montando `-v /proc/asound:/proc/asound:ro` em `dockerrun.sh`
- **Causa 4**: GID do grupo `audio` incompativel entre host e container — `seq` e `timer` em `/dev/snd` pertencem ao grupo `audio` (GID 29 no host); resolvido alinhando o GID no Dockerfile

---

## Fase 3 — Inicializacao em tela cheia via Tcl

### Problema: parametro `-setting fullscreen on` invalido

Tentativa inicial de parametro CLI: `openmsx -setting fullscreen on`

- **Erro**: `Fatal error: Couldn't find fullscreen in ...`
- **Causa**: OpenMSX nao aceita esse formato:
  - `-setting` espera arquivo XML, nao parametro individual
  - Configuracoes nao possuem parametro CLI direto (ex: `-fullscreen`)
- **Pesquisa**: Manual oficial openMSX, secao "Command-line options"

  - <https://openmsx.org/manual/setup.html> - Descricao de parametros
  - <https://openmsx.org/manual/commands.html> - Referencia de parametros

### Solucao: script Tcl para inicializacao

OpenMSX suporta parametro `-script <arquivo>` que executa comandos Tcl no startup.

### Arquivos criados/modificados

1. `src/init-fullscreen.tcl` — novo arquivo Tcl com comando `set fullscreen on`
   - Executado via `-script` durante inicializacao do emulador
   - Ativa tela cheia automaticamente

2. `src/launch-msxair.sh` — modificado
   - Alteracao na linha 39: adicionado `-script` antes de `-machine`
   - Args antes: `args=( -machine "${MACHINE}" )`
   - Args agora: `args=( -script "${SCRIPT_DIR}/init-fullscreen.tcl" -machine "${MACHINE}" )`
   - Mensagem atualizada: "Iniciando openMSX em tela cheia com maquina ${MACHINE}"

### Resultado

- OpenMSX inicia automaticamente em tela cheia (F11 continua funcionando para alternar)
- Script Tcl oferece base para futuras inicializacoes customizadas

### Aprendizado tecnico

- OpenMSX CLI distingue estritamente entre parametros CLI (conjunto limitado) e configuracoes runtime (require Tcl)
- Parametro `-script` permite injecao de Tcl no inicio da execucao
- Ordem dos parametros importa: `-script` deve preceder `-machine` para garantir configuracoes apply

---

## Fase 4 — Script de setup unificado

### Problema: setups manuais requerem execucao de 3 scripts em ordem específica

1. `src/install-openmsx.sh` — instala openMSX
2. `src/copy-systemroms.sh` (novo) — copia ROMs para local correto
3. `src/setup-autostart.sh` — configura autostart (opcional)

Usuarios nao tinham comando unico para execucao completa.

### Solucao: script orquestrador `msxair-setup.sh`

### scripts criados/modificados

1. `src/copy-systemroms.sh` — novo arquivo
   - **Deteccao automatica**: Verifica se openMSX foi instalado nativamente ou via Flatpak
   - **Nativo**: Copia ROMs de `src/systemroms/` para:
     - `~/.local/share/openmsx/systemroms` (usuario XDG, localizado primeiro)
     - `/usr/share/openmsx/systemroms` (global APT, se tiver permissoes)
     - `~/.openmsx/systemroms` (legado/portatil)
   - **Flatpak**: Copia para `~/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms` (sandbox de dados)
   - Funcoes de logging e validacao (erros sao criados se ROMs nao copiarem)
   - Valida existencia do diretorio source `src/systemroms/`

2. `src/msxair-setup.sh` — novo arquivo script orquestrador
   - Funcoes de suporte: `log()`, `warn()`, `error()`, `assert_file_exists()`
   - Opcoes: `set -euo pipefail` para falha immediata em erros
   - Executa em ordem:
     1. Valida existencia de cada script
     2. Corrige permissoes automaticamente (warning se for necessario)
     3. Carrega `src/msxair.conf` para variaveis globais
     4. Executa cada setup script (para imediatamente se falhar)
     5. Oferece instrucoes do proximo passo ao final
   - Mensagens user-friendly com barras de progresso visual

### Resultados

Usuarios agora tem:

- **Setup automatico**: `./src/msxair-setup.sh` executa tudo de uma vez
- **Setup manual**: Documentacao explain cada passo individual em USO-RAPIDO.md
- **Validacao**: Script valida permissoes, existencia de arquivos, e oferece feedback claro

---

## Fase 5 — Instalacao de extensao GNOME

### Problema: GNOME exibe "Activities overview" ao iniciar

Em ambientes GNOME, a tela inicial mostra a "Activities overview", bloqueando a experiencia fullscreen do emulador.

### Solucao: extensao GNOME "No Overview at startup"

### Arquivos criados

1. `src/nooverview-install.sh` — novo arquivo
   - Instala `gnome-tweaks`, `gnome-shell-extensions`, `gnome-shell-extension-manager`
   - Clona extensao "No Overview at startup" do GitHub (`https://github.com/fthx/no-overview`)
   - Ativa a extensao automaticamente via `gnome-extensions enable`
   - Gracefully falha em ambientes nao-GNOME (warning apenas)
   - Falha nao-critica: setup continua mesmo se extensao nao instale

### Detalhes de implementacao

- **Deteccao GNOME**: Verifica `GNOME_DESKTOP_SESSION_ID` ou `XDG_CURRENT_DESKTOP`
- **Instalacao via git**: Clona para `~/.local/share/gnome-shell/extensions/`
- **Ativacao**: Usa `gnome-extensions enable` se disponivel
- **Fallback manual**: Oferece instrucoes se ativacao automatica falhar
- **Setup opcional**: Pula sem erro se `gnome-extensions` nao estiver disponivel
- **Integrada ao setup**: Executada como parte de `msxair-setup.sh`

### Resultado

- GNOME nao mostra Activities overview ao iniciar
- Emulador fullscreen tem melhor UX em ambientes GNOME
- Setup ainda funciona em ambientes nao-GNOME

---

## Fase 6 — Varredura de seguranca

### Problema: Garantir que nenhuma informacao sensivel seja publicada no repositorio

### Solucao: Varredura completa de credenciais e seguranca

### Verificacoes realizadas

1. **Arquivos de configuracao**: Nenhum `.env`, `.env.local`, `.pem`, `.key`, ou arquivo de credenciais
2. **Padroes de senhas**: Nenhuma linha com `password`, `token`, `api_key`, `secret`, `credential`, `AUTH`, etc.
3. **URLs e endpoints**: Nenhuma URL com credenciais embutidas (ex: `user:password@host`)
4. **Informacoes de usuario**: Nenhuma email, telefone, endereco IP, ou nome de usuario hardcoded
5. **Chaves SSH/TLS**: Nenhuma chave privada no repositorio

### Problema encontrado e corrigido

**Arquivo:** `src/launch-msxair.sh` (linhas 51-63 originalmente)  
**Problema:** Caminhos hardcoded de usuario especifico (`/home/david/...`)

**Antes:**
```bash
if [[ -d "/home/david/msxdostools/" ]]; then
if [[ -d "/home/david/msxdemos/" ]]; then
if [[ -d "/home/david/msxdrawings/" ]]; then
```

**Depois:**
```bash
if [[ -d "${HOME}/msxdostools/" ]]; then
if [[ -d "${HOME}/msxdemos/" ]]; then
if [[ -d "${HOME}/msxdrawings/" ]]; then
```

### Resultado

- Repositorio e agora **SEGURO PARA PUBLICACAO PUBLICA**
- Relatorio completo em `docs/SECURITY-SCAN.md`
- Nenhuma informacao sensivel exposta

---

## Fase 7 — Imagem de disco rigido (HDD) com Nextor para Sunrise IDE

### Problema: extensao IDE sem disco rigido

A extensao `ide` (Sunrise IDE) estava configurada em `msxair.conf`, mas nao havia imagem de disco rigido para o emulador. O script `launch-msxair.sh` tentava usar `diskmanipulator` como comando externo, mas esse e um comando interno do openMSX (acessivel apenas via console Tcl).

### Solucao: criacao de imagem HDD via Python (independente do openMSX)

Criado script Python que gera diretamente uma imagem de disco rigido com estrutura MBR + FAT16 compativel com Nextor/Sunrise IDE, sem depender do openMSX ou de ferramentas externas.

### Arquivos criados

1. `src/create-nextor-hdd.py` — script principal de criacao de HDD
   - Gera imagem binaria com MBR valido (assinatura 0x55AA)
   - 3 particoes FAT16 de ~32MB cada (tipo 0x06)
   - Particao 1: boot com NEXTOR.SYS, COMMAND2.COM, MSXDOS.SYS, COMMAND.COM
   - Subdiretorio TOOLS/ com 13 ferramentas Nextor
   - AUTOEXEC.BAT com `SET PATH=A:\TOOLS`
   - Particoes 2 e 3: formatadas e vazias (uso geral)
   - Nao requer openMSX, Flatpak, display ou dependencias externas
   - Uso: `python3 create-nextor-hdd.py [saida] [dir-nextor-files]`

2. `src/create-hdd-image.sh` — script shell alternativo (via openMSX + Tcl)
   - Detecta openMSX nativo ou Flatpak
   - Baixa ferramentas Nextor v2.1.0 se necessario
   - Usa `create-hdd.tcl` para criacao via `diskmanipulator` do openMSX

3. `src/create-hdd.tcl` — script Tcl para openMSX
   - Executa `diskmanipulator create` com 3 particoes Nextor
   - Importa arquivos de boot e ferramentas nas particoes

4. `src/nextor-boot-files/` — diretorio com arquivos Nextor 2.1.0
   - NEXTOR.SYS (4467 bytes) — kernel Nextor
   - COMMAND2.COM (23935 bytes) — shell Nextor
   - MSXDOS.SYS (2432 bytes) — compatibilidade MSX-DOS 1
   - COMMAND.COM (6656 bytes) — shell MSX-DOS 1
   - 13 ferramentas: MAPDRV, EMUFILE, DEVINFO, DRIVERS, DRVINFO, etc.

### Arquivos modificados

1. `src/launch-msxair.sh`
   - Funcao `setup_sunrise_ide()` reescrita: usa `create-nextor-hdd.py` em vez de `diskmanipulator`
   - Corrigido flag de disco: `-cartridge "hda:..."` → `-hda`
   - Corrigida deteccao de extensao IDE: case-insensitive (`"ide"` e `"IDE"`)
   - Disco HDD adicionado automaticamente aos argumentos quando extensao IDE ativa

2. `docker/Dockerfile`
   - Adicionado `python3` as dependencias instaladas
   - Imagem HDD gerada durante o build via `create-nextor-hdd.py`

3. `docker-run.sh`
   - Adicionado volume `$HOME/MSX/media` montado em `/root/MSX/media`
   - Permite que imagem HDD do host seja usada dentro do container

### Detalhes tecnicos da imagem HDD

| Caracteristica     | Valor                        |
|--------------------|------------------------------|
| Formato            | MBR + 3 particoes FAT16      |
| Tamanho total      | 96 MB                        |
| Setores/cluster    | 32 (16KB clusters)           |
| Setores/trilha     | 63                           |
| Cabecas            | 16                           |
| Tipo particao      | 0x06 (FAT16 > 32MB)          |
| OEM                | NEXTOR20                     |
| Compatibilidade    | Sunrise IDE / openMSX `-hda` |

### Estrutura da imagem

```
msxair-hdd.dsk (96MB)
├── MBR (setor 0, assinatura 0x55AA)
├── Particao 1 - MSXAIR P1 (32MB, FAT16, bootavel)
│   ├── NEXTOR.SYS
│   ├── COMMAND2.COM
│   ├── MSXDOS.SYS
│   ├── COMMAND.COM
│   ├── AUTOEXEC.BAT
│   └── TOOLS/
│       ├── DELALL.COM
│       ├── DEVINFO.COM
│       ├── DRIVERS.COM
│       ├── DRVINFO.COM
│       ├── EMUFILE.COM
│       ├── FASTOUT.COM
│       ├── LOCK.COM
│       ├── MAPDRV.COM
│       ├── RALLOC.COM
│       ├── Z80MODE.COM
│       ├── NSYSVER.COM
│       ├── NEXBOOT.COM
│       ├── CONCLUS.COM
│       └── EPTCFT.COM
├── Particao 2 - MSXAIR P2 (32MB, FAT16, vazia)
└── Particao 3 - MSXAIR P3 (32MB, FAT16, vazia)
```

### Comando de execucao do emulador com HDD

```bash
# Nativo
openmsx -machine Panasonic_FS-A1GT -ext nextor-ide -hda ~/MSX/media/msxair-hdd.dsk

# Via MSX Air
./src/launch-msxair.sh
```

### Resultado

- Emulador Turbo-R inicia com disco rigido Nextor funcional
- Boot automatico via NEXTOR.SYS com shell COMMAND2.COM
- Ferramentas Nextor acessiveis via `A:\TOOLS`
- Imagem gerada automaticamente no primeiro lancamento se nao existir
- Docker: imagem HDD pre-gerada durante o build

---

## Observacoes tecnicas gerais

- Nomes de extensao do openMSX podem variar por versao/pacote. Valide com `openmsx -ext list`.
- Todos os mapeamentos de dispositivo em `dockerrun.sh` sao condicionais: o script funciona em hosts com e sem os dispositivos.
- GNOME Extension Manager pode ser instalada para gerenciamento manual de extensoes caso instalacao automatica falhe.

## Proxima etapa sugerida

---

## Fase 8 — Atualizacao para Nextor 2.1.4

### Problema: arquivos Nextor desatualizados (2.1.0)

O projeto usava Nextor 2.1.0 (lancado em 2020). A versao mais recente e 2.1.4 (novembro de 2025), com correcoes importantes de bugs:
- Correcao no calculo do tamanho do diretorio raiz (#158)
- Correcao no scan de teclas para mudanca de disco em modo de emulacao de floppy (#161)
- NEXTOR.SYS v2.1.3: correcao no _GETCLUS, suporte a long integers em printf
- MAPDRV.COM e EPTCFT.COM v2.1.2 (EPTCFT e ferramenta nova para corrigir tipos de particao estendida)

A ROM para emuladores foi renomeada: `SunriseIDE.emulators.ROM` passou a ser `SunriseIDE.blueMSX.ROM` a partir da v2.1.2.

### Solucao: script de download + atualizacao de todos os scripts

### Arquivos criados

1. `src/download-nextor-latest.sh` — novo script
   - Baixa `Nextor-2.1.4.SunriseIDE.blueMSX.rom` para `systemroms/extensions/`
   - Baixa `NEXTOR.SYS` v2.1.3 para `nextor-boot-files/`
   - Baixa `MAPDRV.COM` e `EPTCFT.COM` v2.1.2 para `nextor-boot-files/`
   - Suporta `--force` para re-download
   - Saida com exit 0 mesmo em falha de rede (soft-fail), apenas avisa

### Arquivos modificados

1. `src/create-nextor-hdd.py`
   - `EPTCFT.COM` adicionado a lista `tool_files` (14 ferramentas no total)
   - AUTOEXEC.BAT atualizado: menciona Nextor 2.1.4 e chama `A:\TOOLS\NSYSVER` para exibir a versao real ao boot

2. `src/create-hdd.tcl`
   - `EPTCFT.COM` adicionado ao bloco de ferramentas
   - AUTOEXEC.BAT atualizado para versao 2.1.4 com chamada ao NSYSVER
   - Banner de criacao atualizado

3. `src/create-hdd-image.sh`
   - `NEXTOR_ROM_URL` atualizado para `Nextor-2.1.4.SunriseIDE.blueMSX.ROM`
   - Variavel `NEXTOR_ROM_FILENAME` com novo nome do arquivo
   - Funcao `install_nextor_rom()` atualizada

4. `src/launch-msxair.sh`
   - Funcao `setup_sunrise_ide()` chama `download-nextor-latest.sh` antes de criar a imagem HDD
   - Falha do download nao impede a criacao (usa arquivos existentes como fallback)

5. `src/msxair-setup.sh`
   - `download-nextor-latest.sh` inserido na sequencia de setup entre `nooverview-install.sh` e `copy-systemroms.sh`
   - Tratado como passo opcional: falha de rede nao aborta o setup

### Mapeamento de versoes por arquivo

| Arquivo | Versao | Release de origem |
|---|---|---|
| `Nextor-2.1.4.SunriseIDE.blueMSX.rom` | 2.1.4 | v2.1.4 |
| `NEXTOR.SYS` | 2.1.3 | v2.1.3 |
| `MAPDRV.COM` | 2.1.2 | v2.1.2 |
| `EPTCFT.COM` | 2.1.2 | v2.1.2 (novo) |
| Demais ferramentas | 2.1.0 | v2.1.0 (sem alteracoes) |
| `COMMAND2.COM`, `MSXDOS.SYS`, `COMMAND.COM` | 2.1.0 | v2.1.0 (sem alteracoes) |

### Resultado

- Emulador inicia com Nextor 2.1.4 funcional
- AUTOEXEC.BAT exibe a versao real do Nextor via NSYSVER ao entrar no MSX-DOS
- `download-nextor-latest.sh` pode ser re-executado a qualquer momento para atualizar
- Setup automatico (`msxair-setup.sh`) baixa arquivos atualizados se houver internet

---

## Fase 9 — Extensao nextor-ide.xml: correcao do boot com Nextor

### Problema: extensao `ide` do openMSX nao carrega o ROM do Nextor

Apesar do ROM `Nextor-2.1.4.SunriseIDE.blueMSX.rom` estar na pasta `systemroms/extensions/`, o openMSX 20.0 carregava o `ide240.dat` (Sunrise IDE classioco, sem Nextor). O motivo: o arquivo `ide.xml` interno do openMSX lista apenas os SHA1 dos ROMs Sunrise IDE padrao (`ide240.dat`, `ide250.dat`, `ide221.dat`) — nenhum ROM Nextor esta na lista. Com o IDE classico carregado, o HDD nao subia Nextor.

Diagnostico: verificado inspecionando o pacote `openmsx-data` (v20.0) com `apt-get download` + `dpkg -x`, lendo `/usr/share/openmsx/extensions/ide.xml`. SHA1 confirmados com `sha1sum`.

### Solucao: extensao personalizada `nextor-ide.xml`

### Arquivos criados

1. `src/nextor-ide.xml` — extensao openMSX customizada
   - Substitui a extensao `ide` para carregar o ROM Nextor corretamente
   - Lista os SHA1 dos 4 ROMs Nextor/SunriseIDE presentes no projeto:
     - `fe5763b...` — Nextor 2.1.4 SunriseIDE.blueMSX
     - `97094d5...` — Nextor 2.1.0 SunriseIDE.emulators
     - `61cba16...` — Nextor 2.0.1 SunriseIDE
     - `ab1d6dc...` — Nextor 2.0 SunriseIDE
   - Mantém mesma estrutura (`<SunriseIDE>`) do `ide.xml` original

### Arquivos modificados

1. `src/msxair.conf`
   - `EXTENSIONS`: `"ide"` → `"nextor-ide"`

2. `docker/Dockerfile`
   - Adicionado `cp nextor-ide.xml /usr/share/openmsx/extensions/nextor-ide.xml` no build
   - Permite que o container use a extensao sem etapa adicional

3. `src/copy-systemroms.sh`
   - Para **Flatpak**: copia `nextor-ide.xml` para `~/.openMSX/share/extensions/` (caminho que o Flatpak realmente busca, nao `~/.var/app/.../data/`)
   - Para **nativo**: copia para `/usr/share/openmsx/extensions/` (se gravavel) ou `~/.local/share/openmsx/extensions/`

4. `src/launch-msxair.sh`
   - Para **Flatpak**: copia `nextor-ide.xml` para `~/.openMSX/share/extensions/` antes de iniciar o emulador (garante que o XML esta no lugar mesmo sem rodar `copy-systemroms.sh` antes)

### Aprendizado tecnico

- O openMSX identifica ROMs por SHA1, nao por nome de arquivo
- Para adicionar suporte a um ROM novo, basta criar um `.xml` de extensao com os SHA1 do arquivo
- O caminho de extensoes do usuario no **Flatpak** e `~/.openMSX/share/extensions/` — diferente do caminho de ROMs (`~/.var/app/.../data/share/openmsx/systemroms/`)

### Resultado

- Emulador carrega o ROM `Nextor-2.1.4.SunriseIDE.blueMSX.rom` corretamente
- MSX boota com kernel Nextor 2.1.4 no slot de extensao

---

## Fase 10 — Floppy vazio: eliminando "not ready reading drive A:"

### Problema: FS-A1GT tem drive de disquete interno mapeado como A:

Com o Nextor ROM carregado (Fase 9 resolvida), o emulador agora inicializava o Nextor corretamente — mas exibia imediatamente:

```
Not ready reading drive A:
Abort, Retry, Ignore?
```

**Causa**: O Panasonic FS-A1GT tem um drive de disquete interno. O Nextor mapeia este drive como A:. Sem nenhuma imagem de disquete montada, o hardware reporta "Not ready". O Nextor exige interacao do usuario (pressionar I para Ignore) antes de continuar pelo HDD.

**Tentativa 1 (falhou)**: Adicionar `diskmanipulator create` ao `init-fullscreen.tcl`. O Flatpak sandbox do openMSX nao tem acesso de escrita a `/tmp/` — o `catch` absorvia o erro silenciosamente, sem montar nada.

### Solucao: criar floppy FAT12 vazio no HOST antes do openMSX iniciar

O arquivo e criado via Python no **host** (antes do sandbox Flatpak), salvo em `~/MSX/media/msxair-empty-floppy.dsk`, e passado via `-diska` na linha de comando — caminho que o Flatpak ja tem acesso (mesma pasta do HDD).

### Arquivos modificados

1. `src/launch-msxair.sh`
   - Cria `~/MSX/media/msxair-empty-floppy.dsk` (FAT12 720KB) via Python inline antes de iniciar o openMSX
   - Adiciona `-diska "${EMPTY_FLOPPY}"` aos args do openMSX (apenas se `AUTOSTART_DSK` nao estiver definido)
   - Se o usuario definiu `AUTOSTART_DSK`, o disco do usuario e usado em A: normalmente

2. `src/init-fullscreen.tcl`
   - Revertido para apenas `set fullscreen on` (logica de floppy removida — nao funciona no Flatpak)

### Formato do floppy vazio

| Campo              | Valor        |
|--------------------|-------------|
| Tamanho            | 720KB (1440 setores)  |
| Formato            | FAT12        |
| Media byte         | 0xF9         |
| Setores/trilha     | 9            |
| Cabecas            | 2            |
| FATs               | 2 (3 setores cada) |
| Entradas root dir  | 112 (vazio)  |

### Resultado

- Nextor le drive A: sem erro (disco FAT12 montado)
- Nao encontra COMMAND2.COM em A: (disco vazio)
- Avanca automaticamente para C: (HDD, particao 1)
- C:\COMMAND2.COM e executado → prompt `C:\>`
- AUTOEXEC.BAT de C:\ roda: exibe versao do Nextor via NSYSVER

---

## Fase 11 — msxair-setup.sh: rebuild automatico do container Docker

### Problema: rebuild Docker manual apos cada mudanca

Apos o setup nativo, o usuario precisava rodar `./docker-build.sh` manualmente para que as mudancas (novos ROMs, nextor-ide.xml, etc.) fossem incluidas na imagem Docker.

### Solucao: msxair-setup.sh recria o container automaticamente

### Arquivos modificados

1. `src/msxair-setup.sh`
   - `launch-msxair.sh` removido do array `SETUP_SCRIPTS` (evita que o emulador bloqueie o resto do setup)
   - Apos os scripts de setup, verifica se `docker` esta disponivel e executa `docker-build.sh` automaticamente
   - Falha do Docker nao aborta o setup (o ambiente nativo ja esta configurado)
   - Ao final, chama `launch-msxair.sh` explicitamente para iniciar o emulador

### Fluxo completo de `msxair-setup.sh`

```
openmsx-install.sh
  → nooverview-install.sh
  → download-nextor-latest.sh  (soft-fail se sem internet)
  → copy-systemroms.sh         (instala ROMs + nextor-ide.xml)
  → setup-autostart.sh
  → docker-build.sh            (se docker disponivel, soft-fail se falhar)
  → launch-msxair.sh           (inicia o emulador)
```

### Resultado

- Um unico `./src/msxair-setup.sh` configura o ambiente nativo E reconstroi a imagem Docker
- Imagem Docker sempre sincronizada com os ultimos arquivos do projeto

---

## Proxima etapa sugerida

- **Controlador de jogo via rede (remote gamepad)**
  - Suporte a joystick via socket UDP/TCP
  - Integracao com softgame ou protocolo similar

- **Salvos automaticos (save state)**
  - Opcao de backup automatico de estado de emulator
  - Script de restauracao de save state ao iniciar

- **Setup de som com mais controle**
  - Perfis de audio (mono/stereo, taxa de amostragem)
  - Selecao entre card ALSA diferentes em container
