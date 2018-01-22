SHELL:=/bin/bash

ANSIBLE:=$(shell command -v ansible 2> /dev/null)
DOCKER_IMAGE?=vgallissot/fedora-ansible:latest
ROLES_PATH="./roles/"
REPO_PATH ?= "$(shell basename $(CURDIR))"
PLAY_PATH ?= "./playbooks"
OPTS=

yml_files:=$(shell find . -name "*.yml")
json_files:=$(shell find . -name "*.json")
jinja_files:=$(shell find . -name "*.j2")
ansible_files:=$(shell find $(PLAY_PATH) -name "*.yml")

.PHONY: all header help all-playbooks run run-docker docker requirements debug

all: header help

header:
	$(info ---)
	$(info - Build Information)
	$(info - Directory: $(CURDIR))
ifdef ANSIBLE
	$(info - Ansible Version: $(shell ansible --version | head -1 || true))
	$(info - Ansible Playbook Version: $(shell ansible-playbook --version | head -1))
else
	$(info - Ansible *NOT DETECTED*)
endif
	$(info - Operating System: $(shell if [ -a /etc/issue ] ; then cat /etc/issue ; fi ; ))
	$(info - Kernel: $(shell uname -prsmn))
	$(info - DOCKER_IMAGE => $(DOCKER_IMAGE))
	$(info - REPO_PATH => $(REPO_PATH))
	$(info - PLAY_PATH => $(PLAY_PATH))
	$(info ---)

help:

	@echo ''
	@echo 'Usage:'
	@echo '    make run			apply all playbooks and run all tests'
	@echo '    make run-docker		run "make run" in a docker container'
	@echo '    make docker			launch a docker container'
	@echo '    make all-playbooks		apply all playbooks'
	@echo '    make checkdiff		apply all playbooks with --check --diff options (READONLY)'
	@echo '    make requirements		install python and ansible-galaxy requirements'
	@echo ''
	@echo ''
	@echo '    Syntax tests:'
	@echo '        test.syntax		Run all syntax tests'
	@echo '        test.syntax.json		Run syntax tests on .json files'
	@echo '        test.syntax.yml		Run syntax tests on .yml files'
	@echo '        test.syntax.lint		Run lint tests on ansible files'
	@echo '        test.syntax.ansible	Run syntax tests on ansible files'
	@echo ''
	@echo '    test.idempotency		Run idempotency tests'
	@echo ''

## ReadOnly Tests
test.syntax: test.header test.syntax.yml test.syntax.json test.syntax.lint test.syntax.ansible

test.header:
	@echo '==='
	@echo '=== Running syntax tests'
	@echo ''

test.syntax.yml: $(patsubst %,test.syntax.yml/%,$(yml_files))

test.syntax.yml/%:
	python -c "import sys,yaml; yaml.load(open(sys.argv[1]))" $* >/dev/null

test.syntax.json: $(patsubst %,test.syntax.json/%,$(json_files))

test.syntax.json/%:
	jsonlint -v $*

test.syntax.lint: $(patsubst %,test.syntax.lint/%,$(ansible_files))
test.syntax.lint/%:
ifdef LINT_SKIP_LIST
	ansible-lint $* -x $(LINT_SKIP_LIST) --exclude $(ROLES_PATH)
else
	ansible-lint $* --exclude $(ROLES_PATH)
endif

test.syntax.ansible: $(patsubst %,test.syntax.ansible/%,$(ansible_files))
test.syntax.ansible/%:
	ansible-playbook -i inventory $* --syntax-check

## ReadWrite Tests
run: header requirements test.syntax all-playbooks checkdiff test.idempotency

test.idempotency:
ifndef SKIP_IDEMPOTENCY
	@echo ''
	@echo '=== Running idempotency tests'
	@echo ''
	$(MAKE) all-playbooks | tee /tmp/output.txt ; \
	grep -q 'changed=0.*failed=0' /tmp/output.txt && \
	(echo 'Idempotence test: pass' && exit 0) || (echo 'Idempotence test: fail' && exit 1)
else
	@echo ''
	@echo '=== Skipping idempotency tests'
	@echo ''
endif

checkdiff:
ifndef SKIP_CHECKDIFF
	@echo ''
	@echo '=== Running --check --diff all-playbooks'
	@echo ''
	$(MAKE) all-playbooks OPTS='--check --diff'
else
	@echo ''
	@echo '=== Skipping --check --diff all-playbooks'
	@echo ''
endif

all-playbooks:
	@echo ''
	@echo "=== Apply all playbooks"
	@echo ''
	for play in $(shell ls $(PLAY_PATH)/*.yml); do \
	    ansible-playbook -i inventory --connection=local $$play $(OPTS); \
	done


## Actions
run-docker:
	docker run -i --rm --name $(REPO_PATH) -h $(REPO_PATH) -v $(CURDIR):/ansible/$(REPO_PATH) $(DOCKER_IMAGE) /bin/bash -c "cd /ansible/$(REPO_PATH) && make run"

docker:
	docker run -ti --rm --name $(REPO_PATH) -h $(REPO_PATH) -v $(CURDIR):/ansible/$(REPO_PATH) $(DOCKER_IMAGE) /bin/bash


requirements:
	@echo ''
	@echo '=== Installing Python requirements'
	if [ -a python-requirements.txt ]; then pip install -qr python-requirements.txt --exists-action w; fi;
	@echo '=== Installing Ansible requirements'
	if [ -a ansible-galaxy.yml ]; then ansible-galaxy install -r ansible-galaxy.yml --force --ignore-errors; fi;

