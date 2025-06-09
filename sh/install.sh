# install dependencies
#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Ensure script is run as root
# -----------------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

# -----------------------------------------------------------------------------
# 1. System update & upgrade
# -----------------------------------------------------------------------------
echo ">>> Updating package lists and upgrading installed packages..."
apt update -y
apt upgrade -y

# -----------------------------------------------------------------------------
# 2. Install core build tools & system utilities
# -----------------------------------------------------------------------------
echo ">>> Installing core tools..."
apt install -y \
    build-essential \
    git \
    wget \
    curl

# -----------------------------------------------------------------------------
# 3. Install system services
# -----------------------------------------------------------------------------
echo ">>> Installing system services..."
apt install -y \
    openssh-server \
    fail2ban \
    postgresql \
    postgresql-contrib \
    nginx

# -----------------------------------------------------------------------------
# 4. Install Python tooling, pipenv & database dev headers
# -----------------------------------------------------------------------------
echo ">>> Installing Python, pipenv and database development packages..."
apt install -y \
    python3-dev \
    python3-venv \
    python3-pip \
    pipenv \
    libpq-dev \
    libmysqlclient-dev

# -----------------------------------------------------------------------------
# 5. Compression & archive libraries
# -----------------------------------------------------------------------------
echo ">>> Installing compression/archive libraries..."
apt install -y \
    libbz2-dev \
    zlib1g-dev \
    xz-utils \
    liblzma-dev

# -----------------------------------------------------------------------------
# 6. Readline / SQLite / Ncurses / Tk
# -----------------------------------------------------------------------------
echo ">>> Installing readline, sqlite, ncurses, and tk headers..."
apt install -y \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libncursesw5-dev \
    tk-dev

# -----------------------------------------------------------------------------
# 7. SSL & cryptography
# -----------------------------------------------------------------------------
echo ">>> Installing SSL and crypto libraries..."
apt install -y \
    libssl-dev \
    libffi-dev

# -----------------------------------------------------------------------------
# 8. XML / XSLT / LDAP / SASL
# -----------------------------------------------------------------------------
echo ">>> Installing XML, XSLT, LDAP and SASL dev packages..."
apt install -y \
    libxml2-dev \
    libxslt1-dev \
    libsasl2-dev \
    libldap2-dev

# -----------------------------------------------------------------------------
# 9. Image & color management
# -----------------------------------------------------------------------------
echo ">>> Installing image and color management libraries..."
apt install -y \
    libjpeg8-dev \
    liblcms2-dev

# -----------------------------------------------------------------------------
# 10. Linear algebra libraries
# -----------------------------------------------------------------------------
echo ">>> Installing BLAS / Atlas libraries..."
apt install -y \
    libblas-dev \
    libatlas-base-dev

# -----------------------------------------------------------------------------
# 11. Font support for headless rendering
# -----------------------------------------------------------------------------
echo ">>> Installing fonts and X libraries..."
apt install -y \
    fontconfig \
    libxrender1 \
    xfonts-75dpi \
    xfonts-base

# -----------------------------------------------------------------------------
# 12. Install OpenSSL 1.1 .deb (for legacy compatibility)
# -----------------------------------------------------------------------------
echo ">>> Downloading and installing libssl1.1..."
LIBSSL_URL="http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb"
wget -q "$LIBSSL_URL" -O /tmp/libssl1.1.deb
apt install -y /tmp/libssl1.1.deb
rm /tmp/libssl1.1.deb

# -----------------------------------------------------------------------------
# 13. Install wkhtmltopdf .deb
# -----------------------------------------------------------------------------
echo ">>> Downloading and installing wkhtmltopdf..."
WKHTMLTOPDF_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.focal_amd64.deb"
wget -q "$WKHTMLTOPDF_URL" -O /tmp/wkhtmltox.deb
apt install -y /tmp/wkhtmltox.deb
rm /tmp/wkhtmltox.deb

# -----------------------------------------------------------------------------
# 14. Clone Odoo Community Edition & install Python dependencies
# -----------------------------------------------------------------------------
echo ">>> Cloning Odoo 18.0 CE and installing Python requirements..."
ODOO_REPO="https://github.com/odoo/odoo.git"
git clone -b "18.0" --single-branch --depth 1 "$ODOO_REPO" /opt/odoo-ce
cd /opt/odoo-ce
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

echo ">>> All done! Your system is ready."
