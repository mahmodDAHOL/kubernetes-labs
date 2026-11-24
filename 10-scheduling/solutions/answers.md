# Lab 10: Solutions

1–3. See [challenges.yaml](challenges.yaml): `kubectl apply -f solutions/challenges.yaml`
   - Challenge 1 needs a node labelled `disk=ssd` or `disk=nvme` (lab-worker2 from step 2).
   - Challenge 2: `kubectl get pods -l app=even -o wide` shows 2 + 2. **Gotcha:** if you leave
     out `nodeTaintsPolicy: Honor`, only 2 pods run and 2 stay Pending. By default the spread
     calculation ignores taints, so the control-plane counts as a node with 0 pods.
     1 pod per worker is already the maximum skew of 1 against it. Try it without the line to see.
   - Challenge 3: `kubectl get pod on-control-plane -o wide` → `lab-control-plane`.

4. **cordon** only marks the node unschedulable; existing pods keep running.
   **drain** = cordon + evict all pods (respecting PodDisruptionBudgets), so their controllers
   recreate them on other nodes. DaemonSet pods are skipped (`--ignore-daemonsets`).
