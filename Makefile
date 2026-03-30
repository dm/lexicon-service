IMAGE := ghcr.io/dm/lexicon-service
VERSION := latest
PLATFORMS := linux/amd64,linux/arm64

.PHONY: build push login

build:
	docker buildx build --platform $(PLATFORMS) -t $(IMAGE):$(VERSION) .

push:
	docker buildx build --platform $(PLATFORMS) -t $(IMAGE):$(VERSION) --push .

login:
	echo "$$GHCR_TOKEN" | docker login ghcr.io -u dm --password-stdin
