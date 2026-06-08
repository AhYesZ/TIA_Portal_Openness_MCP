#requires -Version 5.1
# Stage 1c: Lt FC + FB(TON Static+PBox+Not+Lt) on 安全PLC. Timer must be FB.Static/DB — not FC.Temp (F-CPU).

$ErrorActionPreference = 'Stop'
$tiaportalRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$exe = Join-Path $tiaportalRoot 'src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Missing TiaMcpServer.exe (build Release first): $exe" }
$srcXml = Join-Path $tiaportalRoot 'skill\lad-cookbook\MCPVerify_FC_LAD_v3.xml'
$srcFb  = Join-Path $tiaportalRoot 'skill\lad-cookbook\MCPVerify_FB_LAD_v3.xml'
if (-not (Test-Path -LiteralPath $srcXml)) { throw "Missing LAD XML: $srcXml" }
if (-not (Test-Path -LiteralPath $srcFb)) { throw "Missing LAD FB XML: $srcFb" }
$staging = Join-Path $env:TEMP 'tiaportal-mcp-verify'
New-Item -ItemType Directory -Force -Path $staging | Out-Null
$xml = Join-Path $staging 'MCPVerify_FC_LAD_v3.xml'
$fbXml = Join-Path $staging 'MCPVerify_FB_LAD_v3.xml'
Copy-Item -LiteralPath $srcXml -Destination $xml -Force
Copy-Item -LiteralPath $srcFb -Destination $fbXml -Force
$reportMd   = "$PSScriptRoot\verify_lad_v3.md"
$reportJson = "$PSScriptRoot\verify_lad_v3.json"

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
    $stdin.WriteLine((@{ jsonrpc='2.0'; method=$method; params=$params } | ConvertTo-Json -Compress -Depth 30))
}
function Send-Request($method, $params, [int]$timeoutMs=60000) {
    $id = $script:nextId++
    $obj = @{ jsonrpc='2.0'; id=$id; method=$method }
    if ($null -ne $params) { $obj.params = $params }
    $stdin.WriteLine(($obj | ConvertTo-Json -Compress -Depth 30))
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
        if ($resp.error) { $entry.detail = "rpc-error: $($resp.error.message)" }
        elseif ($null -eq $resp.result) { $entry.detail = "empty result" }
        else {
            $isErr = ($resp.result.isError -eq $true) -or ($text -like 'An error occurred*')
            $hasOkFalse = $text -match '"ok"\s*:\s*false'
            $hasSuccessFalse = $text -match '"success"\s*:\s*false'
            $hasErrorField = $text -match '"error"\s*:\s*"[^"]+'
            if ($isErr) { $entry.detail = "tool-error: " + ($text.Substring(0,[Math]::Min(2000,$text.Length))) }
            elseif ($hasOkFalse -or $hasSuccessFalse -or $hasErrorField) { $entry.detail = "logical-fail: " + ($text.Substring(0,[Math]::Min(2000,$text.Length))) }
            else {
                $entry.status = 'pass'
                $entry.detail = if ($text) { ($text.Substring(0,[Math]::Min(380,$text.Length)) -replace '\s+', ' ') } else { '' }
            }
        }
    } catch { $entry.detail = "exception: $($_.Exception.Message)" }
    $entry.elapsedMs = [int]([DateTime]::UtcNow - $started).TotalMilliseconds
    $color = if ($entry.status -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ("[{0,-4}] {1,-46} {2,6}ms  {3}" -f $entry.status.ToUpper(), $label, $entry.elapsedMs, ($entry.detail.Substring(0,[Math]::Min(140,$entry.detail.Length)))) -ForegroundColor $color
    [void]$script:results.Add([pscustomobject]$entry)
    return @{ pass = ($entry.status -eq 'pass'); text = $text }
}

