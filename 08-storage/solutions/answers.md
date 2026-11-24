# Lab 08: Solutions

1. The pod stays **Pending** and the PVC stays **Pending**. kind's `local-path` provisioner only
   supports `ReadWriteOnce` (a local folder can't be shared across nodes), so the PVC's events
   show a provisioning error. `ReadWriteMany` needs a storage backend such as NFS, CephFS, Azure
   Files or EFS.

2. See [redis-statefulset.yaml](redis-statefulset.yaml):
   ```powershell
   kubectl apply -f solutions/redis-statefulset.yaml
   kubectl rollout status statefulset/redis
   kubectl exec redis-0 -- redis-cli set hello world
   kubectl delete pod redis-0
   kubectl wait --for=condition=Ready pod/redis-0 --timeout=120s
   kubectl exec redis-0 -- redis-cli get hello        # "world"
   ```

3. With the default StorageClass's `reclaimPolicy: Delete`, the PV (and the data on disk) is
   deleted right after the PVC. With `Retain` the PV would stay in `Released` state for an admin
   to recover manually.
   Note: you can't delete a PVC while a pod still uses it. It waits in `Terminating`
   (storage object in-use protection) until the pod is gone.
