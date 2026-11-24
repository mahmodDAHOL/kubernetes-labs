# Lab 01: Solutions

1. Capacity of `lab-worker2`:
   ```powershell
   kubectl get node lab-worker2 -o jsonpath='{.status.capacity.cpu} CPUs, {.status.capacity.memory}'
   ```
   (In kind every node reports your whole Docker VM's CPU/RAM, because the "nodes" share it.)

2. Pod IP:
   ```powershell
   kubectl get pod hello -n playground -o jsonpath='{.status.podIP}'
   ```

3. CoreDNS image:
   ```powershell
   kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.containers[0].image}'
   ```

4. ```powershell
   kubectl explain pod.spec.restartPolicy
   ```
   `Always` (default), `OnFailure`, `Never`. It controls whether the kubelet restarts
   containers in the pod when they exit.

5. ```powershell
   kubectl config set-context --current --namespace=playground
   kubectl get pods
   kubectl config set-context --current --namespace=default
   ```
