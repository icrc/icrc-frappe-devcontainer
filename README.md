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

## Frappe versions

Two pins, both in `.devcontainer/.env`, both written once by `init-env.sh`:

- `FRAPPE_BUILD` (`v16`) is the [frappe/build](https://hub.docker.com/r/frappe/build/tags) line the container is built from, the image a production Frappe image is built from too, so the bench runs on the same Python and Node. A major, so a rebuild picks up its newest release and never the next major.
- `FRAPPE_VERSION` (`v16.35.0`) is the exact Frappe release `install-bench.sh` installs. Set it to the one your production image is built from: edit `.env` before the first install, or `./switch-version.sh frappe v16.34.0` on a bench that exists, which migrates every site and rewrites `.env`.

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
| `repo-status.sh` | `frstatus` | The git state of every app checkout, in one table |
| `pr-sync.sh` | | Return an app to its default branch once its PR is merged |
| `gh-login.sh` | | Authenticate `gh`, once per host, with the device flow |

Navigation: `godev`, `gobench`, `goapps`, `gosites`. Log tail: `logs`.

## Secrets

`.devcontainer/init-env.sh` runs before the container starts and writes `.devcontainer/.env` with a random 32-character value per secret: the database root password, the Frappe Administrator password, the object store keys, the Keycloak admin and test-user password, the Keycloak client secret and the LiteLLM master key. The file is git-ignored, it is never regenerated behind your back, and no default password exists anywhere in this repository.

The model-provider keys LiteLLM needs (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, the `AZURE_*` three) are yours: `init-env.sh` leaves them empty in `.env`, and `litellm-config.yaml` says which model uses which. Fill in the ones you use and restart the `litellm` service.

```bash
bash .devcontainer/init-env.sh --print   # show the current values
bash .devcontainer/init-env.sh --force   # rotate them
```

Rotating invalidates the database the old password created. `init-env.sh --help` has the rest.

## Git and GitHub

- **git** uses the ssh key from your host's agent, which the editor forwards into the container. No key is copied in and `~/.ssh` is not mounted, so clone, pull and push over ssh (to GitHub or any other host) work as they do on your machine. The only prerequisite is on the host: an agent running with your key loaded (`ssh-add`) before you reopen in the container.
- **gh** uses its own OAuth token, because an ssh key cannot authenticate an API call. Run `./gh-login.sh` once and approve the code in a browser; the token lands in the host's mounted `~/.config/gh`, so it survives every rebuild.

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

### Documentation

- [About commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)
- [Telling Git about your signing key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key#telling-git-about-your-ssh-key)
- [Adding a new SSH key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)

## Divergence from upstream

Kept from [frappe_docker](https://github.com/frappe/frappe_docker/tree/main/devcontainer-example): the Compose-backed container, the `frappe` service and user, the workspace mounted with the bench one level inside it, and the port ranges.

| | Upstream | Here |
|---|---|---|
| Image | `frappe/bench:latest`, used as is | `frappe/build:v16`, the image production images are built from, plus zsh, `micro`, `gh`, `jq`, `bat`. Every other image pinned to a release |
| Passwords | `123`, hardcoded in three places | Generated per install into `.env` |
| Apps | `installer.py`, honoured only at `bench init` | `apps.json` + `get-apps.sh`, which works on an existing bench |
| Site | `installer.py` | `create-site.sh`, with an explicit app list |
| Bench lifecycle | Nothing | The table above |
| Services | MariaDB, Redis. Mailpit and Postgres commented out | MariaDB, Redis, Mailpit, S3, Keycloak with a dev realm imported, LiteLLM. Postgres dropped |
| Credentials | Host `~/.ssh` bind-mounted | Host `~/.gitconfig` and `~/.config/gh` mounted, ssh through the forwarded agent |
| Repository work | Nothing | `gh`, `repo-status.sh`, `pr-sync.sh` |
| Claude Code | Nothing | Installed, with the host `~/.claude` shared |

## Licence

GNU General Public License v3.0. See [LICENSE](LICENSE).
