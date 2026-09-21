# icrc-frappe-devcontainer

A development container for Frappe work at the ICRC.

## Commits must be signed

Every commit on this repository has to carry a verified signature. An unsigned commit will be rejected at review, because a signature is what ties a change to a person rather than to a `user.email` string that anyone can set.

We sign with SSH rather than GPG. The key you already use to push is the key you sign with, so there is nothing extra to manage.

### Setting it up

Generate a key if you have none, and protect it with a passphrase.

```bash
ssh-keygen -t ed25519 -a 100 -C "you@icrc.org"
```

Tell Git to sign with it.

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

Then add the **public** key to GitHub twice, at [Settings, SSH and GPG keys](https://github.com/settings/keys): once as an *Authentication Key* and once as a *Signing Key*. They are separate entries. Adding only the first is the usual reason a commit pushes fine and still shows no Verified badge.

If the organisation enforces SAML single sign-on, authorise the authentication key for `icrc` with the **Configure SSO** button beside it.

### Checking a commit

```bash
git log --format='%h %G? %s' -3
```

`G` is a good signature. **`N` does not reliably mean unsigned.** With SSH signing and no `gpg.ssh.allowedSignersFile`, Git cannot verify the signature, prints `error: gpg.ssh.allowedSignersFile needs to be configured and exist`, and reports `N` for a commit that is correctly signed. GitHub is unaffected: it verifies against the key on your account, not against that file.

So the check that always tells the truth is to look for the header on the object itself.

```bash
git cat-file commit HEAD | grep -c '^gpgsig'
```

To make `%G?` useful locally, list the signers you trust and point Git at the file.

```bash
echo "you@icrc.org $(ssh-add -L | head -1)" >> ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```

A repository can also commit its own `allowed_signers` and point at that, which gives every clone the same list.

### Working in a dev container

Do not mount `~/.ssh` into the container. Forward the agent instead, which is the default for VS Code Dev Containers, so the private key stays on the host and only its use is exposed.

With no `~/.ssh` inside the container, point `user.signingkey` at the key itself rather than at a file:

```bash
git config user.signingkey "key::$(ssh-add -L | head -1)"
```

A public key is not a secret, so holding it in the config is safe. Keep the key's lifetime in the agent bounded, since anything running in the container can ask the agent to sign while it is loaded.

```
# ~/.ssh/config on the host
Host *
  AddKeysToAgent 8h
```

### Documentation

- [About commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification), GitHub
- [Telling Git about your signing key](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key#telling-git-about-your-ssh-key), GitHub, the SSH section
- [Adding a new SSH key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account), GitHub
- [`git config` signing options](https://git-scm.com/docs/git-config#Documentation/git-config.txt-gpgformat), the Git reference for `gpg.format` and `gpg.ssh.allowedSignersFile`

## Licence

GNU General Public License v3.0. See [LICENSE](LICENSE).
