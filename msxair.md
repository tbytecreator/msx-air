# Projeto MSX Air 2026 - Manoel Neto

## Objetivo do projeto

Alterar um Macbook Air 11 de 2015 para que ele se transforme em um MSX notebook.

## Tecnologias usadas

Distribuicao Linux leve para servir de base do sistema operacional (Debian 13)
Emulador OpenMSX versao mais recente instalado via flatpack

## Premissas do projeto

O projeto deve instalar em um MacBook Air 2015 os seguintes softwares:

Debian Bookworm 13
OpenMSX
OpenMSX System ROMS
Extensão No Overview on startup no Debian 13

Um script deve ser rodado automaticamente quando esta distribuicao for iniciada, que chame o OpenMSX configurado para o MSX Turbo-R. Este Turbo-r deve ser levantado com os seguintes perifericos ligados:

Sd-Mapper de 4MB
Som FM
Som SCC
V9990
Conecxao Wi-Fi

O projeto deve permitir acesso a um diretorio configuravel para que o usuario possa depositar seus arquivos ROM/DSK, para que possam ser executados direto do emulador.
