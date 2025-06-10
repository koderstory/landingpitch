#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -------------------------------------------------------------------
# 0) Detect or prompt for USER, DOMAIN, and IP
# -------------------------------------------------------------------
if [[ $# -ge 2 ]]; then
  SYS_USER="$1"
  DOMAIN="$2"
else
  read -r -p "System user (e.g. dev): " SYS_USER
  read -r -p "Domain        (e.g. mysite.example.com): " DOMAIN
fi

# derive primary IP from hostname
SERVER_IP="$(hostname -I | awk '{print $1}')"

# project naming
PROJECT_ROOT_NAME="Project"   # your top‐level folder under $DOMAIN
DJANGO_APP_NAME="Project"     # inner Django project folder

# computed paths
BASE_DIR="/home/${SYS_USER}/${DOMAIN}"
PROJECT_DIR="${BASE_DIR}/${PROJECT_ROOT_NAME}"
SETTINGS_FILE="${PROJECT_DIR}/${DJANGO_APP_NAME}/settings.py"
URLS_FILE="${PROJECT_DIR}/${DJANGO_APP_NAME}/urls.py"
VENV_DIR="${BASE_DIR}/.venv"
SOCK_PATH="/run/serv.${DOMAIN}.sock"
SOCKET_UNIT="/etc/systemd/system/serv.${DOMAIN}.socket"
SERVICE_UNIT="/etc/systemd/system/serv.${DOMAIN}.service"

# -------------------------------------------------------------------
# 1) Must be run as root
# -------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi

# -------------------------------------------------------------------
# 2) Bootstrap as $SYS_USER: dirs, Pipenv & Django
# -------------------------------------------------------------------
sudo -u "$SYS_USER" bash <<EOF
set -euo pipefail
cd "\$HOME"

# create folder structure
mkdir -p "${PROJECT_DIR}"
# NEW: create assets dir
mkdir -p "${BASE_DIR}/assets"
cd "${BASE_DIR}"

# init in-project venv and install packages
export PIPENV_VENV_IN_PROJECT=1
pipenv install django==5.2 \
               gunicorn \
               django-environ \
               psycopg2 \
               pillow \
               whitenoise \
               djlint

# start a new Django project into Project/
pipenv run django-admin startproject "${DJANGO_APP_NAME}" "${PROJECT_ROOT_NAME}"
EOF

# -------------------------------------------------------------------
# 3) Patch settings.py
# -------------------------------------------------------------------
# 3a) ALLOWED_HOSTS
sed -i "s|^ALLOWED_HOSTS = .*|ALLOWED_HOSTS = ['${DOMAIN}','${SERVER_IP}']|" "$SETTINGS_FILE"

# 3b) Remove any old static/media lines
sed -i \
  -e '/^STATIC_URL =/d' \
  -e '/^STATICFILES_DIRS =/d' \
  -e '/^STATIC_ROOT =/d' \
  -e '/^MEDIA_URL =/d' \
  -e '/^MEDIA_ROOT =/d' \
  "$SETTINGS_FILE"

# 3c) Append the exact block
cat >> "$SETTINGS_FILE" <<'EOP'

STATIC_URL = '/static/'

STATICFILES_DIRS = [BASE_DIR.parent / 'assets', ]

STATIC_ROOT = BASE_DIR.parent / 'public/static'

MEDIA_URL = '/upload/'

MEDIA_ROOT = BASE_DIR.parent / 'public/upload'
EOP

# -------------------------------------------------------------------
# 4) Patch urls.py
# -------------------------------------------------------------------
cat > "$URLS_FILE" <<'EOP'
from django.contrib import admin
from django.urls import path
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView

urlpatterns = [
    path('admin/', admin.site.urls),
]

if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static(settings.MEDIA_URL,  document_root=settings.MEDIA_ROOT)
EOP

# -------------------------------------------------------------------
# 5) Create systemd socket unit
# -------------------------------------------------------------------
cat > "$SOCKET_UNIT" <<EOF
[Unit]
Description=gunicorn socket → ${DOMAIN}

[Socket]
ListenStream=${SOCK_PATH}

[Install]
WantedBy=sockets.target
EOF

# -------------------------------------------------------------------
# 6) Create systemd service unit
# -------------------------------------------------------------------
cat > "$SERVICE_UNIT" <<EOF
[Unit]
Description=gunicorn service for ${DOMAIN}
Requires=serv.${DOMAIN}.socket
After=network.target

[Service]
User=${SYS_USER}
Group=${SYS_USER}
WorkingDirectory=${PROJECT_DIR}
ExecStart=${VENV_DIR}/bin/gunicorn \\
          --access-logfile - \\
          --workers 3 \\
          --bind unix:${SOCK_PATH} \\
          --chdir ${PROJECT_DIR}/${DJANGO_APP_NAME} \\
          ${DJANGO_APP_NAME}.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

# -------------------------------------------------------------------
# 7) Enable & start socket
# -------------------------------------------------------------------
systemctl daemon-reload
systemctl enable --now "serv.${DOMAIN}.socket"

echo "✅ Deployed Django at ${DOMAIN} (IP ${SERVER_IP}), assets dir created, socket: ${SOCK_PATH}"
