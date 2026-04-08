# Diagnóstico: Problemas com Autostart do MSX Air

## Problema: O serviço systemd não inicia o OpenMSX no reboot

Se você executou `setup-autostart.sh`, mas o projeto não sobe automaticamente no reboot, siga este guia para diagnosticar o problema.

### Pré-requisitos para Autostart Funcionar

O autostart requer que você tenha completado completamente a setup do MSX Air:

1. ✅ OpenMSX instalado (nativo ou via Flatpak)
2. ✅ System ROMs copiadas para o local correto
3. ✅ Configuração em `src/msxair.conf` está válida
4. ✅ Ambiente systemd de usuário disponível

### Procedimento Correto de Setup

Se você ainda **não fez** o setup completo, execute o script de setup automatizado:

```bash
chmod +x src/*.sh
./src/msxair-setup.sh
```

Este script executa todos os passos em sequência:
1. Instala OpenMSX
2. Instala extensão GNOME (opcional)
3. **Copia system ROMs** ← Passo crítico!
4. Configura autostart
5. Testa o launcher

### Se você já executou `setup-autostart.sh` diretamente

Se você pulou os passos anteriores e executou apenas `setup-autostart.sh`, as ROMs podem não estar instaladas. Resolva com:

```bash
# Instale as ROMs
./src/copy-systemroms.sh

# Depois ative o serviço
systemctl --user daemon-reload
systemctl --user enable --now msxair-openmsx.service
```

### Diagnóstico: Verificar Status do Serviço

#### 1. Verificar se o serviço foi criado e habilitado

```bash
systemctl --user status msxair-openmsx.service
```

Resultado esperado:
```
● msxair-openmsx.service - MSX Air openMSX launcher
   Loaded: loaded (/home/user/.config/systemd/user/msxair-openmsx.service; enabled; vendor preset: enabled)
   Active: inactive (dead) since ... (última execução)
```

#### 2. Verificar se o serviço tenta iniciar e por que falha

```bash
journalctl --user -u msxair-openmsx.service -f
```

Deixe o terminal aberto e reinicie o computador. Você verá os logs do serviço tentando iniciar.

#### 3. Erro Comum: "Couldn't find ROM file"

Se você vir no log:
```
Fatal error: Error in "Panasonic_FS-A1GT" machine: Couldn't find ROM file for "PanasonicRom" fs-a1gt_firmware.rom...
```

**Causa**: As system ROMs não foram instaladas ou não estão no caminho esperado.

**Solução**:
```bash
# Copie as ROMs
./src/copy-systemroms.sh

# Verifique onde as ROMs foram instaladas
find ~ -path "*openmsx/systemroms" -type d 2>/dev/null
find / -path "*openmsx/systemroms" -type d 2>/dev/null

# Depois reinicie o serviço
systemctl --user restart msxair-openmsx.service
```

#### 4. Erro: "Unable to open SDL audio"

Isso é apenas um **aviso** (warning) e não impede a execução. Ocorre em ambientes virtualizados sem suporte de áudio físico.

O OpenMSX ainda funciona normalmente (sem som) mesmo com este aviso.

### Diagnóstico: Verificar ROMs

#### 5. Verificar se as system ROMs foram instaladas

```bash
# Procure em todos os locais possíveis
echo "=== Verificando locais de ROMs ==="
ls -la ~/.local/share/openmsx/systemroms 2>/dev/null && echo "✓ Encontrado em ~/.local/share/openmsx/systemroms" || echo "✗ Não encontrado em ~/.local/share/openmsx/systemroms"
ls -la ~/.var/app/org.openmsx.openMSX/data/share/openmsx/systemroms 2>/dev/null && echo "✓ Encontrado em Flatpak" || echo "✗ Não encontrado em Flatpak"
sudo ls -la /usr/share/openmsx/systemroms 2>/dev/null && echo "✓ Encontrado em /usr/share/openmsx/systemroms" || echo "✗ Não encontrado em /usr/share/openmsx/systemroms"

# Verifique se há ROMs da máquina configurada
grep "^MACHINE=" src/msxair.conf
find ~/.local/share/openmsx/systemroms -iname "*panasonic*" 2>/dev/null | head -5
```

