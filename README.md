# icrc-frappe-devcontainer

A development container for Frappe work at the ICRC.

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


## Licence

GNU General Public License v3.0. See [LICENSE](LICENSE).
