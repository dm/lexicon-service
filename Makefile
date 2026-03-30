IMAGE := ghcr.io/dm/lexicon-service
VERSION := latest

.PHONY: build push login

build:
	docker build -t $(IMAGE):$(VERSION) .

push: build
	docker push $(IMAGE):$(VERSION)

login:
	echo "$$GHCR_TOKEN" | docker login ghcr.io -u dm --password-stdin
