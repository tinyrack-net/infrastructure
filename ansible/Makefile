.PHONY: ping syntax lint preflight check cni-migrate cni-rollback apply verify vault-edit

ANSIBLE ?= ansible
ANSIBLE_PLAYBOOK ?= ansible-playbook
ANSIBLE_VAULT ?= ansible-vault
ANSIBLE_LINT ?= ansible-lint
YAMLLINT ?= yamllint
ANSIBLE_ARGS ?=
HOSTS ?= k3s_servers

PREFLIGHT_PLAYBOOK := ./playbooks/preflight.yml
SETUP_PLAYBOOK := ./playbooks/setup.yml
VERIFY_PLAYBOOK := ./playbooks/verify.yml
CNI_MIGRATE_PLAYBOOK := ./playbooks/cni-migrate.yml
CNI_ROLLBACK_PLAYBOOK := ./playbooks/cni-rollback.yml
VAULT_FILE := ./inventories/production/group_vars/all/vault.yml

ping:
	$(ANSIBLE) '$(HOSTS)' -m ansible.builtin.ping -e ansible_become=false $(ANSIBLE_ARGS)

syntax:
	$(ANSIBLE_PLAYBOOK) --syntax-check $(PREFLIGHT_PLAYBOOK)
	$(ANSIBLE_PLAYBOOK) --syntax-check $(SETUP_PLAYBOOK)
	$(ANSIBLE_PLAYBOOK) --syntax-check $(VERIFY_PLAYBOOK)
	$(ANSIBLE_PLAYBOOK) --syntax-check $(CNI_MIGRATE_PLAYBOOK)
	$(ANSIBLE_PLAYBOOK) --syntax-check $(CNI_ROLLBACK_PLAYBOOK)

lint:
	$(YAMLLINT) .
	$(ANSIBLE_LINT) --profile production ./playbooks ./roles

preflight:
	$(ANSIBLE_PLAYBOOK) $(PREFLIGHT_PLAYBOOK) $(ANSIBLE_ARGS)

check:
	$(ANSIBLE_PLAYBOOK) $(SETUP_PLAYBOOK) --check --diff $(ANSIBLE_ARGS)

cni-migrate:
	$(ANSIBLE_PLAYBOOK) $(CNI_MIGRATE_PLAYBOOK) $(ANSIBLE_ARGS)

cni-rollback:
	$(ANSIBLE_PLAYBOOK) $(CNI_ROLLBACK_PLAYBOOK) $(ANSIBLE_ARGS)

apply:
	$(ANSIBLE_PLAYBOOK) $(SETUP_PLAYBOOK) $(ANSIBLE_ARGS)

verify:
	$(ANSIBLE_PLAYBOOK) $(VERIFY_PLAYBOOK) $(ANSIBLE_ARGS)

vault-edit:
	$(ANSIBLE_VAULT) edit $(VAULT_FILE)
