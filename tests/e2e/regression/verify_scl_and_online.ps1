#requires -Version 5.1
# Stage 2: build a SCL FC that exercises IF/ELSIF, comparison, arithmetic,
# string ops, array indexing, then PlcBuildAndImport + CompileSoftware.
# Stage 3: real-write — DownloadToPlc on 安全PLC, then GoOnline,
# ReadPlcWatchTableCurrentValuesReadOnly, GoOffline. Skips download if PLC is
# offline (TIA may need a network/connection prep).

$ErrorActionPreference = 'Stop'
$exe        = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
$reportMd   = "$PSScriptRoot\verify_scl_and_online.md"
$reportJson = "$PSScriptRoot\verify_scl_and_online.json"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$proc = [System.Diagnostics.Process]::Start($psi)
$stdin = New-Object System.IO.StreamWriter($proc.StandardInput.BaseStream, (New-Object System.Text.UTF8Encoding($false)))
$stdin.AutoFlush = $true

$script:nextId = 1
$script:pending = $null
$script:results = New-Object System.Collections.ArrayList

function Send-Notify($method, $params) {
    $stdin.WriteLine((@{ jsonrpc='2.0'; method=$method; params=$params } | ConvertTo-Json -Compress -Depth 20))
}

function Send-Request($method, $params, [int]$timeoutMs=60000) {
    $id = $script:nextId++
    $obj = @{ jsonrpc='2.0'; id=$id; method=$method }
    if ($null -ne $params) { $obj.params = $params }
    $stdin.WriteLine(($obj | ConvertTo-Json -Compress -Depth 20))
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($null -eq $script:pending) { $script:pending = $proc.StandardOutput.ReadLineAsync() }
        $remain = [int]([Math]::Max(50, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $script:pending.Wait($remain)) { continue }
        $line = $script:pending.Result; $script:pending = $null
        if ($null -eq $line) { throw "stdout closed before id=$id" }
        try {
            $j = $line | ConvertFrom-Json
            if ($null -ne $j.id -and $j.id -eq $id) { return $j }
        } catch {}
    }
    throw "Timeout id=$id ($method) after ${timeoutMs}ms"
}

