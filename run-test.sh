export SOURCE_REGISTRY_LIST="docker.cogitocorp.us,quay.io,k8s.gcr.io"
export TARGET_REGISTRY="docker.io"
export ADDITIONAL_SECRET="myNewSecret"
go test ./...
