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
│       └── CONCLUS.COM
├── Particao 2 - MSXAIR P2 (32MB, FAT16, vazia)
└── Particao 3 - MSXAIR P3 (32MB, FAT16, vazia)
```

### Comando de execucao do emulador com HDD

```bash
# Nativo
openmsx -machine Panasonic_FS-A1GT -ext ide -hda ~/MSX/media/msxair-hdd.dsk

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

- **Controlador de jogo via rede (remote gamepad)**
  - Suporte a joystick via socket UDP/TCP
  - Integracao com softgame ou protocolo similar

- **Salvos automaticos (save state)**
  - Opcao de backup automatico de estado de emulator
  - Script de restauracao de save state ao iniciar

- **Setup de som com mais controle**
  - Perfis de audio (mono/stereo, taxa de amostragem)
  - Selecao entre card ALSA diferentes em container
