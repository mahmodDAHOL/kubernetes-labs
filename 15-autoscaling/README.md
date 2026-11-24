# Lab 15: Metrics & Autoscaling

**Goal:** see live resource usage and let Kubernetes add or remove pods automatically based on load.
**Time:** 40 minutes

## Concepts

- **metrics-server** collects CPU/memory usage from every kubelet (every ~15s). It powers
  `kubectl top` and the autoscaler. It's *not* a monitoring system (no history). For that you'd
  use Prometheus + Grafana.
- **HorizontalPodAutoscaler (HPA)** periodically compares current usage against a target and
  changes a Deployment's `replicas`:

  ```
  desiredReplicas = ceil( currentReplicas × currentUsage / targetUsage )
  ```

  Utilization is measured **relative to the container's CPU *request***, so pods **must** have
  requests set (Lab 07).
- Scale-up is fast; scale-down waits for a **stabilization window** (default 5 min) to avoid flapping.
- Related: **VPA** (adjusts requests/limits), **Cluster Autoscaler / Karpenter** (adds *nodes*),
  **KEDA** (scales on queue length and other events).

## Steps

### 1. Install metrics-server

```powershell
cd 15-autoscaling
powershell -ExecutionPolicy Bypass -File .\install-metrics-server.ps1
```

(Read the script: kind's kubelets use self-signed certs, so we add `--kubelet-insecure-tls`.
Don't do this in production.)

After ~60 seconds:

```powershell
kubectl top nodes
kubectl top pods -A --sort-by=cpu
```

### 2. Deploy a CPU-hungry app and an HPA

Read [app.yaml](app.yaml) (note the CPU **request** of 200m) and [hpa.yaml](hpa.yaml) (target 50% = 100m per pod).

```powershell
kubectl apply -f app.yaml -f hpa.yaml
kubectl rollout status deployment/php-apache
kubectl get hpa                  # TARGETS shows <unknown>/50% for the first ~30s, then 0%/50%
```

### 3. Generate load and watch it scale out

Open **two terminals**. Terminal 1:

```powershell
kubectl get hpa php-apache -w
```

Terminal 2:

```powershell
kubectl apply -f load-generator.yaml
kubectl get pods -l app=php-apache -w
```

Within 1–2 minutes you'll see something like:

```
TARGETS          REPLICAS
cpu: 250%/50%    1   → HPA computes ceil(1 × 250/50) = 5
cpu: 58%/50%     5   → still a bit above target
cpu: 53%/50%     6   → settles around the target
```

```powershell
kubectl top pods -l app=php-apache
kubectl describe hpa php-apache          # Events: "New size: 5; reason: cpu resource utilization above target"
```

### 4. Remove the load and watch it scale in

```powershell
kubectl scale deployment load-generator --replicas=0
```

CPU drops to 0% quickly, but replicas only drop after the **60s stabilization window** we set
in `hpa.yaml` (the default is 300s).

### 5. What the HPA can't fix

Push it harder:

```powershell
kubectl scale deployment load-generator --replicas=4
kubectl get hpa php-apache -w      # climbs to maxReplicas: 8 and stops
kubectl get pods -l app=php-apache # if nodes run out of CPU *requests*, some pods stay Pending
```

HPA adds pods, not capacity. Once nodes are full you need a cluster autoscaler (in the cloud) to add nodes.

## Challenges

1. Create an HPA **imperatively** for the same deployment:
   `kubectl autoscale deployment php-apache --cpu-percent=30 --min=2 --max=5`
   (delete the YAML one first). What's the minimum replica count right after creating it?
2. Add a **memory** target (`averageUtilization: 70`) to `hpa.yaml` alongside CPU. When
   multiple metrics are set, which one wins?
3. Remove the `resources.requests` from `app.yaml` and re-apply. What does `kubectl get hpa`
   show, and why?
4. With 3 replicas at 90% CPU and a target of 60%, how many replicas will the HPA want?

Solutions: [solutions/answers.md](solutions/answers.md)

## Cleanup

```powershell
kubectl delete -f app.yaml -f hpa.yaml -f load-generator.yaml --ignore-not-found
kubectl delete hpa php-apache --ignore-not-found
```

Keep metrics-server installed; `kubectl top` is useful in the next labs.

## Key takeaways

- metrics-server → `kubectl top` + HPA input.
- HPA scales replicas to keep usage near a target **percentage of requests**.
- Scale-down is deliberately slow; and HPA can't create node capacity.
