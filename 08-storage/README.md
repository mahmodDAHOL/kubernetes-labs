# Lab 08: Storage & StatefulSets

**Goal:** keep data when pods die, and run stateful apps with stable identities.
**Time:** 50 minutes

## Concepts

A container's filesystem is **thrown away** when the container restarts. Volumes fix that:

| Volume | Lives as long as | Use for |
|--------|------------------|---------|
| `emptyDir` | the **pod** | scratch space, sharing files between containers (Lab 02) |
| `configMap` / `secret` | the object | config files (Lab 05) |
| `hostPath` | the **node** | node-level agents only; avoid for apps |
| `persistentVolumeClaim` | **independently** of any pod | databases, uploads: real persistent data |

The persistent storage chain:

```
Pod ──uses──▶ PersistentVolumeClaim (PVC)   "I need 1Gi, ReadWriteOnce"     ← you write this
                    │  bound to
                    ▼
              PersistentVolume (PV)          "a real 1Gi disk at ..."       ← created automatically
                    ▲  created by
              StorageClass                   "how to make disks" (provisioner) ← cluster admin
```

**Access modes:** `ReadWriteOnce` (one node), `ReadOnlyMany`, `ReadWriteMany` (many nodes,
needs e.g. NFS), `ReadWriteOncePod`.
**Reclaim policy:** `Delete` (the PV and its data are deleted with the PVC) or `Retain`.

**StatefulSet** = like a Deployment, but each pod has a **stable identity**: a fixed name
(`web-0`, `web-1`...), a stable DNS name, its own PVC that follows it, and ordered startup and shutdown.
Use it for databases, Kafka, ZooKeeper, Elasticsearch...

## Steps

### 1. Explore storage classes

```powershell
cd 08-storage
kubectl get storageclass
kubectl describe storageclass standard
```

`VolumeBindingMode: WaitForFirstConsumer` means the PV isn't created until a pod uses the PVC,
so the disk lands on the same node as the pod.

### 2. Create a PVC and a pod that uses it

```powershell
kubectl apply -f pvc-pod.yaml
kubectl get pvc,pv          # PVC Bound to an automatically created PV
kubectl exec notes -- cat /data/notes.txt
```

### 3. Prove the data survives the pod

```powershell
kubectl delete pod notes
kubectl apply -f pvc-pod.yaml       # recreate the pod (the PVC already exists)
kubectl exec notes -- cat /data/notes.txt   # TWO lines: data survived!
```

Where is it really? (kind's local-path provisioner uses a folder on the node.)

```powershell
kubectl get pv -o jsonpath='{.items[0].spec.local.path}{.items[0].spec.hostPath.path}'
kubectl get pod notes -o jsonpath='{.spec.nodeName}'
docker exec <that-node> ls /var/local-path-provisioner
```

### 4. StatefulSet

Read [statefulset.yaml](statefulset.yaml), then watch the **ordered** startup:

```powershell
kubectl apply -f statefulset.yaml
kubectl get pods -l app=web-sts -w     # web-0 Running → then web-1 → then web-2
kubectl get pvc                        # data-web-0, data-web-1, data-web-2
```

Stable network identities:

```powershell
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh
#   wget -qO- web-0.web
#   wget -qO- web-2.web
#   nslookup web          # 3 pod IPs (headless)
#   exit
```

### 5. Identity and data follow the pod

```powershell
kubectl exec web-1 -- cat /usr/share/nginx/html/index.html
kubectl delete pod web-1
kubectl get pods -l app=web-sts -w     # a NEW pod named web-1 again (not a random name)
kubectl exec web-1 -- cat /usr/share/nginx/html/index.html   # SAME content, same "created" time
```

### 6. Scaling is ordered, and PVCs are kept

```powershell
kubectl scale statefulset web --replicas=1    # removes web-2 first, then web-1
kubectl get pvc                               # all 3 PVCs still exist!
kubectl scale statefulset web --replicas=3    # web-1, web-2 come back WITH their old data
kubectl exec web-2 -- cat /usr/share/nginx/html/index.html
```

PVCs are deliberately **not** deleted on scale-down or StatefulSet deletion, to protect data.
(See `persistentVolumeClaimRetentionPolicy` in `kubectl explain statefulset.spec` to change that.)

## Challenges

1. Create a PVC `big` asking for `5Gi` with access mode `ReadWriteMany`, plus a pod using it.
   What state does the pod end up in, and why? (Read the PVC's events.)
2. Run `redis:7` as a 1-replica StatefulSet with a PVC mounted at `/data`. Write a key with
   `redis-cli set hello world`, delete the pod, and prove the key is still there after it returns.
   (Hint: start redis with `--appendonly yes`.)
3. What happens to the PV when you delete the `notes-data` PVC? Check `kubectl get pv` before and after.

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete -f .
kubectl delete pvc --all          # StatefulSet PVCs are not deleted automatically
kubectl delete -f solutions/ --ignore-not-found
```

## Key takeaways

- Pods are ephemeral; **PVCs** hold data that outlives them.
- StorageClasses provision PVs dynamically. You only write the PVC.
- StatefulSets give each replica a stable name, DNS name and its own volume.
