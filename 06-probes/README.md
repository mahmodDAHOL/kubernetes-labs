# Lab 06: Health Probes

**Goal:** teach Kubernetes how to tell whether your app is alive, ready for traffic, and finished starting.
**Time:** 40 minutes

## Concepts

"Container is running" ≠ "app works". Probes let the kubelet check your app:

| Probe | Question | On failure |
|-------|----------|-----------|
| **livenessProbe** | Is it stuck or dead? | **Restart** the container |
| **readinessProbe** | Can it serve traffic right now? | **Remove from Service endpoints** (no restart) |
| **startupProbe** | Has it finished booting? | Keep waiting; liveness/readiness are paused until it succeeds |

Probe types: `httpGet` (2xx/3xx = OK), `tcpSocket` (port open), `exec` (exit code 0), `grpc`.

Key timing fields: `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`,
`failureThreshold`, `successThreshold`.

⚠ Common mistake: a liveness probe that checks a **dependency** (e.g. the database). If the DB
goes down, every pod restarts in a loop and makes things worse. Liveness should check only "is
*this process* healthy?"; put dependency checks in readiness.

## Steps

### 1. Liveness: automatic restart

```powershell
cd 06-probes
kubectl apply -f liveness.yaml
kubectl get pod liveness-demo -w
```

After about 50 seconds, `RESTARTS` goes 0 → 1, then keeps climbing (30s healthy + 3 failed
checks × 5s + 5s grace period). Then:

```powershell
kubectl describe pod liveness-demo    # Events: "Liveness probe failed: cat: can't open '/tmp/healthy'"
                                      #         "Container app failed liveness probe, will be restarted"
```

> Real-world gotcha: on a restart, the kubelet sends **SIGTERM**, waits
> `terminationGracePeriodSeconds` (default 30s), then sends SIGKILL. A shell script running as
> PID 1 ignores SIGTERM, so it always takes the full 30s. That's why `liveness.yaml` sets it to 5s.
> Real apps should handle SIGTERM and shut down gracefully.

### 2. Readiness: removed from load-balancing

```powershell
kubectl apply -f readiness.yaml
kubectl rollout status deployment/ready-demo
kubectl describe svc ready-demo | Select-String Endpoints   # 3 pod IPs
```

Handy helper: list each endpoint with its readiness (define it once per terminal):

```powershell
function Show-Endpoints($svc) { kubectl get endpointslices -l kubernetes.io/service-name=$svc -o jsonpath='{range .items[*].endpoints[*]}[{.addresses[0]} ready={.conditions.ready}] {end}' }
Show-Endpoints ready-demo
```

Make one pod "not ready" by deleting the file its probe checks:

```powershell
$pod = kubectl get pods -l app=ready-demo -o jsonpath='{.items[0].metadata.name}'
kubectl exec $pod -- rm /usr/share/nginx/html/ready.html
kubectl get pods -l app=ready-demo                 # that pod: READY 0/1, STATUS still Running, RESTARTS 0
kubectl describe svc ready-demo | Select-String Endpoints   # only 2 IPs now
Show-Endpoints ready-demo                          # the 3rd is still listed, but ready=false
kubectl describe pod $pod | Select-String "Readiness"
```

Bring it back:

```powershell
kubectl exec $pod -- sh -c "echo ready > /usr/share/nginx/html/ready.html"
kubectl get pods -l app=ready-demo                 # 1/1 again, back in the endpoints
```

This is how rolling updates know when a new pod can take traffic, and how a temporarily
overloaded pod can step out of rotation.

### 3. Startup probe: slow apps

```powershell
kubectl apply -f startup.yaml
kubectl get pod slow-start -w        # stays 0/1 for ~40s, then 1/1, and RESTARTS stays 0
```

Now break it: in `startup.yaml` change `failureThreshold: 30` to `failureThreshold: 5`
(5 × 2s = 10s budget for a 40s boot), then recreate:

```powershell
kubectl delete pod slow-start
kubectl apply -f startup.yaml
kubectl get pod slow-start -w        # killed after ~10s, restarted again and again → CrashLoopBackOff
```

Put the value back to `30` when done.

## Challenges

1. Add an **httpGet readiness probe** on path `/` port 80 and a **tcpSocket liveness probe** to
   the `whoami` deployment from Lab 04.
2. Write a pod with a liveness probe pointing at the **wrong port** (e.g. 8081 on nginx). Predict
   what you'll see in `kubectl get pods` after 1 minute, then check.
3. Calculate: with `periodSeconds: 10` and `failureThreshold: 3`, how long can an app be
   unhealthy before it is restarted?
4. Why should a readiness probe and a liveness probe usually hit **different** endpoints?

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete -f .
kubectl delete pod wrong-port --ignore-not-found
```

## Key takeaways

- Liveness = restart me. Readiness = don't send me traffic. Startup = give me time to boot.
- A Running pod that isn't Ready gets **no** Service traffic.
- Keep liveness checks simple and local to the process.
