# Lab 17: Capstone Project, "Shop on Kubernetes"

**Goal:** design and deploy a production-style, 3-tier application **from scratch**, using
everything from Labs 01–16. No step-by-step instructions this time: just requirements and a grader.
**Time:** 2–4 hours
**Requires:** Traefik from Lab 12, metrics-server from Lab 15.

## What you're building

```
            http://shop.localhost:30080
                       │
               ┌───────▼────────┐
               │ Traefik Ingress │   (namespace traefik, Lab 12)
               └───────┬────────┘
   namespace "shop"    │
               ┌───────▼────────┐        ┌──────────────┐        ┌──────────────┐
               │   frontend     │ ─────▶ │   backend    │ ─────▶ │    redis     │
               │  3 replicas    │  HTTP  │ 2–5 replicas │  TCP   │ StatefulSet  │
               │  podinfo       │  9898  │ podinfo +HPA │  6379  │  + PVC       │
               └────────────────┘        └──────────────┘        └──────────────┘
```

All tiers use ready-made images, so you don't need to build anything:
- **frontend** and **backend**: [podinfo](https://github.com/stefanprodan/podinfo), a small Go web app
  made for Kubernetes demos: `ghcr.io/stefanprodan/podinfo:6.17.0`
- **redis**: `redis:7`

### podinfo cheat sheet

| What | How |
|------|-----|
| Start command | `./podinfo --port=9898 [flags]` (set it as the container `command`) |
| Forward `POST /echo` calls to another service | flag `--backend-url=http://backend:9898/echo` |
| Use Redis as cache (`/cache/{key}` API) | flag `--cache-server=tcp://redis:6379` |
| UI message / color | env vars `PODINFO_UI_MESSAGE`, `PODINFO_UI_COLOR` |
| Health endpoints | liveness `/healthz`, readiness `/readyz` |
| Useful endpoints | `GET /` (info JSON or web UI), `GET /env`, `POST /echo`, `POST/GET /cache/{key}` |

## Requirements

Write your YAML in a folder `my-solution/` (one file per tier is a good layout).

### Platform
- [ ] **P1** Everything lives in namespace `shop`.
- [ ] **P2** The namespace has a `ResourceQuota` and a `LimitRange`.

### Data tier
- [ ] **D1** Redis runs as a **StatefulSet** named `redis` with a headless Service `redis`.
- [ ] **D2** Redis data is stored on a **PersistentVolumeClaim** (`volumeClaimTemplates`), with AOF
  persistence enabled (`--appendonly yes`).
- [ ] **D3** Readiness + liveness probes, CPU/memory requests and a memory limit.

### API tier
- [ ] **A1** Deployment `backend` (podinfo) with `--cache-server` pointing to redis; Service `backend` on port 9898.
- [ ] **A2** Readiness + liveness probes, requests and a memory limit.
- [ ] **A3** A **HorizontalPodAutoscaler**: 2–5 replicas, target 70% CPU.

### Web tier
- [ ] **W1** Deployment `frontend` (podinfo) with **3 replicas**, `--backend-url` pointing to the backend.
- [ ] **W2** UI message and color come from a **ConfigMap** (not hard-coded in the Deployment).
- [ ] **W3** Readiness + liveness probes, requests and a memory limit.
- [ ] **W4** Zero-downtime rolling updates (`maxUnavailable: 0`) and a **PodDisruptionBudget**
  keeping at least 2 frontend pods up.
- [ ] **W5** Replicas spread across nodes (anti-affinity or topology spread).

### Traffic
- [ ] **T1** An **Ingress** routes `http://shop.localhost:30080` to the frontend.

### Security
- [ ] **S1** **NetworkPolicies**: default-deny ingress in `shop`, then allow only
  Traefik → frontend, frontend → backend, backend → redis.
- [ ] **S2** Pods don't use the `default` ServiceAccount's API access: set
  `automountServiceAccountToken: false` (they never call the Kubernetes API).

## Check your work

```powershell
cd 17-capstone
kubectl apply -f my-solution/
powershell -ExecutionPolicy Bypass -File .\verify.ps1
```

Goal: **20 / 20**. Then open http://shop.localhost:30080 in your browser and try:

```powershell
curl.exe -s -X POST -d "hello" http://shop.localhost:30080/echo        # frontend → backend
kubectl exec -n shop deploy/frontend -- wget -qO- --post-data=bar http://backend:9898/cache/foo
kubectl exec -n shop deploy/frontend -- wget -qO- http://backend:9898/cache/foo   # bar (from redis)
```

## Prove it's production-grade (manual tests)

Do each one and explain to yourself (or a friend) what happened:

1. **Self-healing:** delete a frontend pod while running
   `while ($true) { curl.exe -s -o NUL -w "%{http_code} " http://shop.localhost:30080/; Start-Sleep -Milliseconds 300 }`.
   Do you see anything other than `200`?
2. **Zero-downtime deploy:** change the UI message in the ConfigMap, then
   `kubectl rollout restart deploy/frontend -n shop` while the loop runs.
3. **Persistence:** write a cache key, `kubectl delete pod redis-0 -n shop`, wait for it to come back, read the key.
4. **Node maintenance:** `kubectl drain lab-worker --ignore-daemonsets --delete-emptydir-data`.
   Watch the PDB slow the eviction down so 2 frontends always stay up. Then `uncordon`.
5. **Autoscaling:** generate load against the backend (Lab 15's load generator, pointed at
   `http://backend.shop:9898`). Did it work? (Hint: think about your NetworkPolicies!)
6. **Security:** `kubectl run hacker -n shop --rm -it --image=busybox:1.36 --restart=Never -- nc -zv redis 6379`. Blocked?

## Stretch goals

- Package the whole app as a **Helm chart** (`helm create shop`) with values for replica counts,
  message, color and image tag. Install it as two releases: `shop-staging` and `shop-prod` (in two namespaces).
- Add a **CronJob** that backs up Redis every 5 minutes (`redis-cli --rdb /backup/dump.rdb`
  into its own PVC). Remember to allow it in your NetworkPolicies!
- Add **egress** NetworkPolicies too (don't forget DNS).
- Give the frontend a second Ingress host `admin.shop.localhost` routing to `/env` only.

## Reference solution

[solutions/](solutions/) contains one complete answer (20/20). Look at it **after** you've
tried. There are many valid solutions; the grader checks behaviour, not exact YAML.

```powershell
kubectl apply -f solutions/
```

## Cleanup

```powershell
kubectl delete namespace shop
```

## 🎉 You're done

You can now deploy, expose, configure, secure, scale and debug apps on Kubernetes. Where to go next:
- **CKAD / CKA** certifications: these labs cover most of the CKAD curriculum.
- **GitOps** with Argo CD or Flux (deploy from git automatically).
- **Observability**: Prometheus + Grafana (`kube-prometheus-stack` Helm chart).
- **Operators & CRDs**: extend Kubernetes with your own resource types.
- A managed cloud cluster (EKS, GKE, AKS) to learn LoadBalancers, cloud storage and IAM.
