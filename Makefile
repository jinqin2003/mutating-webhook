github_user = jinqin2003
namespace = mutating

.PHONY: test
test:
	@echo "\n🛠️  Running unit tests..."
	go test ./...

.PHONY: test-chart
test-chart:
	@echo "\n🛠️  Dry running helm chart..."
	helm --namespace $(namespace) install mutating-webhook ./chart --dry-run

.PHONY: build
build:
	@echo "\n🔧  Building Go binaries..."
	GOOS=darwin GOARCH=amd64 go build -o bin/admission-webhook-darwin-amd64 .
	GOOS=linux GOARCH=amd64 go build -o bin/admission-webhook-linux-amd64 .

.PHONY: install-cert-manager
install-cert-manager:
	@echo "\n📦 Installing cert-manager..."
	helm repo add jetstack https://charts.jetstack.io
	helm repo update
	helm install \
		cert-manager jetstack/cert-manager \
		--namespace cert-manager \
		--create-namespace \
		--version v1.8.0 \
		--set installCRDs=true

.PHONY: uninstall-cert-manager
uninstall-cert-manager:
	@echo "\n📦 Uninstalling cert-manager..."
	helm --namespace cert-manager delete cert-manager

.PHONY: install-prometheus
install-prometheus:
	@echo "\n📦 Installing prometheus..."
	kubectl create namespace telemetry
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm install prometheus prometheus-community/prometheus --namespace telemetry

.PHONY: uninstall-prometheus
uninstall-prometheus:
	@echo "\n📦 Uninstalling prometheus..."
	helm uninstall prometheus --namespace telemetry

.PHONY: portforward-prometheus
portforward-prometheus:
	@echo "\n📦 Port forwarding prometheus..."
	@export POD_NAME=$(kubectl get pods --namespace telemetry -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}")
	kubectl --namespace telemetry port-forward $$POD_NAME 9090

.PHONY: docker-build
docker-build:
	@echo "\n📦 Building mutating-webhook Docker image..."
	docker build -t docker.io/$(github_user)/mutating-webhook:latest .

.PHONY: docker-push
docker-push:
	@echo "\n📦 Pushing mutating-webhook Docker image to docker.io ..."
	docker push docker.io/$(github_user)/mutating-webhook:latest

.PHONY: docker-build-push
docker-build-push: docker-build docker-push

.PHONY: deploy
deploy:
	@echo "\n🔧 Deploying mutating-webhook..."
	helm --namespace $(namespace) install mutating-webhook ./chart

.PHONY: delete
delete:
	@echo "\n🔧 Deleting mutating-webhook..."
	kubectl --namespace $(namespace) delete secrets mutating-webhook-ca
	helm uninstall --namespace $(namespace) mutating-webhook

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
