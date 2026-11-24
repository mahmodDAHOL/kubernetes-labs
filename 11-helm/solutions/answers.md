# Lab 11: Solutions

1. ```powershell
   helm install blue podinfo/podinfo -n helm-lab --set replicaCount=2 --set ui.color="#2563eb"
   ```

2. The same command works on the first run and on every later run, so a pipeline doesn't have
   to check whether the release exists yet. Add `--atomic` (Helm 3) or
   `--rollback-on-failure` (Helm 4) to roll back automatically if the upgrade fails.

3. Create `mychart/templates/configmap.yaml`:
   ```yaml
   {{- if .Values.config.enabled }}
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: {{ include "mychart.fullname" . }}-config
   data:
     greeting: {{ .Values.greeting | quote }}
   {{- end }}
   ```
   and in `values.yaml`:
   ```yaml
   config:
     enabled: false
   ```
   ```powershell
   helm template t ./mychart | Select-String ConfigMap                          # nothing
   helm template t ./mychart --set config.enabled=true | Select-String ConfigMap  # kind: ConfigMap
   ```

4. In **Secrets** in the release's namespace, of type `helm.sh/release.v1`, one per revision
   (`sh.helm.release.v1.demo.v1`, `.v2`, ...). Helm has no server component; the cluster *is*
   its database.
