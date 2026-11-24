# Lab 13: RBAC (Role-Based Access Control)

**Goal:** control *who* can do *what* in the cluster, for both humans and programs.
**Time:** 45 minutes

## Concepts

Every API request is checked: **authentication** (who are you?) → **authorization** (are you
allowed?) → **admission** (is the request valid / should it be modified?).

RBAC answers "are you allowed?" with four objects:

| Object | Scope | Says |
|--------|-------|------|
| **Role** | one namespace | *what* is allowed: verbs on resources |
| **ClusterRole** | cluster-wide | same, for all namespaces or cluster-scoped things (nodes...) |
| **RoleBinding** | one namespace | *who* gets a Role (or a ClusterRole, limited to this namespace) |
| **ClusterRoleBinding** | cluster-wide | *who* gets a ClusterRole everywhere |

**Subjects** (the "who"):
- **User / Group**: humans. Kubernetes has no user database; users come from certificates, OIDC (SSO), etc.
- **ServiceAccount**: identities for **pods**. Every namespace has a `default` SA.

**Verbs:** `get, list, watch, create, update, patch, delete, deletecollection` (+ `*`).
RBAC is **additive only**: there are no "deny" rules. Anything not granted is forbidden.

You are `kubernetes-admin` (cluster-admin) in kind, so everything works for you. To test other
identities use **impersonation**: `--as=<user>` / `--as=system:serviceaccount:<ns>:<name>`.

## Steps

### 1. Who am I?

```powershell
kubectl auth whoami
kubectl auth can-i '*' '*'              # yes: you're cluster-admin
kubectl get clusterroles | Select-String -Pattern "^(admin|edit|view|cluster-admin) "
kubectl describe clusterrole view | Select-Object -First 25
```

`admin`, `edit`, `view`, `cluster-admin` are built-in ClusterRoles you can reuse.

### 2. Create a Role, a ServiceAccount, and a binding

Read [rbac.yaml](rbac.yaml), then:

```powershell
cd 13-rbac
kubectl apply -f rbac.yaml
kubectl get sa,role,rolebinding -n dev
```

### 3. Test permissions with `auth can-i`

```powershell
kubectl auth can-i list pods -n dev --as=jane              # yes
kubectl auth can-i delete pods -n dev --as=jane            # no
kubectl auth can-i list pods -n default --as=jane          # no: Role is namespaced
kubectl auth can-i list secrets -n dev --as=jane           # no
kubectl auth can-i list pods -n dev --as=system:serviceaccount:dev:pod-reader   # yes
kubectl auth can-i --list -n dev --as=jane                 # everything jane can do
```

Try a real command as jane:

```powershell
kubectl get pods -n dev --as=jane
kubectl run x -n dev --image=nginx --as=jane     # Forbidden
```

### 4. A pod calling the API with its ServiceAccount

This is how controllers, operators and CI tools talk to Kubernetes from inside the cluster.

```powershell
kubectl apply -f api-client-pod.yaml
kubectl wait --for=condition=Ready pod/api-client -n dev
kubectl exec -n dev api-client -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl cp call-api.sh dev/api-client:/tmp/call-api.sh
```

Read [call-api.sh](call-api.sh): it's plain `curl` with the pod's **token** as a Bearer header.

```powershell
kubectl exec -n dev api-client -- sh /tmp/call-api.sh /api/v1/namespaces/dev/pods        # HTTP 200
kubectl exec -n dev api-client -- sh /tmp/call-api.sh /api/v1/namespaces/default/pods    # HTTP 403
kubectl exec -n dev api-client -- sh /tmp/call-api.sh /api/v1/namespaces/dev/secrets     # HTTP 403
```

Read the 403 message: it names the exact user, verb, resource and namespace that was denied.
That is exactly the information you need to write the missing rule.

### 5. Reuse a built-in ClusterRole in one namespace

Give jane read-only access to *almost everything* in `dev` using the built-in `view` role:

```powershell
kubectl create rolebinding jane-view -n dev --clusterrole=view --user=jane
kubectl auth can-i list deployments -n dev --as=jane       # yes now
kubectl auth can-i list secrets -n dev --as=jane           # still no (view excludes secrets on purpose)
```

### 6. Least privilege for ServiceAccounts

```powershell
kubectl auth can-i list pods -n dev --as=system:serviceaccount:dev:default    # no
```

The `default` SA has no permissions by default. Keep it that way and create dedicated SAs.
For pods that never call the API, set `automountServiceAccountToken: false`.

## Challenges

1. Create a Role `deployer` in `dev` that can `get, list, create, update, patch, delete`
   **deployments** (API group `apps`) and `get, list` **pods**. Bind it to user `bob`.
   Verify with `auth can-i`.
2. Give the ServiceAccount `dev:pod-reader` permission to **list nodes**. (Nodes are
   cluster-scoped. Which objects do you need?)
3. Find which ClusterRoleBinding gives *you* (`kubernetes-admin`) full power. (Hint: look at
   the `kubeadm:cluster-admins` binding and your user's group: `kubectl auth whoami`.)
4. Use `kubectl create role` and `kubectl create rolebinding` (imperative) to give user
   `carol` read access to ConfigMaps in `dev`.

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete namespace dev
kubectl delete clusterrole node-reader --ignore-not-found
kubectl delete clusterrolebinding pod-reader-nodes --ignore-not-found
```

## Key takeaways

- Role/ClusterRole = what; RoleBinding/ClusterRoleBinding = who + where.
- Pods authenticate with **ServiceAccount tokens**; humans via certs/OIDC.
- `kubectl auth can-i ... --as=...` is the fastest way to test and debug permissions.
- Grant the least privilege needed; there are no deny rules.
