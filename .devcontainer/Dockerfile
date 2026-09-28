# =============================================================================
# Frappe dev container.
#
# frappe/bench, the image frappe_docker develops on, with the tooling this
# repository's scripts need: zsh as the login shell, jq for apps.json, gh for
# pull requests, and a terminal editor that does not have to be learned.
#
# frappe/bench carries bench, and pyenv and nvm with the current and the
# previous Python and Node, so a bench on either major line of Frappe runs
# here. latest on purpose: Frappe rebuilds it daily, so a rebuild brings the
# newest toolchain and an app meets a dependency upgrade in development first.
# The Frappe version itself is pinned by FRAPPE_VERSION in .env. Everything
# else is pinned to a release.
# =============================================================================
FROM docker.io/frappe/bench:latest

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
#   iproute2  ss, which stop-bench.sh uses to find what holds a port
# build-essential, curl, git, less, sudo and wget are already in frappe/bench.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    bat \
    gnupg \
    iproute2 \
    jq \
    lsb-release \
    micro \
    procps \
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

# GitHub's host keys, system-wide, so the first clone over ssh does not stop at
# a prompt. Scanned, then checked against the fingerprints GitHub publishes at
# https://api.github.com/meta: a key that does not match fails the build
# rather than being trusted.
ARG GITHUB_SSH_FINGERPRINTS="SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s"
RUN ssh-keyscan -t ed25519,ecdsa,rsa github.com >/tmp/github.keys 2>/dev/null \
    && ssh-keygen -lf /tmp/github.keys | awk '{print $2}' | sort >/tmp/github.scanned \
    && printf '%s\n' ${GITHUB_SSH_FINGERPRINTS} | sort | diff - /tmp/github.scanned \
    && cat /tmp/github.keys >>/etc/ssh/ssh_known_hosts \
    && rm /tmp/github.keys /tmp/github.scanned

# The workspace and the Claude config directory, created here so a volume
# mounted over either arrives frappe-owned: Docker initialises a fresh volume
# from the image content at its target, ownership included, and creates it
# root-owned when that target is missing.
RUN chsh -s /bin/zsh frappe \
    && mkdir -p /workspace /home/frappe/.claude/plugins /home/frappe/.config/gh \
    && chown -R frappe:frappe /workspace /home/frappe/.claude /home/frappe/.config

USER frappe

ENV SHELL=/bin/zsh

# frappe/bench exports this from ~/.bashrc, which zsh never reads. Here it
# reaches every process, the scripts in development/ included.
ENV BENCH_DEVELOPER=1

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

ENV CLAUDE_CONFIG_DIR=/home/frappe/.claude

# development/ on PATH, so the git-* wrappers there answer as `git repo-status`
# and `git pr-sync` in every shell, not only the interactive zsh that sources
# custom.zsh. APPENDED, never prepended: the directory is a bind mount the
# developer writes, and it must not shadow anything in /usr/local/bin.
ENV PATH="${PATH}:/workspace/development"
