#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <db_user> <db_name>

Drops the specified PostgreSQL database and role, if they exist.

  db_user   Name of the Postgres role to drop
  db_name   Name of the database to drop

Example:
  $0 alice alice_db
EOF
  exit 1
}

# -------------------------------------------------------------------
# 1. Validate args
# -------------------------------------------------------------------
if [ $# -ne 2 ]; then
  usage
fi

DB_USER="$1"
DB_NAME="$2"

# -------------------------------------------------------------------
# 2. Drop database and role as the postgres superuser
# -------------------------------------------------------------------
echo ">>> Dropping database '$DB_NAME' (if exists)..."
sudo -u postgres psql -v ON_ERROR_STOP=1 <<-SQL
  SELECT
    CASE
      WHEN EXISTS (
        SELECT 1 FROM pg_catalog.pg_database WHERE datname = '$DB_NAME'
      ) THEN
        'Dropping database.'
      ELSE
        'Database does not exist, skipping.'
    END
  \gexec

  DROP DATABASE IF EXISTS "$DB_NAME";
SQL

echo ">>> Dropping role '$DB_USER' (if exists)..."
sudo -u postgres psql -v ON_ERROR_STOP=1 <<-SQL
  SELECT
    CASE
      WHEN EXISTS (
        SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER'
      ) THEN
        'Dropping role.'
      ELSE
        'Role does not exist, skipping.'
    END
  \gexec

  DROP ROLE IF EXISTS "$DB_USER";
SQL

echo "✅ Done. '$DB_NAME' and role '$DB_USER' have been removed (if they existed)."
