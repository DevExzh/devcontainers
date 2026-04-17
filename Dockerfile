FROM python:3-trixie

# Essential environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    IS_SANDBOX=1 \
    DISABLE_TELEMETRY=1 \
    DISABLE_ERROR_REPORTING=1 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    CLAUDE_CODE_UNDERCOVER=1 \
    CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1 \
    ENABLE_LSP_TOOL=1 \
    USER_TYPE="ant" \
    FNM_DIR="/opt/fnm" \
    PATH="/root/.cargo/bin:/root/.bun/bin:/usr/local/go/bin:/opt/fnm:$PATH"

WORKDIR /root
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    git-lfs \
    vim \
    less \
    ca-certificates \
    unzip \
    tmux \
    jq \
    gettext-base \
    zsh \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    clang \
    clang-tidy \
    clang-format \
    clangd \
    p7zip-full \
    tree \
    htop \
    linux-headers-amd64 \
    linux-perf \
    valgrind \
    heaptrack \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Zsh
RUN chsh -s $(which zsh)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# Git
RUN cat << 'EOF' > ~/.gitconfig
[user]
        name = Ryker Zhu
        email = ryker.zhu@outlook.com
[core]
        autocrlf = input
[http]
        postBuffer = 5242880000
[filter "lfs"]
        required = true
        clean = git-lfs clean -- %f
        smudge = git-lfs smudge -- %f
        process = git-lfs filter-process
[init]
        defaultBranch = main
EOF
RUN git lfs install

# Python
RUN pip install pyright

# Go
RUN GO_VERSION=$(curl -s 'https://go.dev/VERSION?m=text' | head -n1) && \
    OS_ARCH="$(uname -s | tr '[:upper:]' '[:lower:]')-$(case $(uname -m) in x86_64) echo amd64 ;; aarch64|arm64) echo arm64 ;; *) echo $(uname -m) ;; esac)" && \
    wget "https://go.dev/dl/${GO_VERSION}.${OS_ARCH}.tar.gz" && \
    tar -C /usr/local -xzf "${GO_VERSION}.${OS_ARCH}.tar.gz" && \
    rm "${GO_VERSION}.${OS_ARCH}.tar.gz"
RUN go install github.com/jesseduffield/lazygit@latest
RUN go install golang.org/x/tools/gopls@latest

# Bun
RUN curl -fsSL https://bun.com/install | bash
RUN bun install -g typescript-language-server typescript

# Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . "$HOME/.cargo/env" && \
    rustup component add rust-analyzer && \
    rustup +nightly component add miri && \
    rustup component add llvm-tools-preview && \
    mkdir -p ~/.cargo && \
    cat << 'EOF' > ~/.cargo/config.toml
[source.crates-io]
replace-with = 'rsproxy-sparse'
[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"
[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"
[net]
git-fetch-with-cli = true
EOF
RUN . "$HOME/.cargo/env" && cargo +stable install cargo-llvm-cov --locked
RUN . "$HOME/.cargo/env" && cargo install --locked hyperfine
RUN . "$HOME/.cargo/env" && cargo install --locked cargo-nextest
RUN . "$HOME/.cargo/env" && cargo install flamegraph

# Node.js
RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell
RUN fnm install 24 && \
    ln -s "$FNM_DIR/aliases/default/bin/node" /usr/local/bin/node && \
    ln -s "$FNM_DIR/aliases/default/bin/npm" /usr/local/bin/npm && \
    ln -s "$FNM_DIR/aliases/default/bin/npx" /usr/local/bin/npx

WORKDIR /workspaces

# Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

RUN bun --eval "\
const fs = require('fs'); \
const filePath = '/root/.claude.json'; \
if (fs.existsSync(filePath)) { \
    const content = JSON.parse(fs.readFileSync(filePath, 'utf-8')); \
    fs.writeFileSync(filePath, JSON.stringify({ ...content, hasCompletedOnboarding: true }, null, 2), 'utf-8'); \
} else { \
    fs.writeFileSync(filePath, JSON.stringify({ hasCompletedOnboarding: true }), 'utf-8'); \
}"

RUN claude plugin marketplace add anthropics/claude-plugins-official
RUN claude plugin marketplace add affaan-m/everything-claude-code
RUN claude plugin marketplace update
RUN claude plugin install everything-claude-code@everything-claude-code
RUN claude plugin install superpowers@claude-plugins-official
RUN claude plugin install rust-analyzer-lsp@claude-plugins-official
RUN claude plugin install typescript-lsp@claude-plugins-official
RUN claude plugin install pyright-lsp@claude-plugins-official
RUN claude plugin install clangd-lsp@claude-plugins-official
RUN claude plugin install gopls-lsp@claude-plugins-official
RUN claude plugin install security-guidance@claude-plugins-official
RUN claude plugin install ralph-loop@claude-plugins-official
RUN claude plugin install feature-dev@claude-plugins-official
RUN git clone https://github.com/affaan-m/everything-claude-code.git ecc && cd ecc && bun install && cd ..

RUN echo 'eval "$(fnm env --use-on-cd --shell bash)"' | tee -a ~/.bashrc ~/.zshrc && \
    echo "alias ccdsp='claude --dangerously-skip-permissions'" | tee -a ~/.bashrc ~/.zshrc

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources
RUN pip config set global.index-url https://mirrors.ustc.edu.cn/pypi/simple 

ENV TZ="Asia/Shanghai" \
    NO_PROXY="volces.com,aliyun.com,goproxy.cn,goproxy.io,registry.npmmirror.com,google.cn,edu.cn,rsproxy.cn,kimi.com,moonshot.cn" \
    RUSTUP_DIST_SERVER="https://rsproxy.cn" \
    RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup" \
    BUN_CONFIG_REGISTRY="https://registry.npmmirror.com" \
    FNM_NODE_DIST_MIRROR="https://mirrors.ustc.edu.cn/node/" \
    GOPROXY="goproxy.cn,direct" \
    GOSUMDB="sum.golang.google.cn"
