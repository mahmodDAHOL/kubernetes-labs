# Connectivity matrix: who can reach whom? Run after every policy change.
# Usage: powershell -ExecutionPolicy Bypass -File .\test.ps1
function Test-Conn($from, $target, $port) {
    kubectl exec -n netpol $from -- nc -z -w 2 $target $port 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $r = "ALLOWED"; $color = "Green" } else { $r = "BLOCKED"; $color = "Red" }
    Write-Host ("{0,-10} -> {1,-8}:{2,-5} {3}" -f $from, $target, $port, $r) -ForegroundColor $color
}
Test-Conn frontend backend 8080
Test-Conn frontend db      6379
Test-Conn intruder backend 8080
Test-Conn intruder db      6379
Test-Conn backend  db      6379
