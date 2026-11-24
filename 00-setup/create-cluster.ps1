# Creates the "lab" kind cluster used by every lab, with Calico as the network plugin.
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File .\00-setup\create-cluster.ps1

$CalicoVersion = 'v3.29.1'

docker info > $null 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "Docker is not running. Start Docker Desktop first." -ForegroundColor Red; exit 1 }

$existing = kind get clusters 2>$null
if ($existing -contains 'lab') {
    Write-Host "Cluster 'lab' already exists. Delete it first with .\00-setup\delete-cluster.ps1" -ForegroundColor Yellow
    exit 0
}

Write-Host "[1/3] Creating nodes..." -ForegroundColor Cyan
kind create cluster --config "$PSScriptRoot\kind-config.yaml"
if ($LASTEXITCODE -ne 0) { Write-Host "kind create failed." -ForegroundColor Red; exit 1 }

# Nodes stay NotReady until a network (CNI) plugin is installed.
Write-Host "[2/3] Installing Calico $CalicoVersion network plugin..." -ForegroundColor Cyan
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/$CalicoVersion/manifests/calico.yaml" | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "Calico install failed (internet access needed)." -ForegroundColor Red; exit 1 }
kubectl rollout status daemonset/calico-node -n kube-system --timeout=300s

Write-Host "[3/3] Waiting for all nodes to become Ready..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl rollout status deployment/coredns -n kube-system --timeout=180s

kubectl cluster-info --context kind-lab
kubectl get nodes -o wide
Write-Host "`nCluster ready. Your kubectl context is now 'kind-lab'." -ForegroundColor Green
