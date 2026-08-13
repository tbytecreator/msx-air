# Uso Rapido

## Instalacao nativa (sem Docker)

### Pré-requisitos: Instalar dependencias do host

O OpenMSX requer bibliotecas SDL2 que devem estar instaladas no seu sistema:

```bash
# Instalacao automatica de dependencias
./src/install-host-deps.sh
```

Ou manualmente:

```bash
sudo apt-get install -y libsdl2-2.0-0 libsdl2-ttf-2.0-0 libsdl2-image-2.0-0 libsdl2-gfx-1.0-0
```

### Validar dependencias instaladas

Antes de continuar, valide se todas as bibliotecas foram instaladas corretamente:

```bash
chmod +x src/check-deps.sh
./src/check-deps.sh
```

Se algo faltar, o script oferecera as instrucoes para instalar.

### Setup do MSXAir

```bash
# Dar permissao de execucao
chmod +x src/*.sh dockerrun.sh

# Executar setup completo (instala OpenMSX, copia ROMs, configura autostart)
./src/msxair-setup.sh
```

Este script executa os 6 passos abaixo em sequencia:

1. `openmsx-install.sh` — Instala OpenMSX nativo ou Flatpak
2. `nooverview-install.sh` — Instala extensao GNOME (opcional, pula se nao-GNOME)
3. `download-nextor-latest.sh` — Baixa arquivos Nextor 2.1.4 do GitHub (opcional, pula se sem internet)
4. `copy-systemroms.sh` — Copia system ROMs (incluindo ROM Nextor 2.1.4) para o local correto
5. `setup-autostart.sh` — Configura autostart no systemd (opcional)
6. `launch-msxair.sh` — Inicia o emulador (cria HDD se necessario)

### Opcao B: Setup manual (passo a passo)

#### 1) Dar permissao de execucao

```bash
chmod +x openmsx-install.sh src/*.sh dockerrun.sh
```

#### 2) Instalar OpenMSX

```bash
./src/install-openmsx.sh
```

Este script oferece opcoes para:

- Instalacao nativa via APT (Debian/Ubuntu)
- Instalacao via Flatpak (qualquer distro Linux)

#### 3) Instalar extensão GNOME (opcional)

```bash
./src/nooverview-install.sh
```

Este script:

- Instala `gnome-tweaks`, `gnome-shell-extensions` e `gnome-shell-extension-manager`
- Clona e ativa a extensão "No Overview at startup" (melhora UX)
- Pula silenciosamente se nao estiver em ambiente GNOME

#### 4) Copiar system ROMs

```bash
./src/copy-systemroms.sh
```

Este script:

- Detecta automaticamente se OpenMSX foi instalado nativamente ou via Flatpak
- Copia ROMs de `src/systemroms/` para o local correto:
  - Nativo (APT): `~/.local/share/openmsx/systemroms`, `/usr/share/openmsx/systemroms` (global), ou `~/.openmsx/systemroms` (legado)
  - Flatpak: `~/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms`

#### 5) Ajustar configuracao

Edite `src/msxair.conf`:

- `MEDIA_DIR` — diretorio onde ficam seus arquivos ROM/DSK
- `EXTENSIONS` — ajuste para as extensoes disponiveis (`openmsx -ext list`)
- `AUTOSTART_ROM` / `AUTOSTART_DSK` — opcional, midia carregada ao iniciar
- `WIFI_PRE_START_CMD` — opcional, comando de preparacao de rede

#### 6) Criar imagem de disco rigido (Sunrise IDE + Nextor)

A imagem HDD e criada automaticamente na primeira execucao do `launch-msxair.sh` se a extensao `ide` estiver ativa. Antes de criar a imagem, o launcher tenta baixar os arquivos Nextor mais recentes (requer internet). Para criar manualmente:

```bash
# Baixar arquivos Nextor 2.1.4 (recomendado antes de criar o HDD)
./src/download-nextor-latest.sh

# Criar a imagem HDD
python3 src/create-nextor-hdd.py ~/MSX/media/msxair-hdd.dsk src/nextor-boot-files/
```

A imagem contem:

- 3 particoes FAT16 de 32MB (96MB total)
- Nextor 2.1.4 / NEXTOR.SYS v2.1.3 + COMMAND2.COM na particao 1
- AUTOEXEC.BAT que configura PATH e exibe a versao do Nextor via `NSYSVER`
- 14 ferramentas no diretorio TOOLS/ (inclui EPTCFT.COM v2.1.2)

#### 7) Iniciar emulador

```bash
./src/launch-msxair.sh
```

O emulador inicia automaticamente **em tela cheia** (F11 para alternar).

Se a extensao `nextor-ide` estiver configurada, o disco rigido Nextor sera montado automaticamente via `-hda`. O Nextor inicializara e voce tera acesso as ferramentas em `C:\TOOLS`.

#### 8) Habilitar autostart no login (opcional)

```bash
./src/setup-autostart.sh
systemctl --user start msxair-openmsx.service
```

> Em containers Docker, normalmente nao existe sessao `systemd --user` ativa. Nesse caso, o script cria a unit e encerra com aviso, sem falhar. Use execucao manual via `./src/launch-msxair.sh`.

---

## Execucao via Docker

### 1) Construir a imagem

```bash
docker build -f docker/Dockerfile -t msxair:bookworm .
```

A imagem Docker ja inclui o HDD com Nextor pre-gerado durante o build.

### 2) Executar o container

Use o script `dockerrun.sh` — ele detecta automaticamente os dispositivos disponiveis no host:

```bash
./dockerrun.sh
```

Dentro do container:

```bash
cd /opt/msxair
./src/launch-msxair.sh
```

> ROMs e DSKs devem ser colocados em `~/roms/msx` no host; este diretorio e montado automaticamente em `/root/roms/msx` no container.
> A imagem HDD em `~/MSX/media` e montada em `/root/MSX/media` no container (se existir no host).

---

## Dicas de validacao

```bash
# Listar extensoes disponiveis
openmsx -ext list

# Testar maquina Turbo-R
openmsx -machine Panasonic_FS-A1GT
```
