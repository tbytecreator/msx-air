FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update --fix-missing \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        openmsx \
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
        libxml2 \
        zlib1g \
        libpng16-16 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && ldconfig

# Verifica se as bibliotecas criticas foram instaladas
RUN ldconfig -p | grep -q libSDL2-2.0.so.0 || (echo "ERRO: libSDL2 nao encontrada" && exit 1) \
    && ldconfig -p | grep -q libSDL2_ttf-2.0.so.0 || (echo "ERRO: libSDL2_ttf nao encontrada" && exit 1) \
    && echo "✓ Todas as bibliotecas SDL2 detectadas"

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

RUN chmod +x /opt/msxair/src/*.sh \
    && chmod +x /opt/msxair/entrypoint.sh \
    && bash -n /opt/msxair/src/msxair-setup.sh \
    && mkdir -p /root/MSX/media \
    && bash -n /opt/msxair/src/setup-autostart.sh \
    && bash -n /opt/msxair/src/launch-msxair.sh

ENTRYPOINT ["/opt/msxair/entrypoint.sh"]
