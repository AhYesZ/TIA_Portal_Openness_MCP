#requires -Version 5.1
# Real-write E2E verification against the user-authorized 安全PLC inside
# the open TIA Portal project '综合测试项目V21-260511'.
# Strategy: attach → list devices → pick the device named like 安全PLC →
# real PlcBuildAndImport (no dryRun) with MCPVerify_ prefix so user can prune.
# DOES NOT call DownloadToPlc / GoOnline (no real hardware was authorized).

$ErrorActionPreference = 'Stop'

$exe        = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
$reportMd   = "$PSScriptRoot\verify_safetyplc_writes.md"
$reportJson = "$PSScriptRoot\verify_safetyplc_writes.json"

# Project name is auto-detected from GetProject after Connect — do not hardcode.
$attachProject = $null

# spawn server
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $exe
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
# Note: ProcessStartInfo.StandardInputEncoding does NOT exist on .NET Framework
# (only on .NET Core). The default StandardInput writer uses the system code page,
# which corrupts Chinese characters. Wrap BaseStream in a fresh UTF-8 StreamWriter.
$proc = [System.Diagnostics.Process]::Start($psi)
$stdinUtf8 = New-Object System.IO.StreamWriter(
    $proc.StandardInput.BaseStream,
    (New-Object System.Text.UTF8Encoding($false))
)
$stdinUtf8.AutoFlush = $true

$script:nextId  = 1
$script:results = New-Object System.Collections.ArrayList
$script:pendingReadTask = $null

function Send-Notify($method, $params) {
    $msg = @{ jsonrpc='2.0'; method=$method; params=$params } | ConvertTo-Json -Compress -Depth 20
    $stdinUtf8.WriteLine($msg)
}

