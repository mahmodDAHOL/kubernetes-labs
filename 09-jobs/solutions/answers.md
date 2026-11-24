# Lab 09: Solutions

1. See [countdown.yaml](countdown.yaml). After 5 seconds the Job is killed: condition
   `Failed`, reason **`DeadlineExceeded`**, and the running pod is terminated.

2. `schedule: "30 2 * * 0"` (minute 30, hour 2, any day-of-month, any month, Sunday=0).
   Add `timeZone: "Europe/Berlin"` (any IANA zone) if you don't want the cluster's (UTC) time.

3. **3 pods** (the first attempt + 2 retries). Final condition `Failed`, reason
   **`BackoffLimitExceeded`**.

4. ```powershell
   kubectl create job demo --image=busybox:1.36 --dry-run=client -o yaml -- echo hi
   kubectl create cronjob demo --image=busybox:1.36 --schedule="*/5 * * * *" --dry-run=client -o yaml -- echo hi
   ```
