# Lab 11: Helm

**Goal:** install, configure, upgrade and roll back apps with Helm, then package your own app as a chart.
**Time:** 50 minutes

## Concepts

By now you've noticed that one app = many YAML files (Deployment, Service, ConfigMap...), and you
need slightly different values per environment. **Helm** is the Kubernetes package manager:

| Term | Meaning |
|------|---------|
| **Chart** | a package: templated YAML files + default `values.yaml` |
| **Values** | the settings you override (`--set` or `-f my-values.yaml`) |
| **Release** | one installed instance of a chart (you can install the same chart many times) |
| **Repository** | where charts are published (HTTP repo or OCI registry) |
| **Revision** | every install/upgrade/rollback of a release creates a new numbered revision |

```
chart templates  +  values  ──helm──▶  plain Kubernetes YAML  ──▶  API server
```

## Part A: Use someone else's chart

### 1. Add a repository and find a chart

```powershell
helm version
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
helm search repo podinfo
helm show values podinfo/podinfo | Select-Object -First 40     # every setting you can change
```

### 2. Install a release

```powershell
kubectl create namespace helm-lab
helm install demo podinfo/podinfo -n helm-lab
helm list -n helm-lab
kubectl get all -n helm-lab          # Helm created the Deployment, Service... for you
```

### 3. See what Helm actually did

```powershell
helm get values demo -n helm-lab           # only YOUR overrides (none yet)
helm get values demo -n helm-lab --all     # all effective values
helm get manifest demo -n helm-lab         # the exact YAML that was applied
kubectl port-forward -n helm-lab svc/demo-podinfo 9898:9898
# open http://localhost:9898
```

### 4. Upgrade with new values

Create `my-values.yaml`:

```yaml
replicaCount: 3
ui:
  color: "#7c3aed"
  message: "Deployed with Helm!"
```

```powershell
helm upgrade demo podinfo/podinfo -n helm-lab -f my-values.yaml
kubectl get pods -n helm-lab              # 3 replicas
helm history demo -n helm-lab             # revision 2
```

Re-run the port-forward and reload the page: purple, with your message.

`--set` works too (handy for one value): `helm upgrade demo podinfo/podinfo -n helm-lab -f my-values.yaml --set replicaCount=2`

### 5. Roll back

```powershell
helm rollback demo 1 -n helm-lab
helm history demo -n helm-lab             # revision 3 = copy of revision 1
kubectl get pods -n helm-lab              # back to 1 replica
```

### 6. Render without installing

```powershell
helm template demo podinfo/podinfo -f my-values.yaml | Select-Object -First 50
```

Great for reviewing changes, or for GitOps tools that want plain YAML.

## Part B: Build your own chart

### 7. Scaffold a chart

```powershell
helm create mychart
```

Explore the structure:

```
mychart/
  Chart.yaml           # name, version (of the chart), appVersion (of your app)
  values.yaml          # defaults
  templates/
    deployment.yaml    # Go templates: {{ .Values.replicaCount }}, {{ include "mychart.fullname" . }}
    service.yaml
    _helpers.tpl       # reusable named templates
    NOTES.txt          # printed after install
```

Open `mychart/templates/deployment.yaml` and find where `.Values.image.repository`,
`.Values.replicaCount` and `.Release.Name` are used.

### 8. Customise it

Edit `mychart/values.yaml`:
- `image.repository: traefik/whoami`, `image.tag: "v1.10"`
- `replicaCount: 2`

Then lint, render and install:

```powershell
helm lint mychart
helm template test mychart | Select-String "image:"
helm install whoami-dev ./mychart -n helm-lab
helm install whoami-prod ./mychart -n helm-lab --set replicaCount=4   # same chart, 2nd release
helm list -n helm-lab
kubectl get deploy -n helm-lab
```

### 9. Add your own value

Add an env var driven by values. In `mychart/values.yaml` add:

```yaml
greeting: "hello"
```

In `mychart/templates/deployment.yaml`, under the container (same indent as `image:`) add:

```yaml
          env:
            - name: WHOAMI_NAME
              value: {{ .Values.greeting | quote }}
```

```powershell
helm upgrade whoami-dev ./mychart -n helm-lab --set greeting="from-dev"
kubectl port-forward -n helm-lab svc/whoami-dev-mychart 8081:80
# http://localhost:8081 shows "Name: from-dev"
```

## Challenges

1. Install a second podinfo release called `blue` in namespace `helm-lab` with 2 replicas and
   UI color `#2563eb`, using only `--set` flags.
2. `helm upgrade --install` is idempotent ("install if missing, upgrade if present"). Why is
   that useful in CI/CD pipelines?
3. Add an `if` block to your chart so a ConfigMap is only created when `.Values.config.enabled`
   is true. Check with `helm template ... --set config.enabled=true`.
4. Where does Helm store release history? (Hint: `kubectl get secrets -n helm-lab`.)

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
helm uninstall demo blue whoami-dev whoami-prod -n helm-lab
kubectl delete namespace helm-lab
```

(Keep the `mychart` folder if you like; it's yours.)

## Key takeaways

- Charts = templates + values. Releases = installed instances, with revision history.
- `helm template` / `helm get manifest` show you the real YAML: no magic.
- `helm upgrade --install` + `helm rollback` = repeatable deploys and instant undo.
