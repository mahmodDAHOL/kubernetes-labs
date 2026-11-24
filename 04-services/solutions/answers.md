# Lab 04: Solutions

1. ```powershell
   kubectl create deployment nginx --image=nginx:1.27 --replicas=2
   kubectl expose deployment nginx --port=80
   kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://nginx
   ```
   (`kubectl create deployment` adds the label `app=nginx` automatically.)

2. See [api-service.yaml](api-service.yaml). Test it:
   ```powershell
   kubectl apply -f ..\03-deployments\solutions\api-deployment.yaml
   kubectl apply -f solutions\api-service.yaml
   kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://api
   ```

3. ```powershell
   kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}'
   kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- cat /etc/resolv.conf
   ```
   They match (usually `10.96.0.10`). The kubelet writes the DNS Service IP into every pod.

4. Only **Ready** pods are added to the endpoints. A pod failing its readiness probe is
   removed from load-balancing (but not restarted) until it is ready again.
