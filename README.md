# MSX Air - Documentacao

Esta pasta contem a documentacao do projeto MSX Air.

## Arquivos

- `IMPLEMENTACAO.md`: historico completo do que foi criado e por que.
- `USO-RAPIDO.md`: como instalar, configurar e iniciar.
- `ARQUITETURA.md`: visao de estrutura dos diretorios e scripts.
- `DOCKER.md`: como construir e testar a base em container Docker.
- `SECURITY-SCAN.md`: resultado da varredura de segurança do projeto (senhas, credenciais, tokens).

## Escopo atual

Esta base cobre:

**Instalacao e setup:**

- Instalacao de openMSX (nativo ou Flatpak) no Debian/Ubuntu
- Copia automatizada de system ROMs para o local correto
- Instalacao opcional da extensao GNOME "No Overview at startup" (melhora UX)
- Verificacao automatizada de dependencias do host (SDL2, ALSA, OpenGL)
- Setup unificado via `msxair-setup.sh` que executa todos os passos em ordem

**Execucao:**

- Inicializacao do emulador em maquina Turbo-R (Panasonic FS-A1GT)
- Inicializacao automatica em **tela cheia**
- Carregamento de extensoes (SD mapper, FM, SCC, V9990)
- Diretorio configuravel para ROM/DSK
- Suporte a autostart de ROM ou disco
- Comando de preparacao de rede via host (e.g., Wi-Fi)

**Container Docker:**

- Imagem baseada em Debian Bookworm para testes isolados
- Suporte a audio via ALSA dentro do container
- Mapeamento condicional de dispositivos graficos e de audio (compativel com Crostini/Chromebook)
- Scripts de build e execucao automatizados

**Deteccao inteligente:**

- Detecta instalacao nativa vs Flatpak automaticamente
- Copia ROMs para o local correto baseado no tipo de instalacao
- Verifica permissoes, dispositivos e dependencias antes de executar
- Trata gracefully ambientes sem systemd --user (ex: containers)

**Seguranca:**

- Varredura completa de credenciais, senhas e tokens
- Nenhuma informacao sensivel (nome de usuario, chaves privadas, etc) no repositorio
- Projeto pronto para publicacao em repositorio publico

Itens avancados (integracoes de hardware especificas, ajustes finos de extensao) ficam para a proxima etapa.
