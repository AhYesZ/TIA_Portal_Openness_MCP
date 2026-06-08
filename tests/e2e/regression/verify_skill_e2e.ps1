#requires -Version 5.1
# End-to-end verification of L0/L1 MCP tools against a real local TIA Portal V21.
# Strategy: attach to an EXISTING open project (no pollution), use dryRun on builders.
# Output: tests/e2e/regression/verify_skill_e2e.md  +  verify_skill_e2e.json

$ErrorActionPreference = 'Stop'

$exe        = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
$reportMd   = "$PSScriptRoot\verify_skill_e2e.md"
$reportJson = "$PSScriptRoot\verify_skill_e2e.json"

# attach target — provided by caller or auto-detect from window title
$attachProject = $env:MCP_VERIFY_PROJECT
if (-not $attachProject) {
    $portal = Get-Process Siemens.Automation.Portal -ErrorAction SilentlyContinue |
              Where-Object { $_.MainWindowTitle } | Select-Object -First 1
    if ($portal) {
        $leaf = Split-Path $portal.MainWindowTitle -Leaf
        if ($leaf) { $attachProject = $leaf }
    }
}
if (-not $attachProject) { $attachProject = 'MCP_TankCtrl_20260510_230937' }
Write-Host "Attach target: $attachProject" -ForegroundColor Cyan

# probe softwarePath candidates that may exist in the attached project
$plcCandidates = @('PLC_1','PLC_TankCtrl','TankPLC','S71200')

# spawn server
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $exe
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
$proc = [System.Diagnostics.Process]::Start($psi)

$script:nextId  = 1
$script:results = New-Object System.Collections.ArrayList

function Send-Notify($method, $params) {
    $msg = @{ jsonrpc='2.0'; method=$method; params=$params } | ConvertTo-Json -Compress -Depth 20
    $proc.StandardInput.WriteLine($msg); $proc.StandardInput.Flush()
}

