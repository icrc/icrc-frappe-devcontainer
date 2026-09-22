# =============================================================================
# Frappe dev container.
#
# The official frappe/bench image with the tooling this repository's scripts
# need: zsh as the login shell, jq for apps.json, gh for pull requests, and a
# terminal editor that does not have to be learned.
#
# Every version is pinned. A floating base image means a rebuild is a different
# container, which is the one thing a development environment must not be.
# =============================================================================
FROM docker.io/frappe/bench:v5.31.0

ARG ZSH_IN_DOCKER_VERSION=1.2.1

# GitHub CLI. Debian has no `gh` package, so the release tarball is fetched and
# checked against the sha256 that release publishes. Bumping GH_VERSION means
# bumping both digests, from
# https://github.com/cli/cli/releases/download/v<version>/gh_<version>_checksums.txt
ARG GH_VERSION=2.101.0
ARG GH_SHA256_AMD64=9bca2d1c16825f109907a23307628a2f0698fbf99662b73a5cf0b020293072b8
ARG GH_SHA256_ARM64=b57e8063f18862647c9d22727c32e9da1b963f8bf9db648fe123a6975695640f

USER root

#   jq        reads apps.json in get-apps.sh
#   micro     the editor EDITOR names below
#   bat       syntax-highlighted cat, aliased in custom.zsh
#   zstd      restoring a bench backup compressed with it
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    bat \
    build-essential \
    curl \
    git \
    gnupg \
    jq \
    less \
    lsb-release \
    micro \
    procps \
    sudo \
    wget \
    zsh \
    zstd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN arch="$(dpkg --print-architecture)" \
    && case "${arch}" in \
    amd64) sha="${GH_SHA256_AMD64}" ;; \
    arm64) sha="${GH_SHA256_ARM64}" ;; \
    *) echo "gh: unsupported architecture ${arch}" >&2; exit 1 ;; \
    esac \
    && tarball="gh_${GH_VERSION}_linux_${arch}.tar.gz" \
    && curl -fsSL -o "/tmp/${tarball}" \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${tarball}" \
    && echo "${sha}  /tmp/${tarball}" | sha256sum -c - \
    && tar -xzf "/tmp/${tarball}" -C /tmp \
    && install -m 0755 "/tmp/gh_${GH_VERSION}_linux_${arch}/bin/gh" /usr/local/bin/gh \
    && rm -rf "/tmp/${tarball}" "/tmp/gh_${GH_VERSION}_linux_${arch}"

USER frappe

ENV SHELL=/bin/zsh
RUN sudo chsh -s /bin/zsh frappe

ENV EDITOR=micro
ENV VISUAL=micro

# zsh with the powerlevel10k theme. `-p fzf` installs fzf and its own shell
# integration, so nothing of fzf's is vendored into this repository.
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.zsh_history" \
    -x

COPY --chown=frappe:frappe zsh/custom.zsh /home/frappe/.zsh-custom.zsh
RUN printf '\n# Frappe shortcuts\nsource /home/frappe/.zsh-custom.zsh\n' >> /home/frappe/.zshrc

# The workspace and the Claude config directory, created here so a volume
# mounted over either arrives frappe-owned: Docker initialises a fresh volume
# from the image content at its target, ownership included, and creates it
# root-owned when that target is missing.
RUN mkdir -p /workspace /home/frappe/.claude/plugins /home/frappe/.config/gh \
    && sudo chown -R frappe:frappe /workspace /home/frappe/.claude /home/frappe/.config

ENV CLAUDE_CONFIG_DIR=/home/frappe/.claude
