# Lab 02: Solutions

1. See [challenge-pod.yaml](challenge-pod.yaml).

2. Change the command to `... exit 0` and `restartPolicy: OnFailure`. The pod reaches
   `Completed` (phase `Succeeded`). `OnFailure` only restarts containers that exit **non-zero**.
   `Always` would restart even a successful exit, which is why long-running servers use it.

3. ```powershell
   kubectl set image pod/badimg badimg=nginx:1.27
   ```
   A pod's container `image` is one of the few fields you may change on a running pod. Most
   other pod fields are immutable, so you'd have to delete and recreate it.

4. ```powershell
   kubectl delete pod -l app=shop
   ```

5. The `writer` container restarts (RESTARTS goes to 1) but the **pod** stays the same, so the
   `emptyDir` volume and its file survive. An emptyDir lives as long as the *pod*, not the container.
   If you delete the pod, the data is gone.
