#!/usr/bin/env bash
set -euo pipefail

# Create a single age-encrypted tarball containing:
#   - gopass store (git repo)
#   - gopass age identity
#   - Vaultwarden SQLite dump
#
# Recovery:  age -d <backup.age> | tar xzf -
# Requires:  age installed, the backup passphrase set in gopass

GOPASS_STORE="${GOPASS_STORE:-$HOME/.local/share/gopass/store}"
AGE_IDENTITY="${AGE_IDENTITY:-$HOME/.config/gopass/age/identities}"
VAULTWARDEN_DB="${VAULTWARDEN_DB:-/var/lib/vaultwarden/db.sqlite3}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
DATE=$(date +%F)
BACKUP_FILE="${BACKUP_DIR}/vault-full-${DATE}.age"
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

# Validate source paths
if [[ ! -d "${GOPASS_STORE}" ]]; then
    echo "ERROR: gopass store not found at ${GOPASS_STORE}"
    exit 1
fi
if [[ ! -d "${AGE_IDENTITY}" ]]; then
    echo "ERROR: age identity not found at ${AGE_IDENTITY}"
    exit 1
fi

# Get backup passphrase from gopass
PASSPHRASE=$(gopass show -o backup/recovery-passphrase 2>/dev/null || true)
if [[ -z "${PASSPHRASE}" ]]; then
    echo "ERROR: backup passphrase not found in gopass (backup/recovery-passphrase)"
    exit 1
fi

mkdir -p "${BACKUP_DIR}"

# Dump Vaultwarden SQLite (WAL-safe)
if [[ -f "${VAULTWARDEN_DB}" && -r "${VAULTWARDEN_DB}" ]]; then
    sqlite3 "${VAULTWARDEN_DB}" ".backup '${TMPDIR}/vaultwarden.db'"
else
    echo "  WARNING: ${VAULTWARDEN_DB} not readable — skipping SQLite dump"
fi

# Create tarball — fail hard on missing sources
tar czf "${TMPDIR}/vault-full.tar.gz" \
    -C "$(dirname "${GOPASS_STORE}")" "$(basename "${GOPASS_STORE}")" \
    -C "$(dirname "${AGE_IDENTITY}")" "$(basename "${AGE_IDENTITY}")"
if [[ -f "${TMPDIR}/vaultwarden.db" ]]; then
    tar rzf "${TMPDIR}/vault-full.tar.gz" -C "${TMPDIR}" vaultwarden.db
fi

# Encrypt with age passphrase
if [[ ! -f "${TMPDIR}/vault-full.tar.gz" ]]; then
    echo "ERROR: tarball not created; skipping encryption"
    exit 1
fi
age -p -o "${BACKUP_FILE}" "${TMPDIR}/vault-full.tar.gz" <<< "${PASSPHRASE}"

echo "vault-full-backup: created ${BACKUP_FILE} ($(stat -c%s "${BACKUP_FILE}") bytes)"

# Verify integrity
echo "${PASSPHRASE}" | age -d "${BACKUP_FILE}" >/dev/null 2>&1 || {
    echo "ERROR: backup verification FAILED — ${BACKUP_FILE} is corrupt"
    rm -f "${BACKUP_FILE}"
    exit 1
}
echo "vault-full-backup: integrity verified"

# Prune backups older than 90 days
find "${BACKUP_DIR}" -maxdepth 1 -name 'vault-full-*.age' -mtime +90 -delete
