#!/usr/bin/env bash
set -euo pipefail

log() { echo "[rabbitmq.sh] $*"; }

pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }

ensure_pkg() {
  local pkg="$1"
  if pkg_installed "$pkg"; then
    log "Package already installed: $pkg"
  else
    log "Installing package: $pkg"
    sudo dnf -y install "$pkg"
  fi
}

ensure_service() {
  local svc="$1"
  log "Enabling + starting service: $svc"
  sudo systemctl enable --now "$svc"
}

# ---- packages / repos ----
log "Updating package metadata"
sudo dnf -y makecache

ensure_pkg epel-release
ensure_pkg wget

# RabbitMQ repo package (idempotent)
if rpm -q centos-release-rabbitmq-38 >/dev/null 2>&1; then
  log "Repo package already installed: centos-release-rabbitmq-38"
else
  log "Installing repo package: centos-release-rabbitmq-38"
  sudo dnf -y install centos-release-rabbitmq-38
fi

# RabbitMQ server install (idempotent)
if rpm -q rabbitmq-server >/dev/null 2>&1; then
  log "rabbitmq-server already installed"
else
  log "Installing rabbitmq-server from centos-rabbitmq-38 repo"
  sudo dnf --enablerepo=centos-rabbitmq-38 -y install rabbitmq-server
fi

# ---- service ----
ensure_service rabbitmq-server

# ---- firewall (optional but common in labs) ----
if systemctl list-unit-files | grep -q '^firewalld\.service'; then
  ensure_service firewalld
  log "Opening port 5672/tcp in firewalld (if not already open)"
  if ! sudo firewall-cmd --zone=public --query-port=5672/tcp >/dev/null 2>&1; then
    sudo firewall-cmd --zone=public --add-port=5672/tcp --permanent
    sudo firewall-cmd --reload
  else
    log "Port 5672/tcp already allowed"
  fi
else
  log "firewalld not installed; skipping firewall configuration"
fi

# ---- configuration ----
# Allow non-local connections by removing loopback restriction for default users.
# NOTE: rabbitmq.config (Erlang) is older style; newer versions prefer rabbitmq.conf.
CFG="/etc/rabbitmq/rabbitmq.config"
DESIRED='[{rabbit, [{loopback_users, []}]}].'

log "Ensuring RabbitMQ loopback_users config allows remote connections"
if [ -f "$CFG" ]; then
  # Only rewrite if content differs (idempotent)
  if ! sudo grep -qxF "$DESIRED" "$CFG"; then
    echo "$DESIRED" | sudo tee "$CFG" >/dev/null
    log "Updated $CFG"
  else
    log "$CFG already set correctly"
  fi
else
  echo "$DESIRED" | sudo tee "$CFG" >/dev/null
  log "Created $CFG"
fi

# Restart only after config assurance
log "Restarting rabbitmq-server to apply config"
sudo systemctl restart rabbitmq-server

# ---- user setup (idempotent) ----
RABBIT_USER="test"
RABBIT_PASS="test"

log "Ensuring RabbitMQ user exists: $RABBIT_USER"
if sudo rabbitmqctl list_users | awk '{print $1}' | grep -qx "$RABBIT_USER"; then
  log "User already exists: $RABBIT_USER (updating password)"
  sudo rabbitmqctl change_password "$RABBIT_USER" "$RABBIT_PASS"
else
  log "Creating user: $RABBIT_USER"
  sudo rabbitmqctl add_user "$RABBIT_USER" "$RABBIT_PASS"
fi

log "Ensuring user tags and permissions"
sudo rabbitmqctl set_user_tags "$RABBIT_USER" administrator

# Permissions command is safe to repeat
sudo rabbitmqctl set_permissions -p / "$RABBIT_USER" ".*" ".*" ".*"

log "Validating rabbitmq-server is active"
sudo systemctl is-active --quiet rabbitmq-server && log "rabbitmq-server is active"

log "Done."
