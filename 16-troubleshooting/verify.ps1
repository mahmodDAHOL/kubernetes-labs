# Scores your fixes. Run it as often as you like:
#   powershell -ExecutionPolicy Bypass -File .\verify.ps1

# A helper pod used to test Services from inside the cluster.
kubectl get pod checker -n default *> $null
if ($LASTEXITCODE -ne 0) {
    kubectl run checker -n default --image=busybox:1.36 --restart=Never -- sleep 86400 | Out-Null
}
kubectl wait --for=condition=Ready pod/checker -n default --timeout=60s | Out-Null

function Test-Available($ns, $deploy) {
    $want = kubectl get deploy $deploy -n $ns -o jsonpath='{.spec.replicas}' 2>$null
    $have = kubectl get deploy $deploy -n $ns -o jsonpath='{.status.availableReplicas}' 2>$null
    return ($want -and $have -eq $want)
}
function Test-Http($url, $expect) {
    $out = kubectl exec -n default checker -- wget -qO- -T 3 $url 2>$null
    return ("$out" -match $expect)
}
function Test-NoRestarts($ns, $label) {
    $r = kubectl get pods -n $ns -l $label -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}' 2>$null
    if (-not $r) { return $false }
    return (($r -split ' ' | Where-Object { [int]$_ -gt 0 }).Count -eq 0)
}
function Show($n, $title, $ok) {
    if ($ok) { Write-Host "  [PASS] $n. $title" -ForegroundColor Green; $script:score++ }
    else     { Write-Host "  [FAIL] $n. $title" -ForegroundColor Red }
}

$score = 0
Write-Host "`nTroubleshooting lab: results`n"
Show 1 "ts1: shop pods are running"                  (Test-Available ts1 shop)
Show 2 "ts2: http://api.ts2 answers"                 (Test-Http "http://api.ts2" "api is working")
Show 3 "ts3: http://web.ts3 answers"                 (Test-Http "http://web.ts3" "Welcome to nginx")
Show 4 "ts4: worker is processing queue 'orders'"    ((Test-Available ts4 worker) -and ("$(kubectl logs -n ts4 deploy/worker --tail=5 2>$null)" -match "processing queue orders"))
Show 5 "ts5: frontend is stable (no restarts)"       ((Test-Available ts5 frontend) -and (Test-NoRestarts ts5 app=frontend))
Show 6 "ts6: cache is running"                       (Test-Available ts6 cache)
Show 7 "ts7: reporter is running and sending"        ((Test-Available ts7 reporter) -and ("$(kubectl logs -n ts7 deploy/reporter --tail=5 2>$null)" -match "report sent"))
Write-Host "`nScore: $score / 7`n" -ForegroundColor Cyan
