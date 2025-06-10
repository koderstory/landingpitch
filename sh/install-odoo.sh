#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<EOF
Usage: $0 <system_user> <domain_folder>

Example:
  sudo $0 dev erp-dev.hamesha.studio
EOF
  exit 1
}

# 1) Args or prompt
if [[ $# -ge 2 ]]; then
  SYS_USER="$1"
  DOMAIN_DIR="$2"
else
  read -r -p "System user (e.g. dev): " SYS_USER
  read -r -p "Domain folder (e.g. erp-dev.hamesha.studio): " DOMAIN_DIR
fi

HOME_DIR="/home/$SYS_USER"
BASE_DIR="$HOME_DIR/$DOMAIN_DIR"
VENV_FLAG="PIPENV_VENV_IN_PROJECT=1"
ODOO_SRC="/opt/odoo18-ce"
SERVICE_UNIT="/etc/systemd/system/odoo_${DOMAIN_DIR}.service"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN_DIR"

# 2) Must be root
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi

# 3) Bootstrap Odoo as SYS_USER
sudo -u "$SYS_USER" bash <<EOF
set -euo pipefail
cd "\$HOME"

# create project dir & venv
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"
export $VENV_FLAG
pipenv --python \$(which python3)
pipenv run pip install -r "$ODOO_SRC/requirements.txt"

# generate a default odoo.conf and exit
pipenv run python3 "$ODOO_SRC/odoo-bin" \
    --save --config odoo.conf --stop-after-init
EOF

# 4) Create systemd service for Odoo
cat > "$SERVICE_UNIT" <<EOF
[Unit]
Description=Odoo (${DOMAIN_DIR})
Documentation=https://www.odoo.com
After=network.target

[Service]
User=$SYS_USER
Group=$SYS_USER
WorkingDirectory=$BASE_DIR
ExecStart=$BASE_DIR/.venv/bin/python $ODOO_SRC/odoo-bin -c $BASE_DIR/odoo.conf
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now odoo_${DOMAIN_DIR}.service

# 5) Create nginx vhost
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN_DIR;

    client_max_body_size 200M;
    access_log /var/log/nginx/${DOMAIN_DIR}.access.log;
    error_log  /var/log/nginx/${DOMAIN_DIR}.error.log;

    location / {
        proxy_pass         http://127.0.0.1:8069;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    # longpolling (chat / live updates)
    location /longpolling/ {
        proxy_pass         http://127.0.0.1:8072;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "✅ Odoo deployed under $BASE_DIR"
echo "   • systemd service: odoo_${DOMAIN_DIR}.service"
echo "   • nginx vhost:   /etc/nginx/sites-available/$DOMAIN_DIR"
