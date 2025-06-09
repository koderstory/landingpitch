#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# -------------------------------------------------------------------
# 0) Ensure running as root
# -------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: must be run as root" >&2
  exit 1
fi

# -------------------------------------------------------------------
# 1) Parse or prompt for USERNAME and DOMAIN
# -------------------------------------------------------------------
if [[ $# -ge 2 ]]; then
  USERNAME="$1"
  DOMAIN="$2"
else
  read -r -p "Enter the system user to own the project (e.g. dev): " USERNAME
  read -r -p "Enter the domain for this Django project (e.g. testing.koderstory.com): " DOMAIN
fi

# sanitize DOMAIN → folder name
PROJECT_DIR_NAME="${DOMAIN//./_}"
PROJECT_PATH="/home/$USERNAME/$PROJECT_DIR_NAME"

# -------------------------------------------------------------------
# 2) Install prerequisites
# -------------------------------------------------------------------
apt update -y
apt install -y python3-pip python3-venv build-essential

# -------------------------------------------------------------------
# 3) Install pipenv globally if missing
# -------------------------------------------------------------------
if ! command -v pipenv &>/dev/null; then
  pip3 install --upgrade pip
  pip3 install pipenv
fi

# -------------------------------------------------------------------
# 4) Ensure the user exists
# -------------------------------------------------------------------
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -s /bin/bash "$USERNAME"
  echo "Created system user '$USERNAME'."
fi

# -------------------------------------------------------------------
# 5) As that user: create project folder, virtualenv, install Django, bootstrap
# -------------------------------------------------------------------
su - "$USERNAME" <<EOF
set -euo pipefail

cd "\$HOME"
mkdir -p "$PROJECT_DIR_NAME"
cd "$PROJECT_DIR_NAME"

# force in-project .venv
export PIPENV_VENV_IN_PROJECT=1

# install Django 5.2
pipenv install django==5.2

# start a new Django project named 'Project' in this folder
pipenv run django-admin startproject Project .
EOF

echo "✅ Django 5.2 project created at $PROJECT_PATH with .venv in-project."
