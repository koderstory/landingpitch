#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<EOF
Usage: $0 <system_user> <domain_folder> <db_user> <db_name> <db_pass>

Example:
  sudo $0 dev erp-dev.hamesha.studio odoo odoo_dev supersecretpass
EOF
  exit 1
}

# 1) Require exactly five args
if [[ $# -ne 5 ]]; then
  usage
fi

SYS_USER="$1"
DOMAIN_DIR="$2"
DB_USER="$3"
DB_NAME="$4"
DB_PASS="$5"

HOME_DIR="/home/$SYS_USER"
BASE_DIR="$HOME_DIR/$DOMAIN_DIR"
ODOO_SRC="/opt/odoo18-ce"
SERVICE_UNIT="/etc/systemd/system/odoo_${DOMAIN_DIR}.service"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN_DIR"

# 2) Must be root
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi

# 3) Generate random ports
generate_port() {
  local port rand
  while :; do
    rand=$(( ( RANDOM << 15 ) | RANDOM ))
    port=$(( rand % 55001 + 10000 ))
    if (( port >= 10000 && port <= 65000 )); then
      echo "$port"
      return
    fi
  done
}
XMLRPC_PORT="$(generate_port)"
LONGPOLLING_PORT="$(generate_port)"

# 4) Write and run a per-user setup script
USER_SCRIPT="$HOME_DIR/setup_odoo_user.sh"
cat > "$USER_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

cd "\$HOME"

# load pyenv
export PYENV_ROOT="\$HOME/.pyenv"
export PATH="\$PYENV_ROOT/bin:\$PYENV_ROOT/shims:\$PATH"
eval "\$(pyenv init --path)"
eval "\$(pyenv init -)"

# project directory
mkdir -p "\$HOME/$DOMAIN_DIR"
cd "\$HOME/$DOMAIN_DIR"

# ensure Python version installed & selected
PYTHON_VERSION="\$(pyenv version-name)"
pyenv install --skip-existing "\$PYTHON_VERSION"
pyenv local "\$PYTHON_VERSION"

# clean any old venv and create a fresh one
rm -rf .venv
python -m venv .venv
source .venv/bin/activate

# upgrade pip & core tooling
python -m pip install --upgrade pip setuptools wheel

# install Odoo dependencies (no cache)
pip install --no-cache-dir -r "$ODOO_SRC/requirements.txt"

# write dynamic odoo.conf
cat > odoo.conf <<CONF
[options]
addons_path = $ODOO_SRC/odoo/addons,$ODOO_SRC/addons
server_wide_modules = base,web
admin_passwd = admin
proxy_mode = False

db_host       = localhost
db_port       = False
db_user       = $DB_USER
db_name       = $DB_NAME
db_password   = $DB_PASS
list_db       = True

http_enable       = True
http_port         = 8069
xmlrpc_port       = $XMLRPC_PORT
longpolling_port  = $LONGPOLLING_PORT

data_dir = \$HOME/.local/share/Odoo
workers  = 0
log_level = info
CONF

# initialize the base module
python "$ODOO_SRC/odoo-bin" -c odoo.conf -i base --stop-after-init
EOF

chown "$SYS_USER":"$SYS_USER" "$USER_SCRIPT"
chmod +x "$USER_SCRIPT"
sudo -u "$SYS_USER" -H bash "$USER_SCRIPT"

# 5) Create systemd service for Odoo
cat > "$SERVICE_UNIT" <<EOF
[Unit]
Description=Odoo ${DOMAIN_DIR}
After=network.target

[Service]
User=${SYS_USER}
Group=${SYS_USER}
WorkingDirectory=${ODOO_SRC}
ExecStart=${BASE_DIR}/.venv/bin/python ${ODOO_SRC}/odoo-bin -c ${BASE_DIR}/odoo.conf
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now odoo_${DOMAIN_DIR}.service

# 6) Create nginx vhost
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN_DIR;

    client_max_body_size 200M;
    access_log /var/log/nginx/${DOMAIN_DIR}.access.log;
    error_log  /var/log/nginx/${DOMAIN_DIR}.error.log;

    location / {
        proxy_pass         http://127.0.0.1:${XMLRPC_PORT};
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    location /longpolling/ {
        proxy_pass         http://127.0.0.1:${LONGPOLLING_PORT};
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
echo "   • service:   odoo_${DOMAIN_DIR}.service"
echo "   • nginx vhost: /etc/nginx/sites-available/$DOMAIN_DIR"
