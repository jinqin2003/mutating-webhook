docker_hub_user = jinqin2003
namespace = mutating

.PHONY: test
test:
	@echo "\n🛠️  Running unit tests..."
	@. ./run-test.sh

.PHONY: install-minikube
install-minikube:
	@echo "\n📦 Installing minikube on mac os..."
	@brew install minikube
	@minikube start --driver=krunkit

.PHONY: start-cluster
start-cluster:
	@echo "\n📦 Starting cluster..."
	@minikube start --driver=krunkit

.PHONY: stop-cluster
stop-cluster:
	@echo "\n📦 Stopping cluster..."
	@minikube stop

.PHONY: delete-cluster
delete-cluster:
	@echo "\n📦 Deleting cluster..."
	@minikube delete --all

.PHONY: install-cert-manager
install-cert-manager:
	@echo "\n📦 Installing cert-manager..."
	helm repo add jetstack https://charts.jetstack.io
	helm repo update
	helm install \
		cert-manager jetstack/cert-manager \
		--namespace cert-manager \
		--create-namespace \
		--version v1.21.1 \
		--set installCRDs=true

.PHONY: uninstall-cert-manager
uninstall-cert-manager:
	@echo "\n📦 Uninstalling cert-manager..."
	helm --namespace cert-manager delete cert-manager
	kubectl delete namespace cert-manager

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
	kubectl delete namespace telemetry

.PHONY: install-keda
install-keda:
	@echo "\n📦 Installing keda..."
	helm repo add kedacore https://kedacore.github.io/charts
	helm repo update
	kubectl create namespace keda
	helm install keda kedacore/keda --namespace keda

.PHONY: uninstall-keda
uninstall-keda:
	@echo "\n📦 Uninstalling keda..."
	helm uninstall keda --namespace keda
	kubectl delete namespace keda

.PHONY: test-chart
test-chart:
	@echo "\n🛠️  Dry running helm chart..."
	helm --namespace $(namespace) install mutating-webhook ./chart --dry-run

.PHONY: build
build:
	@echo "\n🔧  Building Go binaries..."
	GOOS=linux GOARCH=arm64 go build -o bin/admission-webhook-linux-arm64 .
	GOOS=linux GOARCH=amd64 go build -o bin/admission-webhook-linux-amd64 .

.PHONY: portforward-prometheus
portforward-prometheus:
	@echo "\n📦 Port forwarding prometheus..."
	@. ./run-port-forward.sh

.PHONY: docker-build
docker-build:
	@echo "\n📦 Building mutating-webhook Docker image..."
	docker build -t docker.io/$(docker_hub_user)/mutating-webhook:latest .

.PHONY: docker-push
docker-push:
	@echo "\n📦 Pushing mutating-webhook Docker image to docker.io ..."
	docker login -u jinqin2003 -p $(credentials)
	docker push docker.io/$(docker_hub_user)/mutating-webhook:latest

.PHONY: docker-build-push
docker-build-push: docker-build docker-push

.PHONY: deploy
deploy:
	@echo "\n🔧 Deploying mutating-webhook..."
	kubectl create namespace mutating
	helm --namespace $(namespace) install mutating-webhook ./chart

.PHONY: delete
delete:
	@echo "\n🔧 Deleting mutating-webhook..."
	kubectl --namespace $(namespace) delete secrets mutating-webhook-ca
	helm uninstall --namespace $(namespace) mutating-webhook
	kubectl delete namespace mutating

.PHONY: pod
pod:
	@echo "\n🚀 Deploying test pod..."
	kubectl apply -f pod/apps.ns.yaml
	kubectl apply -f pod/test.pod1.yaml
	kubectl apply -f pod/test.pod2.yaml
	kubectl apply -f pod/test.pod3.yaml

.PHONY: delete-pod
delete-pod:
	@echo "\n♻️ Deleting test pod..."
	kubectl delete -f pod/test.pod1.yaml
	kubectl delete -f pod/test.pod2.yaml
	kubectl delete -f pod/test.pod3.yaml
	kubectl delete -f pod/apps.ns.yaml
