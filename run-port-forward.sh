export POD_NAME=$(kubectl get pods --namespace telemetry -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}")
#export POD_NAME=prometheus-server-74c69b74f5-bbzbn
kubectl --namespace telemetry port-forward $POD_NAME 9090
