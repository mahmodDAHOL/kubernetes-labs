# Lab 12: Solutions

1. See [cherry.yaml](cherry.yaml). Rules for the same host can live in **different** Ingress
   objects; the controller merges them.
   ```powershell
   kubectl apply -f solutions/cherry.yaml
   curl.exe -s http://cherry.localhost:30080
   curl.exe -s http://shop.localhost:30080/cherry
   ```

2. A rule for `shop.localhost` with `path: /` (Prefix) catches everything that a longer
   prefix doesn't match:
   ```yaml
             - path: /
               pathType: Prefix
               backend:
                 service: {name: banana, port: {number: 80}}
   ```
   Longest prefix wins, so `/apple` still goes to apple. (`spec.defaultBackend` is the
   catch-all for requests that match **no host rule at all**.)

3. ```powershell
   kubectl apply -f ..\04-services\app.yaml -f ..\04-services\service-clusterip.yaml
   kubectl create ingress whoami --class=traefik --rule="whoami.localhost/*=whoami:8080"
   curl.exe -s http://whoami.localhost:30080
   ```
   `kubectl create ingress` is a quick way to make simple Ingresses.

4. `Exact` matches **only** `/apple`, so `/apple/x` returns 404.
   `Prefix` matches `/apple`, `/apple/`, `/apple/x`. The Kubernetes spec says Prefix matching is
   element-wise (so `/applesauce` should **not** match), but try
   `curl.exe -i http://shop.localhost:30080/applesauce`: Traefik returns 200!
   Lesson: **controllers interpret Ingress slightly differently**. Always test your routes on the
   controller you actually run. (Gateway API was designed partly to fix this kind of ambiguity.)