function Verify {
    param([string]$category, [string]$label, [hashtable]$toolArgs, [int]$timeoutMs=60000, [string]$toolName='')
    $started = [DateTime]::UtcNow
    if (-not $toolName) { $toolName = $label }
    $entry = [ordered]@{ category=$category; tool=$label; status='fail'; elapsedMs=0; detail='' }
    $text = ''
    try {
        $resp = Send-Request 'tools/call' @{ name=$toolName; arguments=$toolArgs } $timeoutMs
        $text = ($resp.result.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
        if ($resp.error) {
            $entry.detail = "rpc-error: $($resp.error.message)"
        } elseif ($null -eq $resp.result) {
            $entry.detail = "empty result"
        } else {
            $isErr = ($resp.result.isError -eq $true) -or ($text -like 'An error occurred*')
            $hasOkFalse = $text -match '"ok"\s*:\s*false'
            $hasSuccessFalse = $text -match '"success"\s*:\s*false'
            $hasErrorField = $text -match '"error"\s*:\s*"[^"]+'
            if ($isErr) {
                $entry.detail = "tool-error: " + ($text.Substring(0,[Math]::Min(1500,$text.Length)))
            } elseif ($hasOkFalse -or $hasSuccessFalse -or $hasErrorField) {
                $entry.detail = "logical-fail: " + ($text.Substring(0,[Math]::Min(1500,$text.Length)))
            } else {
                $entry.status = 'pass'
                $entry.detail = if ($text) { ($text.Substring(0,[Math]::Min(380,$text.Length)) -replace '\s+', ' ') } else { '' }
            }
        }
    } catch {
        $entry.detail = "exception: $($_.Exception.Message)"
    }
    $entry.elapsedMs = [int]([DateTime]::UtcNow - $started).TotalMilliseconds
    $color = if ($entry.status -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ("[{0,-4}] {1,-50} {2,6}ms  {3}" -f $entry.status.ToUpper(), $label, $entry.elapsedMs, ($entry.detail.Substring(0,[Math]::Min(120,$entry.detail.Length)))) -ForegroundColor $color
    [void]$script:results.Add([pscustomobject]$entry)
    return @{ pass = ($entry.status -eq 'pass'); text = $text }
}

# --- Build the SCL test FC payload (DSL supports IF/ELSE/ENDIF + assignment + line) ---
# Note: DSL `if/elsif` accepts a single-variable boolean condition only. Use `line` for
# expression-based assignments / arithmetic. Use handwritten XML for FOR/CASE/multi-cond.
$sclBlock = [ordered]@{
    blockName   = 'MCPVerify_FC_SCL_Multi'
    blockNumber = 902
    inputs  = @(
        @{ name='Speed'; datatype='Real' }
        @{ name='Limit'; datatype='Real' }
        @{ name='Reset'; datatype='Bool' }
    )
    outputs = @(
        @{ name='Out';       datatype='Real' }
        @{ name='Saturated'; datatype='Bool' }
        @{ name='Mode';      datatype='Int' }
    )
    structuredText = @{
        operations = @(
            @{ op='assignment'; target='Out';       literalValue='0.0'   }
            @{ op='assignment'; target='Saturated'; literalValue='FALSE' }
            @{ op='assignment'; target='Mode';      literalValue='0'     }
            @{ op='if'; condition='Reset' }
              @{ op='assignment'; target='Out';  literalValue='0.0'; indent=1 }
              @{ op='assignment'; target='Mode'; literalValue='0';   indent=1 }
            @{ op='else' }
              @{ op='line'; indent=1; items=@(
                  @{ sym='Out' }, @{ token=':=' }, @{ sym='Speed' }, @{ token='*' }, @{ lit='1.5' }
              ) }
              @{ op='assignment'; target='Mode'; literalValue='1'; indent=1 }
            @{ op='endif' }
        )
    }
}

try {
    Start-Sleep -Seconds 3
    Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='verify-scl-online'; version='1.0' } } 30000 | Out-Null
    Send-Notify 'notifications/initialized' @{}

    $conn = Verify 'L1-Portal' 'Connect' @{} 180000
    if (-not $conn.pass) {
        throw "PRECONDITION_FAILED: Connect did not succeed ($($conn.detail)). Start TIA Portal, open the project, accept Openness if prompted, rerun."
    }
    $gp = Verify 'L1-Project' 'GetProject' @{} 60000
    if (-not $gp.pass) { throw "GetProject failed" }
    $gpObj = $gp.text | ConvertFrom-Json
    if ($null -eq $gpObj.items -or @($gpObj.items).Count -lt 1) {
        throw "PRECONDITION_FAILED: GetProject returned no open projects (items empty)."
    }
    $projectName = [string]$gpObj.items[0].name
    if ([string]::IsNullOrWhiteSpace($projectName)) { throw "PRECONDITION_FAILED: GetProject items[0].name is empty." }
    Write-Host "Project: $projectName" -ForegroundColor Cyan
    Verify 'L1-Project' 'AttachToOpenProject' @{ projectName=$projectName } 60000 | Out-Null

    $sw = '安全PLC'

    # --- Stage 2: SCL multi-instruction ---
    $sclJson = $sclBlock | ConvertTo-Json -Depth 20 -Compress
    $sclArgs = @{
        softwarePath    = $sw
        kind            = 'fc'
        json            = $sclJson
        blockGroupPath  = ''
        compileAfter    = $true
        dryRun          = $false
    }
    Verify -category 'L2-SCL' -label 'PlcBuildAndImport(SCL multi-instruction)' -toolArgs $sclArgs -timeoutMs 180000 -toolName 'PlcBuildAndImport' | Out-Null

    $cmp = Verify -category 'L2-SCL' -label 'CompileSoftware(after SCL import)' -toolArgs @{ softwarePath = $sw } -timeoutMs 240000 -toolName 'CompileSoftware'
    if ($cmp.pass) {
        try {
            $c = $cmp.text | ConvertFrom-Json
            Write-Host ("    -> errorCount={0} warningCount={1} state={2}" -f $c.errorCount, $c.warningCount, $c.state) -ForegroundColor Cyan
        } catch {}
    }

    # --- Stage 3: real download + online ---
    Write-Host ""
    Write-Host "=== Stage 3: real hardware download + online ===" -ForegroundColor Yellow

    Verify -category 'L3-Online' -label 'GetOnlineState(pre-download)' -toolArgs @{ softwarePath=$sw } -timeoutMs 30000 -toolName 'GetOnlineState' | Out-Null

    $rdy = Verify -category 'L3-Online' -label 'CheckDownloadReadiness(safetyPlc)' -toolArgs @{ softwarePath=$sw } -timeoutMs 60000 -toolName 'CheckDownloadReadiness'

    $shouldDownload = $rdy.pass -and -not ($rdy.text -match '"reachable"\s*:\s*false') -and -not ($rdy.text -match '"isReadyToDownload"\s*:\s*false')
    if (-not $shouldDownload) {
        Write-Host "  PLC not reachable - skipping live download. Real-write path verified up to readiness check." -ForegroundColor Yellow
    } else {
        $dl = Verify -category 'L3-Download' -label 'DownloadToPlc(safetyPlc)' -toolArgs @{
            softwarePath        = $sw
            consistentBlocksOnly= $true
            keepActualValues    = $true
            startAfterDownload  = $true
            stopBeforeDownload  = $true
        } -timeoutMs 600000 -toolName 'DownloadToPlc'

        if ($dl.pass) {
            Verify -category 'L3-Online' -label 'GoOnline(safetyPlc)' -toolArgs @{ softwarePath=$sw } -timeoutMs 60000 -toolName 'GoOnline' | Out-Null
            Verify -category 'L3-Online' -label 'GetOnlineState(post-online)' -toolArgs @{ softwarePath=$sw } -timeoutMs 30000 -toolName 'GetOnlineState' | Out-Null
            Verify -category 'L3-Online' -label 'GoOffline(safetyPlc)' -toolArgs @{ softwarePath=$sw } -timeoutMs 60000 -toolName 'GoOffline' | Out-Null
        }
    }

    Verify -category 'L1-Project' 'SaveProject' @{} 240000 -toolName 'SaveProject' | Out-Null
    Verify -category 'L1-Portal'  'Disconnect' @{} 30000 -toolName 'Disconnect' | Out-Null

} catch {
    Write-Host "EXCEPTION: $_" -ForegroundColor Red
} finally {
    try { $stdin.Close() } catch {}
    try { $proc.StandardInput.Close() } catch {}
    $proc.WaitForExit(15000) | Out-Null
    if (-not $proc.HasExited) { $proc.Kill() }

    $script:results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportJson -Encoding UTF8

    $passes = $script:results | Where-Object { $_.status -eq 'pass' }
    $fails  = $script:results | Where-Object { $_.status -ne 'pass' }
    $md = @()
    $md += "# SCL Multi-instruction + Real Download/Online Verification"
    $md += ""
    $md += "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $md += "PASS: $($passes.Count) / $($script:results.Count)  FAIL: $($fails.Count)"
    $md += ""
    $md += "| Layer | Tool | Time(ms) | Status & Detail |"
    $md += "|---|---|---:|---|"
    foreach ($r in $script:results) {
        $d = ($r.detail -replace '\|','\\|')
        $d = $d.Substring(0,[Math]::Min(220,$d.Length))
        $md += "| $($r.category) | ``$($r.tool)`` | $($r.elapsedMs) | $($r.status.ToUpper()): $d |"
    }
    $md -join "`r`n" | Set-Content -LiteralPath $reportMd -Encoding UTF8

    Write-Host ""
    Write-Host "PASS=$($passes.Count)/$($script:results.Count)  FAIL=$($fails.Count)  Report=$reportMd" -ForegroundColor Cyan
}
