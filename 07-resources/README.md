# Lab 07: Resources, Namespaces & Quotas

**Goal:** size your containers correctly and share a cluster safely between teams.
**Time:** 45 minutes

## Concepts

### Requests and limits

| | **requests** | **limits** |
|---|---|---|
| Used by | the **scheduler** (does it fit on a node?) | the **kernel** at runtime |
| CPU | guaranteed share | throttled (slowed down) above it |
| Memory | guaranteed amount | **OOMKilled** above it |

Units: CPU `1` = 1 core = `1000m`. Memory `Mi`/`Gi` (binary) or `M`/`G` (decimal).

### QoS classes (who gets evicted first when a node runs low on memory)

| Class | When | Eviction order |
|-------|------|----------------|
| `Guaranteed` | requests == limits for CPU and memory, every container | last |
| `Burstable` | some requests/limits set | middle |
| `BestEffort` | nothing set | **first** |

### Namespaces

Namespaces split one cluster into virtual sub-clusters: names only need to be unique inside a
namespace, and RBAC, quotas and network policies can be applied per namespace. Some objects
(Nodes, PersistentVolumes, Namespaces themselves) are **cluster-scoped**.

## Steps

### 1. Requests and limits

```powershell
cd 07-resources
kubectl apply -f requests-limits.yaml
kubectl describe pod well-sized | Select-String -Context 0,6 "Limits"
kubectl get pod well-sized -o jsonpath='{.status.qosClass}'    # Burstable
kubectl describe node lab-worker | Select-String -Context 0,8 "Allocated resources"
```

The node's *Allocated resources* section sums the **requests** of all its pods. That's what
the scheduler looks at, **not** real usage.

### 2. OOMKilled

```powershell
kubectl apply -f oom.yaml
kubectl get pod memory-hog -w       # OOMKilled (or Error) → CrashLoopBackOff
kubectl describe pod memory-hog | Select-String -Context 0,4 "Last State"
#   Reason: OOMKilled, Exit Code: 137 (= 128 + signal 9, SIGKILL)
```

Exit code **137** + `OOMKilled` = raise the memory limit or fix a memory leak.

> On hosts with **cgroup v1** (see Lab 00), the reason may show `Error` instead of `OOMKilled`,
> but the exit code is still **137**. Confirm with the node's kernel log:
> ```powershell
> $node = kubectl get pod memory-hog -o jsonpath='{.spec.nodeName}'
> docker exec $node sh -c "dmesg | grep -i 'out of memory' | tail -n 3"
> #   Memory cgroup out of memory: Killed process 12345 (tail) ...
> ```

### 3. Unschedulable: Pending

```powershell
kubectl apply -f too-big.yaml
kubectl get pod too-big             # Pending, forever
kubectl describe pod too-big        # Events: "0/3 nodes are available: 3 Insufficient cpu"
```

A pod stuck in `Pending` almost always means: not enough resources, no matching node
(selectors/taints, see Lab 10), or an unbound volume (Lab 08).

### 4. Namespaces with a LimitRange and a ResourceQuota

Read [team-namespace.yaml](team-namespace.yaml), then:

```powershell
kubectl apply -f team-namespace.yaml
kubectl describe namespace team-a      # shows quota and limit range
```

**LimitRange defaults:** create a pod *without* resources and see what it gets:

```powershell
kubectl run plain -n team-a --image=nginx:1.27
kubectl get pod plain -n team-a -o jsonpath='{.spec.containers[0].resources}'
```

**LimitRange max:**

```powershell
kubectl run greedy -n team-a --image=nginx:1.27 --overrides='{\"spec\":{\"containers\":[{\"name\":\"greedy\",\"image\":\"nginx:1.27\",\"resources\":{\"limits\":{\"memory\":\"1Gi\"}}}]}}'
#   Error: maximum memory usage per Container is 512Mi, but limit is 1Gi
```

**ResourceQuota:** try to run 6 pods when the quota allows 5:

```powershell
kubectl create deployment filler -n team-a --image=nginx:1.27 --replicas=6
kubectl get pods -n team-a              # only 4 filler pods (plus "plain" = 5)
kubectl describe resourcequota budget -n team-a     # Used vs Hard
kubectl get events -n team-a | Select-String "exceeded quota"
kubectl describe replicaset -n team-a | Select-String "exceeded quota"
```

The Deployment exists, but its ReplicaSet can't create more pods. The quota error shows up in the
**ReplicaSet's events**, not on any pod, which is a common source of confusion.

### 5. Working with namespaces day-to-day

```powershell
kubectl get all -n team-a
kubectl config set-context --current --namespace=team-a   # make it the default
kubectl get pods                                          # now team-a
kubectl config set-context --current --namespace=default  # back
```

## Challenges

1. Make `well-sized` a **Guaranteed** pod. Verify its `qosClass`.
2. In `team-a`, what is the maximum number of pods with `requests.cpu: 300m` you can run
   (ignoring the pod-count limit)? Prove it.
3. List all resource types that are **cluster-scoped** (don't belong to any namespace).
4. Delete namespace `team-a`. What happens to the pods, quota and deployment inside it?

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete -f requests-limits.yaml -f oom.yaml -f too-big.yaml --ignore-not-found
kubectl delete namespace team-a
```

## Key takeaways

- **Always set requests** (for scheduling) and a **memory limit** (to protect neighbours).
- `Pending` → check scheduling events. `OOMKilled`/137 → memory limit too low.
- Namespaces + LimitRange + ResourceQuota = safe multi-team clusters.
