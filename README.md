# Kubernetes From Scratch: Hands-On Labs

A step-by-step track of labs that takes you from "what is a Pod?" to running a complete
multi-tier app with ingress, autoscaling, RBAC and network policies. Everything runs **locally**
on a 3-node cluster built with [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker).

## How to use these labs

1. Do the labs **in order**. Each one builds on the previous one.
2. **Type the commands yourself** instead of copy-pasting. Muscle memory matters.
3. Read the *Concepts* section of each lab first, then do the *Steps*.
4. At the end of each lab, attempt the **Challenges** without looking at `solutions/`.
5. Run the lab's *Cleanup* before moving on (the cluster itself stays).

All commands are written for **PowerShell** on Windows (they also work in bash unless noted).

## Roadmap

| #  | Lab | What you learn |
|----|-----|----------------|
| 00 | [Setup](00-setup/README.md) | Install tools, create the 3-node `lab` cluster |
| 01 | [First steps with kubectl](01-first-steps/README.md) | Cluster anatomy, nodes, namespaces, `get/describe/explain` |
| 02 | [Pods](02-pods/README.md) | YAML anatomy, logs, exec, multi-container pods, labels |
| 03 | [Deployments](03-deployments/README.md) | ReplicaSets, self-healing, scaling, rolling updates, rollback |
| 04 | [Services & DNS](04-services/README.md) | ClusterIP, NodePort, endpoints, service discovery |
| 05 | [ConfigMaps & Secrets](05-config-secrets/README.md) | Env vars, mounted config files, secrets |
| 06 | [Health probes](06-probes/README.md) | Liveness, readiness, startup probes |
| 07 | [Resources & Namespaces](07-resources/README.md) | Requests/limits, OOMKilled, ResourceQuota, LimitRange |
| 08 | [Storage](08-storage/README.md) | Volumes, PVCs, StorageClasses, StatefulSets |
| 09 | [Jobs & CronJobs](09-jobs/README.md) | Batch workloads, retries, parallelism, schedules |
| 10 | [Scheduling](10-scheduling/README.md) | nodeSelector, affinity, taints/tolerations, DaemonSets, drain |
| 11 | [Helm](11-helm/README.md) | Charts, values, releases, upgrades, rollbacks |
| 12 | [Ingress](12-ingress/README.md) | HTTP routing by host and path with an ingress controller |
| 13 | [RBAC](13-rbac/README.md) | ServiceAccounts, Roles, RoleBindings, `auth can-i` |
| 14 | [Network Policies](14-network-policies/README.md) | Default-deny, allow-lists, pod isolation |
| 15 | [Autoscaling](15-autoscaling/README.md) | metrics-server, `kubectl top`, HorizontalPodAutoscaler |
| 16 | [Troubleshooting](16-troubleshooting/README.md) | Fix 6 broken apps: a debugging workout |
| 17 | [Capstone project](17-capstone/README.md) | Build a full multi-tier app using everything you learned |

## Quick start

```powershell
# 1. Make sure Docker Desktop is running, then:
powershell -ExecutionPolicy Bypass -File .\00-setup\create-cluster.ps1

# 2. Start with Lab 01
code .\01-first-steps\README.md
```

## Daily-use cheat sheet

```powershell
kubectl get pods -o wide               # list pods + node + IP
kubectl get all                        # common objects in current namespace
kubectl describe pod <name>            # details + EVENTS (read these first when debugging!)
kubectl logs <pod> [-c container] [-f] [--previous]
kubectl exec -it <pod> -- sh           # shell into a container
kubectl apply -f file.yaml             # create/update from YAML (declarative)
kubectl delete -f file.yaml
kubectl explain deployment.spec.strategy   # built-in API docs
kubectl get pod <name> -o yaml         # see the full live object
kubectl config set-context --current --namespace=<ns>   # switch default namespace
```

## If something goes wrong

- Cluster broken? Just rebuild it: `.\00-setup\delete-cluster.ps1` then `.\00-setup\create-cluster.ps1`.
- `kubectl` says *connection refused*: Docker Desktop is probably stopped.
- See the troubleshooting notes in [00-setup/README.md](00-setup/README.md).
