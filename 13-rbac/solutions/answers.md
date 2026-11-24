# Lab 13: Solutions

1 & 2. See [challenges.yaml](challenges.yaml):
```powershell
kubectl apply -f solutions/challenges.yaml
kubectl auth can-i create deployments -n dev --as=bob          # yes
kubectl auth can-i delete pods -n dev --as=bob                 # no
kubectl auth can-i list nodes --as=system:serviceaccount:dev:pod-reader   # yes
kubectl exec -n dev api-client -- sh /tmp/call-api.sh /api/v1/nodes       # HTTP 200
```
A RoleBinding can't grant access to cluster-scoped resources like nodes, so challenge 2
needs a **ClusterRole + ClusterRoleBinding**.

3. ```powershell
   kubectl auth whoami                                   # groups include kubeadm:cluster-admins
   kubectl get clusterrolebinding kubeadm:cluster-admins -o yaml
   ```
   It binds the **group** `kubeadm:cluster-admins` to the `cluster-admin` ClusterRole. Your client
   certificate (in `~/.kube/config`) carries that group in its Organization field.

4. ```powershell
   kubectl create role cm-reader -n dev --verb=get,list,watch --resource=configmaps
   kubectl create rolebinding carol-cm -n dev --role=cm-reader --user=carol
   kubectl auth can-i list configmaps -n dev --as=carol    # yes
   ```