function Send-Request($method, $params, [int]$timeoutMs=30000) {
    $id  = $script:nextId++
    $obj = @{ jsonrpc='2.0'; id=$id; method=$method }
    if ($null -ne $params) { $obj.params = $params }
    $msg = $obj | ConvertTo-Json -Compress -Depth 20
    $proc.StandardInput.WriteLine($msg); $proc.StandardInput.Flush()
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    while ([DateTime]::UtcNow -lt $deadline) {
        $task = $proc.StandardOutput.ReadLineAsync()
        $remain = [int]([Math]::Max(50, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $task.Wait($remain)) { continue }
        $line = $task.Result
        if ($null -eq $line) { throw "stdout closed before id=$id" }
        try {
            $j = $line | ConvertFrom-Json
            if ($null -ne $j.id -and $j.id -eq $id) { return $j }
        } catch {}
    }
    throw "Timeout id=$id ($method) after ${timeoutMs}ms"
}

# Stricter PASS judge — also looks for "ok":false / "success":false / "error" keys.
function Verify($category, $tool, $toolArgs, [int]$timeoutMs=60000, [string]$mustContain="") {
    $started = [DateTime]::UtcNow
    $entry = [ordered]@{
        category   = $category
        tool       = $tool
        status     = 'fail'
        elapsedMs  = 0
        detail     = ''
    }
    try {
        $resp = Send-Request 'tools/call' @{ name=$tool; arguments=$toolArgs } $timeoutMs
        if ($resp.error) {
            $entry.detail = "rpc-error: $($resp.error.message)"
        }
        elseif ($null -eq $resp.result) {
            $entry.detail = "empty result"
        }
        else {
            $text = ($resp.result.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
            $isErr = ($resp.result.isError -eq $true) -or ($text -like 'An error occurred*')
            $hasOkFalse      = $text -match '"ok"\s*:\s*false'
            $hasSuccessFalse = $text -match '"success"\s*:\s*false'
            $hasErrorField   = $text -match '"error"\s*:\s*"[^"]+'
            if ($isErr) {
                $entry.detail = "tool-error: " + ($text.Substring(0,[Math]::Min(220,$text.Length)))
            }
            elseif ($hasOkFalse -or $hasSuccessFalse -or $hasErrorField) {
                $entry.detail = "logical-fail: " + ($text.Substring(0,[Math]::Min(220,$text.Length)))
            }
            elseif ($mustContain -ne "" -and $text -notmatch [regex]::Escape($mustContain)) {
                $entry.detail = "missing pattern '$mustContain' in: " + ($text.Substring(0,[Math]::Min(220,$text.Length)))
            }
            else {
                $entry.status = 'pass'
                $snippet = if ($text) { $text.Substring(0,[Math]::Min(180,$text.Length)) -replace '\s+', ' ' } else { '' }
                $entry.detail = $snippet
            }
        }
    } catch {
        $entry.detail = "exception: $($_.Exception.Message)"
    }
    $entry.elapsedMs = [int]([DateTime]::UtcNow - $started).TotalMilliseconds
    $color = if ($entry.status -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ("[{0,-4}] {1,-30} {2,5}ms  {3}" -f $entry.status.ToUpper(), $tool, $entry.elapsedMs, $entry.detail.Substring(0,[Math]::Min(90,$entry.detail.Length))) -ForegroundColor $color
    [void]$script:results.Add([pscustomobject]$entry)
    return $entry.status -eq 'pass'
}

try {
    Start-Sleep -Seconds 3
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='verify-skill'; version='1.0' } } 30000
    Write-Host "[init] server=$($init.result.serverInfo.name) v$($init.result.serverInfo.version)" -ForegroundColor Cyan
    Send-Notify 'notifications/initialized' @{}

    # ============ L0 ============
    Verify 'L0' 'Bootstrap'             @{} 10000 | Out-Null
    Verify 'L0' 'GetState'              @{} 5000  | Out-Null
    Verify 'L0' 'RunCapabilitySelfTest' @{ inspectPortalProcesses=$false; includeProjectTree=$false } 30000 | Out-Null

    # ============ L2 Offline builders (independent of TIA connection) ============
    Verify 'L2-Builder' 'BuildPlcTagTableXml' @{
        tagTableJson = '{"tableName":"X","tags":[{"name":"a","dataTypeName":"Bool","logicalAddress":"%M0.0"}]}'
    } 10000 | Out-Null
    Verify 'L2-Builder' 'ComposePlcFcBlockXml' @{
        fcBlockJson = '{"blockName":"FC_T","blockNumber":99,"inputs":[],"outputs":[],"structuredText":{"operations":[{"op":"line","items":[{"sym":"a"},{"token":":="},{"lit":"1"},{"token":";"}]}]}}'
    } 10000 | Out-Null
    Verify 'L2-Builder' 'BuildClassicHmiScreenXml' @{
        designJson = '{"Screen":{"Name":"Main","Width":800,"Height":480},"Items":[{"Type":"Button","Name":"Btn1","Left":10,"Top":10,"Width":120,"Height":60,"Text":"GO"}]}'
    } 10000 | Out-Null

    # ============ L1 Portal connect (TIA Openness — first call may need user to click Yes in TIA UI) ============
    Write-Host "Calling Connect... If TIA Portal shows an authorization dialog, click 'Yes'. Timeout 180s." -ForegroundColor Yellow
    $connected = Verify 'L1-Portal' 'Connect' @{} 180000

    if (-not $connected) {
        Write-Host "Connect failed — skipping all project-bound verifications." -ForegroundColor Red
    } else {
        # ============ L1 Project — attach to existing open project (no creation, no pollution) ============
        $attached = Verify 'L1-Project' 'AttachToOpenProject' @{ projectName=$attachProject } 60000
        Verify 'L1-Project' 'GetProject'     @{} 30000 | Out-Null

        if ($attached) {
            Verify 'L1-Project'  'GetProjectTree' @{} 30000   | Out-Null
            Verify 'L1-Hardware' 'GetDevices'     @{} 30000   | Out-Null
            Verify 'L1-Hardware' 'SearchHardwareCatalog' @{ keyword='1211C' } 30000 | Out-Null

            # find a real PLC softwarePath from the open project
            $devicesResp = Send-Request 'tools/call' @{ name='GetDevices'; arguments=@{} } 30000
            $devText = ($devicesResp.result.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
            $plcPath = $null
            foreach ($cand in $plcCandidates) {
                if ($devText -match [regex]::Escape($cand)) { $plcPath = $cand; break }
            }
            if (-not $plcPath -and $devText -match '"name"\s*:\s*"([^"]+)"') {
                $plcPath = $Matches[1]
            }
            Write-Host "Using softwarePath: '$plcPath'" -ForegroundColor Cyan

            if ($plcPath) {
                Verify 'L1-PLC'  'GetSoftwareInfo' @{ softwarePath=$plcPath } 30000  | Out-Null
                Verify 'L1-PLC'  'GetSoftwareTree' @{ softwarePath=$plcPath } 30000  | Out-Null
                Verify 'L1-PLC'  'GetBlocks'       @{ softwarePath=$plcPath } 30000  | Out-Null

                # dry-run builders (no project mutation, just generate XML side files)
                Verify 'L1-PLC-Build' 'PlcBuildAndImport' @{
                    softwarePath=$plcPath; kind='tagtable'
                    json='{"tableName":"DefaultTagTable","tags":[{"name":"VerifyTag","dataTypeName":"Bool","logicalAddress":"%M100.0"}]}'
                    dryRun=$true
                } 30000 | Out-Null

                Verify 'L1-PLC-Build' 'PlcBuildAndImport' @{
                    softwarePath=$plcPath; kind='globaldb'
                    json='{"dbName":"DB_Verify","dbNumber":99,"staticMembers":[{"name":"X","datatype":"Int","startValue":"0"}]}'
                    dryRun=$true
                } 30000 | Out-Null

                Verify 'L1-PLC-Build' 'PlcBuildAndImport' @{
                    softwarePath=$plcPath; kind='fc'
                    json='{"blockName":"FC_Verify","blockNumber":98,"inputs":[],"outputs":[],"structuredText":{"operations":[{"op":"line","items":[{"sym":"#tmp"},{"token":":="},{"lit":"0"},{"token":";"}]}]}}'
                    dryRun=$true
                } 30000 | Out-Null

                # Online state on real device (read-only — should return Offline cleanly without throwing)
                Verify 'L2-Online' 'GetOnlineState'         @{ softwarePath=$plcPath } 30000 | Out-Null
                Verify 'L2-Online' 'CheckDownloadReadiness' @{ softwarePath=$plcPath } 30000 | Out-Null
            }
        }

        Verify 'L0' 'GetState'   @{} 5000  | Out-Null
        Verify 'L1-Portal' 'Disconnect' @{} 30000 | Out-Null
    }

} catch {
    Write-Host "EXCEPTION: $_" -ForegroundColor Red
} finally {
    try { $proc.StandardInput.Close() } catch {}
    $proc.WaitForExit(15000) | Out-Null
    if (-not $proc.HasExited) { $proc.Kill() }

    $script:results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportJson -Encoding UTF8

    $passes = $script:results | Where-Object { $_.status -eq 'pass' }
    $fails  = $script:results | Where-Object { $_.status -ne 'pass' }

    $md = @()
    $md += "# MCP E2E Verification Result"
    $md += ""
    $md += "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  |  Attached project: ``$attachProject``"
    $md += "Pass: $($passes.Count) / $($script:results.Count)  |  Fail: $($fails.Count)"
    $md += ""
    $md += "## Verified (PASS)"
    $md += ""
    $md += "| Layer | Tool | Time(ms) | Sample output |"
    $md += "|---|---|---:|---|"
    foreach ($r in $passes) {
        $d = ($r.detail -replace '\|','\\|')
        $d = $d.Substring(0,[Math]::Min(120,$d.Length))
        $md += "| $($r.category) | ``$($r.tool)`` | $($r.elapsedMs) | $d |"
    }
    if ($fails.Count -gt 0) {
        $md += ""
        $md += "## Failures"
        $md += ""
        $md += "| Layer | Tool | Detail |"
        $md += "|---|---|---|"
        foreach ($r in $fails) {
            $d = ($r.detail -replace '\|','\\|')
            $d = $d.Substring(0,[Math]::Min(220,$d.Length))
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
