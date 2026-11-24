# Lab 16: Troubleshooting Workout

**Goal:** fix 7 broken applications using only what the cluster tells you.
**Time:** 60–90 minutes

## The method

Work through these steps in order and you'll find most problems:

```
1. kubectl get pods -n <ns>                 What's the STATUS? READY? RESTARTS?
2. kubectl describe pod <pod> -n <ns>       Read the EVENTS at the bottom. They usually name the problem.
3. kubectl logs <pod> -n <ns> [--previous]  What did the app say before it died?
4. kubectl get events -n <ns> --sort-by=.lastTimestamp
5. For Services:  kubectl get endpointslices -n <ns>   → empty?  compare selector ↔ pod labels
                  kubectl get svc <svc> -o yaml        → port / targetPort correct?
6. kubectl exec / a debug pod                → test from inside the cluster
```

| Symptom | Usual suspects |
|---------|---------------|
| `ImagePullBackOff` / `ErrImagePull` | typo in image name/tag, private registry without credentials |
| `CrashLoopBackOff` | the app exits: read `logs --previous`; bad command, missing file or config; liveness probe too strict |
| `CreateContainerConfigError` | referenced ConfigMap/Secret (or a key in it) doesn't exist |
| `Pending` | not enough CPU/memory requests free, nodeSelector/taints, unbound PVC |
| `Running` but not `Ready` | readiness probe failing |
| Service doesn't answer | no endpoints (selector mismatch / pods not ready) or wrong `targetPort` |
| `OOMKilled` / exit code 137 | memory limit too low |

## Setup

```powershell
cd 16-troubleshooting
kubectl apply -f broken.yaml
powershell -ExecutionPolicy Bypass -File .\verify.ps1     # Score: 0 / 7
```

⚠ **Don't read `broken.yaml`!** Debug from the cluster, as you would in production, where you
often don't have the original YAML. Fix things with `kubectl edit`, `kubectl set ...`,
`kubectl patch`, `kubectl create ...`.

## The tickets

Each scenario is in its own namespace. Re-run `verify.ps1` after each fix.

| # | Namespace | Ticket from the "users" |
|---|-----------|-------------------------|
| 1 | `ts1` | "The **shop** deployment never starts." |
| 2 | `ts2` | "Pods of **api** are Running, but `http://api.ts2` doesn't answer." |
| 3 | `ts3` | "**web** pods are fine, but `http://web.ts3` refuses connections." |
| 4 | `ts4` | "The **worker** never starts. It should process the queue named `orders`." |
| 5 | `ts5` | "**frontend** keeps restarting every few seconds, though nginx looks fine." |
| 6 | `ts6` | "The **cache** has been 'starting' for an hour." |
| 7 | `ts7` | "**reporter** crashes immediately, but its ConfigMap definitely exists!" |

To test a Service yourself:

```powershell
kubectl run t --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- -T 3 http://api.ts2
```

## Hints (only if stuck)

<details><summary>Hint 1</summary>Look at the <b>Events</b> in <code>kubectl describe pod</code>. What image name is it pulling? Check it carefully, letter by letter.</details>
<details><summary>Hint 2</summary>Compare <code>kubectl get svc api -n ts2 -o wide</code> (SELECTOR column) with <code>kubectl get pods -n ts2 --show-labels</code>.</details>
<details><summary>Hint 3</summary>Endpoints exist this time. Which port do the pods listen on, and which port does the Service send traffic to?</details>
<details><summary>Hint 4</summary><code>kubectl describe pod</code> tells you a ConfigMap is missing. Which key does the app read? (Check the container's command with <code>kubectl get deploy worker -n ts4 -o yaml</code>.)</details>
<details><summary>Hint 5</summary><code>kubectl describe pod</code> → "Liveness probe failed: HTTP probe failed with statuscode: 404". Does nginx serve that path?</details>
<details><summary>Hint 6</summary>Events: "Insufficient memory". How much memory does it request? How much does a node have?</details>
<details><summary>Hint 7</summary><code>kubectl logs --previous</code> says which path it reads. <code>kubectl describe pod</code> → Mounts shows where the ConfigMap actually is.</details>

Solutions: [solutions/answers.md](solutions/answers.md). Or run them all at once:
`powershell -ExecutionPolicy Bypass -File .\solutions\fix-all.ps1`

## Bonus: break it yourself

Pair up with a friend (or future you): one person breaks a working app from an earlier lab in
a creative way, the other fixes it. Ideas: wrong namespace in a DNS name, a NetworkPolicy
blocking traffic, a readiness probe on the wrong port, a ResourceQuota that's full, a node
tainted `NoExecute`, a typo in a Secret key...

## Cleanup

```powershell
kubectl delete namespace ts1 ts2 ts3 ts4 ts5 ts6 ts7
kubectl delete pod checker -n default
```

## Key takeaways

- **Describe → events → logs** solves most problems.
- Learn the status words: each one points to a small set of causes.
- Services break silently: always check **endpoints** and **targetPort**.
