#!/bin/bash
set -euo pipefail

DATABASE_PASS='admin123'
REPO_URL="https://github.com/hkhcoder/vprofile-project.git"
REPO_BRANCH="main"

sudo dnf -y update
sudo dnf -y install epel-release
sudo dnf -y install git zip unzip mariadb-server

sudo systemctl enable --now mariadb

# Set root password only if not set yet (idempotent-ish)
if sudo mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
  # root has socket auth/no password; set password
  sudo mysql -u root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DATABASE_PASS}';
FLUSH PRIVILEGES;
SQL
fi

# Now authenticate with password
sudo mysql -u root -p"${DATABASE_PASS}" <<SQL
CREATE DATABASE IF NOT EXISTS accounts;
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY '${DATABASE_PASS}';
CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED BY '${DATABASE_PASS}';
GRANT ALL PRIVILEGES ON accounts.* TO 'admin'@'%';
GRANT ALL PRIVILEGES ON accounts.* TO 'admin'@'localhost';
FLUSH PRIVILEGES;
SQL

# Fetch SQL backup from YOUR repo (not instructor’s)
rm -rf /tmp/vprofile-project
git clone -b "${REPO_BRANCH}" "${REPO_URL}" /tmp/vprofile-project

# Import schema/data (idempotent enough for lab)
sudo mysql -u root -p"${DATABASE_PASS}" accounts < /tmp/vprofile-project/src/main/resources/db_backup.sql

# Firewall
sudo systemctl enable --now firewalld
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --reload

sudo systemctl restart mariadb