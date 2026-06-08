$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Debug\net48\TiaMcpServer.exe"
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$projDir = "C:\Users\XL626\Desktop\testtia\mcp-demo_$ts"
$projName = "MCP_Demo_$ts"
$logJson = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_demo.jsonl"
$summary = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_demo_summary.md"

if (-not (Test-Path "C:\Users\XL626\Desktop\testtia")) { New-Item -ItemType Directory -Path "C:\Users\XL626\Desktop\testtia" -Force | Out-Null }
if (Test-Path $logJson) { Remove-Item -Force $logJson }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
$p = [System.Diagnostics.Process]::Start($psi)
$stderrTask = $p.StandardError.ReadToEndAsync()

$script:nextId = 1
$script:results = New-Object System.Collections.Generic.List[object]

function _RawSend($obj) {
    $msg = $obj | ConvertTo-Json -Compress -Depth 30
    $p.StandardInput.WriteLine($msg)
    $p.StandardInput.Flush()
}
function Send-Notify($method, $params) {
    _RawSend @{ jsonrpc='2.0'; method=$method; params=$params }
}
function Send-Request($method, $params, [int]$timeoutMs) {
    $id = $script:nextId++
    $obj = @{ jsonrpc='2.0'; id=$id; method=$method }
    if ($null -ne $params) { $obj.params = $params }
    _RawSend $obj
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    while ([DateTime]::UtcNow -lt $deadline) {
        $task = $p.StandardOutput.ReadLineAsync()
        $remain = [int]([Math]::Max(50, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $task.Wait($remain)) { continue }
        $line = $task.Result
        if ($null -eq $line) { throw "Server stdout closed" }
        try {
            $j = $line | ConvertFrom-Json
            if ($null -ne $j.id -and $j.id -eq $id) { return $j }
        } catch {}
    }
    throw "TIMEOUT after ${timeoutMs}ms"
}

function Validate {
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$ToolName,
        [hashtable]$Args = @{},
        [int]$TimeoutMs = 90000,
        [string]$Note = ''
    )
    $start = [DateTime]::UtcNow
    $entry = [ordered]@{
        category = $Category
        tool = $ToolName
        note = $Note
        status = 'UNKNOWN'
        elapsedMs = 0
        message = ''
        excerpt = ''
    }
    try {
        $resp = Send-Request 'tools/call' @{ name=$ToolName; arguments=$Args } $TimeoutMs
        $entry.elapsedMs = [int]([DateTime]::UtcNow - $start).TotalMilliseconds
        if ($resp.error) {
            $entry.status = 'FAIL'
            $entry.message = "$($resp.error.message)"
        } else {
            $text = $null
            if ($resp.result.content) {
                $text = ($resp.result.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
            }
            $entry.excerpt = if ($text) { $text.Substring(0,[Math]::Min(500,$text.Length)) } else { '' }
            $isToolError = $false
            if ($resp.result.PSObject.Properties.Name -contains 'isError' -and $resp.result.isError) { $isToolError = $true }
            if (-not $isToolError -and $text -and $text -like 'An error occurred*') { $isToolError = $true }
            $isLogicalFail = $false
            if (-not $isToolError -and $text -match '"success"\s*:\s*false') { $isLogicalFail = $true }
            if ($isToolError) {
                $entry.status = 'FAIL'
                $entry.message = if ($text) { $text.Substring(0,[Math]::Min(300,$text.Length)) } else { 'isError=true' }
            } elseif ($isLogicalFail) {
                $entry.status = 'LOGICAL_FAIL'
                $entry.message = 'success=false in payload'
            } else {
                $entry.status = 'OK'
                $entry.message = 'OK'
            }
        }
    } catch {
        $entry.elapsedMs = [int]([DateTime]::UtcNow - $start).TotalMilliseconds
        $entry.status = if ("$_" -like '*TIMEOUT*') { 'TIMEOUT' } else { 'EXCEPTION' }
        $entry.message = "$_"
    }
    $script:results.Add([pscustomobject]$entry)
    Add-Content -Path $logJson -Value (($entry | ConvertTo-Json -Compress -Depth 5)) -Encoding UTF8
    $color = switch ($entry.status) { 'OK' { 'Green' } 'LOGICAL_FAIL' { 'Yellow' } 'FAIL' { 'Red' } 'TIMEOUT' { 'Magenta' } default { 'DarkRed' } }
    $head = "[{0,5}ms][{1,-12}] {2,-30} {3}" -f $entry.elapsedMs, $entry.status, $ToolName, $Note
    Write-Host "$head $($entry.message)" -ForegroundColor $color
    return [pscustomobject]$entry
}

try {
    Start-Sleep -Seconds 3
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='e2e-demo'; version='1.0' } } 30000
    Write-Host "[init] $($init.result.serverInfo.name) v$($init.result.serverInfo.version)" -ForegroundColor Cyan
    Send-Notify 'notifications/initialized' @{}

    $r = Validate 'Portal' 'Connect' @{} 90000
    if ($r.status -ne 'OK') { throw "Connect did not succeed (status=$($r.status)). Likely a TIA Openness auth dialog needs your click. Aborting demo." }
    $r = Validate 'Project' 'CreateProject' @{ directoryPath=$projDir; projectName=$projName } 180000
    if ($r.status -ne 'OK') { throw "CreateProject failed; aborting." }

    Validate 'Hardware' 'AddDeviceWithFallback' @{ preferredMlfb='6ES7211-1BE40-0XB0'; preferredVersion='V4.7'; deviceName='PLC_1'; family='S7-1200' } 180000 'CPU 1211C V4.7' | Out-Null
    Validate 'Hardware' 'AddHardwareCatalogDeviceWithProbe' @{ keyword='KTP700 Basic PN'; deviceName='HMI_1' } 240000 'KTP700 Basic PN' | Out-Null
    Validate 'Hardware' 'ConnectDeviceNodesToProfinetSubnet' @{ firstRootPath='PLC_1'; secondRootPath='HMI_1/HMI_1.IE_CP_1' } 60000 'PLC<->HMI on PN_IE_1' | Out-Null

    # ---------- 1) UDT_Motor ----------
    $udtJson = @{
        name = 'UDT_Motor'
        members = @(
            @{ name='Speed';  datatype='Real'; commentZhCn='转速' },
            @{ name='Run';    datatype='Bool'; commentZhCn='运行中' },
            @{ name='Fault';  datatype='Bool'; commentZhCn='故障' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'PLC' 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='udt'; json=$udtJson; dryRun=$false; compileAfter=$false } 120000 'UDT_Motor' | Out-Null

    # ---------- 2) Default tag table ----------
    $tagJson = @{
        tableName = 'DefaultTagTable'
        tags = @(
            @{ name='I_Start';     dataTypeName='Bool'; logicalAddress='%I0.0' },
            @{ name='I_Stop';      dataTypeName='Bool'; logicalAddress='%I0.1' },
            @{ name='I_EStop';     dataTypeName='Bool'; logicalAddress='%I0.2' },
            @{ name='Q_Run';       dataTypeName='Bool'; logicalAddress='%Q0.0' },
            @{ name='Q_RunLamp1';  dataTypeName='Bool'; logicalAddress='%Q0.1' },
            @{ name='Q_RunLamp2';  dataTypeName='Bool'; logicalAddress='%Q0.2' },
            @{ name='Q_RunLamp3';  dataTypeName='Bool'; logicalAddress='%Q0.3' },
            @{ name='Q_RunLamp4';  dataTypeName='Bool'; logicalAddress='%Q0.4' },
            @{ name='M_HoldRun';   dataTypeName='Bool'; logicalAddress='%M10.0' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'PLC' 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='tagtable'; json=$tagJson; dryRun=$false; compileAfter=$false } 120000 'DefaultTagTable' | Out-Null

    # ---------- 3) GlobalDB_Motor ----------
    $dbJson = @{
        dbName = 'DB_Motor'
        dbNumber = 1
        staticMembers = @(
            @{ name='Speed';  datatype='Real'; startValue='0.0' },
            @{ name='Run';    datatype='Bool'; startValue='FALSE' },
            @{ name='Fault';  datatype='Bool'; startValue='FALSE' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'PLC' 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='globaldb'; json=$dbJson; dryRun=$false; compileAfter=$false } 120000 'DB_Motor' | Out-Null

    # ---------- 4) FB_StartStop (SCL: classic 起保停) ----------
    $fbStartStop = @{
        blockName = 'FB_StartStop'
        blockNumber = 2
        inputs = @(
            @{ name='Start'; datatype='Bool' },
            @{ name='Stop';  datatype='Bool' },
            @{ name='EStop'; datatype='Bool' }
        )
        outputs = @(
            @{ name='Run';   datatype='Bool' }
        )
        structuredText = @{
            operations = @(
                @{ op='if';   condition='EStop' },
                @{ op='assignment'; target='Run'; literalValue='FALSE'; indent=2 },
                @{ op='else' },
                @{ op='if';   condition='Stop'; indent=2 },
                @{ op='assignment'; target='Run'; literalValue='FALSE'; indent=4 },
                @{ op='endif'; indent=2 },
                @{ op='if';   condition='Start'; indent=2 },
                @{ op='assignment'; target='Run'; literalValue='TRUE'; indent=4 },
                @{ op='endif'; indent=2 },
                @{ op='endif' }
            )
        }
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'PLC' 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fb'; json=$fbStartStop; dryRun=$false; compileAfter=$false } 180000 'FB_StartStop SCL' | Out-Null

    # ---------- 5) FC_Lamp (SCL: simple lamp set) ----------
    $fcLamp = @{
        blockName = 'FC_Lamp'
        blockNumber = 3
        inputs = @(
            @{ name='Enable'; datatype='Bool' }
        )
        outputs = @(
            @{ name='Lamp';   datatype='Bool' }
        )
        structuredText = @{
            operations = @(
                @{ op='if'; condition='Enable' },
                @{ op='assignment'; target='Lamp'; literalValue='TRUE'; indent=2 },
                @{ op='else' },
                @{ op='assignment'; target='Lamp'; literalValue='FALSE'; indent=2 },
                @{ op='endif' }
            )
        }
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'PLC' 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fc'; json=$fcLamp; dryRun=$false; compileAfter=$false } 180000 'FC_Lamp SCL' | Out-Null

    # ---------- 6) Final compile (must be 0 errors) ----------
    $compile = Validate 'PLC' 'CompileSoftware' @{ softwarePath='PLC_1' } 240000 'final compile - expect 0 errors'

    # ---------- 7) HMI offline screen + tag table ----------
    $hmiScreen = @{
        Screen = @{ Name='Main'; Width=800; Height=480 }
        Items  = @(
            @{ Type='Button'; Name='BtnStart'; Left=40;  Top=80; Width=120; Height=60; Text='START' },
            @{ Type='Button'; Name='BtnStop';  Left=200; Top=80; Width=120; Height=60; Text='STOP'  },
            @{ Type='Lamp';   Name='LmpRun';   Left=400; Top=80; Width=80;  Height=60; Text='RUN'   }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'HMI' 'BuildClassicHmiScreenXml' @{ designJson=$hmiScreen } 10000 | Out-Null

    $hmiTags = @{
        Name = 'HmiTags'
        Tags = @(
            @{ Name='BtnStart'; DataType='Bool' },
            @{ Name='BtnStop';  DataType='Bool' },
            @{ Name='LmpRun';   DataType='Bool' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'HMI' 'BuildClassicHmiTagTableXml' @{ tableJson=$hmiTags } 10000 | Out-Null

    # ---------- 8) Save ----------
    Validate 'Project' 'SaveProject' @{} 240000 | Out-Null
    Validate 'Portal' 'GetState' @{} 5000 | Out-Null
    Validate 'Portal' 'Disconnect' @{} 30000 | Out-Null

    # ---------- compile report ----------
    Write-Host ""
    Write-Host "=== Final compile excerpt ===" -ForegroundColor Cyan
    Write-Host $compile.excerpt

} catch {
    Write-Host "EXCEPTION: $_" -ForegroundColor Red
} finally {
    try { $p.StandardInput.Close() } catch {}
    $p.WaitForExit(15000) | Out-Null
    if (-not $p.HasExited) { $p.Kill() }
    Write-Host "--- server exit: $($p.ExitCode) ---"

    $byStatus = $script:results | Group-Object status | Sort-Object Name
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# MCP Demo Project — Validation")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format o)")
    [void]$sb.AppendLine("Project: $projName")
    [void]$sb.AppendLine("Path: $projDir")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## By status')
    foreach ($g in $byStatus) { [void]$sb.AppendLine("- $($g.Name): $($g.Count)") }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Step-by-step')
    [void]$sb.AppendLine('| # | Tool | Status | ms | Note | Message |')
    [void]$sb.AppendLine('|---|---|---|---|---|---|')
    $i = 1
    foreach ($r in $script:results) {
        $msg = ($r.message -replace '\|','/' -replace '\r?\n',' ')
        if ($msg.Length -gt 120) { $msg = $msg.Substring(0,120) + '...' }
        [void]$sb.AppendLine("| $i | $($r.tool) | $($r.status) | $($r.elapsedMs) | $($r.note) | $msg |")
        $i++
    }
    [System.IO.File]::WriteAllText($summary, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
    Write-Host "Summary: $summary" -ForegroundColor Cyan
    foreach ($g in $byStatus) { Write-Host (" {0}: {1}" -f $g.Name, $g.Count) }

    try {
        if ($stderrTask.Wait(5000)) {
            $errPath = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_demo.stderr.log"
            [System.IO.File]::WriteAllText($errPath, $stderrTask.Result, [System.Text.UTF8Encoding]::new($false))
        }
    } catch {}
}
