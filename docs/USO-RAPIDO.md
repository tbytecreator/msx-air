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

Este script executa os 5 passos abaixo em sequencia:

1. `install-host-deps.sh` — Instala dependências SDL2, ALSA, OpenGL
2. `openmsx-install.sh` — Instala OpenMSX nativo ou Flatpak
3. `nooverview-install.sh` — Instala extensão GNOME (optional, pula se nao-GNOME)
4. `copy-systemroms.sh` — Copia system ROMs para o local correto
5. `setup-autostart.sh` — Configura autostart no systemd (optional)

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
  - Nativo: `~/.local/share/openmsx/systemroms` ou `~/.openmsx/systemroms`
  - Flatpak: `~/.openMSX/share/systemroms`

#### 5) Ajustar configuracao

Edite `src/msxair.conf`:

- `MEDIA_DIR` — diretorio onde ficam seus arquivos ROM/DSK
- `EXTENSIONS` — ajuste para as extensoes disponiveis (`openmsx -ext list`)
- `AUTOSTART_ROM` / `AUTOSTART_DSK` — opcional, midia carregada ao iniciar
- `WIFI_PRE_START_CMD` — opcional, comando de preparacao de rede

#### 6) Iniciar emulador

```bash
./src/launch-msxair.sh
```

O emulador inicia automaticamente **em tela cheia** (F11 para alternar).

#### 7) Habilitar autostart no login (opcional)

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

> ROMs e DSKs devem ser colocados em `~/MSX/media` no host; este diretorio e montado automaticamente em `/root/MSX/media` no container.

---

## Dicas de validacao

```bash
# Listar extensoes disponiveis
openmsx -ext list

# Testar maquina Turbo-R
openmsx -machine Panasonic_FS-A1GT
```
