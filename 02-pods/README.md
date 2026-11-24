# Lab 02: Pods

**Goal:** create Pods from YAML, inspect them, debug them, and understand labels.
**Time:** 45 minutes

## Concepts

A **Pod** is one or more containers that are always scheduled together on the same node and share:
- one **IP address** (containers talk to each other via `localhost`)
- **volumes** (shared files)
- a lifecycle

Most of the time a pod has **one** container. Extra containers are "helpers" (sidecars).
Pods are **disposable**: they are never moved or healed. If a pod dies or its node dies, it
is gone. (Lab 03's Deployments fix that.)

**Imperative** (`kubectl run ...`) vs **declarative** (`kubectl apply -f file.yaml`): in real life you
keep YAML in git and `apply` it. You'll do that from now on.

Pod phases: `Pending` → `Running` → `Succeeded` / `Failed`. Common waiting reasons:
`ContainerCreating`, `ImagePullBackOff`, `CrashLoopBackOff`.

## Steps

### 1. Create a pod from YAML

Open [pod.yaml](pod.yaml) and read every line, including the comments. Then:

```powershell
cd 02-pods
kubectl apply -f pod.yaml
kubectl get pods -o wide
kubectl get pod web --show-labels
```

### 2. Inspect it

```powershell
kubectl describe pod web        # scroll to the Events at the bottom
kubectl get pod web -o yaml     # notice: Kubernetes added MANY defaults + a status section
kubectl logs web                # nginx access/error log
```

### 3. Reach it and get inside

```powershell
# Forward localhost:8080 → pod port 80 (leave running, open http://localhost:8080)
kubectl port-forward pod/web 8080:80
```

In a **second terminal**:

```powershell
kubectl exec -it web -- bash                # shell inside the container
#   cat /etc/nginx/conf.d/default.conf
#   hostname        (= pod name)
#   exit
kubectl exec web -- nginx -v                # run a single command
```

### 4. Talk pod-to-pod

Every pod gets its own IP on a flat cluster network. Any pod can reach any other pod.

```powershell
kubectl get pod web -o jsonpath='{.status.podIP}'
kubectl run client --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://<WEB_POD_IP>
```

`--rm -it` = interactive throwaway pod, deleted on exit. Handy for debugging.

### 5. Pods are not self-healing

```powershell
kubectl delete pod web
kubectl get pods            # gone. Nothing brings it back.
```

### 6. Multi-container pod, init containers and shared volumes

Read [multi-container.yaml](multi-container.yaml), then:

```powershell
kubectl apply -f multi-container.yaml
kubectl get pod shared -w                       # Init:0/1 → PodInitializing → Running (2/2)
kubectl logs shared -c init                     # -c picks a container
kubectl exec shared -c nginx -- cat /usr/share/nginx/html/index.html
kubectl exec shared -c writer -- wget -qO- localhost   # writer reaches nginx via localhost!
```

### 7. Debug a crashing pod

```powershell
kubectl apply -f crashing.yaml
kubectl get pod crasher -w      # Running → Error → CrashLoopBackOff, RESTARTS climbing
kubectl logs crasher            # current attempt
kubectl logs crasher --previous # the attempt that crashed
kubectl describe pod crasher    # Last State: Terminated, Exit Code: 1, Back-off restarting...
```

**CrashLoopBackOff** = "the container keeps exiting; I'm waiting longer and longer between
restarts (10s, 20s, 40s ... up to 5 min)". Always check `logs --previous` and the exit code.

### 8. Broken image

```powershell
kubectl run badimg --image=nginx:does-not-exist
kubectl get pod badimg          # ErrImagePull → ImagePullBackOff
kubectl describe pod badimg     # Events say exactly why
```

### 9. Labels and selectors

```powershell
kubectl run a --image=nginx:1.27 --labels="app=shop,env=dev"
kubectl run b --image=nginx:1.27 --labels="app=shop,env=prod"
kubectl run c --image=nginx:1.27 --labels="app=blog,env=prod"

kubectl get pods -l app=shop
kubectl get pods -l env=prod
kubectl get pods -l 'env in (dev,prod),app!=blog'
kubectl get pods -L app,env           # show labels as columns
kubectl label pod c team=red          # add a label
kubectl label pod c env=dev --overwrite
```

Labels are how Deployments find their pods and Services find their backends. You'll use them constantly.

### 10. Generate YAML instead of writing it

```powershell
kubectl run gen --image=redis:7 --dry-run=client -o yaml > my-pod.yaml
```

`--dry-run=client -o yaml` produces a starter manifest without creating anything.

## Challenges

1. Write `challenge-pod.yaml` from scratch: pod `redis` with image `redis:7`, labels
   `app=cache, env=dev`, container port 6379. Apply it and run `redis-cli ping` inside it.
2. Change `crashing.yaml` so the container **exits 0** with `restartPolicy: OnFailure`. What
   final status does the pod reach? Why is it not restarted?
3. Fix `badimg` **without deleting it** (hint: `kubectl set image pod/badimg badimg=nginx:1.27`).
4. Delete all pods with label `app=shop` in a single command.
5. Bonus: what happens to the `shared` pod if you `kubectl exec shared -c writer -- kill 1`?
   Check `RESTARTS`, and check whether the file content survived. Why?

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete pod --all
```

## Key takeaways

- Pod = containers sharing network + storage. One IP per pod.
- Pods are mortal: nothing recreates a deleted pod (yet).
- Debugging loop: `get` → `describe` (events) → `logs` (`--previous`) → `exec`.
- Labels + selectors are the glue of Kubernetes.
