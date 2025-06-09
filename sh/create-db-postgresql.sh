#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <db_user> <db_name> <db_password>

Creates a PostgreSQL role and database, then locks down the public schema
so only the new role can use/create objects there.

  db_user       Name of the new Postgres role (login user)
  db_name       Name of the new database to create
  db_password   Password for the new role

Example:
  $0 alice alice_db S3cr3tP@ssw0rd
EOF
  exit 1
}

# -------------------------------------------------------------------
# 1. Validate args
# -------------------------------------------------------------------
if [ $# -ne 3 ]; then
  usage
fi

DB_USER="$1"
DB_NAME="$2"
DB_PASS="$3"

# -------------------------------------------------------------------
# 2. Create role and database as the postgres superuser
# -------------------------------------------------------------------
echo ">>> Creating role '$DB_USER' and database '$DB_NAME'..."

sudo -u postgres psql <<-SQL
-- create role if not exists
DO
\$do\$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER'
   ) THEN
      CREATE ROLE "$DB_USER"
        WITH LOGIN
             PASSWORD '$DB_PASS'
             NOSUPERUSER
             NOCREATEDB
             NOREPLICATION
             INHERIT;
   END IF;
END
\$do\$;

-- create database if not exists
SELECT
  CASE
    WHEN EXISTS(
      SELECT FROM pg_catalog.pg_database WHERE datname = '$DB_NAME'
    ) THEN
      'Database already exists, skipping creation.'
    ELSE
      'Creating database.'
  END;
\gexec

CREATE DATABASE "$DB_NAME"
  WITH OWNER = "$DB_USER"
       TEMPLATE = template0;

\connect "$DB_NAME"

-- lock down public schema
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO "$DB_USER";
SQL

echo "✅ Done. Role '$DB_USER' and database '$DB_NAME' are ready."
