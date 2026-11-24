# Lab 03: Solutions

1. See [api-deployment.yaml](api-deployment.yaml): `kubectl apply -f solutions/api-deployment.yaml`

2. Edit `-text=v1` → `-text=v2`, then:
   ```powershell
   kubectl apply -f solutions/api-deployment.yaml
   kubectl rollout status deployment/api
   ```

3. ```powershell
   kubectl rollout undo deployment/api
   kubectl get pods -l app=api -o jsonpath='{.items[*].spec.containers[0].args}'
   ```
   Your YAML file still says v2, though. The cluster and git have "drifted". In real life you'd
   revert the file in git and re-apply. That's the idea behind GitOps.

4. The Deployment notices its ReplicaSet is gone and creates a new one (with the same template
   hash, so the same name). The pods are recreated too. **Delete the owner (the Deployment), not
   the children.**

5. Error: `selector does not match template labels`. The API validates this so a controller can
   never create pods it wouldn't recognise as its own (which would loop forever).
