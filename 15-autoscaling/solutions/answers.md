# Lab 15: Solutions

1. ```powershell
   kubectl delete hpa php-apache
   kubectl autoscale deployment php-apache --cpu-percent=30 --min=2 --max=5
   kubectl get hpa,deploy php-apache
   ```
   The deployment is scaled up to **2** right away: `minReplicas` is enforced even with no load.

2. ```yaml
     metrics:
       - type: Resource
         resource:
           name: cpu
           target: {type: Utilization, averageUtilization: 50}
       - type: Resource
         resource:
           name: memory
           target: {type: Utilization, averageUtilization: 70}
   ```
   The HPA computes a desired replica count **per metric** and uses the **highest** one.
   (Memory also needs a memory *request* on the container to compute utilization.)

3. `TARGETS` shows `cpu: <unknown>/50%` and the events say
   `failed to get cpu utilization: missing request for cpu`. Utilization is a percentage
   of the request, so without a request there's nothing to divide by.

4. `ceil(3 × 90 / 60) = ceil(4.5) = 5` replicas.
