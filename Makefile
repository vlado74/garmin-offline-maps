# Raster running map for Garmin Forerunner 265S.
SHELL := /bin/bash

DEVICE      ?= fr265s
BREW_PREFIX := $(shell brew --prefix 2>/dev/null)
CASK_SDK    := $(lastword $(sort $(wildcard $(BREW_PREFIX)/Caskroom/connectiq/*/connectiq-sdk-mac-*/bin)))
SDK_BIN     ?= $(CASK_SDK)
MONKEYC     := $(if $(SDK_BIN),$(SDK_BIN)/monkeyc,monkeyc)

KEY         ?= developer_key
BIN         := bin
PRG         := $(BIN)/offline-maps.prg
IQ          := $(BIN)/offline-maps.iq
PYTHON      ?= python3
PACK_DIR    := tools/mappack

RASTER_BBOX      ?=
RASTER_ZOOMS     ?= 13,15
RASTER_NAME      ?= EUR 5 km
RASTER_FONT      ?= /System/Library/Fonts/Supplemental/Arial.ttf
RASTER_BOLD_FONT ?= /System/Library/Fonts/Supplemental/Arial Bold.ttf
RASTER_CACHE     ?= $(PACK_DIR)/eur.osm.cache
PACK             ?= mapdata/raster-demo
ZOOM             ?= 15
OUTPUT           ?= preview-raster.png

.PHONY: help doctor key raster-pack raster-demo raster-preview build watch package test lint regression clean

help:
	@echo "Targets:"
	@echo "  make raster-pack     build the private EUR map"
	@echo "  make raster-demo     rebuild the committed synthetic map"
	@echo "  make raster-preview  compose a 360 px preview (PACK=... ZOOM=13|15)"
	@echo "  make build           compile the Forerunner 265S PRG"
	@echo "  make watch           side-load the PRG onto a connected watch"
	@echo "  make package         build the Connect IQ bundle"
	@echo "  make regression      run tests, generation checks and builds"

doctor:
	@printf '  %-18s' "compiler"; \
		if [ -x "$(MONKEYC)" ] || command -v "$(MONKEYC)" >/dev/null 2>&1; then \
			"$(MONKEYC)" --version 2>&1 | head -1; else echo "MISSING"; fi
	@printf '  %-18s' "signing key"; \
		if [ -f "$(KEY)" ]; then echo "present"; else echo "MISSING: make key"; fi
	@printf '  %-18s' "Pillow"; \
		if $(PYTHON) -c "import PIL" 2>/dev/null; then echo "present"; else echo "MISSING"; fi

$(KEY):
	openssl genrsa -out $(KEY).pem 4096
	openssl pkcs8 -topk8 -inform PEM -outform DER -in $(KEY).pem -out $(KEY) -nocrypt
	@rm -f $(KEY).pem

key: $(KEY)

raster-pack:
ifeq ($(strip $(RASTER_BBOX)),)
	$(error set RASTER_BBOX=west,south,east,north)
endif
	cd $(PACK_DIR) && $(PYTHON) -m mappack.raster_cli \
		--bbox "$(RASTER_BBOX)" --zooms "$(RASTER_ZOOMS)" \
		--font "$(RASTER_FONT)" --bold-font "$(RASTER_BOLD_FONT)" \
		--cache "$(abspath $(RASTER_CACHE))" --name "$(RASTER_NAME)" \
		--out "$(CURDIR)/mapdata/raster" \
		--index "$(CURDIR)/source/generated/RasterMapIndex.mc"

raster-demo:
	cd $(PACK_DIR) && $(PYTHON) -m mappack.raster_cli \
		--input tests/demo-city.osm \
		--bbox "13.3267,52.495,13.3997,52.5317988" --zooms "13,15" \
		--pillow-default-font --name "Synthetic Raster Demo" \
		--out "$(CURDIR)/mapdata/raster-demo" \
		--index "$(CURDIR)/source/generated/RasterMapIndex.mc"

raster-preview:
	cd $(PACK_DIR) && $(PYTHON) -m mappack.raster_preview \
		--pack "$(abspath $(PACK))" --zoom "$(ZOOM)" --out "$(abspath $(OUTPUT))"

build: $(KEY)
	@mkdir -p $(BIN)
	$(MONKEYC) -f monkey.jungle -o $(PRG) -y $(KEY) -d $(DEVICE) -w
	@ls -lh $(PRG)

watch: build
	@tools/push-watch.sh $(DEVICE)

package: $(KEY)
	@mkdir -p $(BIN)
	$(MONKEYC) -e -f monkey.jungle -o $(IQ) -y $(KEY) -w -r
	@ls -lh $(IQ)

test:
	cd $(PACK_DIR) && $(PYTHON) -m unittest discover -s tests -t . -v

lint:
	cd $(PACK_DIR) && $(PYTHON) -m compileall -q mappack tests

regression:
	@tools/regression.sh

clean:
	@$(PYTHON) -c "import shutil; shutil.rmtree('$(BIN)', ignore_errors=True)"
