FROM gcc:13-bookworm AS openmsx-build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl make pkg-config python3 \
        libsdl2-dev libsdl2-ttf-dev libglew-dev libpng-dev \
        zlib1g-dev tcl-dev libasound2-dev \
        libogg-dev libvorbis-dev libtheora-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN curl -fsSL --retry 3 \
        https://github.com/openMSX/openMSX/releases/download/RELEASE_22_0/openmsx-22.0.tar.gz \
        -o openmsx.tar.gz \
    && echo 'f6d5ff89c62d32447dd5f731ff653d26a2a3c4ac6e86ea4f1bda3c4f8ad98c5d  openmsx.tar.gz' | sha256sum -c - \
    && tar -xzf openmsx.tar.gz

WORKDIR /build/openmsx-22.0
RUN make -j2 OPENMSX_INSTALL=/usr INSTALL_SHARE_DIR=/usr/share/openmsx \
    && make install OPENMSX_INSTALL=/usr INSTALL_SHARE_DIR=/usr/share/openmsx \
    && mkdir -p /openmsx-libs \
    && cp -L "$(g++ -print-file-name=libstdc++.so.6)" /openmsx-libs/ \
    && cp -L "$(gcc -print-file-name=libgcc_s.so.1)" /openmsx-libs/

FROM openmsx-build AS unapi-assets
RUN mkdir -p /unapi \
    && curl -fsSL --retry 3 \
        https://raw.githubusercontent.com/ducasp/MSX-Development/20fcedf1377b1ea3d1346e87e5bf7cc42ebe2c76/UNAPI_BIOS_CUSTOM_ESP_V2/ESPUNAPI_IO.rom \
        -o /unapi/ESPUNAPI_IO.rom \
    && echo '233ef8d636ae8e34038fc281972cd15b194c6affdca453d82339c2e125b73332  /unapi/ESPUNAPI_IO.rom' | sha256sum -c - \
    && curl -fsSL --retry 3 \
        https://raw.githubusercontent.com/ducasp/MSX-Development/0299d025a32bd3111171b2e7bfef7a87ae299304/UNAPI/HGET/hget.com \
        -o /unapi/HGET.COM \
    && echo '8fdc2bd28d8f2f8b675cd1602f431eb099f220a45c7343dc077fe45d41bb47f4  /unapi/HGET.COM' | sha256sum -c -

FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV MSXAIR_UNAPI=1

RUN apt-get update --fix-missing \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        dbus \
        dbus-x11 \
        libappstream4 \
        libsoup2.4-1 \
        libsystemd0 \
        libxmlb2 \
        alsa-utils \
        libasound2 \
        libasound2-plugins \
        systemd \
        libgl1-mesa-glx \
        libgl1-mesa-dri \
        libegl1-mesa \
        libegl1 \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libxrender1 \
        libxrandr2 \
        libsdl2-2.0-0 \
        libsdl2-ttf-2.0-0 \
        libsdl2-image-2.0-0 \
        libsdl2-gfx-1.0-0 \
        libglew2.2 \
        libxml2 \
        libssl3 \
        zlib1g \
        libpng16-16 \
        libglew2.2 \
        libtcl8.6 \
        python3 \
        util-linux \
    && ldconfig

COPY --from=openmsx-build /usr/bin/openmsx /usr/bin/openmsx
COPY --from=openmsx-build /usr/share/openmsx /usr/share/openmsx
COPY --from=openmsx-build /openmsx-libs/ /usr/local/lib/

# Executa ldconfig final e limpa cache de apt
RUN ldconfig \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && openmsx -v | grep -Fx 'openMSX 22.0'

# Garante que o grupo audio dentro do container usa o mesmo GID do host (29),
# permitindo acesso aos devices /dev/snd/seq e /dev/snd/timer.
RUN groupmod -g 29 audio 2>/dev/null || groupadd -g 29 audio \
    && usermod -aG audio root

RUN printf '%s\n' \
    'defaults.ctl.card 0' \
    'defaults.pcm.card 0' \
    'pcm.!default {' \
    '  type plug' \
    '  slave.pcm "hw:0,0"' \
    '}' \
    'ctl.!default {' \
    '  type hw' \
    '  card 0' \
    '}' > /etc/asound.conf

WORKDIR /opt/msxair

COPY src ./src
COPY docs ./docs
COPY msxair.md ./msxair.md
COPY docker/entrypoint.sh ./entrypoint.sh

# A ROM fica fora de src/systemroms, que pode ser montado somente para leitura.
COPY --from=unapi-assets /unapi/ESPUNAPI_IO.rom /usr/share/openmsx/extensions/ESPUNAPI_IO.rom
COPY --from=unapi-assets /unapi/HGET.COM /opt/msxair/src/hdd-software/UNAPI/HGET.COM

RUN chmod +x /opt/msxair/src/*.sh \
    && chmod +x /opt/msxair/entrypoint.sh \
    && bash -n /opt/msxair/src/msxair-setup.sh \
    && mkdir -p /root/MSX/media \
    && mkdir -p /root/.local/share/openmsx \
    && mkdir -p /root/.openmsx \
    && ln -sf /opt/msxair/src/systemroms /root/.local/share/openmsx/systemroms \
    && rm -rf /usr/share/openmsx/systemroms \
    && ln -sf /opt/msxair/src/systemroms /usr/share/openmsx/systemroms \
    && cp /opt/msxair/src/nextor-ide.xml /usr/share/openmsx/extensions/nextor-ide.xml \
    && bash -n /opt/msxair/src/setup-autostart.sh \
    && python3 /opt/msxair/src/create-nextor-hdd.py /root/MSX/media/msxair-hdd.dsk /opt/msxair/src/nextor-boot-files

ENTRYPOINT ["/opt/msxair/entrypoint.sh"]
