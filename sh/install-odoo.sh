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

# 3) Generate dynamic values
DB_NAME="${DOMAIN_DIR//./_}"
DB_USER="$SYS_USER"

# Prompt manually for database password (silent input)
read -s -p "Enter database password for $DB_USER@$DB_NAME: " DB_PASS
echo

# helper to pick a port between 10000–65000
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

# 4) Bootstrap Odoo as SYS_USER
sudo -u "$SYS_USER" bash <<EOF
set -euo pipefail
cd "\$HOME"

# create project dir & venv
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"
export $VENV_FLAG
pipenv --python \$(which python3)
pipenv run pip install -r "$ODOO_SRC/requirements.txt"

# generate dynamic odoo.conf
cat > odoo.conf <<CONF
[options]
addons_path = $ODOO_SRC/odoo/addons,$ODOO_SRC/addons
server_wide_modules = base,web
import_partial =
without_demo = False
translate_modules = ['all']

admin_passwd = admin
proxy_mode = False
dbfilter =

db_host = localhost
db_port = False
db_user = $DB_USER
db_name = $DB_NAME
db_password = $DB_PASS
db_template = template0
db_sslmode = prefer
unaccent = False
db_maxconn = 64
db_maxconn_gevent = False
db_replica_host = False
db_replica_port = False
list_db = True

http_enable = True
http_interface =
http_port = 8069
gevent_port = 8072
xmlrpc_port = $XMLRPC_PORT
longpolling_port = $LONGPOLLING_PORT
websocket_keep_alive_timeout = 3600
websocket_rate_limit_burst = 10
websocket_rate_limit_delay = 0.2
x_sendfile = False
pidfile =

data_dir = $HOME_DIR/.local/share/Odoo

workers = 0
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_hard_gevent = False
limit_memory_soft = 2147483648
limit_memory_soft_gevent = False
limit_request = 65536
limit_time_cpu = 60
limit_time_real = 120
limit_time_real_cron = -1
limit_time_worker_cron = 0
osv_memory_count_limit = 0
transient_age_limit = 1.0

logfile =
log_level = info
log_handler = :INFO
syslog = False
log_db = False
log_db_level = warning
reportgz = False
screencasts =
screenshots = /tmp/odoo_tests

smtp_server = localhost
smtp_port = 25
smtp_ssl = False
smtp_user = False
smtp_password = False
smtp_ssl_certificate_filename = False
smtp_ssl_private_key_filename = False
email_from = False
from_filter = False

csv_internal_sep = ,
geoip_city_db = /usr/share/GeoIP/GeoLite2-City.mmdb
geoip_country_db = /usr/share/GeoIP/GeoLite2-Country.mmdb

test_enable = False
test_file =
test_tags = None
pre_upgrade_scripts =
upgrade_path =
CONF

EOF

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

    # longpolling (chat / live updates)
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
echo "   • systemd service: odoo_${DOMAIN_DIR}.service"
echo "   • nginx vhost:   /etc/nginx/sites-available/$DOMAIN_DIR"
