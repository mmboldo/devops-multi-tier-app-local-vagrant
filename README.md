# DevOps Multi-Tier Application (Local Vagrant Lab)

A production-style multi-tier web application deployed locally using Vagrant and automated shell provisioning.

This project demonstrates infrastructure provisioning, service orchestration, and operational validation across multiple Linux hosts, simulating a real-world backend architecture.

---

## Architecture Overview

![Multi-Tier Architecture Diagram](docs/architecture.png)

---

## Stack Components

**Nginx (Reverse Proxy) — web01 (Ubuntu 22.04)**
  Acts as a reverse proxy, accepting HTTP traffic and forwarding requests
  to the application server.
  
**Tomcat (Java App Server) — app01 (CentOS Stream 9)**
  Hosts the Java web application (WAR) and handles business logic.

**MariaDB / MySQL (Database) — db01 (CentOS Stream 9)**
  Stores application data and user information.

**Memcached (User Cache) — mc01 (CentOS Stream 9)**
  Provides in-memory caching for user/session-related data.

**RabbitMQ (Message Broker) — rmq01 (CentOS Stream 9)**
  Handles asynchronous messaging between application components.

---

## Prerequisites

- Vagrant
- VirtualBox
- Git
- Minimum 8 GB RAM recommended

Tested on Windows (Git Bash / PowerShell), macOS, and Linux hosts.

---

## How to Run

Bring up the full environment by running the below command from the folder vagrant/automated:
```bash
vagrant up
```
This will:
- Create all virtual machines
- Provision system services
- Build and deploy the Java application
- Configure service-to-service communication

Check VM status:
```bash
vagrant status
```
---

## Application Access

Once provisioning completes, access the application via browser:

http://web01

---

## Verification & Validation

A complete verification guide is available in:

[VERIFY.md](VERIFY.md)

It covers:
- Service health checks
- Port validation
- Inter-service connectivity
- End-to-end application testing
- Failure simulation

---

## Known Issues & Lessons Learned

Known issues and troubleshooting notes are documented in:

[KNOWN_ISSUES.md](KNOWN_ISSUES.md)

---

## Key Characteristics

- Multi-VM environment
- Mixed Linux distributions (Ubuntu + CentOS Stream)
- Infrastructure provisioned via shell scripts
- Reverse proxy + app server pattern
- Stateful vs stateless separation
- Local environment simulating production topology

---

## Project Intent

- Designing and provisioning a realistic multi-tier architecture
- Integrating heterogeneous services across multiple hosts
- Debugging service startup, networking, and dependency issues
- Applying operational discipline through verification and documentation

---

## DevOps Practices Demonstrated

- Automated infrastructure provisioning
- Idempotent shell scripts
- systemd-managed services
- Multi-tier service integration
- Troubleshooting distributed systems
- Clear operational documentation

---

## Cleanup

To destroy all virtual machines and free resources:
```bash
vagrant destroy -f
```
---

## Author

Marcelo M. Boldo  
DevOps / Cloud Engineering Portfolio Project