try {
    Start-Sleep -Seconds 3
    Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='verify-lad-v3'; version='1.0' } } 30000 | Out-Null
    Send-Notify 'notifications/initialized' @{}

    $conn = Verify -category 'L1-Portal' -label 'Connect' -toolArgs @{} -timeoutMs 180000 -toolName 'Connect'
    if (-not $conn.pass) {
        throw "PRECONDITION_FAILED: Connect did not succeed ($($conn.detail)). Start TIA Portal, open the project, accept Openness if prompted, rebuild Release TiaMcpServer.exe, rerun."
    }
    $gp = Verify -category 'L1-Project' -label 'GetProject' -toolArgs @{} -timeoutMs 60000 -toolName 'GetProject'
    if (-not $gp.pass) { throw "GetProject failed" }
    $gpObj = $gp.text | ConvertFrom-Json
    if ($null -eq $gpObj.items -or @($gpObj.items).Count -lt 1) {
        throw "PRECONDITION_FAILED: GetProject returned no open projects (items empty). In TIA: File -> Open and keep the project open."
    }
    $projectName = [string]$gpObj.items[0].name
    if ([string]::IsNullOrWhiteSpace($projectName)) { throw "PRECONDITION_FAILED: GetProject items[0].name is empty." }
    $att = Verify -category 'L1-Project' -label 'AttachToOpenProject' -toolArgs @{ projectName=$projectName } -timeoutMs 60000 -toolName 'AttachToOpenProject'
    if (-not $att.pass) { throw "AttachToOpenProject failed: $($att.detail)" }

    $plc = '安全PLC'
    $imp = Verify -category 'L2-PLC' -label "ImportBlock(MCPVerify_FC_LAD_v3.xml)" -toolArgs @{
        softwarePath=$plc; groupPath=''; importPath=$xml
    } -timeoutMs 60000 -toolName 'ImportBlock'
    if (-not $imp.pass) { throw "ImportBlock FC failed: $($imp.detail)" }

    $impFb = Verify -category 'L2-PLC' -label "ImportBlock(MCPVerify_FB_LAD_v3.xml)" -toolArgs @{
        softwarePath=$plc; groupPath=''; importPath=$fbXml
    } -timeoutMs 60000 -toolName 'ImportBlock'
    if (-not $impFb.pass) { throw "ImportBlock FB failed: $($impFb.detail)" }

    Verify -category 'L2-PLC' -label "GetBlocks(post-import)" -toolArgs @{ softwarePath=$plc; groupPath='' } -timeoutMs 30000 -toolName 'GetBlocks' | Out-Null
    $cmp = Verify -category 'L2-PLC' -label "CompileSoftware($plc)" -toolArgs @{ softwarePath=$plc } -timeoutMs 240000 -toolName 'CompileSoftware'
    if (-not $cmp.pass) {
        Verify -category 'L2-PLC' -label "CompileAndDiagnosePlc($plc)" -toolArgs @{ softwarePath=$plc } -timeoutMs 240000 -toolName 'CompileAndDiagnosePlc' | Out-Null
    }
    if ($cmp.pass) {
        try {
            $jo = $cmp.text | ConvertFrom-Json
            $ec = [int]$jo.errorCount
            if ($ec -gt 0) {
                [void]$script:results.Add([pscustomobject]@{
                    category='L2-PLC'; tool='CompileSoftware(errorCount=0)'; status='fail'; elapsedMs=0
                    detail = "errorCount=$ec (LAD v3 FC+FB must compile clean)"
                })
            }
        } catch { }
    }

    Verify -category 'L1-Project' -label 'SaveProject' -toolArgs @{} -timeoutMs 240000 -toolName 'SaveProject' | Out-Null
    Verify -category 'L1-Portal'  -label 'Disconnect'  -toolArgs @{} -timeoutMs 30000  -toolName 'Disconnect' | Out-Null
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
    $md += "# LAD v3 Verification (FC Lt + FB TON Static / PBox / Not / Lt on 安全PLC)"
    $md += ""
    $md += "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $md += "PASS: $($passes.Count) / $($script:results.Count)  FAIL: $($fails.Count)"
    $md += ""
    $md += "| Layer | Tool | Time(ms) | Status & Detail |"
    $md += "|---|---|---:|---|"
    foreach ($r in $script:results) {
        $d = ($r.detail -replace '\|','\\|').Substring(0,[Math]::Min(220,($r.detail -replace '\|','\\|').Length))
        $md += "| $($r.category) | ``$($r.tool)`` | $($r.elapsedMs) | $($r.status.ToUpper()): $d |"
    }
    $md -join "`r`n" | Set-Content -LiteralPath $reportMd -Encoding UTF8
    Write-Host ""
    Write-Host "PASS=$($passes.Count)/$($script:results.Count)  FAIL=$($fails.Count)  Report=$reportMd" -ForegroundColor Cyan
}
