all: clear build

VERSION=$(shell git rev-parse --verify HEAD --short=7)
BRANCH=$(shell git rev-parse --abbrev-ref HEAD)
PACKAGES ?= $(shell go list ./... | grep -v /vendor/)
#GOPROXY ?= https://goproxy.io

ifdef GOPROXY
PROXY := GOPROXY="${GOPROXY}"
endif

.PHONY: build
build:
	GOOS=linux ${PROXY} go build -ldflags="-s -w -X 'main.Version=${VERSION}'" -v -o bin/containerd-nydus-grpc ./cmd/containerd-nydus-grpc

static-release:
	CGO_ENABLED=0 ${PROXY} GOOS=linux go build -ldflags '-s -w -X "main.Version=${VERSION}" -extldflags "-static"' -v -o bin/containerd-nydus-grpc ./cmd/containerd-nydus-grpc

.PHONY: clear
clear:
	rm -f bin/*
	rm -rf _out


.PHONY: install
install: static-release
	sudo install -D -m 755 bin/containerd-nydus-grpc /usr/local/bin/containerd-nydus-grpc
	sudo install -D -m 755 misc/snapshotter/nydusd-config.json /etc/nydus/config.json
	sudo install -D -m 644 misc/snapshotter/nydus-snapshotter.service /etc/systemd/system/nydus-snapshotter.service
	sudo systemctl enable /etc/systemd/system/nydus-snapshotter.service

.PHONY: vet
vet:
	go vet $(PACKAGES)

.PHONY: check
check: vet
	golangci-lint run

.PHONY: test
test:
	go test -race -v -mod=mod -cover ${PACKAGES}

.PHONY: cover
cover:
	go test -v -covermode=atomic -coverprofile=coverage.txt ./...
	go tool cover -func=coverage.txt
