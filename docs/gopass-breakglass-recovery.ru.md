# gopass Break-Glass Recovery

Используйте этот runbook, когда на текущей машине больше нет рабочего file-based `age` decrypt path.

## Минимальный backup set

- `~/.config/gopass/age/identities`
- пароль, которым разблокируется эта identity
- git URL store
- этот runbook

Храните backup identity отдельно от пароля или инструкции по passphrase.

## Шаги восстановления

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
