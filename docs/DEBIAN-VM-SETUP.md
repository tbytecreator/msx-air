# Setup MSX Air em Debian 13 Virtualizado

Este guia é específico para instalar e configurar o MSX Air em uma máquina virtual (VM) Debian 13.

## Considerações Especiais para VM

### Áudio em VM

- A maioria das VMs não possui áudio físico (apenas virtual/simulado)
- OpenMSX emitirá warnings sobre SDL audio não disponível
- **Isso é normal e não impede o funcionamento** — o emulador funciona sem som

### Vídeo em VM

- Certifique-se de ter aceleração 3D habilitada (se disponível)
- KVM: `-vga qxl` ou `-device qxl-vga` melhoram performance
- VirtualBox: Habilite "3D Acceleration" nas configurações

### Requisitos Mínimos

- **CPU**: 2+ cores (4+ recomendado)
- **RAM**: 2GB (4GB+ recomendado)
- **Disco**: 1GB livre (para ROMs + dados do emulador)
- **Rede**: Conexão de internet (para download de dependências)

## Instalação Passo a Passo

### 1. Preparar o Sistema Debian 13

```bash
# Atualizar repositórios
sudo apt-get update
sudo apt-get upgrade -y

# Instalar ferramentas básicas
sudo apt-get install -y git curl wget build-essential
```

### 2. Clonar o Repositório MSX Air

```bash
cd ~
git clone https://github.com/tbytecreator/msx-air.git
cd msx-air

# Dar permissão de execução nos scripts
chmod +x src/*.sh *.sh
```

### 3. Executar Setup Completo (Recomendado)

```bash
./src/msxair-setup.sh
```

Este script:

- ✅ Instala OpenMSX (nativo ou Flatpak)
- ✅ Instala extensões GNOME (se disponível)
- ✅ Copia system ROMs
- ✅ Configura autostart no systemd
- ✅ Testa o launcher

Se tudo passou sem erros, pule para seção "Usar o MSX Air"

### 4. Setup Manual (Se Necessário)

Se o setup automático falhar, execute os passos manualmente:

#### 4.1 Instalar Dependências

```bash
sudo apt-get install -y \
  libsdl2-2.0-0 \
  libsdl2-ttf-2.0-0 \
  libsdl2-image-2.0-0 \
  libsdl2-gfx-1.0-0 \
  libasound2 \
  libx11-6 \
  libgl1 \
  libglew2.2 \
  libxml2 \
  zlib1g
```

#### 4.2 Instalar OpenMSX

```bash
# Opção A: Via APT (mais simples)
sudo apt-get install -y openmsx

# Opção B: Via Flatpak (se disponível)
# flatpak install flathub org.openmsx.openMSX
```

Validar instalação:

```bash
which openmsx
openmsx --version
```

#### 4.3 Copiar System ROMs

```bash
cd ~/msx-air
./src/copy-systemroms.sh
```

Validar:

```bash
find ~ -path "*openmsx/systemroms" -name "*.rom" | head -5
```

#### 4.4 Configurar Autostart (Opcional)

```bash
cd ~/msx-air
./src/setup-autostart.sh

# Ativar o serviço
systemctl --user daemon-reload
systemctl --user enable --now msxair-openmsx.service

# Validar
systemctl --user status msxair-openmsx.service
```

## Usar o MSX Air

### Teste Manual Antes do Autostart

```bash
cd ~/msx-air
./src/launch-msxair.sh
```

Você deve ver:

1. Tela do OpenMSX em fullscreen
2. Logo do CBIOS ou menu customizado
3. **Aviso sobre SDL audio é normal**

Para sair: Pressione `Ctrl+Q` ou clique em fechar.

### Teste Autostart após Reboot

Se você configurou autostart:

```bash
# Reiniciar VM
sudo reboot

# Após reboot, OpenMSX deve iniciar automaticamente em fullscreen
```

## Resolução de Problemas Specificos para Debian/VM

### Problema: OpenMSX não inicia (comando não encontrado)

```bash
# Validar instalação
which openmsx
openmsx --version

# Se falhar, reinstalar
sudo apt-get install --reinstall openmsx
```

### Problema: "Cannot open display" ou "No audio device"

Isso é esperado em VM. Ignorar avisos. Se o OpenMSX não iniciar:

```bash
# Verificar se X11 está disponível
echo $DISPLAY

# Se vazio, tente:
export DISPLAY=:0
./src/launch-msxair.sh
```

### Problema: Autostart não funciona após reboot

```bash
# Verificar status do serviço
systemctl --user status msxair-openmsx.service

# Ver últimos 50 linhas de log
journalctl --user -u msxair-openmsx.service -n 50

# Reativar serviço
systemctl --user restart msxair-openmsx.service
```

### Problema: "Couldn't find ROM file"

ROMs não foram copiadas:

```bash
# Copiar manualmente
./src/copy-systemroms.sh

# Validar
ls -la ~/.local/share/openmsx/systemroms/machines/panasonic/ | head -5
```

### Problema: Usuário não tem permissão para o serviço systemd

```bash
# Verificar se systemd de usuário está ativo
systemctl --user show-environment | head

# Se erro, criar userbus
systemctl --user daemon-reload
```

### Problema: Tela preta após iniciar OpenMSX

Possível falta de suporte gráfico na VM:

```bash
# Tentar com fallback de vídeo
LIBGL_ALWAYS_INDIRECT=1 ./src/launch-msxair.sh
```

### Problema: Performance lenta / travamentos

Em VM com recursos limitados:

```bash
# Ajustar em msxair.conf para máquina menos exigente
# Mude MACHINE para algo mais simples como:
# MACHINE="MSX2"
# ou
# MACHINE="MSX2_KBD"

nano src/msxair.conf
./src/launch-msxair.sh
```

## Próximas Ações

1. **Criar pastas de mídia**:

   ```bash
   mkdir -p ~/roms/msx
   mkdir -p ~/MSX/media
   ```

2. **Adicionar seus próprios ROMs**:

   ```bash
   # Coloque seus ROMs em ~/roms/msx
   cp seu-jogo.rom ~/roms/msx/
   ```

3. **Configurar autostart de jogo**:

   ```bash
   # Editar src/msxair.conf
   nano src/msxair.conf
   
   # Adicionar:
   AUTOSTART_ROM="/home/seu-usuario/roms/msx/seu-jogo.rom"
   
   # Salvar (Ctrl+X, Y, Enter)
   ```

4. **Desabilitar avisos de áudio** (opcional):

   ```bash
   # Adicionar a launch-msxair.sh antes de exec:
   export SDL_AUDIODRIVER=dummy
   ```

## Suporte Adicional

Para diagnóstico detalhado, veja:

- [DEBUG-AUTOSTART.md](DEBUG-AUTOSTART.md) — Diagnóstico de autostart
- [USO-RAPIDO.md](USO-RAPIDO.md) — Instruções gerais de uso
- [IMPLEMENTACAO.md](IMPLEMENTACAO.md) — Detalhes técnicos

## Validação Final

Para verificar se tudo está funcional:

```bash
# 1. Verificar OpenMSX
openmsx --version

# 2. Verificar ROMs
find ~/.local/share/openmsx/systemroms -name "*.rom" | wc -l

# 3. Verificar Launcher
./src/launch-msxair.sh
# (deve abrir OpenMSX, pressione Ctrl+Q para sair)

# 4. Verificar Autostart (se configurado)
systemctl --user status msxair-openmsx.service
```

Todos os comandos acima devem executar sem erros. Se algum falhar, volte para "Resolução de Problemas".
