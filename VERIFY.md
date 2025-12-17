# Verification & Validation Guide

This document describes how to verify that each component of the multi-tier application stack is running correctly and integrated as expected.

## Stack Components

- **Nginx (Reverse Proxy)** — `web01`
- **Tomcat (Java App Server)** — `app01`
- **MariaDB/MySQL (Database)** — `db01`
- **Memcached (User Cache)** — `mc01`
- **RabbitMQ (Message Broker)** — `rmq01`

---

## 1. Nginx (web01)

### Service status
```bash
vagrant ssh web01
sudo systemctl status nginx --no-pager
```

**Expected:** `Active: active (running)`

### Port listening
```bash
sudo ss -lntp | grep ':80 '
```

**Expected:** Nginx listening on port 80.

### HTTP response (from host)
```bash
curl -I http://web01
```

**Expected:** `HTTP/1.1 200 OK`

---

## 2. Tomcat (app01)

### Service status
```bash
vagrant ssh app01
sudo systemctl status tomcat --no-pager
```

### Port listening
```bash
sudo ss -lntp | grep ':8080 '
```

### Application deployment
```bash
ls -lah /usr/local/tomcat/webapps/
```

**Expected:** `ROOT.war` and `ROOT/`

---

## 3. Database (db01)

### Service status
```bash
vagrant ssh db01
sudo systemctl status mariadb --no-pager
```

### Database check
```bash
mysql -u root -padmin123 -e "SHOW DATABASES;"
```

**Expected:** `accounts`

---

## 4. Memcached (mc01)

### Service status
```bash
vagrant ssh mc01
sudo systemctl status memcached --no-pager
```

### Port listening
```bash
sudo ss -lntup | grep 11211
```

---

## 5. RabbitMQ (rmq01)

### Service status
```bash
vagrant ssh rmq01
sudo systemctl status rabbitmq-server --no-pager
```

### Port listening
```bash
sudo ss -lntp | grep 5672
```

---

## 6. End-to-End Test

```bash
curl http://web01
```

Application should load successfully.

---

## Verification Summary

All layers validated:
- Reverse proxy
- Application server
- Database
- Cache
- Message broker
