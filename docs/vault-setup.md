# Vaultwarden Initial Setup

Step-by-step procedure for setting up Vaultwarden on a new machine.

## 1. Apply Salt state

```bash
just apply vaultwarden
```

This installs vaultwarden (Podman Quadlet container on localhost:8222), bitwarden-cli, deploys systemd user units and timers, creates `/var/lib/vaultwarden`.

**Failure modes:**
- Port 8222 already in use → edit `states/units/vaultwarden-container.container` line 20 before applying, or stop the conflicting service.
- Missing `just` → run `scripts/salt-apply.sh vaultwarden` directly.

## 2. Vaultwarden initial user registration

Visit `http://localhost:8222` and register the initial admin account.

Signups are blocked after this: the container has `SIGNUPS_ALLOWED=false` in its Quadlet unit (`states/units/vaultwarden-container.container:27`). Only the first registration succeeds.

Confirm in the admin panel (http://localhost:8222/admin) that "Allow new signups" is unchecked.

**Failure modes:**
- Container not running → `sudo systemctl status vaultwarden.service` to check. If inactive, the Quadlet unit may need a start: `sudo systemctl start vaultwarden.service`. On first install, systemd may not have picked up the new unit yet—check `sudo systemctl daemon-reload` was run (Salt does this automatically).

## 3. bw CLI authentication

Get your API key from `https://vault.bitwarden.com/#/organizations/<org>/api` (or from the Vaultwarden admin panel at http://localhost:8222/admin → API Key).

```bash
bw logout 2>/dev/null || true
bw config server http://localhost:8222
bw login --apikey
```

Enter `BW_CLIENTID` (e.g. `user.xxxx`) and `BW_CLIENTSECRET` when prompted.

Test that the session works:

```bash
bw list items --search test
```

**Failure modes:**
- `bw login --apikey` hangs → ensure the bw config server is set correctly. The `bw config server` command persists the server URL in `~/.config/Bitwarden CLI/settings.json`. If you see a server mismatch error, re-run `bw config server http://localhost:8222`.
- API key prompts fail → pass via environment: `BW_CLIENTID=user.xxxx BW_CLIENTSECRET=yyyy bw login --apikey`.

## 4. Verify sync timer

The `bw-sync.timer` fires hourly. For a manual test:

```bash
systemctl --user start bw-sync.service && journalctl --user -u bw-sync.service -n 20 --no-pager
```

The `bw-sync.py` script requires an unlocked Bitwarden session. The oneshot service (`~/.config/systemd/user/bw-sync.service`) does **not** set `BW_SESSION` or `BW_PASSWORD` by default — it calls `bw unlock --raw` which will prompt on stdin and fail in a systemd context.

To make the timer work, set a session key:

```bash
export BW_SESSION="$(bw unlock --raw)"   # prompt for master password once
systemctl --user set-environment BW_SESSION="$BW_SESSION"
```

Alternatively, set `BW_PASSWORD` via a systemd drop-in:

```bash
systemctl --user edit bw-sync.service
# Add:
# [Service]
# Environment=BW_PASSWORD=<your-master-password>
```

Verify items appear in gopass:

```bash
gopass ls bw/
```

**Failure modes:**
- `bw unlock --raw` fails → ensure `bw login --apikey` completed successfully (step 3). The session may have expired — re-authenticate with `bw login --apikey` or `bw unlock --raw`.
- No items in gopass → the sync script only imports items that don't already exist in gopass. If the bw vault is empty, add an item first. Check sync logs: `journalctl --user -u bw-sync.service --no-pager`.

## 5. Set up backup passphrase

```bash
gopass generate backup/recovery-passphrase 32
```

This generates a 32-character passphrase stored in gopass. The `vault-full-backup.sh` script reads it via `gopass show -o backup/recovery-passphrase` to encrypt the backup tarball with `age -p`.

**Failure mode:** The backup script exits with an error if this passphrase is missing. Verify: `gopass show -o backup/recovery-passphrase`.

## 6. Test backup

```bash
systemctl --user start vault-full-backup.service && journalctl --user -u vault-full-backup.service -n 20 --no-pager
ls -la ~/backups/
```

Expect a file like `~/backups/vault-full-<DATE>.age` (~/backups/ is the default; override with `BACKUP_DIR` env var).

The tarball contains:
- gopass store (`~/.local/share/gopass/store/`)
- gopass age identity (`~/.config/gopass/age/identities/`)
- Vaultwarden SQLite dump (if `/var/lib/vaultwarden/db.sqlite3` exists)

Recovery command (for reference — not part of setup):

```bash
age -d ~/backups/vault-full-<DATE>.age | tar xzf -
```

**Failure modes:**
- Missing `/var/lib/vaultwarden/db.sqlite3` → the backup script handles this gracefully (skips the SQLite dump, logs a warning to journal).
- `gopass` not initialized → `gopass setup` first. The backup will fail with "gopass store not found".
- `age` not installed → `sudo pacman -S age` or let the Salt state handle it. The backup script requires `age` to encrypt.
