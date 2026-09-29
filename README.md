# icrc-frappe-devcontainer

> Under construction: things can change without notice. Contributions go through pull requests, see [CONTRIBUTING.md](CONTRIBUTING.md).

A dev container for Frappe: MariaDB, Redis, a mail catcher, an S3 store, Keycloak and a LiteLLM proxy, with the bench and its apps built from a config file you edit. Based on the [frappe_docker devcontainer example](https://github.com/frappe/frappe_docker/tree/main/devcontainer-example), with the differences listed at the end.

## Quick start

1. Install Docker (or Podman) and the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers), then open this repository and **Reopen in Container**. Passwords are generated on first start, so there is nothing to copy or fill in.
2. In the container terminal:

```bash
cd /workspace/development
./install-bench.sh          # bench + the apps in apps.json, a few minutes
./create-site.sh            # dev.localhost, every app installed
./start.sh                  # http://localhost:8000
```

`create-site.sh` prints the Administrator password. Recover it later with `bash .devcontainer/init-env.sh --print`.

| Service | Where |
|---|---|
| Frappe | http://localhost:8000 |
| Realtime | http://localhost:9000 |
| Mail catcher | http://localhost:8025 |
| S3 API | http://localhost:9100, `http://seaweedfs:8333` from inside |
| MariaDB | `localhost:3306`, host `mariadb` from inside |
| Keycloak | http://localhost:8080, `http://keycloak:8080` from inside. Admin `admin`, realm `frappe` with client `frappe` and user `dev` |
| LiteLLM | http://localhost:4000, `http://litellm:4000` from inside. OpenAI-compatible, key `LITELLM_MASTER_KEY` |

## On the host

The container is the same on every OS. What runs before it is created, `.devcontainer/init-env.sh`, is a bash script that reads `$HOME`, and a proxy has to be set where the container is opened from.

### Windows

Keep the repository inside WSL2 and **Reopen in Container** from there, which is Microsoft's own Dev Containers workflow. Otherwise install [Git for Windows](https://git-scm.com/download/win) with `bash` on `PATH`, which also sets `HOME`. Without either, `init-env.sh` stops and says so.

### Behind a proxy

Export the proxy in the host shell before opening the container:

```bash
export HTTP_PROXY=http://proxy.example.org:8080
export HTTPS_PROXY=http://proxy.example.org:8080
export NO_PROXY=localhost,127.0.0.1,.example.org
```

Compose passes them to the image build and to the `frappe` and `litellm` containers, and adds its own service names to `NO_PROXY`, so the bench reaches MariaDB, Keycloak or LiteLLM directly. Put your internal domains in the host's `NO_PROXY`, never in a tracked file. An editor started from a desktop menu may not see the shell's variables; the same three lines, without `export`, in `.devcontainer/.env` are read as a fallback.

Pulling the base images goes through the Docker daemon, which has its own proxy setting: Docker Desktop's *Resources, Proxies*, or the daemon's `proxies` in `/etc/docker/daemon.json`.

With no proxy, set nothing: every value is empty and every tool connects directly.

## Frappe versions

Three pins in `.devcontainer/.env`, written once by `init-env.sh`:

