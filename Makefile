#!/usr/bin/make -f

VERSION := $(shell echo $(shell git describe --tags) | sed 's/^v//')
COMMIT := $(shell git log -1 --format='%H')
LEDGER_ENABLED ?= true
CUDA_ENABLED ?= true

export GO111MODULE = on

# process build tags

build_tags = netgo
ifeq ($(LEDGER_ENABLED),true)
  ifeq ($(OS),Windows_NT)
    GCCEXE = $(shell where gcc.exe 2> NUL)
    ifeq ($(GCCEXE),)
      $(error gcc.exe not installed for ledger support, please install or set LEDGER_ENABLED=false)
    else
      build_tags += ledger
    endif
  else
    UNAME_S = $(shell uname -s)
    ifeq ($(UNAME_S),OpenBSD)
      $(warning OpenBSD detected, disabling ledger support (https://github.com/cosmos/cosmos-sdk/issues/1988))
    else
      GCC = $(shell command -v gcc 2> /dev/null)
      ifeq ($(GCC),)
        $(error gcc not installed for ledger support, please install or set LEDGER_ENABLED=false)
      else
        build_tags += ledger
      endif
    endif
  endif
endif

ifeq ($(CUDA_ENABLED),true)
    NVCC_RESULT := $(shell which nvcc 2> NULL)
    NVCC_TEST := $(notdir $(NVCC_RESULT))
    ifeq ($(NVCC_TEST),nvcc)
        build_tags += cuda
    else
        $(error CUDA not installed for GPU support, please install or set CUDA_ENABLED=false)
    endif
endif

ifeq ($(WITH_CLEVELDB),yes)
  build_tags += gcc
endif
build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

whitespace :=
whitespace += $(whitespace)
comma := ,
build_tags_comma_sep := $(subst $(whitespace),$(comma),$(build_tags))

# process linker flags

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=cyber \
		  -X github.com/cosmos/cosmos-sdk/version.ServerName=cyberd \
		  -X github.com/cosmos/cosmos-sdk/version.ClientName=cyberdcli \
		  -X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
		  -X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)"

ifeq ($(WITH_CLEVELDB),yes)
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=cleveldb
endif
ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

BUILD_FLAGS := -tags "$(build_tags)" -ldflags '$(ldflags)'


all: install

build: go.sum
ifeq ($(OS),Windows_NT)
	go build $(BUILD_FLAGS) -o build/cyberd.exe ./cmd/cyberd
	go build $(BUILD_FLAGS) -o build/cyberdcli.exe ./cmd/cyberdcli
else
	go build $(BUILD_FLAGS) -o build/cyberd ./cmd/cyberd
	go build $(BUILD_FLAGS) -o build/cyberdcli ./cmd/cyberdcli
endif

build-linux: go.sum
	LEDGER_ENABLED=false GOOS=linux GOARCH=amd64 $(MAKE) build

install: go.sum
	go install $(BUILD_FLAGS) ./cmd/cyberd
	go install $(BUILD_FLAGS) ./cmd/cyberdcli

########################################
### Tools & dependencies

go.sum: go.mod
	@echo "--> Ensuring dependencies have not been modified"
	@go mod verify

clean:
	rm -rf build/

.PHONY: all build-linux install clean build test-all