# Lab 05: ConfigMaps & Secrets

**Goal:** keep configuration out of your container images and inject it at runtime.
**Time:** 40 minutes

## Concepts

Build an image **once**, then run it in dev, staging and prod with different config.

| Object | For | Stored as |
|--------|-----|-----------|
| **ConfigMap** | non-sensitive settings, config files | plain text |
| **Secret** | passwords, tokens, keys, TLS certs | base64 (+ optional encryption at rest, RBAC-restricted) |

Two ways to consume them:
1. **Environment variables** (`env`, `envFrom`): read once at container start. Changes need a restart.
2. **Mounted volumes** (files): updated automatically in the running pod (after ~a minute),
   but your app must re-read the file.

## Steps

### 1. Create the ConfigMap and the Secret

```powershell
cd 05-config-secrets
kubectl apply -f configmap.yaml -f secret.yaml
kubectl get configmaps,secrets
kubectl describe configmap app-config
kubectl describe secret db-credentials      # values hidden, only sizes shown
kubectl get secret db-credentials -o yaml   # ...but here they are, base64-encoded
```

Decode a value (proof that base64 is **not** security):

```powershell
$b64 = kubectl get secret db-credentials -o jsonpath='{.data.DB_PASSWORD}'
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
```

### 2. Imperative creation (very common)

```powershell
kubectl create configmap from-literals --from-literal=LEVEL=debug --from-literal=REGION=eu
"some file content" | Out-File -Encoding ascii settings.txt
kubectl create configmap from-file --from-file=settings.txt
kubectl create secret generic api-key --from-literal=key=abc123
kubectl get configmap from-file -o yaml
Remove-Item settings.txt
```

### 3. Inject as environment variables

Read [pod-env.yaml](pod-env.yaml), then:

```powershell
kubectl apply -f pod-env.yaml
kubectl logs env-demo
```

You should see `APP_COLOR`, `APP_MODE`, `COLOR`, `DB_USER`, `DB_PASSWORD`, `DB_PASS`,
`MY_LITERAL`, `MY_POD_IP`.

Question: `envFrom` imports *every* key, including `nginx.conf`. Did that become a variable?
Check with `kubectl exec env-demo -- env`. (Older Kubernetes skipped keys that weren't valid
C-style names; newer versions allow most characters.)

### 4. Inject as files

Read [deployment-volume.yaml](deployment-volume.yaml), then:

```powershell
kubectl apply -f deployment-volume.yaml
kubectl rollout status deployment/configured-nginx
kubectl exec deploy/configured-nginx -- ls -l /etc/nginx/conf.d /etc/secrets
kubectl exec deploy/configured-nginx -- cat /etc/secrets/DB_PASSWORD
kubectl port-forward deploy/configured-nginx 8080:80
#   → http://localhost:8080 shows the message from the ConfigMap
```

### 5. Live updates: files vs env vars

Edit the ConfigMap's message:

```powershell
kubectl edit configmap app-config      # change the "Hello from..." text, save & close
```

Wait ~60 seconds, then:

```powershell
kubectl exec deploy/configured-nginx -- cat /etc/nginx/conf.d/default.conf   # file UPDATED
curl.exe -s localhost:8080                                                  # but nginx still serves OLD text
kubectl exec deploy/configured-nginx -- nginx -s reload                     # app must re-read
```

The file changed in place, but the app has to reload it. Env vars **never** change in a running
container. The usual pattern is to trigger a rollout:

```powershell
kubectl rollout restart deployment/configured-nginx
```

### 6. Missing references

```powershell
kubectl run broken --image=busybox:1.36 --restart=Never --dry-run=client -o yaml -- sleep 3600 > broken.yaml
```

Edit `broken.yaml` to add an `envFrom: - configMapRef: {name: does-not-exist}` under the
container, apply it, and look at `kubectl get pod broken` → `CreateContainerConfigError`.
`kubectl describe` tells you which ConfigMap is missing. Delete the pod and `broken.yaml` after.

## Challenges

1. Create a ConfigMap `greeting` with key `MESSAGE=Hello K8s`, and a pod that prints
   `$MESSAGE` every 5 seconds using `envFrom`.
2. Mount **only** the `DB_USER` key of the secret as a file at `/creds/username`.
3. Make the ConfigMap `app-config` immutable (`immutable: true`). Then try to edit it. What happens,
   and why might you want this?
4. Create a TLS secret: `kubectl create secret tls --help`. What two keys does it contain?

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete -f .
kubectl delete configmap from-literals from-file greeting --ignore-not-found
kubectl delete secret api-key --ignore-not-found
kubectl delete pod greeter creds-demo broken --ignore-not-found
```

## Key takeaways

- Config lives in ConfigMaps/Secrets, not images.
- Env vars are fixed at start; mounted files update live (the app must reload them).
- Secrets are only base64. Protect them with RBAC, encryption at rest, or an external vault.
