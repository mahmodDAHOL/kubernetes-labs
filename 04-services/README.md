# Lab 04: Services & DNS

**Goal:** give a changing set of pods one stable address, and reach it from inside and outside the cluster.
**Time:** 45 minutes

## Concepts

Pod IPs change every time a pod is recreated, so you can't hard-code them. A **Service** gives you:
- a **stable virtual IP** (ClusterIP) and a **DNS name**
- **load-balancing** across all *ready* pods that match its **label selector**

```
client pod ──▶ whoami (DNS) ──▶ 10.96.x.x:8080 (ClusterIP) ──kube-proxy──▶ pod A :80
                                                                   ├──▶ pod B :80
                                                                   └──▶ pod C :80
```

| Type | Reachable from | Use for |
|------|----------------|---------|
| `ClusterIP` (default) | inside the cluster only | service-to-service traffic |
| `NodePort` | `<any-node-IP>:30000-32767` | quick external access, dev clusters |
| `LoadBalancer` | a cloud load balancer IP | production external access on cloud |
| Headless (`clusterIP: None`) | DNS returns pod IPs directly | StatefulSets, client-side balancing |

The Service controller keeps an **EndpointSlice** object up to date with the IPs of matching, ready pods.

**DNS:** CoreDNS gives every Service a name:
`<service>.<namespace>.svc.cluster.local`. From the same namespace, just `<service>` works.

## Steps

### 1. Deploy the app

```powershell
cd 04-services
kubectl apply -f app.yaml
kubectl get pods -l app=whoami -o wide
```

### 2. Create a ClusterIP Service

```powershell
kubectl apply -f service-clusterip.yaml
kubectl get svc whoami
kubectl describe svc whoami          # see Endpoints: the 3 pod IPs
kubectl get endpointslices -l kubernetes.io/service-name=whoami
```

### 3. Call it from inside the cluster

```powershell
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh
```

Inside the busybox shell:

```sh
wget -qO- http://whoami:8080 | grep Hostname     # run it 5-6 times: hostnames rotate!
nslookup whoami                                  # name → ClusterIP
nslookup whoami.default.svc.cluster.local
cat /etc/resolv.conf                             # why short names work (search domains)
exit
```

> busybox's `nslookup` also prints `server can't find whoami.cluster.local: NXDOMAIN` lines.
> That's harmless: it tries each search domain from `resolv.conf`, and only
> `whoami.default.svc.cluster.local` exists.

### 4. Endpoints follow the pods

```powershell
kubectl scale deployment whoami --replicas=5
kubectl describe svc whoami | Select-String Endpoints    # 5 IPs now
kubectl scale deployment whoami --replicas=0
kubectl describe svc whoami | Select-String Endpoints    # <none>: requests would fail
kubectl scale deployment whoami --replicas=3
```

### 5. Selector mismatch (the #1 Service bug)

```powershell
kubectl patch svc whoami -p '{\"spec\":{\"selector\":{\"app\":\"whoamiii\"}}}'
kubectl get endpointslices -l kubernetes.io/service-name=whoami    # no endpoints!
kubectl apply -f service-clusterip.yaml                             # fix it
```

> PowerShell tip: inner double quotes in JSON must be escaped as `\"` when passed to kubectl.
> In bash use: `kubectl patch svc whoami -p '{"spec":{"selector":{"app":"whoamiii"}}}'`

### 6. NodePort: reach it from your PC

```powershell
kubectl apply -f service-nodeport.yaml
kubectl get svc whoami-nodeport
```

> Revisiting this lab after Lab 12? Traefik already owns node port 30080, and you'll get
> `provided port is already allocated`. Use the Ingress instead, or temporarily
> `helm uninstall traefik -n traefik`.

Open http://localhost:30080 in your browser and refresh a few times (or run
`curl.exe -s localhost:30080`). Traffic path:
`browser → localhost:30080 → kind node container :30080 → kube-proxy → a whoami pod`.

### 7. port-forward (quick developer access)

```powershell
kubectl port-forward svc/whoami 9090:8080
# open http://localhost:9090 (note: port-forward picks ONE pod; no load-balancing)
```

### 8. Headless Service and DNS records

```powershell
kubectl create service clusterip whoami-headless --clusterip=None --tcp=80:80
kubectl set selector svc whoami-headless app=whoami
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- nslookup whoami-headless
```

You get **3 A-records (pod IPs)** instead of one virtual IP. StatefulSets use this (Lab 08).

### 9. Cross-namespace DNS

```powershell
kubectl create namespace other
kubectl run tmp -n other --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://whoami:8080
#   ✗ fails: "whoami" is looked up in namespace "other"
kubectl run tmp -n other --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://whoami.default:8080
#   ✓ works
```

## Challenges

1. Deploy `nginx:1.27` (2 replicas, label `app=nginx`) and expose it with
   `kubectl expose deployment nginx --port=80`. Then curl it from a busybox pod by DNS name.
2. Write a Service YAML `api` that listens on port **80** and forwards to the pods'
   port **5678**, selecting `app=api` (reuse Lab 03's http-echo deployment).
3. Find the ClusterIP of the `kube-dns` Service in `kube-system`, and compare it to the
   `nameserver` line in a pod's `/etc/resolv.conf`.
4. Why would a pod that is Running but **not Ready** receive no traffic from a Service?
   (You'll prove it in Lab 06.)

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete -f .
kubectl delete svc whoami-headless nginx api --ignore-not-found
kubectl delete deployment nginx api --ignore-not-found
kubectl delete namespace other
```

## Key takeaways

- Service = stable IP + DNS name + load balancer, glued to pods by **labels**.
- No endpoints? Check the selector and pod readiness first.
- `<svc>.<namespace>` reaches services in other namespaces.
