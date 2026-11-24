# Lab 06: Solutions

1. Add this under the `whoami` container in Lab 04's `app.yaml`:
   ```yaml
   readinessProbe:
     httpGet:
       path: /
       port: http
     periodSeconds: 5
   livenessProbe:
     tcpSocket:
       port: http
     periodSeconds: 10
   ```

2. See [wrong-port.yaml](wrong-port.yaml). nginx itself is fine, but the probe fails
   (`connection refused`), so the kubelet restarts the container every ~30s (3 × 10s). After a
   few restarts you see `CrashLoopBackOff`, even though the app was never broken. A wrong
   probe can take down a healthy app.

3. About **30 seconds** (3 failures × 10s period), plus up to `timeoutSeconds` per check.

4. Readiness can be **broader** ("can I handle requests: are my caches warm, is my DB reachable?").
   Liveness must be **narrow** ("is this process wedged?"). Mixing them leads to restarting
   healthy pods when a dependency has problems.
