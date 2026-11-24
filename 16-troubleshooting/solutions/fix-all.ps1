# Applies the fix for every scenario. Only use this AFTER you've tried yourself!
# Explanations are in answers.md.

# 1. typo in the image tag
kubectl set image deployment/shop -n ts1 nginx=nginx:1.27-alpine

# 2. Service selector doesn't match the pod labels
kubectl patch service api -n ts2 -p '{\"spec\":{\"selector\":{\"app\":\"api\"}}}'

# 3. Service targetPort points at a port nobody listens on
kubectl patch service web -n ts3 --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/ports/0/targetPort\",\"value\":80}]'

# 4. referenced ConfigMap doesn't exist
kubectl create configmap worker-config -n ts4 --from-literal=QUEUE_NAME=orders

# 5. liveness probe checks a path that returns 404
kubectl patch deployment frontend -n ts5 --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/livenessProbe/httpGet/path\",\"value\":\"/\"}]'

# 6. memory request larger than any node
kubectl set resources deployment/cache -n ts6 --requests=cpu=100m,memory=64Mi

# 7. config mounted at the wrong path
kubectl patch deployment reporter -n ts7 --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/volumeMounts/0/mountPath\",\"value\":\"/config\"}]'