function Send-Request($method, $params, [int]$timeoutMs=30000) {
    $id  = $script:nextId++
    $obj = @{ jsonrpc='2.0'; id=$id; method=$method }
    if ($null -ne $params) { $obj.params = $params }
    $msg = $obj | ConvertTo-Json -Compress -Depth 20
    $stdinUtf8.WriteLine($msg)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    while ([DateTime]::UtcNow -lt $deadline) {
        # Cache the pending ReadLineAsync — never start a 2nd one before consuming the 1st.
        if ($null -eq $script:pendingReadTask) {
            $script:pendingReadTask = $proc.StandardOutput.ReadLineAsync()
        }
        $remain = [int]([Math]::Max(50, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $script:pendingReadTask.Wait($remain)) { continue }
        $line = $script:pendingReadTask.Result
        $script:pendingReadTask = $null
        if ($null -eq $line) { throw "stdout closed before id=$id" }
        try {
            $j = $line | ConvertFrom-Json
            if ($null -ne $j.id -and $j.id -eq $id) { return $j }
        } catch {}
    }
    throw "Timeout id=$id ($method) after ${timeoutMs}ms"
}

function Get-RespText($resp) {
    if ($null -eq $resp -or $null -eq $resp.result) { return $null }
    return ($resp.result.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
}

function Verify($category, $label, $toolArgs, [int]$timeoutMs=60000, [string]$mustContain="", [string]$toolName="") {
    $started = [DateTime]::UtcNow
    if (-not $toolName) { $toolName = $label }
    $entry = [ordered]@{ category=$category; tool=$label; status='fail'; elapsedMs=0; detail='' }
    try {
        $resp = Send-Request 'tools/call' @{ name=$toolName; arguments=$toolArgs } $timeoutMs
        $text = Get-RespText $resp
        if ($resp.error) {
            $entry.detail = "rpc-error: $($resp.error.message)"
        } elseif ($null -eq $resp.result) {
            $entry.detail = "empty result"
        } else {
            $isErr = ($resp.result.isError -eq $true) -or ($text -like 'An error occurred*')
            $hasOkFalse      = $text -match '"ok"\s*:\s*false'
            $hasSuccessFalse = $text -match '"success"\s*:\s*false'
            $hasErrorField   = $text -match '"error"\s*:\s*"[^"]+'
            if ($isErr) {
                $entry.detail = "tool-error: " + ($text.Substring(0,[Math]::Min(240,$text.Length)))
            } elseif ($hasOkFalse -or $hasSuccessFalse -or $hasErrorField) {
                $entry.detail = "logical-fail: " + ($text.Substring(0,[Math]::Min(240,$text.Length)))
            } elseif ($mustContain -ne "" -and $text -notmatch [regex]::Escape($mustContain)) {
                $entry.detail = "missing pattern '$mustContain' in: " + ($text.Substring(0,[Math]::Min(240,$text.Length)))
            } else {
                $entry.status = 'pass'
                $snippet = if ($text) { $text.Substring(0,[Math]::Min(220,$text.Length)) -replace '\s+', ' ' } else { '' }
                $entry.detail = $snippet
            }
        }
    } catch {
        $entry.detail = "exception: $($_.Exception.Message)"
    }
    $entry.elapsedMs = [int]([DateTime]::UtcNow - $started).TotalMilliseconds
    $color = if ($entry.status -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ("[{0,-4}] {1,-30} {2,6}ms  {3}" -f $entry.status.ToUpper(), $tool, $entry.elapsedMs, $entry.detail.Substring(0,[Math]::Min(120,$entry.detail.Length))) -ForegroundColor $color
    [void]$script:results.Add([pscustomobject]$entry)
    return @{ pass = ($entry.status -eq 'pass'); text = $text }
}

try {
    Start-Sleep -Seconds 3
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='verify-safetyplc'; version='1.0' } } 30000
    Write-Host "[init] server=$($init.result.serverInfo.name) v$($init.result.serverInfo.version)" -ForegroundColor Cyan
    Send-Notify 'notifications/initialized' @{}

    Verify 'L1-Portal'  'Connect'             @{} 180000 | Out-Null

    # Auto-detect the real internal project Name (TIA window title may differ from Project.Name).
    $gp = Verify 'L1-Project' 'GetProject' @{} 60000
    if (-not $gp.pass) { throw "GetProject failed; cannot detect attach target" }
    # Parse the JSON text so \uXXXX escapes are decoded to real Chinese characters.
    try {
        $gpObj = $gp.text | ConvertFrom-Json
        $attachProject = $gpObj.items[0].name
    } catch {
        throw "Failed to parse GetProject JSON: $($_.Exception.Message)"
    }
    if (-not $attachProject) { throw "Could not parse project name from GetProject response" }
    Write-Host "Auto-detected project Name: '$attachProject'" -ForegroundColor Green

    $att = Verify 'L1-Project' 'AttachToOpenProject' @{ projectName=$attachProject } 60000
    if (-not $att.pass) { throw "Could not attach to '$attachProject'" }

    $treeR = Verify 'L1-Project'  'GetProjectTree' @{} 60000
    Verify 'L1-Hardware' 'GetDevices' @{} 60000 | Out-Null

    # Parse the project tree for "PlcSoftware: <name>" lines — that's what softwarePath wants.
    # Prefer one whose name contains "安全" (user-authorized safety PLC).
    $safetyDevice = $null
    if ($treeR.pass) {
        $treeStr = ($treeR.text | ConvertFrom-Json).tree
        $plcMatches = [regex]::Matches($treeStr, 'PlcSoftware:\s*([^\s\[]+)')
        $allPlcs = @($plcMatches | ForEach-Object { $_.Groups[1].Value })
        Write-Host ""; Write-Host "Discovered PLC software nodes: $($allPlcs -join ', ')" -ForegroundColor Cyan
        $safetyDevice = $allPlcs | Where-Object { $_ -match '安全' } | Select-Object -First 1
        if (-not $safetyDevice) { $safetyDevice = $allPlcs | Select-Object -First 1 }
    }
    if (-not $safetyDevice) { throw "Could not locate any PLC software node in project tree." }
    Write-Host "Using softwarePath: '$safetyDevice'" -ForegroundColor Green

    # Inspect
    Verify 'L1-PLC' 'GetSoftwareInfo' @{ softwarePath=$safetyDevice } 60000 | Out-Null
    $sw = Verify 'L1-PLC' 'GetSoftwareTree' @{ softwarePath=$safetyDevice } 60000
    Verify 'L1-PLC' 'GetBlocks'       @{ softwarePath=$safetyDevice } 60000 | Out-Null

    # ---- REAL WRITES with MCPVerify_ prefix so user can identify and delete later ----
    $tagJson = '{"tableName":"MCPVerify_Tags","tags":[{"name":"MCPVerify_Start","dataTypeName":"Bool","logicalAddress":"%M200.0"},{"name":"MCPVerify_Stop","dataTypeName":"Bool","logicalAddress":"%M200.1"},{"name":"MCPVerify_Out","dataTypeName":"Bool","logicalAddress":"%M200.2"}]}'
    Verify 'L1-PLC-Build' 'PlcBuildAndImport(tagtable real)' @{
        softwarePath=$safetyDevice; kind='tagtable'; json=$tagJson; dryRun=$false; compileAfter=$false
    } 90000 "" 'PlcBuildAndImport' | Out-Null

    $dbJson = '{"dbName":"MCPVerify_DB","dbNumber":900,"staticMembers":[{"name":"Counter","datatype":"Int","startValue":"0","commentZhCn":"计数"},{"name":"Active","datatype":"Bool","startValue":"FALSE","commentZhCn":"激活"}]}'
    Verify 'L1-PLC-Build' 'PlcBuildAndImport(globaldb real)' @{
        softwarePath=$safetyDevice; kind='globaldb'; json=$dbJson; dryRun=$false; compileAfter=$false
    } 90000 "" 'PlcBuildAndImport' | Out-Null

    $fcJson = '{"blockName":"MCPVerify_FC","blockNumber":900,"commentZhCn":"MCP 验证用 FC","titleZhCn":"起保停","networkTitleZhCn":"主网络","networkCommentZhCn":"急停>停止>启动","inputs":[],"outputs":[],"structuredText":{"operations":[{"op":"if","condition":"\"MCPVerify_Stop\""},{"op":"assignment","target":"\"MCPVerify_Out\"","literalValue":"FALSE","indent":2},{"op":"elsif","condition":"\"MCPVerify_Start\""},{"op":"assignment","target":"\"MCPVerify_Out\"","literalValue":"TRUE","indent":2},{"op":"endif"}]}}'
    Verify 'L1-PLC-Build' 'PlcBuildAndImport(fc real)' @{
        softwarePath=$safetyDevice; kind='fc'; json=$fcJson; dryRun=$false; compileAfter=$false
    } 90000 "" 'PlcBuildAndImport' | Out-Null

    Verify 'L1-PLC' 'GetBlocks(after-write)' @{ softwarePath=$safetyDevice; namePattern='MCPVerify_*' } 30000 "" 'GetBlocks' | Out-Null

    Verify 'L1-PLC' 'CompileSoftware(real)' @{ softwarePath=$safetyDevice } 240000 "" 'CompileSoftware' | Out-Null

    # Real-hardware readiness probes (read-only — safe even without a CPU plugged in)
    Verify 'L2-Online' 'CheckDownloadReadiness' @{ softwarePath=$safetyDevice } 30000 | Out-Null
    Verify 'L2-Online' 'GetOnlineState'         @{ softwarePath=$safetyDevice } 30000 | Out-Null

    # Persist (this is the only call that touches disk on the real project)
    Verify 'L1-Project' 'SaveProject' @{} 240000 | Out-Null

    Verify 'L0' 'GetState' @{} 5000 | Out-Null
    Verify 'L1-Portal' 'Disconnect' @{} 30000 | Out-Null

} catch {
    Write-Host "EXCEPTION: $_" -ForegroundColor Red
} finally {
    try { $stdinUtf8.Close() } catch {}
    try { $proc.StandardInput.Close() } catch {}
    $proc.WaitForExit(30000) | Out-Null
    if (-not $proc.HasExited) { $proc.Kill() }

    $script:results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportJson -Encoding UTF8
    $passes = $script:results | Where-Object { $_.status -eq 'pass' }
    $fails  = $script:results | Where-Object { $_.status -ne 'pass' }

    $md = @()
    $md += "# Safety-PLC Real-Write Verification"
    $md += ""
    $md += "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $md += "Project: ``$attachProject``"
    $md += "Pass: $($passes.Count) / $($script:results.Count)"
    $md += ""
    $md += "## PASS"
    $md += ""
    $md += "| Layer | Tool | Time(ms) | Sample |"
    $md += "|---|---|---:|---|"
    foreach ($r in $passes) {
        $d = ($r.detail -replace '\|','\\|')
        $d = $d.Substring(0,[Math]::Min(140,$d.Length))
        $md += "| $($r.category) | ``$($r.tool)`` | $($r.elapsedMs) | $d |"
    }
    if ($fails.Count -gt 0) {
        $md += ""
        $md += "## FAIL"
        $md += ""
        $md += "| Layer | Tool | Detail |"
        $md += "|---|---|---|"
        foreach ($r in $fails) {
            $d = ($r.detail -replace '\|','\\|')
            $d = $d.Substring(0,[Math]::Min(260,$d.Length))
            $md += "| $($r.category) | ``$($r.tool)`` | $d |"
        }
    }
    $md -join "`r`n" | Set-Content -LiteralPath $reportMd -Encoding UTF8

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "PASS: $($passes.Count) / $($script:results.Count)" -ForegroundColor Green
    Write-Host "FAIL: $($fails.Count)" -ForegroundColor $(if ($fails.Count -eq 0) {'Green'} else {'Red'})
    Write-Host "Report: $reportMd"
    Write-Host "============================================" -ForegroundColor Cyan
}
