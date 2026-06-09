#!/usr/bin/env bash
set -euo pipefail

AGE_KEY="${AGE_KEY:-${AGE_KEY_PATH:-${HOME}/.config/age/keys.txt}}"
SECRETS_FILE="$(dirname "$0")/../secrets/secrets.yaml.age"

red() { echo -e "\033[31m$*\033[0m" >&2; }

if [ ! -f "$AGE_KEY" ]; then
    red "ERROR: Age key not found at $AGE_KEY"
    red "Set AGE_KEY or AGE_KEY_PATH to the age private key file"
    exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
    red "ERROR: Secrets bundle not found at $SECRETS_FILE"
    red "Encrypt your secrets with: age -e -R <pubkey> -o $SECRETS_FILE secrets/secrets-plain.yaml"
    exit 1
fi

# Validate the age key can decrypt the secrets bundle
if ! age --decrypt -i "$AGE_KEY" "$SECRETS_FILE" > /dev/null 2>&1; then
    red "ERROR: Cannot decrypt secrets bundle with provided age key"
    red "Verify the key at $AGE_KEY matches the public key used to encrypt $SECRETS_FILE"
    exit 1
fi

echo "Age key validated successfully"
echo "Secrets bundle readable at $SECRETS_FILE"
exit 0
