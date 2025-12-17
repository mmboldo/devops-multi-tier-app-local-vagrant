#!/usr/bin/env bash
set -euo pipefail

PORT="11211"
UDP_PORT="11111"

echo "[memcache.sh] Installing memcached"
sudo dnf -y install epel-release
sudo dnf -y install memcached

echo "[memcache.sh] Configuring /etc/sysconfig/memcached"
# Ensure file exists
sudo touch /etc/sysconfig/memcached

# Set explicit variables in a safe/idempotent way
sudo sed -i \
  -e "s/^PORT=.*/PORT=${PORT}/" \
  -e "s/^USER=.*/USER=memcached/" \
  -e "s/^MAXCONN=.*/MAXCONN=1024/" \
  -e "s/^CACHESIZE=.*/CACHESIZE=64/" \
  /etc/sysconfig/memcached

# If missing, append them
grep -q '^PORT=' /etc/sysconfig/memcached || echo "PORT=${PORT}" | sudo tee -a /etc/sysconfig/memcached >/dev/null
grep -q '^USER=' /etc/sysconfig/memcached || echo "USER=memcached" | sudo tee -a /etc/sysconfig/memcached >/dev/null
grep -q '^MAXCONN=' /etc/sysconfig/memcached || echo "MAXCONN=1024" | sudo tee -a /etc/sysconfig/memcached >/dev/null
grep -q '^CACHESIZE=' /etc/sysconfig/memcached || echo "CACHESIZE=64" | sudo tee -a /etc/sysconfig/memcached >/dev/null

# Force a single, explicit listen config.
# IMPORTANT: only set OPTIONS once, don’t "replace 127.0.0.1 everywhere".
sudo sed -i "s/^OPTIONS=.*/OPTIONS=\"-l 0.0.0.0\"/" /etc/sysconfig/memcached
grep -q '^OPTIONS=' /etc/sysconfig/memcached || echo "OPTIONS=\"-l 0.0.0.0\"" | sudo tee -a /etc/sysconfig/memcached >/dev/null

echo "[memcache.sh] Enabling + starting memcached (systemd only)"
sudo systemctl daemon-reload
sudo systemctl enable --now memcached

echo "[memcache.sh] Firewall (if firewalld is running)"
if systemctl is-active --quiet firewalld; then
  sudo firewall-cmd --add-port=${PORT}/tcp --permanent
  sudo firewall-cmd --add-port=${UDP_PORT}/udp --permanent
  sudo firewall-cmd --reload
fi

echo "[memcache.sh] Status:"
sudo systemctl status memcached --no-pager
sudo ss -lntup | grep ":${PORT}" || true