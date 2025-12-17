# Known Issues & Limitations

This document lists known issues, limitations, and design trade-offs in the
current version of the multi-tier Vagrant-based deployment.

These items are **intentionally documented** to demonstrate awareness,
debugging ability, and future improvement planning.

---

## 1. Hardcoded Credentials (Non-Production)

**Status:** Known limitation  
**Impact:** Security (acceptable for local lab)

### Description
Database, RabbitMQ, and application credentials are currently hardcoded in:
- `application.properties`
- provisioning shell scripts

This is intentional to keep the lab self-contained and reproducible.

### Planned Improvement
- Replace hardcoded secrets with:
  - Environment variables
  - `.env` files ignored by Git
  - Vault-based secret management (e.g., HashiCorp Vault, AWS SSM)

---

## 2. Memcached Double-Start Conflict (Resolved)

**Status:** Fixed  
**Impact:** Service startup failure

### Description
Initial provisioning attempted to:
- Start `memcached` via systemd
- Manually start `memcached` using a background command

This caused a port conflict on `11211`, resulting in:
failed to listen on TCP port 11211: Address already in use

### Resolution
- Removed manual `memcached` startup command
- Rely exclusively on systemd-managed service

### Lesson Learned
System services should be managed **only by systemd**, not mixed with manual daemon execution.

---

## 3. MariaDB Database Initialization Failure (Resolved)

**Status:** Fixed  
**Impact:** Application login failure

### Description
The `accounts` database was not created correctly during initial provisioning,
causing:
- Application authentication failures
- Missing tables

### Root Cause
- SQL import executed before database creation
- Lack of idempotency checks in the provisioning script

### Resolution
- Added explicit database creation step
- Ensured SQL import runs only after database exists
- Improved ordering and error handling in `mysql.sh`

---

## 4. Idempotency Gaps in Provisioning Scripts

**Status:** Known limitation  
**Impact:** Re-provisioning may cause failures

### Description
Some provisioning scripts do not fully guard against re-execution, including:
- Re-creating users
- Re-importing SQL data
- Re-downloading artifacts

### Planned Improvement
- Add conditional checks (`systemctl is-active`, file existence tests)
- Convert shell scripts to Ansible roles for true idempotency

---

## 5. No Health Checks or Readiness Probes

**Status:** Known limitation  
**Impact:** Startup order dependency

### Description
Services assume availability of upstream dependencies at startup:
- Tomcat assumes database and cache are available
- Nginx assumes Tomcat is reachable

There are no health or readiness checks.

### Planned Improvement
- Add:
  - TCP/HTTP health checks
  - Retry logic in application startup
  - Service dependency validation scripts

---

## 6. Lack of TLS / HTTPS

**Status:** Known limitation  
**Impact:** Security (acceptable for local lab)

### Description
All communication occurs over plain HTTP and TCP.

### Planned Improvement
- Add TLS termination at Nginx
- Use self-signed certificates for local development
- Enforce HTTPS-only access

---

## 7. Single-Node Architecture

**Status:** Design limitation  
**Impact:** No high availability

### Description
Each tier runs as a single instance:
- No load balancing
- No failover
- No clustering

### Planned Improvement
- Add multiple app nodes
- Introduce Nginx upstream load balancing
- Use clustered cache and database replication

---

## 8. Manual Verification Process

**Status:** Known limitation  
**Impact:** Operational efficiency

### Description
Verification steps are manual and documented in `VERIFY.md`.

### Planned Improvement
- Automate validation using:
  - Smoke test scripts
  - CI pipeline checks
  - Infrastructure validation tools

---

## Summary

These issues are **documented by design** to:
- Demonstrate real-world troubleshooting
- Show architectural awareness
- Provide a roadmap for future improvements

The current implementation prioritizes **clarity, reproducibility, and learning**
over production-grade hardening.