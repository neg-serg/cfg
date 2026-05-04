# Vault Recovery

Full restore of gopass store, age identity, and Vaultwarden from a single
age-encrypted backup tarball.

You need the recovery passphrase. It is stored in gopass at
`backup/recovery-passphrase` on a working system. If gopass is gone, you must
know it from memory or a written record.

Backup files are at `~/backups/vault-full-<date>.age`.

## Prerequisites

- `age` installed
- Backup file present in `~/backups/`
- Recovery passphrase

## Decrypt and extract

```bash
mkdir -p /tmp/vault-restore
age -d ~/backups/vault-full-$(date +%F).age | tar xzf - -C /tmp/vault-restore
```

This creates:
- `/tmp/vault-restore/store/` — gopass git repository
- `/tmp/vault-restore/identities` — age identity file
- `/tmp/vault-restore/vaultwarden.db` — Vaultwarden SQLite dump

If you do not know today's date, list the available backups first:

```bash
ls ~/backups/vault-full-*.age
```

Then substitute the correct date manually.

## Restore gopass store

```bash
rm -rf ~/.local/share/gopass/store
cp -a /tmp/vault-restore/store ~/.local/share/gopass/
```

## Restore age identity

```bash
mkdir -p ~/.config/gopass/age
cp -a /tmp/vault-restore/identities ~/.config/gopass/age/
chmod -R 600 ~/.config/gopass/age
```

## Verify gopass decryption

```bash
gopass config age.agent-enabled true
gopass age agent start
gopass age agent unlock
gopass ls bw/
```

If `gopass ls` works but decrypt fails, the identity file or its password is
wrong. Retry the identity restore or use the break-glass procedure.

## Restore Vaultwarden

Stop the container, replace the database, and restart:

```bash
sudo systemctl stop vaultwarden.service
sudo cp /tmp/vault-restore/vaultwarden.db /var/lib/vaultwarden/db.sqlite3
sudo systemctl start vaultwarden.service
```

Verify:

```bash
curl -sf http://127.0.0.1:8222
# Expected: 200 OK — Vaultwarden web UI is reachable
```

## Clean up

```bash
rm -rf /tmp/vault-restore
```

## Recovery from passphrase-only (no backup file)

If you have no backup tarball but remember the gopass master password and age
identity passphrase, restore from git remotes:

```bash
gopass init --store ~/.local/share/gopass/store
gopass git remote add origin <git-url>
gopass sync
```

Then rotate your Vaultwarden passwords through the web UI.

## Recovery from git without age identity

You need the YubiKey break-glass procedure — see the "Break-Glass Recovery" section in `docs/gopass-age-recovery.md`.
