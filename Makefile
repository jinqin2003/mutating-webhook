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
	docker build -t harbor-proxy-webhook:latest .

.PHONY: docker-push
docker-push:
	@echo "\n📦 Pushing harbor-proxy-webhook Docker image to docker.io ..."
	docker tag harbor-proxy-webhook docker.io/jinqin2003/harbor-proxy-webhook:latest
	docker push docker.io/jinqin2003/harbor-proxy-webhook:latest

.PHONY: docker-build-push
docker-build-push: docker-build docker-push

.PHONY: deploy
deploy:
    @echo "\n🚀 Deploying harbor-proxy-webhook..."
	helm install harbor-proxy-webhook ./chart