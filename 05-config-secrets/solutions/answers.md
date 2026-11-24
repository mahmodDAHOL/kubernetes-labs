# Lab 05: Solutions

1 & 2. See [challenges.yaml](challenges.yaml):
```powershell
kubectl apply -f solutions/challenges.yaml
kubectl logs greeter
kubectl logs creds-demo      # prints: admin
```

3. Add `immutable: true` at the top level of the ConfigMap (next to `data`) and apply it. Then
   any change to `data` is rejected: `field is immutable when immutable is set`. You must delete
   and recreate it (usually under a new name, e.g. `app-config-v2`). Why bother: it protects
   against accidental changes that would hit every pod, and the kubelet stops watching it,
   which reduces API server load in big clusters.

4. ```powershell
   kubectl create secret tls my-tls --cert=path/to/tls.crt --key=path/to/tls.key
   ```
   Type `kubernetes.io/tls`, with keys `tls.crt` and `tls.key`. Ingress controllers use this (Lab 12).
