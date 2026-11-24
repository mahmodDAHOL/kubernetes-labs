# Lab 07: Solutions

1. Requests must equal limits for both CPU and memory. See [guaranteed.yaml](guaranteed.yaml).
   ```powershell
   kubectl delete pod well-sized
   kubectl apply -f solutions/guaranteed.yaml
   kubectl get pod well-sized -o jsonpath='{.status.qosClass}'    # Guaranteed
   ```
   (Most pod resource fields can't be changed in place, hence the delete.)

2. `requests.cpu: "1"` / `300m` = **3 pods** (900m). The 4th would need 1200m.
   ```powershell
   kubectl delete deployment filler -n team-a; kubectl delete pod plain -n team-a
   kubectl create deployment cpu300 -n team-a --image=nginx:1.27 --replicas=4
   kubectl set resources deployment cpu300 -n team-a --requests=cpu=300m
   kubectl get pods -n team-a           # 3 running
   kubectl describe rs -n team-a | Select-String "exceeded quota"
   ```

3. ```powershell
   kubectl api-resources --namespaced=false
   ```
   Nodes, Namespaces, PersistentVolumes, StorageClasses, ClusterRoles, CRDs, ...

4. Deleting a namespace deletes **everything inside it** (the namespace goes `Terminating`
   until that's finished). It's the fastest cleanup in Kubernetes, and also the most dangerous command.
