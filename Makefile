# Default shell
SHELL := /bin/sh

# Global CI
LANGUAGES := go
# Global CI. Do not edit
MAKEFILE := Makefile.docs
CI_REPO_URL := https://github.com/src-d/ci.git
SHARED_PATH ?= /etc/shared
CI_PATH ?= $(SHARED_PATH)/ci

$(MAKEFILE):
	@if [ ! -r "./$(MAKEFILE)" ]; then \
		if [ ! -r "$(CI_PATH)/$(MAKEFILE)" ]; then \
			echo "Downloading 'ci'..."; \
			rm -rf "$(CI_PATH)"; \
			mkdir -p "$(CI_PATH)"; \
			git clone "$(CI_REPO_URL)" "$(CI_PATH)"; \
		fi; \
		echo "Installing 'ci'..."; \
		cp $(CI_PATH)/$(MAKEFILE) .; \
	fi; \

-include $(MAKEFILE)

# Conf vars
GITHUB_API_KEY ?=
LOGS_PATH ?= /var/log/docsrv
LANDING_PATH ?= $(SHARED_PATH)/landing
INIT_PATH ?= $(shell pwd)/../ci/docs/init.d
CONF_PATH ?= $(shell pwd)/../ci/docs/conf.d

#vars
docker_container_name = docsrv-instance
docker_image_name = docsrv-image

#tools
mkdir := mkdir -p
goBuild := CGO_ENABLED=0 go build -o
remove := rm -rf
dockerRun := docker run --detach
dockerBuild := docker build -t
dockerLogs := docker logs
dockerRemove := docker rm -f
dockerPs := docker ps
grep := grep
tail := tail -f
touch := touch

build:
	@$(mkdir) bin;
	@$(goBuild) bin/docsrv docsrv.go

develop: build drop-running-instances
	@$(dockerBuild) $(docker_image_name) .
	@$(mkdir) $(LOGS_PATH) $(SHARED_PATH)
	@$(touch) $(LOGS_PATH)/caddy.log $(LOGS_PATH)/docsrv.log
	$(dockerRun) \
		--name $(docker_container_name) \
		--publish 9090:9090 \
		--env GITHUB_API_KEY="$(GITHUB_API_KEY)" \
		--env DEBUG_LOG=true \
		--volume $(LOGS_PATH):/var/log/docsrv \
		--volume $(INIT_PATH):/etc/docsrv/init.d \
		--volume $(CONF_PATH):/etc/docsrv/conf.d \
		--volume $(SHARED_PATH):/etc/shared \
		--volume $(LANDING_PATH):/etc/shared/landing \
		--volume $(CI_PATH):/etc/shared/ci \
		$(docker_image_name);
	@$(dockerLogs) $(docker_container_name);
	@$(tail) $(LOGS_PATH)/*

drop-running-instances:
	@running=`$(dockerPs) -f name=$(docker_container_name) | $(grep) $(docker_container_name)`; \
	if [ -n "$$running" ]; then \
		echo "[INFO] Removing already existent container '$(docker_container_name)'."; \
		$(dockerRemove) $(docker_container_name); \
	fi;
	$(remove) logs/*
