# Lab 14: Solutions

1. Policies are additive, so just add another allow rule for the db. Save this as
   `db-allow-frontend.yaml` and `kubectl apply -f` it:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: db-allow-frontend
     namespace: netpol
   spec:
     podSelector:
       matchLabels: {role: db}
     policyTypes: ["Ingress"]
     ingress:
       - from:
           - podSelector:
               matchLabels: {role: frontend}
         ports:
           - port: 6379
   ```

2. See [frontend-egress.yaml](frontend-egress.yaml).
   ```powershell
   kubectl apply -f solutions/frontend-egress.yaml
   kubectl exec -n netpol frontend -- wget -qO- -T 3 http://backend:8080     # works
   kubectl exec -n netpol frontend -- wget -qO- -T 3 http://example.com     # times out
   ```
   `http://backend:8080` first needs a **DNS lookup** of `backend` (UDP/TCP 53 to CoreDNS in
   `kube-system`). Without the DNS rule, the name never resolves, so the "allowed" connection
   fails too. This is the #1 egress-policy mistake.

3. See [allow-from-namespace.yaml](allow-from-namespace.yaml).
   ```powershell
   kubectl create namespace monitoring
   kubectl label namespace monitoring team=monitoring
   kubectl apply -f solutions/allow-from-namespace.yaml
   kubectl run probe -n monitoring --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- -T 3 http://backend.netpol:8080
   ```

4. **AND** (both conditions in one element, no `-` before `podSelector`):
   ```yaml
     ingress:
       - from:
           - namespaceSelector:
               matchLabels: {env: prod}
             podSelector:
               matchLabels: {role: frontend}
   ```
   **OR** (two list elements) would be:
   ```yaml
       - from:
           - namespaceSelector:
               matchLabels: {env: prod}
           - podSelector:
               matchLabels: {role: frontend}
   ```
   That single `-` changes the meaning completely, so read policies carefully.
