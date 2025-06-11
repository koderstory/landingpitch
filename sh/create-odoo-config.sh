#!/usr/bin/env bash
set -euo pipefail

# Default output
OUTPUT_FILE="odoo.conf"

usage() {
  cat <<USAGE
Usage: $0 -d <domain> -u <db_user> -p <db_pass> [-o <output_file>]

  -d  Domain name (dots will be replaced with underscores for db_name)
  -u  PostgreSQL username
  -p  PostgreSQL password
  -o  (optional) where to write the odoo.conf (default: ./odoo.conf)
USAGE
  exit 1
}

# parse args
while getopts ":d:u:p:o:" opt; do
  case "$opt" in
    d) DOMAIN="$OPTARG" ;;
    u) DB_USER="$OPTARG" ;;
    p) DB_PASS="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    *) usage ;;
  esac
done

# validate
if [[ -z "${DOMAIN:-}" || -z "${DB_USER:-}" || -z "${DB_PASS:-}" ]]; then
  usage
fi

# convert domain to db_name
DB_NAME="${DOMAIN//./_}"

# function to pick a free port in [10000,65000]
get_free_port() {
  while :; do
    port=$(( RANDOM % (65000-10000+1) + 10000 ))
    # using ss to check if it's LISTENING
    if ! ss -lntu | awk '{print $5}' | grep -E -q "(^|:)$port\$"; then
      echo "$port"
      return
    fi
  done
}

# get two distinct ports
XMLRPC_PORT=$(get_free_port)
LONGPOLLING_PORT=$(get_free_port)
if [[ "$LONGPOLLING_PORT" == "$XMLRPC_PORT" ]]; then
  LONGPOLLING_PORT=$(get_free_port)
fi

# emit the conf
cat > "$OUTPUT_FILE" <<EOF
[options]

; ============================================================
; 1. Core Add-ons & Modules
; ============================================================
addons_path = /opt/odoo18-ce/odoo/addons,/opt/odoo18-ce/addons
server_wide_modules = base,web
import_partial =
without_demo = False
translate_modules = ['all']

; ============================================================
; 2. Security & Access Control
; ============================================================
admin_passwd = admin
proxy_mode = False
dbfilter =

; ============================================================
; 3. Database Configuration & Management
; ============================================================
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

; ============================================================
; 4. Server & Protocol Interfaces
; ============================================================
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

; ============================================================
; 5. Paths & Data Storage
; ============================================================
data_dir = /home/dev/.local/share/Odoo

; ============================================================
; 6. Performance & Resource Limits
; ============================================================
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

; ============================================================
; 7. Logging & Reporting
; ============================================================
logfile =
log_level = info
log_handler = :INFO
syslog = False
log_db = False
log_db_level = warning
reportgz = False
screencasts =
screenshots = /tmp/odoo_tests

; ============================================================
; 8. Email & Notifications
; ============================================================
smtp_server = localhost
smtp_port = 25
smtp_ssl = False
smtp_user = False
smtp_password = False
smtp_ssl_certificate_filename = False
smtp_ssl_private_key_filename = False
email_from = False
from_filter = False

; ============================================================
; 9. Localization & Data Formats
; ============================================================
csv_internal_sep = ,
geoip_city_db = /usr/share/GeoIP/GeoLite2-City.mmdb
geoip_country_db = /usr/share/GeoIP/GeoLite2-Country.mmdb

; ============================================================
; 10. Testing & Maintenance
; ============================================================
test_enable = False
test_file =
test_tags = None
pre_upgrade_scripts =
upgrade_path =
EOF

echo "Generated $OUTPUT_FILE:"
echo "  DB:       $DB_NAME (@$DB_USER)"
echo "  Ports:    xmlrpc=$XMLRPC_PORT, longpolling=$LONGPOLLING_PORT"
