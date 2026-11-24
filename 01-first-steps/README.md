# Lab 01: First Steps with kubectl

**Goal:** understand what a cluster is made of and learn to explore it with `kubectl`.
**Time:** 30 minutes

## Concepts

Kubernetes is a **desired-state system**. You tell it *what you want* ("3 copies of nginx should
be running"), and it keeps working to make reality match. You never tell it *how*.

```
   you ──kubectl──▶  API SERVER  ◀──watches── controllers ("make reality match")
                        │                       scheduler   ("which node should this go on?")
                        ▼
                      etcd  (database of desired + current state)
                        ▲
   node: kubelet ───────┘  ("what should run on me?" → tells containerd to start containers)
```

| Component | Lives on | Job |
|-----------|----------|-----|
| **kube-apiserver** | control plane | The front door. *Everything* (kubectl, nodes, controllers) talks only to it. |
| **etcd** | control plane | Key-value database storing all cluster state. |
| **kube-scheduler** | control plane | Picks a node for each new Pod. |
| **kube-controller-manager** | control plane | Runs control loops (Deployments, ReplicaSets, Nodes...). |
| **kubelet** | every node | Starts/stops containers on its node and reports status. |
| **kube-proxy** | every node | Programs networking rules for Services. |
| **container runtime** | every node | Actually runs containers (containerd here). |

Every *thing* in Kubernetes is an **object** (a.k.a. resource): Pod, Deployment, Service, Node,
Namespace... Each has a `kind`, `metadata` (name, labels), a `spec` (what you want) and a
`status` (what currently is).

## Steps

### 1. Talk to the cluster

```powershell
kubectl cluster-info
kubectl config get-contexts     # which cluster is kubectl pointed at? (* = current)
kubectl config current-context  # should print: kind-lab
```

> kubectl reads its settings from `~/.kube/config`. A *context* = cluster + user + default namespace.

### 2. Look at the nodes

```powershell
kubectl get nodes
kubectl get nodes -o wide        # more columns: internal IP, OS, runtime
kubectl describe node lab-worker # capacity, allocated resources, conditions, pods on it
```

In the `describe` output find: **Capacity** (CPU/memory), **Conditions** (`Ready=True`), and
**Non-terminated Pods**.

### 3. Namespaces: folders for objects

```powershell
kubectl get namespaces
kubectl get pods                     # "No resources found in default namespace."
kubectl get pods -n kube-system      # the control plane itself runs as pods!
kubectl get pods -A                  # all namespaces
```

You should recognise `etcd-…`, `kube-apiserver-…`, `kube-scheduler-…`, `kube-controller-manager-…`,
`kube-proxy-…` (one per node), `coredns-…` (cluster DNS) and `calico-node-…` (the network plugin
that gives pods their IPs and enforces network policies, one per node).

```powershell
kubectl get pods -n kube-system -o wide   # which node is each one on?
```

Question: why is there one `kube-proxy` per node but only one `kube-apiserver`?

### 4. Discover the API

```powershell
kubectl api-resources              # every kind of object the cluster knows
kubectl api-resources --namespaced=false   # cluster-wide objects (Nodes, Namespaces...)
kubectl explain pod                # built-in documentation
kubectl explain pod.spec.containers
kubectl explain deployment.spec --recursive | Select-Object -First 40
```

`kubectl explain` is your best friend: it works offline and always matches your cluster version.

### 5. Output formats

```powershell
kubectl get node lab-worker -o yaml          # the full object, as stored
kubectl get node lab-worker -o json
kubectl get nodes -o name
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}'
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEM:.status.capacity.memory
```

### 6. Your first imperative command

```powershell
kubectl create namespace playground
kubectl run hello --image=nginx:1.27 -n playground
kubectl get pods -n playground -w     # watch it go ContainerCreating → Running (Ctrl+C to stop)
kubectl get pods -n playground -o wide   # which worker did the scheduler pick?
kubectl get events -n playground --sort-by=.lastTimestamp
```

Read the events: `Scheduled` → `Pulling` → `Pulled` → `Created` → `Started`. That's the
scheduler, then the kubelet on the chosen node, doing their jobs.

### 7. Peek under the hood (kind-specific)

Nodes are Docker containers, so you can step inside one:

```powershell
docker exec -it lab-worker crictl ps     # containers running on this "node"
docker exec lab-control-plane ls /etc/kubernetes/manifests   # control plane = static pod files
```

## Challenges

1. How many CPUs and how much memory does `lab-worker2` report?
2. Find the IP address of the `hello` pod using **jsonpath**.
3. Which container image (with tag) does the `coredns` pod use?
4. Use `kubectl explain` to find out what `pod.spec.restartPolicy` does and its allowed values.
5. Make `playground` your default namespace so `kubectl get pods` shows `hello` without `-n`.
   Then switch back to `default`.

Solutions: [solutions/answers.md](solutions/answers.md)

## Cleanup

```powershell
kubectl delete namespace playground   # deletes everything inside it too
```

## Key takeaways

- The API server is the only entry point; everything else watches it.
- Objects = `spec` (desired) + `status` (actual). Controllers close the gap.
- `get`, `describe`, `explain`, `-o yaml` and **events** are how you see what's going on.
