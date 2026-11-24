# Installs metrics-server (the source of `kubectl top` and HPA CPU/memory metrics).
# On kind, kubelets use self-signed certificates, so metrics-server must skip verifying them.
$Version = 'v0.7.2'
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/$Version/components.yaml"
kubectl patch deployment metrics-server -n kube-system --type=json `
  -p '[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"--kubelet-insecure-tls\"}]'
kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s
Write-Host "metrics-server installed. Wait ~60s, then try: kubectl top nodes" -ForegroundColor Green
