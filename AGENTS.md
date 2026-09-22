# AGENTS.md

Guidance for coding agents working in this repository. Humans: [README.md](README.md) is the one to read, and everything here is true for you too.

## What this is

A dev container for Frappe development. It ships no application code: the apps come from `development/apps.json` and are cloned into `development/frappe-bench/`, which is generated and git-ignored. A change here is a change to the environment, never to an app.

## Layout

```
.devcontainer/    the container: Dockerfile, Compose services, init-env.sh
development/      the scripts, apps.json, and (generated) frappe-bench/
```

Inside the container the repository is at `/workspace` and the bench at `/workspace/development/frappe-bench`. Do not hardcode either: every script derives its paths from its own location through `development/common.sh`, which is what lets the repository be mounted anywhere.

## Running things

Every script lives in `development/`, takes `--help`, and is the only supported way to do its job. Prefer them over raw `bench` commands, because they carry the flags and the checks.

```bash
cd /workspace/development
./install-bench.sh      # once, creates the bench
./get-apps.sh           # after editing apps.json
./create-site.sh        # a site, with apps installed
./start.sh              # the server
./migrate-site.sh       # after ANY DocType change
./repo-status.sh        # the git state of every app checkout
```

## Rules

**Never edit anything under `frappe-bench/apps/frappe/`**, or under any other upstream app such as `helpdesk` or `telephony`. They are external checkouts, and a local edit is lost on the next update and invisible in review. Extend them from your own app instead, through hooks, `override_whitelisted_methods`, `override_doctype_class`, `doc_events` or a custom script. If no extension point exists, the change belongs in a pull request upstream.

**Run `./migrate-site.sh` after changing a DocType JSON.** Without it the column does not exist, the field never appears on the form, and the failure looks like a bug in the code.

**Never write a secret into a tracked file.** Every password is generated into `.devcontainer/.env` by `init-env.sh` and read from the environment. There is no default password in this repository and no new one should appear: if a script needs a secret, add it to `SECRETS` in `init-env.sh` and read it through `require_secret` in `common.sh`.

**No ICRC-internal hostname, URL, project name or address anywhere.** This repository is licensed for publication. An internal example goes in `apps.local.json`, which is git-ignored, or in a placeholder form such as `tfs.example.org`.

**Commits are signed**, and pull requests go through a feature branch. README.md has the ssh signing setup.

## Conventions for a change here

- A new script: `set -euo pipefail`, source `common.sh`, a `usage()` with a `--help` case, and `require_bench` / `require_secret` where they apply. Add it to the table in README.md and to `.devcontainer/zsh/custom.zsh` if it deserves an alias.
- Pin every version you add: an image tag, a release tarball with its sha256, an app branch in `apps.json`. A floating version makes a rebuild a different container.
- Check a shell change with `bash -n` at minimum. There is no test suite; the end-to-end check is a container rebuild, `install-bench.sh`, `create-site.sh`, `start.sh`, and the site loading.
- Keep the divergence table in README.md current when you change something the upstream frappe_docker example does differently. That table is how anyone tells our decisions from theirs.
