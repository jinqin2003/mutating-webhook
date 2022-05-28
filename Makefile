.PHONY: test
test:
	@echo "\n🛠️  Running unit tests..."
	go test ./...

.PHONY: test-chart
test-chart:
	@echo "\n🛠️  Dry running helm chart..."
	helm --namespace harbor install mutating-webhook ./chart --dry-run

.PHONY: build
build:
	@echo "\n🔧  Building Go binaries..."
	GOOS=darwin GOARCH=amd64 go build -o bin/admission-webhook-darwin-amd64 .
	GOOS=linux GOARCH=amd64 go build -o bin/admission-webhook-linux-amd64 .

.PHONY: docker-build
docker-build:
	@echo "\n📦 Building mutating-webhook Docker image..."
	docker build -t docker.io/jinqin2003/mutating-webhook:latest .

.PHONY: docker-push
docker-push:
	@echo "\n📦 Pushing mutating-webhook Docker image to docker.io ..."
	docker push docker.io/jinqin2003/mutating-webhook:latest

.PHONY: docker-build-push
docker-build-push: docker-build docker-push

.PHONY: deploy
deploy:
	@echo "\n🔧 Deploying mutating-webhook..."
	helm --namespace harbor install mutating-webhook ./chart

.PHONY: delete
delete:
	@echo "\n🔧 Deleting mutating-webhook..."
	kubectl --namespace harbor delete secrets mutating-webhook-ca
	helm uninstall --namespace harbor mutating-webhook

.PHONY: pod
pod:
	@echo "\n🚀 Deploying test pod..."
	kubectl apply -f pod/apps.ns.yaml
	kubectl apply -f pod/test.pod.yaml

.PHONY: delete-pod
delete-pod:
	@echo "\n♻️ Deleting test pod..."
	kubectl delete -f pod/test.pod.yaml
	kubectl delete -f pod/apps.ns.yaml