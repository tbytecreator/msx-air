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

## Observacoes tecnicas gerais

- Nomes de extensao do openMSX podem variar por versao/pacote. Valide com `openmsx -ext list`.
- Todos os mapeamentos de dispositivo em `dockerrun.sh` sao condicionais: o script funciona em hosts com e sem os dispositivos.
- GNOME Extension Manager pode ser instalada para gerenciamento manual de extensoes caso instalacao automatica falhe.

## Proxima etapa sugerida

- **Validacao pre-execucao**: Script que verifica disponibilidade de componentes
  - Disponibilidade da maquina Turbo-R instalada
  - Disponibilidade das extensoes configuradas (`openmsx -ext list`)
  - Existencia dos arquivos ROM/DSK definidos em `AUTOSTART_ROM`, `AUTOSTART_DSK`
  - Acesso de leitura ao diretorio `MEDIA_DIR`

- **Controlador de jogo via rede (remote gamepad)**
  - Suporte a joystick via socket UDP/TCP
  - Integracao com softgame ou protocolo similar

- **Salvos automaticos (save state)**
  - Opcao de backup automatico de estado de emulator
  - Script de restauracao de save state ao iniciar

- **Setup de som com mais controle**
  - Perfis de audio (mono/stereo, taxa de amostragem)
  - Selecao entre card ALSA diferentes em container
