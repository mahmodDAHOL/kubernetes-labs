# Lab 12: Ingress

**Goal:** expose many HTTP services through **one** entry point, routing by hostname and URL path.
**Time:** 40 minutes
**Requires:** Helm (Lab 11)

## Concepts

NodePort/LoadBalancer gives you one port or one IP **per Service**. With 20 web services that's
messy and expensive. An **Ingress** describes HTTP routing rules; an **Ingress controller** (a
reverse proxy running in the cluster) implements them:

```
                         ┌── Host: apple.localhost ─────▶ Service apple  ─▶ pods
browser ─▶ :30080 ─▶ Traefik (ingress controller) ── Host: banana.localhost ────▶ Service banana ─▶ pods
                         └── shop.localhost/apple ──────▶ Service apple
```

- The **Ingress** object is just config. Without a controller, nothing happens.
- **IngressClass** says which controller handles which Ingress (`ingressClassName`).
- Popular controllers: Traefik, HAProxy, NGINX (F5), Contour, cloud ones (AWS ALB, GKE...).
  (The community `ingress-nginx` project was retired in 2026.)
- **Gateway API** (`Gateway`, `HTTPRoute`) is the newer, more expressive successor to Ingress.
  Learn Ingress first; the concepts carry over directly.

## Steps

### 1. Install the Traefik ingress controller with Helm

```powershell
cd 12-ingress
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik --version 42.4.2 -n traefik --create-namespace -f traefik-values.yaml
kubectl rollout status deploy/traefik -n traefik
kubectl get svc -n traefik           # NodePort 80:30080
kubectl get ingressclass             # "traefik"
```

> You may see `Warning: unrecognized format "int64"` lines. They're harmless.
> Port 30080 must be free: delete Lab 04's `whoami-nodeport` Service if it's still there.

Read [traefik-values.yaml](traefik-values.yaml) to see how we wired it to `localhost:30080`.

Before any Ingress exists, Traefik answers everything with 404:

```powershell
curl.exe -s http://localhost:30080      # 404 page not found
```

### 2. Deploy two backend apps

```powershell
kubectl apply -f apps.yaml
kubectl get deploy,svc
```

### 3. Host-based routing

Read [ingress-hosts.yaml](ingress-hosts.yaml), then:

```powershell
kubectl apply -f ingress-hosts.yaml
kubectl get ingress
kubectl describe ingress fruit-hosts
curl.exe -s http://apple.localhost:30080
curl.exe -s http://banana.localhost:30080
```

Or open http://apple.localhost:30080 and http://banana.localhost:30080 in your browser.
(Any `*.localhost` name points to 127.0.0.1, so you don't need to edit your hosts file.)

What actually decides the route is the HTTP `Host` header:

```powershell
curl.exe -s -H "Host: banana.localhost" http://localhost:30080
```

### 4. Path-based routing

```powershell
kubectl apply -f ingress-paths.yaml
curl.exe -s http://shop.localhost:30080/apple
curl.exe -s http://shop.localhost:30080/banana
curl.exe -s -i http://shop.localhost:30080/cherry     # 404: no rule matches
```

### 5. Watch load-balancing and failure

```powershell
kubectl scale deployment apple --replicas=0
curl.exe -s -i http://apple.localhost:30080      # 503 Service Unavailable: no endpoints
kubectl scale deployment apple --replicas=2
```

### 6. Look at the controller

```powershell
kubectl logs -n traefik deploy/traefik
kubectl port-forward -n traefik deploy/traefik 9000:8080
# Traefik's dashboard isn't exposed by default; see the chart docs if you want to enable it
```

## Challenges

1. Add a third app `cherry` (http-echo with `-text=Hello from CHERRY`) and route **both**
   `cherry.localhost` and `shop.localhost/cherry` to it.
2. Add a **default backend** to `fruit-paths` so that unknown paths on `shop.localhost` go to
   `banana` instead of returning 404. (Hint: `kubectl explain ingress.spec.defaultBackend`.)
3. Expose Lab 04's `whoami` app at `whoami.localhost` without changing its Service.
4. What's the difference between `pathType: Prefix` and `pathType: Exact`? Test `/apple/x`
   with each.

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete -f apps.yaml -f ingress-hosts.yaml -f ingress-paths.yaml --ignore-not-found
kubectl delete -f solutions/cherry.yaml --ignore-not-found
kubectl delete ingress whoami --ignore-not-found
```

Keep Traefik installed; Lab 17 uses it. (To remove it: `helm uninstall traefik -n traefik`.)

## Key takeaways

- Ingress = L7 (HTTP) routing rules; the **controller** does the actual work.
- Route by `host` and/or `path`; backends are ordinary ClusterIP Services.
- One entry point for many apps; TLS can be terminated there too (`spec.tls`).
