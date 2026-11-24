# Lab 14: Network Policies

**Goal:** firewall pod-to-pod traffic. By default every pod can talk to every pod; fix that.
**Time:** 40 minutes

## Concepts

Kubernetes networking is **flat and open**: any pod can reach any other pod in any namespace.
A **NetworkPolicy** restricts traffic for the pods it selects:

```yaml
spec:
  podSelector: {...}        # WHICH pods this policy protects
  policyTypes: [Ingress, Egress]
  ingress:  - from: [...]   # who may connect IN  (podSelector / namespaceSelector / ipBlock)
              ports: [...]
  egress:   - to:   [...]   # where they may connect OUT
              ports: [...]
```

Rules of the game:
1. A pod **not selected** by any policy: everything allowed.
2. Once a pod **is selected** by a policy for a direction (Ingress/Egress), only traffic that
   some policy explicitly allows gets through. Policies are **additive allow-lists**.
3. Usual pattern: **default-deny** for the namespace, then add small allow rules.
4. ⚠ Policies are enforced by the **network plugin (CNI)**. If the CNI doesn't support them, they
   are *silently ignored*. Our cluster uses **Calico**, which enforces them. (kind's default
   `kindnet` fails to enforce them on WSL2 kernels; that's why Lab 00 installs Calico.)

The app in this lab:

```
 frontend ──8080──▶ backend ──6379──▶ db
 intruder ──✗────▶ backend / db   (should be blocked)
```

## Steps

### 1. Deploy the pods

```powershell
cd 14-network-policies
kubectl apply -f apps.yaml
kubectl wait --for=condition=Ready pod --all -n netpol --timeout=180s
kubectl get pods -n netpol -o wide --show-labels
```

### 2. Baseline: everything is open

[test.ps1](test.ps1) checks 5 connections with `nc -z` (port open?) from inside the pods:

```powershell
powershell -ExecutionPolicy Bypass -File .\test.ps1
```

All `ALLOWED`. Even the intruder can reach the database!

### 3. Default deny

```powershell
kubectl apply -f default-deny.yaml
powershell -ExecutionPolicy Bypass -File .\test.ps1     # everything BLOCKED
```

`podSelector: {}` selects every pod in the namespace, and no `ingress` rules means nothing gets in.

### 4. Allow only what's needed

Read [allow-rules.yaml](allow-rules.yaml), then:

```powershell
kubectl apply -f allow-rules.yaml
powershell -ExecutionPolicy Bypass -File .\test.ps1
```

Expected:

```
frontend   -> backend :8080  ALLOWED
frontend   -> db      :6379  BLOCKED
intruder   -> backend :8080  BLOCKED
intruder   -> db      :6379  BLOCKED
backend    -> db      :6379  ALLOWED
```

### 5. Labels are identity

The policies match **labels**, not pod names. So what happens if the intruder relabels itself?

```powershell
kubectl label pod intruder -n netpol role=frontend --overwrite
powershell -ExecutionPolicy Bypass -File .\test.ps1      # intruder → backend now ALLOWED!
kubectl label pod intruder -n netpol role=intruder --overwrite
```

That's why RBAC (who can change labels/pods, Lab 13) and network policies go together.

### 6. Inspect policies

```powershell
kubectl get networkpolicy -n netpol
kubectl describe networkpolicy backend-allow-frontend -n netpol
```

## Challenges

1. Allow the `frontend` to also reach `db` on 6379, **without** editing the existing policies
   (add a new one). Run the test to prove it, then delete it again.
2. **Egress:** restrict the `frontend` so it can *only* connect to `backend:8080` and DNS.
   Verify `wget -qO- http://backend:8080` still works but `wget http://example.com` times out.
   Why would forgetting DNS break even the allowed connection?
3. Create namespace `monitoring` with label `team=monitoring` and allow any pod in it to reach
   `backend:8080`. Test from a busybox pod in that namespace using `http://backend.netpol:8080`.
4. Write a policy that allows ingress to `backend` from pods with `role=frontend` **in a namespace
   labelled `env=prod`**. Hint: `namespaceSelector` and `podSelector` in the **same** `from`
   element = AND; in **separate** elements = OR.

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete namespace netpol monitoring --ignore-not-found
```

## Key takeaways

- Kubernetes networking is open by default. Use default-deny + explicit allows.
- Policies select pods by **labels**, and only work if the **CNI enforces them**.
- With egress policies, always remember to allow **DNS** (port 53 to kube-dns).
