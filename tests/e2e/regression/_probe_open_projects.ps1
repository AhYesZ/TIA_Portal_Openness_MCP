#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
$proc = [System.Diagnostics.Process]::Start($psi)
$stdin = New-Object System.IO.StreamWriter($proc.StandardInput.BaseStream, (New-Object System.Text.UTF8Encoding($false)))
$stdin.AutoFlush = $true

$id = 1
$script:pendingReadTask = $null
function Call($method, $params, [int]$timeoutMs=60000) {
    $msg = @{ jsonrpc='2.0'; id=$script:id; method=$method }
    if ($null -ne $params) { $msg.params = $params }
    $stdin.WriteLine(($msg | ConvertTo-Json -Compress -Depth 20))
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($null -eq $script:pendingReadTask) {
            $script:pendingReadTask = $proc.StandardOutput.ReadLineAsync()
        }
        $remain = [int]([Math]::Max(50, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $script:pendingReadTask.Wait($remain)) { continue }
        $line = $script:pendingReadTask.Result
        $script:pendingReadTask = $null
        if (-not $line) { continue }
        try {
            $j = $line | ConvertFrom-Json
            if ($j.id -eq $script:id) { $script:id++; return $j }
        } catch {}
    }
    throw "timeout"
}

try {
    Start-Sleep -Seconds 3
    Call 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='probe'; version='1.0' } } 30000 | Out-Null
    $stdin.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}')

    $r = Call 'tools/call' @{ name='Connect'; arguments=@{} } 180000
    Write-Host "--- Connect ---"
    Write-Host (($r.result.content | ? { $_.type -eq 'text' } | Select -First 1).text)

    $r = Call 'tools/call' @{ name='ListPortalProcessProjects'; arguments=@{} } 60000
    Write-Host ""; Write-Host "--- ListPortalProcessProjects ---"
    Write-Host (($r.result.content | ? { $_.type -eq 'text' } | Select -First 1).text)

    $r = Call 'tools/call' @{ name='GetProject'; arguments=@{} } 60000
    Write-Host ""; Write-Host "--- GetProject ---"
    Write-Host (($r.result.content | ? { $_.type -eq 'text' } | Select -First 1).text)
} finally {
    try { $stdin.Close() } catch {}
    $proc.WaitForExit(10000) | Out-Null
    if (-not $proc.HasExited) { $proc.Kill() }
}
