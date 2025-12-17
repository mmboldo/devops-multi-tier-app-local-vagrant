SHELL := /bin/bash

.PHONY: help up provision status ssh test halt destroy clean rebuild

help:
	@echo "Targets:"
	@echo "  make up         - Start VMs (vagrant up)"
	@echo "  make provision  - Re-run provisioning (vagrant provision)"
	@echo "  make status     - Show VM status"
	@echo "  make ssh VM=... - SSH into a VM (ex: make ssh VM=web01)"
	@echo "  make test       - Run smoke tests from host (scripts/verify.sh)"
	@echo "  make halt       - Stop VMs (vagrant halt)"
	@echo "  make destroy    - Destroy VMs (vagrant destroy -f)"
	@echo "  make rebuild    - Destroy then bring up fresh"

up:
	vagrant up

provision:
	vagrant provision

status:
	vagrant status

ssh:
	@if [ -z "$$VM" ]; then echo "Usage: make ssh VM=web01"; exit 1; fi
	vagrant ssh "$$VM"

test:
	bash scripts/verify.sh

halt:
	vagrant halt

destroy:
	vagrant destroy -f

clean: destroy
	@echo "Cleaned."

rebuild:
	vagrant destroy -f
	vagrant up

