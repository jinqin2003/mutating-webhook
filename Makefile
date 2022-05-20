.PHONY: test
test:
	@echo "\n🛠️  Running unit tests..."
	go test ./...

.PHONY: build
build:
	@echo "\n🔧  Building Go binaries..."
	GOOS=darwin GOARCH=amd64 go build -o bin/admission-webhook-darwin-amd64 .
	GOOS=linux GOARCH=amd64 go build -o bin/admission-webhook-linux-amd64 .

.PHONY: docker-build
docker-build:
	@echo "\n📦 Building harbor-proxy-webhook Docker image..."
	docker build -t ctrl.ctrl-green.us-east-1.harbor.cogitocorp.io/docker-snapshot/harbor-proxy-webhook:latest .

.PHONY: docker-push
docker-push:
	@echo "\n📦 Pushing harbor-proxy-webhook Docker image to ctrl.ctrl-green.us-east-1.harbor.cogitocorp.io ..."
	docker push ctrl.ctrl-green.us-east-1.harbor.cogitocorp.io/docker-snapshot/harbor-proxy-webhook:latest

.PHONY: docker-build-push
docker-build-push: docker-build docker-push