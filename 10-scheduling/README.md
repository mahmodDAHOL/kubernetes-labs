# Lab 10: Scheduling

**Goal:** control *where* pods run, and safely take nodes out for maintenance.
**Time:** 50 minutes

## Concepts

The **scheduler** places each new pod in two phases:
1. **Filter**: drop nodes that can't run it (not enough resources, wrong labels, taints it doesn't tolerate...).
2. **Score**: rank the rest (spread, affinity preferences, resource balance) and pick the best.

| Tool | Says | Hard/soft |
|------|------|-----------|
| `nodeSelector` | "only nodes with these labels" | hard |
| **node affinity** | richer node label rules (`In`, `NotIn`, `Exists`...) | `required...` = hard, `preferred...` = soft |
| **pod affinity / anti-affinity** | "near / away from pods with label X" | hard or soft |
| `topologySpreadConstraints` | "spread evenly across zones/nodes" | hard or soft |
| **taints** (on nodes) | "keep away unless you tolerate me" | `NoSchedule`, `PreferNoSchedule`, `NoExecute` (also evicts) |
| **tolerations** (on pods) | "I can live with that taint" | - |

**DaemonSet** = one pod per node (or per matching node).
**cordon** = mark a node unschedulable. **drain** = cordon + evict its pods safely.

## Steps

### 1. Look at node labels and taints

```powershell
cd 10-scheduling
kubectl get nodes --show-labels
kubectl describe node lab-control-plane | Select-String Taints
```

The control-plane has the taint `node-role.kubernetes.io/control-plane:NoSchedule`. That's why
none of your pods have landed there so far.

### 2. nodeSelector

```powershell
kubectl apply -f node-selector.yaml
kubectl get pods -l app=needs-ssd          # Pending: no node has disk=ssd
kubectl describe pod -l app=needs-ssd | Select-String "FailedScheduling" | Select-Object -First 1
kubectl label node lab-worker2 disk=ssd
kubectl get pods -l app=needs-ssd -o wide  # all 3 now on lab-worker2
```

### 3. Pod anti-affinity (high availability)

```powershell
kubectl apply -f anti-affinity.yaml
kubectl get pods -l app=spread -o wide     # one per worker; the 3rd is Pending. Why?
kubectl describe pod -l app=spread | Select-String "anti-affinity"
```

Change `requiredDuringScheduling...` to a **soft** rule and the 3rd pod gets placed anyway:

```yaml
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: spread
                topologyKey: kubernetes.io/hostname
```

### 4. Taints and tolerations

Dedicate `lab-worker2` to "GPU" workloads:

```powershell
kubectl taint node lab-worker2 dedicated=gpu:NoSchedule
kubectl label node lab-worker2 dedicated=gpu
kubectl create deployment normal --image=nginx:1.27 --replicas=4
kubectl get pods -l app=normal -o wide     # all on lab-worker: they don't tolerate the taint
kubectl apply -f toleration.yaml
kubectl get pod gpu-job -o wide            # on lab-worker2
```

Note: the `needs-ssd` pods already on `lab-worker2` were **not** evicted. `NoSchedule` only
affects *new* pods. Try `NoExecute` to see eviction:

```powershell
kubectl taint node lab-worker2 maintenance=now:NoExecute
kubectl get pods -o wide              # pods on lab-worker2 without a matching toleration are evicted
kubectl taint node lab-worker2 maintenance=now:NoExecute-      # trailing "-" removes the taint
```

### 5. DaemonSet

```powershell
kubectl apply -f daemonset.yaml
kubectl get daemonset node-agent
kubectl get pods -l app=node-agent -o wide   # one per node... including the control plane?
```

Only 2 of 3? `lab-worker2` has the `dedicated=gpu` taint, which the DaemonSet doesn't tolerate.
Remove it and watch the DaemonSet fill the gap automatically:

```powershell
kubectl taint node lab-worker2 dedicated=gpu:NoSchedule-
kubectl get pods -l app=node-agent -o wide   # 3 pods
kubectl logs -l app=node-agent --prefix
```

### 6. Node maintenance: cordon and drain

```powershell
kubectl scale deployment normal --replicas=4
kubectl rollout restart deployment normal       # re-spread across both workers
kubectl get pods -l app=normal -o wide
kubectl cordon lab-worker                       # no NEW pods here
kubectl get nodes                               # SchedulingDisabled
kubectl drain lab-worker --ignore-daemonsets --delete-emptydir-data
kubectl get pods -o wide                        # everything moved to lab-worker2
kubectl uncordon lab-worker                     # back in service (existing pods don't move back)
```

### 7. (Bonus) Simulate a node failure

```powershell
docker stop lab-worker2
kubectl get nodes -w          # NotReady after ~40s
# After ~5 min, pods on lab-worker2 are marked for eviction and Deployments recreate them elsewhere.
docker start lab-worker2
```

## Challenges

1. Use **node affinity** (not nodeSelector) to schedule a pod on any node whose `disk` label is
   `ssd` **or** `nvme`.
2. Write a Deployment of 4 replicas with a `topologySpreadConstraints` rule (`maxSkew: 1`,
   `topologyKey: kubernetes.io/hostname`) and check the spread across the 2 workers.
3. Run a pod **on the control-plane node** (tolerate its taint + select it by hostname).
4. What's the difference between `kubectl cordon` and `kubectl drain`?

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete -f . --ignore-not-found
kubectl delete -f solutions/ --ignore-not-found
kubectl delete deployment normal
kubectl uncordon lab-worker lab-worker2
kubectl label node lab-worker2 disk- dedicated-
kubectl taint node lab-worker2 dedicated- maintenance-   # errors if not present; that's fine
```

## Key takeaways

- Labels on nodes + selectors/affinity on pods = *attraction*. Taints + tolerations = *repulsion*.
- Anti-affinity / topology spread = high availability.
- Always `drain` before node maintenance; `uncordon` afterwards.
