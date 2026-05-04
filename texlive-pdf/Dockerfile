FROM registry.gitlab.com/islandoftex/images/texlive:latest

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

USER root

# Enable contrib repository for ttf-mscorefonts-installer
RUN if [ -f /etc/apt/sources.list ]; then \
        sed -i '/^deb/ {/contrib/! s/ main/ main contrib/g}' /etc/apt/sources.list; \
    fi && \
    for f in /etc/apt/sources.list.d/*.sources; do \
        [ -e "$f" ] || continue; \
        sed -i '/^Components:/ {/contrib/! s/$/ contrib/}' "$f"; \
    done

# Accept MS Core Fonts EULA
RUN echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections

RUN apt-get update && apt-get install -y \
    # Python & Pygments
    python3 \
    python3-pip \
    python3-pygments \
    # PDF utilities
    poppler-utils \
    qpdf \
    ghostscript \
    pdftk \
    imagemagick \
    # Fonts (Windows-compatible, CJK, high-quality alternatives)
    fonts-liberation \
    fonts-liberation2 \
    fonts-noto \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-noto-color-emoji \
    fonts-dejavu \
    fonts-freefont-ttf \
    fonts-urw-base35 \
    fonts-texgyre \
    ttf-mscorefonts-installer \
    fontconfig \
    # General utilities
    wget \
    curl \
    git \
    unzip \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Refresh font cache so all new fonts are available to TeX and other apps
RUN fc-cache -fv

WORKDIR /workspaces
