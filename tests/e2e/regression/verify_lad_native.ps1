#requires -Version 5.1
# Stage 1 verification: import a hand-crafted LAD FC with 7 native-instruction
# networks (Contact-series, Contact-parallel, SCoil, RCoil, Compare-Gt, Move,
# Add) into the user-authorized 安全PLC, then CompileSoftware and require
# errorCount=0.

$ErrorActionPreference = 'Stop'
$exe        = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
$ladXml     = "C:\Users\XL626\Desktop\testtia\lad_native_verify\MCPVerify_FC_LAD.xml"
$reportMd   = "$PSScriptRoot\verify_lad_native.md"
$reportJson = "$PSScriptRoot\verify_lad_native.json"

if (-not (Test-Path $ladXml)) { throw "Missing LAD XML: $ladXml" }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
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

function Verify($category, $label, $toolArgs, [int]$timeoutMs=60000, [string]$toolName="") {
    $started = [DateTime]::UtcNow
    if (-not $toolName) { $toolName = $label }
    $entry = [ordered]@{ category=$category; tool=$label; status='fail'; elapsedMs=0; detail='' }
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
                $entry.detail = if ($text) { ($text.Substring(0,[Math]::Min(260,$text.Length)) -replace '\s+', ' ') } else { '' }
            }
        }
    } catch {
        $entry.detail = "exception: $($_.Exception.Message)"
    }
    $entry.elapsedMs = [int]([DateTime]::UtcNow - $started).TotalMilliseconds
    $color = if ($entry.status -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ("[{0,-4}] {1,-30} {2,6}ms  {3}" -f $entry.status.ToUpper(), $label, $entry.elapsedMs, $entry.detail.Substring(0,[Math]::Min(120,$entry.detail.Length))) -ForegroundColor $color
    [void]$script:results.Add([pscustomobject]$entry)
    return @{ pass = ($entry.status -eq 'pass'); text = $text }
}

try {
    Start-Sleep -Seconds 3
    Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='verify-lad-native'; version='1.0' } } 30000 | Out-Null
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

    # Where to put the LAD FC: Program blocks root group
    $imp = Verify -category 'L1-PLC' -label 'ImportBlock(MCPVerify_FC_LAD.xml LAD native)' -toolArgs @{
        softwarePath = $sw
        groupPath    = ''
        importPath   = $ladXml
    } -timeoutMs 120000 -toolName 'ImportBlock'

    Verify -category 'L1-PLC' -label 'GetBlocks(post-import)' -toolArgs @{
        softwarePath = $sw
        namePattern  = 'MCPVerify_*'
    } -timeoutMs 30000 -toolName 'GetBlocks' | Out-Null

    $cmp = Verify -category 'L1-PLC' -label 'CompileSoftware(after LAD import)' -toolArgs @{
        softwarePath = $sw
    } -timeoutMs 240000 -toolName 'CompileSoftware'
    if ($cmp.pass) {
        try {
            $cobj = $cmp.text | ConvertFrom-Json
            Write-Host ("    -> errorCount={0} warningCount={1} state={2}" -f $cobj.errorCount, $cobj.warningCount, $cobj.state) -ForegroundColor Cyan
            if ($cobj.errorCount -gt 0) {
                Write-Host "    !! errors > 0; compile messages:" -ForegroundColor Red
                $cobj.messages | Select-Object -First 10 | ForEach-Object { Write-Host "       $_" -ForegroundColor Red }
            }
        } catch {}
    }

    Verify 'L1-Project' 'SaveProject' @{} 240000 | Out-Null
    Verify 'L1-Portal'  'Disconnect' @{} 30000 | Out-Null

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
    $md += "# LAD Native Instruction Verification"
    $md += ""
    $md += "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $md += "PASS: $($passes.Count) / $($script:results.Count)"
    $md += "FAIL: $($fails.Count)"
    $md += ""
    $md += "| Layer | Tool | Time(ms) | Detail |"
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