- `FRAPPE_VERSION` (`v16.35.0`), the exact Frappe release `install-bench.sh` installs. Set it to the release your production image uses. Avoid a floating tag such as `v16`, which resolves to the newest v16 at install time.
- `FRAPPE_PYTHON` (`3.14.7`) and `FRAPPE_NODE` (`24.21.0`), the Python and Node [frappe/build](https://hub.docker.com/r/frappe/build/tags) carries at that tag, so the bench runs on the production toolchain. Read them with `docker run --rm --entrypoint sh frappe/build:v16.35.0 -c 'python --version; node --version'`.

The container is [frappe/bench](https://hub.docker.com/r/frappe/bench/tags)`:latest`, which Frappe rebuilds daily, so a rebuild brings the newest tooling and an app meets a dependency upgrade here before production does. The Dockerfile installs the pinned Python and Node with its pyenv and nvm and makes them the default, so a rebuild never moves the interpreter the bench runs on. The Python and Node frappe/bench ships stay installed next to them.

After changing `FRAPPE_PYTHON`, rebuild the container and recreate the bench's virtualenv on it: `cd frappe-bench && bench migrate-env python3.14`.

### Moving to another release on the same line

```bash
./switch-version.sh frappe v16.36.0   # checks out, migrates every site, rewrites FRAPPE_VERSION
```

If frappe/build at the new tag has another Python or Node, set `FRAPPE_PYTHON` and `FRAPPE_NODE` to match and rebuild.

### Testing the next major line

Do it on a second bench next to the first, so the current one stays usable. Every script takes the bench from `BENCH_NAME`, default `frappe-bench`, and `BENCH_PYTHON` picks the Python `install-bench.sh` creates it on.

```bash
BENCH_NAME=frappe-bench-v17 ./install-bench.sh version-17
```

If `frappe/build:version-17` has another Python or Node than the pins, add them for that bench first, until the next rebuild: `pyenv install 3.X.Y`, `nvm install N && nvm use N`, and `BENCH_PYTHON="$(pyenv root)/versions/3.X.Y/bin/python"`. Restore a backup into a site on the new bench, then run `BENCH_NAME=frappe-bench-v17 ./migrate-site.sh`. To move for good, set the three pins to the v17 release, rebuild, and `bench migrate-env` the bench.

### A bench on the previous major line

frappe/bench also ships the previous Python and Node (3.12 and 22 today):

```bash
nvm use 22
BENCH_NAME=frappe-bench-v15 BENCH_PYTHON=python3.12 ./install-bench.sh version-15
```

Only one bench can serve on port 8000 at a time: `./stop-bench.sh` one before `./start.sh` on the other.

### Checking a bench against a production image

`bench version -f table` lists each app with its version, branch and commit. In a production image only the version is left, because the image build removes every `.git`. The version comes from `__version__` in the app, so it tells two builds apart only when the app bumps it on every release. An app followed at a branch head, such as frappe/telephony at `0.0.1`, reads the same in every build.

The fix belongs in the production image build, not here: stamp the commit into `__version__` before installing the app, as a PEP 440 local label, `0.0.1+g0123abc`. The `-` form (`0.0.1-0123abc`) is not valid PEP 440 and flit, the build backend Frappe apps use, refuses it. Parity is then the version in the image against the version and commit `bench version` shows here.

## Choosing the apps

`development/apps.json` is the list, in the shape `bench` itself uses:

```json
[
  { "url": "https://github.com/frappe/erpnext.git", "branch": "version-16" }
]
```

Add an entry, run `./get-apps.sh`, and only the new app is fetched. `apps-example.json` holds a longer list to copy from.

bench clones one commit deep, which is all a dependency needs. For an app you develop on, add `"history": true` to its entry and the full history is fetched right after the clone, so `git log`, `blame` and a rebase work in `frappe-bench/apps/<name>`. That checkout is a normal git repository on the declared branch: work from there, and `repo-status.sh` shows where each one stands.

Nothing in this repository authenticates to a git host, which is what lets the same file reach any of them:

```jsonc
// public, over https
{ "url": "https://github.com/frappe/helpdesk.git", "branch": "v1.22.1" }

// private, over ssh, using the agent your editor forwards in
{ "url": "git@github.com:your-org/your_app.git", "branch": "main" }

// an on-premises Azure DevOps collection, using the credentials already in
// the ~/.gitconfig mounted from your host
{ "url": "https://tfs.example.org/YourCollection/Your%20Project/_git/your_app",
  "branch": "main" }
```

A private repository on a public host can go in `apps.json`, provided everyone using this repository can reach it (a clone that fails stops `install-bench.sh`). Keep in `development/apps.local.json`, which `get-apps.sh` reads too and git ignores, what must not be published: an internal host such as an on-premises Azure DevOps, and your personal additions. The ICRC Protection apps will live in [icrc-prot-ecosystem](https://github.com/icrc/icrc-prot-ecosystem); until that is published, list them there.

## The scripts

All in `development/`, all with `--help`, all aliased in the shell.

| Script | Alias | Does |
|---|---|---|
| `install-bench.sh` | | Create the bench and install the apps. Run once |
| `get-apps.sh` | `frapps` | Install any app in `apps.json` not yet in the bench |
| `create-site.sh` | | Create a site and install apps into it |
| `delete-site.sh` | | Drop a site, its database and its files |
| `start.sh` | `frstart` | Run the development server |
| `stop-bench.sh` | `frstop` | Kill every bench process and free the ports |
| `migrate-site.sh` | `frmigrate` | Apply schema changes. Needed after any DocType edit |
| `build.sh` / `watch.sh` | `frbuild` / `frwatch` | Build assets once, or on change |
| `clear-cache.sh` | `frcache` | Clear the cache when the browser shows an old build |
| `console.sh` / `db-console.sh` | `frconsole` / `frdb` | A Python console, or a database shell |
| `switch-version.sh` | `frswitch` | Move an app, frappe included, to another tag or branch and migrate every site |
| `s3-create-buckets.sh`, `s3-list-buckets.sh`, `s3-list-files.sh` | | The local object store |
| `repo-status.sh` | `frstatus`, `git repo-status` | The git state of every app checkout, in one table |
| `pr-sync.sh` | `git pr-sync` | Return an app to its default branch once its PR is merged |
| `gh-login.sh` | | Authenticate `gh`, once per host, with the device flow |

Navigation: `godev`, `gobench`, `goapps`, `gosites`. Log tail: `logs`.

The two git ones are git subcommands as well, completed by `git <TAB>`, so neither has to be remembered as a file name. Under that form the help is `-h`: git answers `--help` with a man page before the script runs.

## Adding a tool

`sudo apt-get install PACKAGE` works in the container without a password: frappe/bench gives the `frappe` user sudo. What it installs lasts until the next rebuild. A tool the whole team needs goes in the apt list in `.devcontainer/Dockerfile` instead.

## Secrets

`.devcontainer/init-env.sh` runs before the container starts and writes `.devcontainer/.env` with a random 32-character value per secret: the database root password, the Frappe Administrator password, the object store keys, the Keycloak admin and test-user password, the Keycloak client secret and the LiteLLM master key. The file is git-ignored, it is never regenerated behind your back, and no default password exists anywhere in this repository.

The model-provider keys LiteLLM needs (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, the `AZURE_*` three) are yours: `init-env.sh` leaves them empty in `.env`, and `litellm-config.yaml` says which model uses which. Fill in the ones you use and restart the `litellm` service.

```bash
bash .devcontainer/init-env.sh --print   # show the current values
bash .devcontainer/init-env.sh --force   # rotate them
```

Rotating invalidates the database the old password created. `init-env.sh --help` has the rest.

### Secret scanning

[gitleaks](https://github.com/gitleaks/gitleaks) checks every commit twice. In the container, a pre-commit hook scans what is staged and refuses the commit on a finding. On GitHub, the `gitleaks` workflow scans the commits a pull request adds, so a commit made with `--no-verify` or outside the container is still caught. Both cover this repository only, not the app checkouts under `frappe-bench/apps/`.

The hook is installed when the container is created. In a container created before it existed, run `pre-commit install` once. A false positive is silenced with a `gitleaks:allow` comment on the line, which a reviewer then sees.

The workflow blocks a merge only once `gitleaks` is a required status check in the branch ruleset of `main`.

## Git and GitHub

- **git** uses the ssh key from your host's agent, which the editor forwards into the container. No private key is copied in and only the public `allowed_signers` list reaches `~/.ssh`, so clone, pull and push over ssh (to GitHub or any other host) work as they do on your machine. The only prerequisite is on the host: an agent running with your key loaded (`ssh-add`) before you reopen in the container.
- **gh** uses its own OAuth token, because an ssh key cannot authenticate an API call. Run `./gh-login.sh` once and approve the code in a browser; the token lands in the host's mounted `~/.config/gh`, so it survives every rebuild.
- **git config** is the host's `~/.gitconfig`, copied into `.devcontainer/` by `init-env.sh` on every start and included by the container's own `~/.gitconfig`. A change made on the host arrives at the next start. `git config --global` inside the container writes the container's file and never touches the host's. The copy is git-ignored, and can hold whatever credential your host config holds.
- **npm config** is the host's `~/.npmrc`, copied the same way and mounted read-only as the container's `~/.npmrc`, so a private registry and its token work for npm and yarn in the bench. Any `prefix` line is left out, since nvm refuses to run under one. Change it on the host; it arrives at the next start. With no host `~/.npmrc`, npm uses the public registry.

An app cloned over https, like the default one in `apps.json`, can still push over ssh with one line in your host `~/.gitconfig`:

```bash
git config --global url."git@github.com:".pushInsteadOf "https://github.com/"
```

Check with `ssh -T git@github.com` and `gh auth status`. If ssh fails, confirm the agent arrived: `SSH_AUTH_SOCK` must be set and `ssh-add -L` must list your key.

## Commits must be signed

Every commit here carries a verified signature. An unsigned commit is rejected at review, because a signature ties a change to a person rather than to a `user.email` string anyone can set.

We sign with SSH, so the key you push with is the key you sign with.

```bash
ssh-keygen -t ed25519 -a 100 -C "you@yourmail.com"      # if you have no key
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

Then add the **public** key at [Settings, SSH and GPG keys](https://github.com/settings/keys) **twice**: once as an *Authentication Key*, once as a *Signing Key*. They are separate entries, and only the second produces the Verified badge.

In a dev container, forward the agent rather than mounting `~/.ssh`, and point at the key itself so no file is needed:

```bash
git config user.signingkey "key::$(ssh-add -L | head -1)"
```

To check signatures locally, as `git log --show-signature` does, git needs the list of keys you trust. On the host:

```bash
echo "you@yourmail.com $(cat ~/.ssh/id_ed25519.pub)" >>~/.ssh/allowed_signers
git config --global gpg.ssh.allowedSignersFile '~/.ssh/allowed_signers'
```

Keep the single quotes: git expands the `~` on each machine, so the same setting finds the file on the host and in the container, where `init-env.sh` copies it on every start. It changes nothing about signing or about GitHub's Verified badge, only what a local check reports.

### Documentation

- [About commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)
- [Telling Git about your signing key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key#telling-git-about-your-ssh-key)
- [Adding a new SSH key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)

## herdr (optional)

[herdr](https://herdr.dev) shows whether the agent in each pane is working or waiting by watching the pane, which needs nothing from the container. Its Claude Code hook also reports the session id to herdr over a control socket, which the container reaches through the host's `~/.config/herdr`, mounted at `~/.herdr-host`.

To opt in, run `herdr integration install claude` on the host, then enter the container from a herdr pane with:

```bash
devpod ssh <workspace> \
  --set-env HERDR_ENV=1 \
  --set-env HERDR_SOCKET_PATH=/home/frappe/.herdr-host/herdr.sock \
  --set-env HERDR_PANE_ID="$HERDR_PANE_ID"
```

Without those variables the hook exits and nothing changes. `herdr integration install` writes the hook's absolute host path into `~/.claude/settings.json`, which does not exist in the container: change it to `bash "$HOME/.claude/hooks/herdr-agent-state.sh" session`, and again after a herdr update.

Linux hosts only: a unix socket does not cross the VM of Docker Desktop on macOS or Windows.

## Divergence from upstream

Kept from [frappe_docker](https://github.com/frappe/frappe_docker/tree/main/devcontainer-example): the Compose-backed container, the `frappe` service and user, the workspace mounted with the bench one level inside it, and the port ranges.

| | Upstream | Here |
|---|---|---|
| Image | `frappe/bench:latest`, used as is | `frappe/bench:latest` too, plus GitHub's host keys, zsh, `micro`, `gh`, `lazygit`, `jq`, `bat`, `fzf`. Every other image pinned to a release |
| Passwords | `123`, hardcoded in three places | Generated per install into `.env` |
| Apps | `installer.py`, honoured only at `bench init` | `apps.json` + `get-apps.sh`, which works on an existing bench |
| Site | `installer.py` | `create-site.sh`, with an explicit app list |
| Bench lifecycle | Nothing | The table above |
| Services | MariaDB, Redis. Mailpit and Postgres commented out | MariaDB, Redis, Mailpit, S3, Keycloak with a dev realm imported, LiteLLM. Postgres dropped |
| Credentials | Host `~/.ssh` bind-mounted | Host `~/.gitconfig`, `~/.ssh/allowed_signers` and `~/.npmrc` copied in on every start, `~/.config/gh` mounted, ssh through the forwarded agent |
| Proxy | Nothing | Host `HTTP_PROXY`, `HTTPS_PROXY` and `NO_PROXY` passed to the build and the containers, empty when unset |
| Windows | Nothing | `init-env.sh` runs under WSL2 or Git Bash, and no host file is mounted by an absolute path |
| Repository work | Nothing | `gh`, `repo-status.sh`, `pr-sync.sh` |
| Claude Code | Nothing | Installed, with the host `~/.claude` shared |

## Licence

Copyright (C) 2026 International Committee of the Red Cross (ICRC), portions Copyright (c) 2017 Frappe Technologies Pvt. Ltd.

GNU General Public License v3.0. See [LICENSE](LICENSE).

Portions derived from [frappe_docker](https://github.com/frappe/frappe_docker), Copyright (c) 2017 Frappe Technologies Pvt. Ltd., under the MIT licence. See [LICENSES/MIT-frappe_docker.txt](LICENSES/MIT-frappe_docker.txt).
