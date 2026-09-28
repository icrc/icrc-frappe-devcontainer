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
# The Frappe version and the default Python and Node are pinned in .env, by
# FRAPPE_VERSION, FRAPPE_PYTHON and FRAPPE_NODE. Everything else is pinned to
# a release.
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

# gitleaks, which the pre-commit hook runs on every commit. Fetched the same
# way as gh. The CI workflow in .github/workflows/gitleaks.yml reads these
# three lines, so a bump here moves both. Digests from
# https://github.com/gitleaks/gitleaks/releases/download/v<version>/gitleaks_<version>_checksums.txt
ARG GITLEAKS_VERSION=8.30.1
ARG GITLEAKS_SHA256_AMD64=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
ARG GITLEAKS_SHA256_ARM64=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080

USER root

#   jq        reads apps.json in get-apps.sh
#   micro     the editor EDITOR names below
#   bat       syntax-highlighted cat, aliased in custom.zsh
#   zstd      restoring a bench backup compressed with it
#   iproute2  ss, which stop-bench.sh uses to find what holds a port
#   fzf       loaded by the oh-my-zsh plugin below
# build-essential, curl, git, less, sudo and wget are already in frappe/bench.
#
# The slim base excludes /usr/share/doc/* from every package, and that is where
# Debian ships fzf's key-bindings.zsh and completion.zsh, which the oh-my-zsh
# plugin sources. dpkg reads dpkg.cfg.d/ in order and the last match wins, so
# this file, sorting after `docker`, lets them back in.
RUN printf 'path-include /usr/share/doc/fzf/*\n' > /etc/dpkg/dpkg.cfg.d/fzf \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    bat \
    fzf \
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

# gitleaks names its amd64 build x64.
RUN arch="$(dpkg --print-architecture)" \
    && case "${arch}" in \
    amd64) asset=x64; sha="${GITLEAKS_SHA256_AMD64}" ;; \
    arm64) asset=arm64; sha="${GITLEAKS_SHA256_ARM64}" ;; \
    *) echo "gitleaks: unsupported architecture ${arch}" >&2; exit 1 ;; \
    esac \
    && tarball="gitleaks_${GITLEAKS_VERSION}_linux_${asset}.tar.gz" \
    && curl -fsSL -o "/tmp/${tarball}" \
    "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${tarball}" \
    && echo "${sha}  /tmp/${tarball}" | sha256sum -c - \
    && tar -xzf "/tmp/${tarball}" --no-same-owner -C /usr/local/bin gitleaks \
    && chmod 0755 /usr/local/bin/gitleaks \
    && rm -f "/tmp/${tarball}"

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

# The Python and Node the bench runs on, those of frappe/build at
# FRAPPE_VERSION, installed next to the ones frappe/bench ships and made the
# default. Pinned to the patch release, so a daily rebuild of latest never
# moves the interpreter the bench's virtualenv points at. pyenv skips the
# build when frappe/bench already has that exact release. The names are not
# PYTHON_VERSION and NODE_VERSION: frappe/bench sets both with ENV, which
# would silently win over a build arg of the same name.
ARG FRAPPE_PYTHON
ARG FRAPPE_NODE
RUN pyenv install -s "${FRAPPE_PYTHON}" \
    && PYENV_VERSION="${FRAPPE_PYTHON}" pip install --no-cache-dir virtualenv \
    && pyenv global "${FRAPPE_PYTHON}" "${PYTHON_VERSION_PREV}" \
    && . "${NVM_DIR}/nvm.sh" \
    && nvm install "${FRAPPE_NODE}" \
    && npm install -g yarn \
    && nvm alias default "${FRAPPE_NODE}" \
    && nvm use default \
    && rm -rf "${NVM_DIR}/.cache"

ENV SHELL=/bin/zsh

# frappe/bench exports this from ~/.bashrc, which zsh never reads. Here it
# reaches every process, the scripts in development/ included.
ENV BENCH_DEVELOPER=1

ENV EDITOR=micro
ENV VISUAL=micro

# zsh with the powerlevel10k theme. `-p fzf` only enables the oh-my-zsh plugin;
# the fzf it loads is the Debian package installed above.
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
