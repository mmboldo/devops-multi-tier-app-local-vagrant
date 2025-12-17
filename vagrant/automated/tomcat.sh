#!/usr/bin/env bash
set -euo pipefail

log() { echo "[tomcat.sh] $*"; }

TOM_VERSION="9.0.113"
TOMURL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOM_VERSION}/bin/apache-tomcat-${TOM_VERSION}.tar.gz"
TOM_TAR="/tmp/apache-tomcat-${TOM_VERSION}.tar.gz"
TOM_DIR="/usr/local/tomcat"

MAVEN_VERSION="3.9.9"
MAVEN_ZIP="/tmp/apache-maven-${MAVEN_VERSION}-bin.zip"
MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip"
MAVEN_HOME="/usr/local/maven${MAVEN_VERSION}"
MVN="${MAVEN_HOME}/bin/mvn"

APP_REPO_URL="https://github.com/hkhcoder/vprofile-project.git"
APP_BRANCH="main"
APP_DIR="/tmp/vprofile-project"

# Optional: if your Vagrant synced folder contains application.properties
# (recommended to keep config in your repo and mount into VM)
VAGRANT_APP_PROPS="/vagrant/application.properties"

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

ensure_user() {
  local user="$1"
  if id -u "$user" >/dev/null 2>&1; then
    log "User exists: $user"
  else
    log "Creating user: $user"
    sudo useradd --shell /sbin/nologin "$user"
  fi
}

download_if_missing() {
  local url="$1"
  local out="$2"
  if [ -f "$out" ]; then
    log "Already downloaded: $out"
  else
    log "Downloading: $url"
    sudo wget -q "$url" -O "$out"
  fi
}

write_file_if_changed() {
  local path="$1"
  local content="$2"
  if [ -f "$path" ] && sudo cmp -s <(echo "$content") "$path"; then
    log "File unchanged: $path"
  else
    log "Writing file: $path"
    echo "$content" | sudo tee "$path" >/dev/null
  fi
}

# ------------------ Packages ------------------
log "Updating package metadata"
sudo dnf -y makecache

ensure_pkg java-17-openjdk
ensure_pkg java-17-openjdk-devel
ensure_pkg git
ensure_pkg wget
ensure_pkg unzip
ensure_pkg zip
ensure_pkg rsync

# ------------------ Tomcat install ------------------
ensure_user tomcat

if [ -d "${TOM_DIR}/bin" ] && [ -x "${TOM_DIR}/bin/catalina.sh" ]; then
  log "Tomcat already installed at ${TOM_DIR}"
else
  log "Installing Tomcat ${TOM_VERSION}"
  download_if_missing "$TOMURL" "$TOM_TAR"

  # Extract to temp
  sudo rm -rf /tmp/apache-tomcat-"${TOM_VERSION}"
  sudo tar -xzf "$TOM_TAR" -C /tmp

  # Install to /usr/local/tomcat
  sudo rm -rf "$TOM_DIR"
  sudo mkdir -p "$TOM_DIR"
  sudo rsync -a "/tmp/apache-tomcat-${TOM_VERSION}/" "$TOM_DIR/"
fi

sudo chown -R tomcat:tomcat "$TOM_DIR"

# ------------------ systemd unit ------------------
TOMCAT_UNIT_CONTENT="[Unit]
Description=Tomcat
After=network.target

[Service]
Type=simple
User=tomcat
Group=tomcat
WorkingDirectory=${TOM_DIR}

Environment=JAVA_HOME=/usr/lib/jvm/jre
Environment=CATALINA_HOME=${TOM_DIR}
Environment=CATALINA_BASE=${TOM_DIR}

ExecStart=${TOM_DIR}/bin/catalina.sh run
ExecStop=${TOM_DIR}/bin/shutdown.sh

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"

write_file_if_changed "/etc/systemd/system/tomcat.service" "$TOMCAT_UNIT_CONTENT"

sudo systemctl daemon-reload
ensure_service tomcat

# ------------------ Maven install ------------------
if [ -x "$MVN" ]; then
  log "Maven already installed: $MVN"
else
  log "Installing Maven ${MAVEN_VERSION}"
  download_if_missing "$MAVEN_URL" "$MAVEN_ZIP"
  sudo rm -rf "/tmp/apache-maven-${MAVEN_VERSION}"
  sudo unzip -q "$MAVEN_ZIP" -d /tmp
  sudo rm -rf "$MAVEN_HOME"
  sudo mv "/tmp/apache-maven-${MAVEN_VERSION}" "$MAVEN_HOME"
fi

export MAVEN_OPTS="${MAVEN_OPTS:-"-Xmx512m"}"

# ------------------ App source (clone/pull) ------------------
if [ -d "$APP_DIR/.git" ]; then
  log "App repo already present, updating: $APP_DIR"
  sudo git -C "$APP_DIR" fetch --all --prune
  sudo git -C "$APP_DIR" checkout "$APP_BRANCH"
  sudo git -C "$APP_DIR" pull --ff-only
else
  if [ -d "$APP_DIR" ]; then
    log "Removing non-git directory at $APP_DIR (unexpected)"
    sudo rm -rf "$APP_DIR"
  fi
  log "Cloning app repo: $APP_REPO_URL (branch: $APP_BRANCH)"
  sudo git clone -b "$APP_BRANCH" "$APP_REPO_URL" "$APP_DIR"
fi

# ------------------ Build (pragmatic) ------------------
# Only rebuild if target war is missing. (Good enough for a lab.)
WAR_PATH="${APP_DIR}/target/vprofile-v2.war"
if [ -f "$WAR_PATH" ]; then
  log "WAR already built: $WAR_PATH"
else
  log "Building application with Maven"
  (cd "$APP_DIR" && sudo "$MVN" -q -DskipTests install)
fi

# ------------------ Deploy ------------------
log "Deploying ROOT.war"
sudo systemctl stop tomcat
sudo rm -rf "${TOM_DIR}/webapps/ROOT" "${TOM_DIR}/webapps/ROOT.war"
sudo cp "$WAR_PATH" "${TOM_DIR}/webapps/ROOT.war"
sudo chown tomcat:tomcat "${TOM_DIR}/webapps/ROOT.war"

sudo systemctl start tomcat

# ------------------ Optional config injection ------------------
# If you want to override application.properties AFTER deployment, do it here.
# This is optional because some apps bake properties into the war at build time.
if [ -f "$VAGRANT_APP_PROPS" ]; then
  log "Found ${VAGRANT_APP_PROPS}. Attempting to inject into deployed app (best-effort)."
  # Wait for expansion
  sleep 10
  if [ -f "${TOM_DIR}/webapps/ROOT/WEB-INF/classes/application.properties" ]; then
    sudo cp "$VAGRANT_APP_PROPS" "${TOM_DIR}/webapps/ROOT/WEB-INF/classes/application.properties"
    sudo chown tomcat:tomcat "${TOM_DIR}/webapps/ROOT/WEB-INF/classes/application.properties"
    sudo systemctl restart tomcat
    log "Injected application.properties and restarted tomcat."
  else
    log "WAR not expanded yet or path differs; skipping injection. (This may be OK.)"
  fi
else
  log "No /vagrant/application.properties found; skipping config injection."
fi

log "Done."