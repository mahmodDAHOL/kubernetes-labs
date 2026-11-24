# Lab 16: Solutions

All fixes in one script: [fix-all.ps1](fix-all.ps1).

### 1. ts1 / shop: `ImagePullBackOff`
`describe pod` → `failed to resolve reference "docker.io/library/nginx:1.27-alpne": not found`.
Typo in the tag (`alpne` → `alpine`).
```powershell
kubectl set image deployment/shop -n ts1 nginx=nginx:1.27-alpine
```

### 2. ts2 / api: Service has no endpoints
Service selector is `app=api-server`, pods are labelled `app=api`.
```powershell
kubectl get svc api -n ts2 -o wide
kubectl get pods -n ts2 --show-labels
kubectl patch service api -n ts2 -p '{\"spec\":{\"selector\":{\"app\":\"api\"}}}'
```

### 3. ts3 / web: connection refused
Endpoints exist, but `targetPort: 8080` while nginx listens on **80**.
```powershell
kubectl patch service web -n ts3 --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/ports/0/targetPort\",\"value\":80}]'
```

### 4. ts4 / worker: `CreateContainerConfigError`
`describe pod` → `configmap "worker-config" not found`. The command uses `$QUEUE_NAME`.
```powershell
kubectl create configmap worker-config -n ts4 --from-literal=QUEUE_NAME=orders
```
No restart needed: the kubelet keeps retrying and the container starts on its own.

### 5. ts5 / frontend: liveness restarts
`describe pod` → `Liveness probe failed: HTTP probe failed with statuscode: 404`. nginx has no
`/healthz`, so the probe kills a perfectly healthy container.
```powershell
kubectl patch deployment frontend -n ts5 --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/livenessProbe/httpGet/path\",\"value\":\"/\"}]'
```

### 6. ts6 / cache: `Pending`
`describe pod` → `0/3 nodes are available: ... Insufficient memory`. It requests **64Gi**.
```powershell
kubectl set resources deployment/cache -n ts6 --requests=cpu=100m,memory=64Mi
```

### 7. ts7 / reporter: `CrashLoopBackOff`
`logs --previous` → `FATAL: config file /config/app.conf not found`.
`describe pod` → `Mounts: /etc/config from cfg`. The ConfigMap exists but is mounted at the
wrong path.
```powershell
kubectl patch deployment reporter -n ts7 --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/volumeMounts/0/mountPath\",\"value\":\"/config\"}]'
```
