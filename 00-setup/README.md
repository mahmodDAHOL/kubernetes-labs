# Lab 00: Setup

**Goal:** get a working 3-node Kubernetes cluster on your laptop.
**Time:** 15 minutes

## What you are building

```
 Your PC (Windows)
 └── Docker Desktop
      ├── container "lab-control-plane"  ← runs the Kubernetes brain (API server, etcd, scheduler...)
      ├── container "lab-worker"         ← runs your apps
      └── container "lab-worker2"        ← runs your apps
```

**kind** = *Kubernetes IN Docker*. Each "node" is a Docker container that pretends to be a
machine. It behaves like a real multi-node cluster, so you can practice scheduling, node failures
and more, and you can delete and rebuild it in a minute.

## 1. Install the tools

| Tool | Why | Install |
|------|-----|---------|
| Docker Desktop | runs the node containers | https://www.docker.com/products/docker-desktop |
| kubectl | the CLI to talk to Kubernetes | ships with Docker Desktop, or `winget install Kubernetes.kubectl` |
| kind | creates the cluster | `winget install Kubernetes.kind` |
| helm | package manager (Lab 11+) | `winget install Helm.Helm` |

After installing with winget, **open a new terminal** so the PATH is refreshed, then check:

```powershell
docker version
kubectl version --client
kind version
helm version
```

## 2. Create the cluster

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\00-setup\create-cluster.ps1
```

The script:
1. creates the nodes from [kind-config.yaml](kind-config.yaml): 1 control-plane + 2 workers, plus
   a port mapping (`localhost:30080`) used from Lab 04 on;
2. installs **Calico** as the network plugin (CNI). Until a CNI is installed, nodes stay
   `NotReady`. We use Calico instead of kind's default (kindnet) because it enforces
   NetworkPolicies on WSL2 (Lab 14);
3. waits until all nodes are `Ready`.

It needs internet access (it pulls images and the Calico manifest). The first run takes a few minutes.

## 3. Verify

```powershell
kubectl get nodes
```

Expected (after up to a minute, all `Ready`):

```
NAME                STATUS   ROLES           AGE   VERSION
lab-control-plane   Ready    control-plane   1m    v1.34.0
lab-worker          Ready    <none>          1m    v1.34.0
lab-worker2         Ready    <none>          1m    v1.34.0
```

```powershell
docker ps        # you'll see the 3 "nodes" are just containers!
```

## Start / stop / reset

| Action | Command |
|--------|---------|
| Delete cluster | `.\00-setup\delete-cluster.ps1` |
| Recreate cluster | `.\00-setup\create-cluster.ps1` |
| Pause (save RAM) | Quit Docker Desktop; the cluster usually comes back when Docker restarts. If not, recreate it. |

## Troubleshooting

**`kind create` fails at "Starting control-plane" and prints `cgroup v1 is deprecated`.**
Kubernetes 1.35+ won't run on cgroup v1 hosts. The config here pins `kindest/node:v1.34.0`
for that reason. The real fix is to update Docker Desktop and WSL (`wsl --update`), then
check that `docker info --format '{{.CgroupVersion}}'` prints `2`.

**kubectl warns about version skew.** kubectl supports a server ±1 minor version away. Docker
Desktop's bundled kubectl may be older. It works for these labs; to update it, run
`winget install Kubernetes.kubectl` and make sure that one comes first in your PATH.

**Port 30080 already in use.** Change `hostPort` in `kind-config.yaml` and recreate the cluster.

**Running out of memory.** In Docker Desktop → Settings → Resources (or `.wslconfig`), give
it at least 4 GB of RAM.
