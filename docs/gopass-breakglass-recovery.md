# gopass Break-Glass Recovery

Use this runbook when the current machine no longer has a working file-based `age` decrypt path.

## Minimum backup set

- `~/.config/gopass/age/identities`
- the password used to unlock that identity
- the git URL of the store
- this runbook

Store the identity backup separately from the password or passphrase instructions.

## Recovery steps

```bash
mkdir -p ~/.config/gopass/age
chmod 700 ~/.config/gopass ~/.config/gopass/age
cp identities ~/.config/gopass/age/identities
chmod 600 ~/.config/gopass/age/identities

export GPG_TTY="$(tty)"
gopass clone <store-url>
gopass config age.agent-enabled true
gopass age agent start
gopass age agent unlock
gopass show -o <known-key>
```
