export CLUSTER_NODE_TUNING_OPERATOR_TARGET_COMMIT?=main
IMAGE_BUILD_CMD ?= "podman"

PROJECT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

RHEL9_RELEASE ?= $(shell awk '/^FROM registry.access.redhat.com\/ubi9\/ubi-minimal:/ {split($$2, parts, /[:|@]/); print parts[2]}' $(PROJECT_DIR)/Dockerfile)
RHEL9_RELEASE_DASHED := $(subst .,-,$(RHEL9_RELEASE))

RHEL9_ACTIVATION_KEY ?= ""
RHEL9_ORG_ID ?= ""

REGISTRY_AUTH_FILE ?= $(shell echo $${XDG_RUNTIME_DIR:-/run/user/$$(id -u)})/containers/auth.json

TARGET_GOOS=linux
TARGET_GOARCH=amd64

export GO111MODULE=on

.PHONY: test-bin \
	init-git-submodules \
	image

deps-update:
	go mod tidy && \
	go mod vendor

test-bin:
	@echo "Making test binary"
	git submodule update --init --force
	hack/build-test-bin.sh

init-git-submodules:
	@echo "Initializing git submodules"
	git submodule update --init --force
	hack/init-git-submodules.sh

image:
	@echo "Building cnf-tests image"
	$(IMAGE_BUILD_CMD) build --no-cache -f Dockerfile -t cnf-tests-local .

.PHONY: konflux-update-rpm-lock-runtime
konflux-update-rpm-lock-runtime: ## Update the rpm lock file for the runtime
	@echo "Updating rpm lock file for the runtime..."
	@echo "Creating lock-runtime directory..."
	mkdir -p $(PROJECT_DIR)/lock-runtime
	@echo "Copying Dockerfile to lock-runtime directory for rpm-lockfile-prototype..."
	cp $(PROJECT_DIR)/Dockerfile $(PROJECT_DIR)/lock-runtime/Dockerfile
	@echo "Copying rpms.in.yaml to lock-runtime directory..."
	cp $(PROJECT_DIR)/rpms.in.yaml $(PROJECT_DIR)/lock-runtime/rpms.in.yaml
	sed -i 's|sslclientkey: $$SSL_CLIENT_KEY|sslclientkey: /etc/pki/entitlement/placeholder-key.pem|g' $(PROJECT_DIR)/lock-runtime/rpms.in.yaml
	sed -i 's|sslclientcert: $$SSL_CLIENT_CERT|sslclientcert: /etc/pki/entitlement/placeholder.pem|g' $(PROJECT_DIR)/lock-runtime/rpms.in.yaml
	@cat $(PROJECT_DIR)/lock-runtime/rpms.in.yaml
	@echo "Update rpms.lock.yaml with new contents..."
	cp $(PROJECT_DIR)/lock-runtime/rpms.lock.yaml $(PROJECT_DIR)/rpms.lock.yaml
	@echo "RPM lock file updated successfully."

.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$$@$$'

.PHONY: pao-functests-latency-testing
pao-functests-latency-testing: init-git-submodules
	$(MAKE) -C submodules/cluster-node-tuning-operator pao-functests-latency-testing