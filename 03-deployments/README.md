# Lab 03: Deployments

**Goal:** run apps that heal themselves, scale, and update with zero downtime.
**Time:** 45 minutes

## Concepts

You almost never create Pods directly. You create a **Deployment**, which manages a
**ReplicaSet**, which manages **Pods**:

```
Deployment  web            (desired: 3 replicas of nginx:1.26, rolling-update strategy)
  └─ ReplicaSet web-7d4b…  (keeps exactly 3 pods matching app=web + pod-template-hash)
       ├─ Pod web-7d4b…-abcde
       ├─ Pod web-7d4b…-fghij
       └─ Pod web-7d4b…-klmno
```

- **ReplicaSet**: a control loop that counts pods matching its selector and creates or deletes pods to hit `replicas`.
- **Deployment**: manages ReplicaSets so you can do **rolling updates** and **rollbacks**. Each
  change to the pod template creates a *new* ReplicaSet. Old ones are kept (scaled to 0) as history.

## Steps

### 1. Create the Deployment

Read [deployment.yaml](deployment.yaml), then:

```powershell
cd 03-deployments
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl get replicasets
kubectl get pods -o wide --show-labels     # spread across both workers?
```

Notice the naming chain: `web` → `web-<hash>` → `web-<hash>-<random>`.

### 2. Self-healing

```powershell
kubectl delete pod <one-of-the-web-pods>
kubectl get pods        # a replacement appears immediately (new name, AGE a few seconds)
```

Try to trick it by adding an "impostor" pod with the same label:

```powershell
kubectl run impostor --image=nginx:1.27 --labels=app=web
kubectl get pods        # 4 pods with app=web... why didn't the ReplicaSet delete one?
kubectl get rs -o wide  # look at the SELECTOR column
```

The ReplicaSet's selector is `app=web,pod-template-hash=<hash>`. The Deployment adds that hash
label so ReplicaSets from different versions never fight over the same pods. The impostor lacks
it, so it is ignored. Now make it a *perfect* impostor:

```powershell
$hash = kubectl get rs -l app=web -o jsonpath='{.items[0].metadata.labels.pod-template-hash}'
kubectl label pod impostor pod-template-hash=$hash
kubectl get pods        # now there are 4 matching pods for 3 replicas → one gets deleted!
```

Controllers just **count labels**. They don't care who created a pod.

### 3. Scaling

```powershell
kubectl scale deployment web --replicas=6
kubectl get pods
kubectl scale deployment web --replicas=3
```

The *declarative* way: edit `replicas:` in the YAML and `kubectl apply -f deployment.yaml` again.

### 4. Rolling update

Open **two terminals**. In terminal 1, watch:

```powershell
kubectl get pods -w
```

In terminal 2, change the image:

```powershell
kubectl set image deployment/web nginx=nginx:1.27
kubectl rollout status deployment/web
kubectl get replicasets            # old RS scaled to 0, new RS at 3
```

Because `maxSurge: 1, maxUnavailable: 0`, Kubernetes adds 1 new pod, waits until it's Ready,
removes 1 old pod, and repeats. There are always 3 pods serving.

Record *why* you changed something (shows up in history):

```powershell
kubectl annotate deployment/web kubernetes.io/change-cause="upgrade to nginx 1.27" --overwrite
kubectl rollout history deployment/web
```

### 5. A bad rollout and a rollback

```powershell
kubectl set image deployment/web nginx=nginx:9.99-broken
kubectl rollout status deployment/web --timeout=30s   # it won't finish
kubectl get pods                    # one new pod in ImagePullBackOff, the 3 old ones still serve!
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}'
```

`maxUnavailable: 0` protected you: the broken version never replaced a working pod.

```powershell
kubectl rollout history deployment/web
kubectl rollout undo deployment/web --to-revision=1   # jump to a specific revision
```

### 6. Pause, restart

```powershell
kubectl rollout restart deployment/web   # recreate all pods (e.g. to pick up a new config)
kubectl rollout pause deployment/web     # batch several changes...
kubectl set image deployment/web nginx=nginx:1.27
kubectl set resources deployment/web -c nginx --limits=memory=128Mi
kubectl rollout resume deployment/web    # ...then roll them out in one go
```

### 7. Recreate strategy (compare)

Edit `deployment.yaml`: replace the whole `strategy:` block with `strategy: {type: Recreate}`,
`apply` it, then change the image and watch. All old pods die **first**, so there is downtime.
This is useful when two versions can't run at the same time (e.g. a DB schema change).

## Challenges

1. Create (from scratch, in YAML) a Deployment `api` with 4 replicas of `hashicorp/http-echo:1.0`,
   args `["-text=v1", "-listen=:5678"]`, label `app=api`.
2. Roll it out to `-text=v2` with `kubectl apply` (edit the YAML) and watch the rollout.
3. Roll back to v1 and prove it by checking the pod args.
4. Why does `kubectl delete replicaset <web-rs>` not really delete your app? Try it.
5. What would happen if `spec.selector.matchLabels` did **not** match the template labels?
   Try it. (The API server rejects it; read the error.)

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete deployment web api --ignore-not-found
kubectl delete pod impostor --ignore-not-found
```

## Key takeaways

- Deployment → ReplicaSet → Pods. Use Deployments for stateless apps.
- Controllers continuously reconcile **labels and counts**.
- Rolling updates + `maxUnavailable: 0` = zero downtime; `rollout undo` = instant rollback.
