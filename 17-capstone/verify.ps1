# Grades your capstone against the requirements in README.md.
#   powershell -ExecutionPolicy Bypass -File .\verify.ps1
$ns = 'shop'
$script:score = 0; $script:total = 0

function Check($title, [scriptblock]$test) {
    $script:total++
    $ok = $false
    try { $ok = & $test } catch { $ok = $false }
    if ($ok) { Write-Host "  [PASS] $title" -ForegroundColor Green; $script:score++ }
    else     { Write-Host "  [FAIL] $title" -ForegroundColor Red }
}
function J($args2) { kubectl -n $ns get @args2 2>$null }
function Avail($kind, $name) {
    $want = kubectl -n $ns get $kind $name -o jsonpath='{.spec.replicas}' 2>$null
    $have = kubectl -n $ns get $kind $name -o jsonpath='{.status.readyReplicas}' 2>$null
    return [int]$have -ge [int]$want -and [int]$want -gt 0
}
function HasProbesAndRequests($kind, $name) {
    $c = kubectl -n $ns get $kind $name -o jsonpath='{.spec.template.spec.containers[0]}' 2>$null | ConvertFrom-Json
    return ($c.readinessProbe -and $c.livenessProbe -and $c.resources.requests.cpu -and $c.resources.requests.memory -and $c.resources.limits.memory)
}

Write-Host "`n== Platform ==" -ForegroundColor Cyan
Check "Namespace 'shop' exists"                       { kubectl get ns $ns *> $null; $LASTEXITCODE -eq 0 }
Check "ResourceQuota in 'shop'"                       { (J @('resourcequota','-o','name')).Count -ge 1 }
Check "LimitRange in 'shop'"                          { (J @('limitrange','-o','name')).Count -ge 1 }

Write-Host "`n== Data tier (redis) ==" -ForegroundColor Cyan
Check "StatefulSet 'redis' is ready"                  { Avail statefulset redis }
Check "redis has a Bound PersistentVolumeClaim"       { "$(J @('pvc','-o','jsonpath={.items[*].status.phase}'))" -match 'Bound' }
Check "redis has probes, requests and a memory limit" { HasProbesAndRequests statefulset redis }

Write-Host "`n== API tier (backend) ==" -ForegroundColor Cyan
Check "Deployment 'backend' has >= 2 ready replicas"  { [int](J @('deploy','backend','-o','jsonpath={.status.readyReplicas}')) -ge 2 }
Check "backend has probes, requests and a memory limit" { HasProbesAndRequests deployment backend }
Check "HPA targets 'backend'"                          { "$(J @('hpa','-o','jsonpath={.items[*].spec.scaleTargetRef.name}'))" -match 'backend' }
Check "backend can use the redis cache"               {
    kubectl -n $ns exec deploy/frontend -- wget -qO- --post-data=ok http://backend:9898/cache/capstone-check 2>$null | Out-Null
    "$(kubectl -n $ns exec deploy/frontend -- wget -qO- http://backend:9898/cache/capstone-check 2>$null)" -match 'ok'
}

Write-Host "`n== Web tier (frontend) ==" -ForegroundColor Cyan
Check "Deployment 'frontend' has 3 ready replicas"    { [int](J @('deploy','frontend','-o','jsonpath={.status.readyReplicas}')) -ge 3 }
Check "frontend has probes, requests and a memory limit" { HasProbesAndRequests deployment frontend }
Check "frontend gets its UI message from a ConfigMap" {
    $c = J @('deploy','frontend','-o','json') | ConvertFrom-Json
    $refs = @($c.spec.template.spec.containers[0].envFrom.configMapRef.name) + @($c.spec.template.spec.containers[0].env.valueFrom.configMapKeyRef.name)
    ($refs | Where-Object { $_ }).Count -ge 1
}
Check "PodDisruptionBudget protects 'frontend'"       { "$(J @('pdb','-o','jsonpath={.items[*].spec.selector.matchLabels.app}'))" -match 'frontend' }

Write-Host "`n== Traffic ==" -ForegroundColor Cyan
Check "http://shop.localhost:30080 is served by frontend" { "$(curl.exe -s -m 5 http://shop.localhost:30080/)" -match '"hostname": "frontend-' }
Check "Custom UI message is shown"                    { $m = "$(curl.exe -s -m 5 http://shop.localhost:30080/)"; ($m -match '"message"') -and ($m -notmatch 'greetings from podinfo') }
Check "frontend -> backend works (POST /echo)"        { "$(curl.exe -s -m 5 -X POST -d capstone http://shop.localhost:30080/echo)" -match 'capstone' }

Write-Host "`n== Security ==" -ForegroundColor Cyan
Check "NetworkPolicies exist in 'shop'"               { (J @('networkpolicy','-o','name')).Count -ge 1 }
Check "No API token mounted in frontend/backend/redis" {
    $vals = foreach ($w in 'deployment/frontend','deployment/backend','statefulset/redis') {
        kubectl -n $ns get $w -o jsonpath='{.spec.template.spec.automountServiceAccountToken}' 2>$null
    }
    (@($vals | Where-Object { $_ -eq 'false' })).Count -eq 3
}
Check "A random pod can NOT reach redis or backend"   {
    # only meaningful if the targets exist and the probe pod really runs
    kubectl -n $ns get svc redis backend *> $null
    if ($LASTEXITCODE -ne 0) { return $false }
    kubectl -n $ns run np-probe --image=busybox:1.36 --restart=Never --labels=app=np-probe -- sleep 120 *> $null
    kubectl -n $ns wait --for=condition=Ready pod/np-probe --timeout=90s *> $null
    $started = ($LASTEXITCODE -eq 0)
    kubectl -n $ns exec np-probe -- nc -z -w 2 redis 6379 *> $null;  $r = $LASTEXITCODE
    kubectl -n $ns exec np-probe -- nc -z -w 2 backend 9898 *> $null; $b = $LASTEXITCODE
    kubectl -n $ns delete pod np-probe --now *> $null
    $started -and ($r -ne 0) -and ($b -ne 0)
}

Write-Host "`nScore: $score / $total`n" -ForegroundColor Cyan
