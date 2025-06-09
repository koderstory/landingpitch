#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Prompt for input
read -rp "Enter new username: " USERNAME
if id "$USERNAME" &>/dev/null; then
  echo "⚠️ User '$USERNAME' already exists!" >&2
  exit 1
fi

read -rp "Enter full name/comment (e.g. John Doe): " COMMENT
read -rsp "Enter password for $USERNAME: " PASS
echo
read -rsp "Confirm password: " PASS2
echo

if [[ "$PASS" != "$PASS2" ]]; then
  echo "❌ Passwords do not match!" >&2
  exit 1
fi

# Create the user without sudo privileges
# -m : create home directory
# -c : set GECOS/comment field
# -s : set default shell
useradd -m -c "$COMMENT" -s /bin/bash "$USERNAME"

# Set the user's password
echo "${USERNAME}:${PASS}" | chpasswd

# OPTIONAL: add to extra groups
read -rp "Add $USERNAME to additional groups? (comma-separated, or leave blank): " GROUPS
if [[ -n "$GROUPS" ]]; then
  usermod -aG "${GROUPS// /}" "$USERNAME"
fi

echo "✅ User '$USERNAME' created successfully!"