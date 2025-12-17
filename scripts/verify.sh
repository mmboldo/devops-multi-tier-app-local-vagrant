#!/usr/bin/env bash
set -euo pipefail

# -------- helpers --------
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }

ssh_vm() {
  local vm="$1"; shift
  vagrant ssh "$vm" -c "$*"
}

ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
fail() { echo "❌ $*"; exit 1; }

# -------- preflight --------
need vagrant

if [ ! -f Vagrantfile ]; then
  fail "Run this from the repo root (Vagrantfile not found)."
fi

# -------- expected topology --------
VMS=(db01 mc01 rmq01 app01 web01)

declare -A SERVICES=(
  [db01]="mariadb"
  [mc01]="memcached"
  [rmq01]="rabbitmq-server"
  [app01]="tomcat"
  [web01]="nginx"
)

# Ports we expect to be reachable inside the private network
# (checked from app01/web01 where it makes sense)
declare -A PORTS=(
  [db01]="3306"
  [mc01]="11211"
  [rmq01]="5672"
  [app01]="8080"
  [web01]="80"
)

echo "=== Checking VMs are running ==="
for vm in "${VMS[@]}"; do
  # machine-readable is stable-ish, but plain status is fine too
  if vagrant status "$vm" | grep -qE "running"; then
    ok "$vm is running"
  else
    fail "$vm is not running. Run: make up"
  fi
done

echo
echo "=== Checking systemd services ==="
for vm in "${VMS[@]}"; do
  svc="${SERVICES[$vm]}"
  if ssh_vm "$vm" "systemctl is-active --quiet $svc"; then
    ok "$vm: $svc is active"
  else
    ssh_vm "$vm" "systemctl --no-pager -l status $svc || true"
    fail "$vm: $svc is not active"
  fi
done

echo
echo "=== Checking network ports (basic reachability) ==="

# Use app01 as the "integration hub" for backend checks
ssh_vm app01 "command -v nc >/dev/null 2>&1 || sudo dnf -y install nc >/dev/null"

# From app01 -> db01/mc01/rmq01
for target in db01 mc01 rmq01; do
  port="${PORTS[$target]}"
  if ssh_vm app01 "nc -z -w 3 $target $port"; then
    ok "app01 can reach $target:$port"
  else
    fail "app01 cannot reach $target:$port"
  fi
done

# From web01 -> app01:8080
ssh_vm web01 "command -v nc >/dev/null 2>&1 || sudo apt-get update -y >/dev/null && sudo apt-get install -y netcat-openbsd >/dev/null"
if ssh_vm web01 "nc -z -w 3 app01 ${PORTS[app01]}"; then
  ok "web01 can reach app01:${PORTS[app01]}"
else
  fail "web01 cannot reach app01:${PORTS[app01]}"
fi

echo
echo "=== Checking HTTP endpoints ==="

# From web01 -> app01 directly (Tomcat)
if ssh_vm web01 "curl -fsS http://app01:8080 >/dev/null"; then
  ok "Tomcat responds on http://app01:8080"
else
  warn "Tomcat did not respond on http://app01:8080 (could still be warming up)."
fi

# From host -> web01 (Nginx -> Tomcat)
if curl -fsS http://web01 >/dev/null; then
  ok "Nginx responds on http://web01 (host -> web01)"
else
  warn "Host curl to http://web01 failed. If hostnames aren't resolving, ensure vagrant-hostmanager ran."
  warn "Try: vagrant hostmanager && retry"
fi

echo
ok "Smoke tests complete."
