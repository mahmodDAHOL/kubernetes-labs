# Lab 09: Jobs & CronJobs

**Goal:** run tasks that *finish* (batch work, migrations, backups), once or on a schedule.
**Time:** 30 minutes

## Concepts

Deployments keep pods running **forever**. A **Job** runs pods **until they succeed**, then stops.

| Field | Meaning |
|-------|---------|
| `completions` | how many successful pods are needed (default 1) |
| `parallelism` | how many run at the same time |
| `backoffLimit` | how many failures are allowed before the Job is marked Failed |
| `activeDeadlineSeconds` | hard timeout for the whole Job |
| `ttlSecondsAfterFinished` | auto-cleanup after completion |
| `restartPolicy` | `Never` (new pod per retry) or `OnFailure` (restart the same pod) |

A **CronJob** creates a Job on a schedule (`"0 3 * * *"` = 03:00 every day).

## Steps

### 1. A simple Job

```powershell
cd 09-jobs
kubectl apply -f job.yaml
kubectl get jobs -w                 # COMPLETIONS 0/1 → 1/1
kubectl get pods                    # pod status: Completed
kubectl logs job/pi                 # 3.14159...
kubectl describe job pi
```

### 2. Parallel, indexed Job

```powershell
kubectl apply -f parallel-job.yaml
kubectl get pods -l job-name=batch-work -w     # never more than 2 running at once
kubectl logs -l job-name=batch-work --prefix   # which pod handled which index?
```

### 3. Retries

```powershell
kubectl apply -f failing-job.yaml
kubectl get pods -l job-name=flaky -w          # several Error pods, eventually one Completed (probably!)
kubectl describe job flaky | Select-String -Context 0,3 "Pods Statuses"
```

With `restartPolicy: Never` you get a **new pod per attempt**, so you can read each failure's logs.
The delay between retries grows (10s, 20s, 40s...).

### 4. CronJob

```powershell
kubectl apply -f cronjob.yaml
kubectl get cronjob heartbeat
kubectl get jobs -w                  # a new Job appears every minute (wait 2-3 min)
kubectl logs job/<one-of-the-heartbeat-jobs>
```

Trigger it manually, right now, without waiting for the schedule:

```powershell
kubectl create job manual-run --from=cronjob/heartbeat
kubectl logs job/manual-run
```

Pause it:

```powershell
kubectl patch cronjob heartbeat -p '{\"spec\":{\"suspend\":true}}'
```

## Challenges

1. Write a Job `countdown` that prints 10..1 (one per second) and then exits. Give it an
   `activeDeadlineSeconds: 5`. What happens? Read `kubectl describe job countdown`.
2. Write a CronJob that runs at **02:30 every Sunday**. (Only the `schedule` line matters.)
3. Make `flaky` **always** fail (`exit 1`) with `backoffLimit: 2`. How many pods get created,
   and what's the Job's final condition?
4. Use `kubectl create job` and `kubectl create cronjob` with `--dry-run=client -o yaml` to
   generate starter YAML.

Solutions: [solutions/](solutions/)

## Cleanup

```powershell
kubectl delete -f .
kubectl delete job manual-run countdown --ignore-not-found
```

## Key takeaways

- Job = run to completion, with retries. CronJob = Job on a schedule.
- Use `restartPolicy: Never` to keep failed pods (and their logs) around for debugging.
- Set `ttlSecondsAfterFinished` and history limits so finished Jobs don't pile up.