#### 6. Testar o launcher manualmente

Antes de confiar no autostart, teste o launcher para garantir que funciona:

```bash
# Execute o launcher manualmente
./src/launch-msxair.sh

# Se funcionar, o OpenMSX deve iniciar em tela cheia
# Para sair: pressione `Ctrl+Q` ou clique em fechar
```

Se o launcher funcionar mas o serviço não iniciar:
- Verifique se há dispositivo de áudio (virtual ou não)
- Verifique se o espaço em disco é suficiente
- Reinstale o serviço:
  ```bash
  systemctl --user daemon-reload
  systemctl --user enable --now msxair-openmsx.service
  ```

### Diagnóstico: Configuração do Serviço

#### 7. Verificar conteúdo do arquivo de serviço

```bash
cat ~/.config/systemd/user/msxair-openmsx.service
```

Deve parecer com:
```ini
[Unit]
Description=MSX Air openMSX launcher
After=graphical-session.target

[Service]
Type=simple
WorkingDirectory=/path/to/msx-air
ExecStart=/path/to/msx-air/src/launch-msxair.sh
Restart=on-failure

[Install]
WantedBy=default.target
```

#### 8. Verificar se systemd de usuário está disponível

```bash
systemctl --user show-environment | head -10
```

Se retornar um erro, o systemd de usuário pode não estar disponível (comum em containers ou ambientes restringidos).

### Diagnóstico: Variáveis de Ambiente

#### 9. Verificar caminho do HOME no serviço

O serviço systemd de usuário usa seu HOME, então verifique:

```bash
echo $HOME
systemctl --user show-environment | grep HOME
```

Se forem diferentes, haverá problemas ao encontrar `/src/msxair.conf`.

### Resolução de Problemas Específicos

#### Problema: "systemctl --user nao encontrado"

Solução: Instale `systemd`:
```bash
sudo apt-get install systemd
```

#### Problema: "systemd --user indisponivel nesta sessao"

Causa: Você está em um container ou em uma sessão sem bus de usuário.

Solução: Use setup manual sem autostart:
```bash
./src/launch-msxair.sh
```

#### Problema: Serviço inicia mas OpenMSX fecha imediatamente

Causa: Erro no launcher ou ROMs inválidas.

Solução: Verifique os logs:
```bash
journalctl --user -u msxair-openmsx.service -n 50
```

### Próximas Ações

Se nenhuma das soluções acima funcionou:

1. **Teste o launcher manualmente**:
   ```bash
   ./src/launch-msxair.sh
   ```

2. **Verifique se OpenMSX está instalado**:
   ```bash
   which openmsx
   openmsx --version
   # Ou para Flatpak:
   flatpak list --app | grep openMSX
   ```

3. **Verifique as dependências**:
   ```bash
   ./src/check-deps.sh
   ```

4. **Reexecute o setup completo**:
   ```bash
   ./src/msxair-setup.sh
   ```

5. **Recrie o serviço**:
   ```bash
   systemctl --user disable msxair-openmsx.service
   rm ~/.config/systemd/user/msxair-openmsx.service
   systemctl --user daemon-reload
   ./src/setup-autostart.sh
   ```

### Verificação Final

Se tudo estiver funcionando:

```bash
# 1. Serviço deve estar ativo
systemctl --user status msxair-openmsx.service

# 2. Launcher deve funcionar manualmente
./src/launch-msxair.sh

# 3. Reinicie para validar autostart
sudo reboot

# 4. Após reboot, o OpenMSX deve iniciar automaticamente em tela cheia
```

---

**Dúvidas?** Verifique todos os logs disponíveis:
- Logs do serviço: `journalctl --user -u msxair-openmsx.service -n 100`
- Logs de sistema: `journalctl -e -n 50`
- Status: `systemctl --user status msxair-openmsx.service`
