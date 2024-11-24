SHELL := bash# we want bash behaviour in all shell invocations

# https://stackoverflow.com/questions/4842424/list-of-ansi-color-escape-sequences
RED := \033[1;31m
GREEN := \033[1;32m
YELLOW := \033[1;33m
BOLD := \033[1m
NORMAL := \033[0m

SILENT := 1>/dev/null 2>&1



### VARS ###
#
GCP_USER := gerhard@lazu.co.uk
GCP_ACCOUNT := 0
GCP_PROJECT := gerhard
# https://cloud.google.com/compute/docs/regions-zones/
GCP_REGION := europe-west2
GCP_ZONE := $(GCP_REGION)-a

WEB_DOMAIN := gerhard.io
WEB_GCP_REGION := eu

GCR_HOST := eu.gcr.io

HUGO_THEME := site/themes/academic/layouts

LOCAL_BIN := $(CURDIR)/bin
PATH := $(LOCAL_BIN):$(PATH)
export PATH

# https://github.com/GoogleCloudPlatform/gsutil/issues/961#issuecomment-663565856
CLOUDSDK_PYTHON := $(shell which python3.11)
export CLOUDSDK_PYTHON

INSTALL_PATH := $(shell brew --prefix)



### DEPS ###
#
CURL ?= /usr/bin/curl

GCLOUD := $(INSTALL_PATH)/bin/gcloud
GSUTIL := $(INSTALL_PATH)/bin/gsutil
$(GCLOUD) $(GSUTIL):
	brew install google-cloud-sdk

JQ := $(INSTALL_PATH)/bin/jq
$(JQ):
	brew install jq

GCLOUD_CONFIG := $(HOME)/.config/gcloud/configurations/config_$(GCP_PROJECT)
$(GCLOUD_CONFIG): $(GCLOUD)
	($(GCLOUD) config configurations describe $(GCP_PROJECT) || $(GCLOUD) config configurations create $(GCP_PROJECT) --no-activate) && \
	$(GCLOUD) config configurations activate $(GCP_PROJECT) && \
	$(GCLOUD) config set account $(GCP_ACCOUNT) && \
	$(GCLOUD) config set project $(GCP_PROJECT) && \
	$(GCLOUD) config set compute/region $(GCP_REGION) && \
	$(GCLOUD) config set compute/zone $(GCP_ZONE)

# https://github.com/gohugoio/hugo/releases
# In Hugo v0.60.0 Markdown rendering library changed from Blackfriday to Goldmark.
# This broke all slides formatting: every single slide appears on the same page, one on top of the other 🤦
#
# Pinning Hugo to v0.59.1 until I make time to update Academic theme (latest stable is v4.7.0, currently using v4.0.0),
# and keep it in lock-step with Hugo version, as well as address the slides formatting issue.
HUGO_VERSION := 0.59.1
HUGO_BIN_DIR := hugo_extended_$(HUGO_VERSION)_macOS-64bit
HUGO_URL := https://github.com/gohugoio/hugo/releases/download/v$(HUGO_VERSION)/$(HUGO_BIN_DIR).tar.gz
HUGO := $(LOCAL_BIN)/$(HUGO_BIN_DIR)/hugo
$(HUGO):
	mkdir -p $(LOCAL_BIN) \
	&& cd $(LOCAL_BIN) \
	&& $(CURL) --progress-bar --fail --location --output $(HUGO_BIN_DIR).tar.gz "$(HUGO_URL)" \
	&& mkdir -p $(HUGO_BIN_DIR) \
	&& tar zxf $(HUGO_BIN_DIR).tar.gz -C $(HUGO_BIN_DIR) \
	&& touch $(HUGO) \
	&& chmod +x $(HUGO) \
	&& $(HUGO) version \
	   | grep $(HUGO_VERSION) \
	&& ln -sf $(HUGO) $(LOCAL_BIN)/hugo
.PHONY: hugo
hugo: $(HUGO)

DOCKER := $(INSTALL_PATH)/bin/docker
$(DOCKER):
	brew install docker

FFMPEG := $(INSTALL_PATH)/bin/ffmpeg
$(FFMPEG):
	brew install ffmpeg

OP := $(INSTALL_PATH)/bin/op
$(OP):
	brew install 1password-cli



### TARGETS ###
#
.DEFAULT_GOAL := help

.PHONY: help
help:
	@awk -F"[:#]" '/^[^\.][a-zA-Z\._\-]+:+.+##.+$$/ { printf "\033[36m%-24s\033[0m %s\n", $$1, $$4 }' $(MAKEFILE_LIST) \
	| sort

define MAKE_TARGETS
  awk -F: '/^[^\.%\t][a-zA-Z\._\-]*:+.*$$/ { printf "%s\n", $$1 }' $(MAKEFILE_LIST)
endef
define BASH_AUTOCOMPLETE
  complete -W \"$$($(MAKE_TARGETS) | sort | uniq)\" make gmake m
endef
.PHONY: bash_autocomplete
bash_autocomplete: ## ba | Configure bash autocompletion - eval "$(make bash_autocomplete)"
	@echo "$(BASH_AUTOCOMPLETE)"
.PHONY: bac
bac: bash_autocomplete

.PHONY: build
build: $(HUGO_THEME) $(HUGO) clean
	cd site \
	&& $(HUGO) --buildFuture
.PHONY: b
b: build

.PHONY: clean
clean: ## c  | Clean cached content
	rm -fr site/resources/_gen site/public \
	&& find $(CURDIR) -name .DS_Store -exec rm {} \;
.PHONY: c
c: clean

.PHONY: gcloud_login
gcloud_login: $(GCLOUD_CONFIG) $(JQ) $(GSUTIL)
	( $(GCLOUD) auth list --format=json | \
	   $(JQ) '.[] | select(.status == "ACTIVE")' | \
	   grep --silent "$(GCP_USER)" ) || \
	$(GCLOUD) auth login $(GCP_USER)

.PHONY: gcloud_config
gcloud_config: gcloud_login
	($(GSUTIL) ls -L -b gs://$(WEB_DOMAIN) $(SILENT) \
	  || $(GSUTIL) mb -l $(WEB_GCP_REGION) gs://$(WEB_DOMAIN)) \
	&& $(GSUTIL) iam ch allUsers:objectViewer gs://$(WEB_DOMAIN) \
	&& $(GSUTIL) web set -m index.html -e 404.html gs://$(WEB_DOMAIN)
.PHONY: gc
gc: gcloud_config

.PHONY: gcloud
gcloud: gcloud_config build
	cd site \
	&& $(GSUTIL) -o "GSUtil:parallel_process_count=1" -m rsync -d -r public gs://$(WEB_DOMAIN)
.PHONY: g
g: gcloud

.PHONY: $(HUGO_THEME)
$(HUGO_THEME):
	git submodule update --init --recursive

.PHONY: preview
preview: $(HUGO_THEME) $(HUGO) ## p  | Preview local website
	cd site \
	&& $(HUGO) server --buildExpired --buildDrafts --buildFuture --bind 0.0.0.0
.PHONY: p
p: preview

.PHONY: readme
readme: $(DOCKER) ## r  | Preview README
	$(DOCKER) run --interactive --tty --rm --name gerhard_md \
	  --volume $(CURDIR):/data \
	  --volume $(HOME)/.grip:/.grip \
	  --expose 5000 --publish 5000:5000 \
	  mbentley/grip --context=. 0.0.0.0:5000
.PHONY: r
r: readme

.PHONY: update
update: gcloud ## u  | Update public website
.PHONY: u
u: update

# https://trac.ffmpeg.org/wiki/Encode/H.264#iOS
# https://trac.ffmpeg.org/wiki/Scaling
SCALE = 'min(1920,iw)':'min(1080,ih)'
.PHONY: video
video: $(FFMPEG) ## v  | Convert MOVs to mobile-friendly MP4s
ifndef F
	$(error F variable must reference a valid mov file path)
endif
	$(FFMPEG) -i $(F) \
	  -vcodec h264 \
	  -vf "scale=$(SCALE)" \
	  -profile:v high -level 4.2 \
	  $(subst .mov,.mp4,$(F))
.PHONY: v
v: video
