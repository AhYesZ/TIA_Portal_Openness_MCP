$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Debug\net48\TiaMcpServer.exe"
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$projDir = "C:\Users\XL626\Desktop\testtia\mcp-validation_$ts"
$projName = "MCP_Validation_$ts"
$tmpExport = "C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT"
$logJson = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_full.jsonl"
$summary = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_full_summary.md"

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
            $entry.excerpt = if ($text) { $text.Substring(0,[Math]::Min(300,$text.Length)) } else { '' }
            # MCP convention: result.isError=true marks a tool failure inside content[]
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
    $line = ($entry | ConvertTo-Json -Compress -Depth 5)
    Add-Content -Path $logJson -Value $line -Encoding UTF8
    $color = switch ($entry.status) { 'OK' { 'Green' } 'LOGICAL_FAIL' { 'Yellow' } 'FAIL' { 'Red' } 'TIMEOUT' { 'Magenta' } default { 'DarkRed' } }
    $head = "[{0,4}ms][{1,-13}] {2,-45}" -f $entry.elapsedMs, $entry.status, $ToolName
    Write-Host "$head $($entry.message)" -ForegroundColor $color
}

function Skip { param($Cat,$Tool,$Reason)
    $entry = [pscustomobject]@{ category=$Cat; tool=$Tool; note=''; status='SKIP'; elapsedMs=0; message=$Reason; excerpt='' }
    $script:results.Add($entry)
    Add-Content -Path $logJson -Value ($entry | ConvertTo-Json -Compress) -Encoding UTF8
    Write-Host ("[skip][{0,-13}] {1,-45} {2}" -f 'SKIP', $Tool, $Reason) -ForegroundColor DarkGray
}

try {
    Start-Sleep -Seconds 3
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='e2e-full'; version='1.0' } } 30000
    Write-Host "[init] $($init.result.serverInfo.name) v$($init.result.serverInfo.version)" -ForegroundColor Cyan
    Send-Notify 'notifications/initialized' @{}

    # === 1. Portal & Diagnostics ===
    Validate 'Portal' 'GetState'
    Validate 'Diagnostics' 'RunCapabilitySelfTest'
    Validate 'Portal' 'ListPortalProcessProjects'
    Validate 'Portal' 'Connect' @{} 60000
    Validate 'Portal' 'GetState'

    # === 2. Project ===
    Validate 'Project' 'CreateProject' @{ directoryPath=$projDir; projectName=$projName } 180000
    Validate 'Project' 'GetProjectTree'

    # === 3. Hardware: catalog search ===
    Validate 'Hardware' 'SearchHardwareCatalog' @{ keyword='1211C'; limit=5 } 30000
    Validate 'Hardware' 'SearchHardwareCatalog' @{ keyword='KTP700 Basic PN'; limit=5 } 30000
    Validate 'Hardware' 'SearchInstalledGsdDevices' @{ keyword='AFM60A'; limit=5 } 30000

    # === 4. Hardware: device add ===
    Validate 'Hardware' 'AddDeviceWithFallback' @{ preferredMlfb='6ES7211-1BE40-0XB0'; preferredVersion='V4.7'; deviceName='PLC_1'; family='S7-1200' } 180000
    Validate 'Hardware' 'AddHardwareCatalogDeviceWithProbe' @{ keyword='KTP700 Basic PN'; deviceName='HMI_KTP700_1' } 240000
    Validate 'Hardware' 'GetDevices'
    Validate 'Hardware' 'GetProjectTree'
    Validate 'Hardware' 'GetDeviceItemTree' @{ deviceItemPath='PLC_1' }

    # === 5. PROFINET interconnect ===
    Validate 'Hardware' 'ConnectDeviceNodesToProfinetSubnet' @{ firstRootPath='PLC_1'; secondRootPath='HMI_KTP700_1/HMI_KTP700_1.IE_CP_1' } 60000 'deeper IE path'
    Validate 'Hardware' 'EnsureSubnet' @{ anchorDeviceItemPath='PLC_1'; subnetType='PROFINET'; subnetName='PN_IE_1' } 60000

    # === 6. PLC software basics ===
    Validate 'PLC-Software' 'GetSoftwareInfo' @{ softwarePath='PLC_1' }
    Validate 'PLC-Software' 'GetSoftwareTree' @{ softwarePath='PLC_1' }
    Validate 'PLC-Software' 'GetBlocks' @{ softwarePath='PLC_1' }
    Validate 'PLC-Software' 'GetTypes' @{ softwarePath='PLC_1' }
    Validate 'PLC-Software' 'GetPlcTagTables' @{ softwarePath='PLC_1' }
    Validate 'PLC-Software' 'GetPlcWatchTables' @{ softwarePath='PLC_1' }

    # === 7. PLC import (use real samples from TMP_EXPORT) ===
    $udtSample = Join-Path $tmpExport 'Source\5T车\Datatypes\UDT_Fault.xml'
    $blockSample = Join-Path $tmpExport 'Source\5T车\Blocks\Cyclic interrupt.xml'
    if (Test-Path $udtSample) {
        Validate 'PLC-Import' 'ImportType' @{ softwarePath='PLC_1'; groupPath=''; importPath=$udtSample } 90000
    } else { Skip 'PLC-Import' 'ImportType' "no sample at $udtSample" }
    if (Test-Path $blockSample) {
        Validate 'PLC-Import' 'ImportBlock' @{ softwarePath='PLC_1'; groupPath=''; importPath=$blockSample } 90000
    } else { Skip 'PLC-Import' 'ImportBlock' "no sample at $blockSample" }

    # === 8. PLC compile ===
    Validate 'PLC-Software' 'CompileSoftware' @{ softwarePath='PLC_1' } 240000

    # === 9. PLC export ===
    $expDir = Join-Path $env:TEMP "mcp_e2e_export"
    if (Test-Path $expDir) { Remove-Item -Recurse -Force $expDir }
    New-Item -ItemType Directory -Path $expDir | Out-Null
    Validate 'PLC-Export' 'ExportBlocks' @{ softwarePath='PLC_1'; exportPath=$expDir; regexName='.*'; preservePath=$false } 120000

    # === 10. PLC offline builders ===
    $udtJson = '{"name":"UDT_Demo","members":[{"name":"Speed","datatype":"Real"},{"name":"Active","datatype":"Bool"}]}'
    Validate 'PLC-Builders' 'BuildPlcUdtXml' @{ udtJson=$udtJson } 10000
    $tagJson = '{"tableName":"DefaultTagTable","tags":[{"name":"Start","dataTypeName":"Bool","logicalAddress":"%I0.0"},{"name":"RunOut","dataTypeName":"Bool","logicalAddress":"%Q0.0"}]}'
    Validate 'PLC-Builders' 'BuildPlcTagTableXml' @{ tagTableJson=$tagJson } 10000
    $dbJson = '{"dbName":"DB_Motor","dbNumber":1,"staticMembers":[{"name":"Speed","datatype":"Real"},{"name":"Run","datatype":"Bool"}]}'
    Validate 'PLC-Builders' 'BuildPlcGlobalDbXml' @{ globalDbJson=$dbJson } 10000
    $stJson = '{"operations":[{"op":"assignment","target":"#Out","literalValue":"42"}]}'
    Validate 'PLC-Builders' 'BuildStructuredTextXml' @{ structuredTextJson=$stJson; innerOnly=$true } 10000
    $fcJson = '{"blockName":"FC_Add","blockNumber":1,"inputs":[{"name":"A","datatype":"Int"},{"name":"B","datatype":"Int"}],"outputs":[{"name":"Sum","datatype":"Int"}],"structuredText":{"operations":[{"op":"assignment","target":"#Sum","value":"#A + #B"}]}}'
    Validate 'PLC-Builders' 'ComposePlcFcBlockXml' @{ fcBlockJson=$fcJson } 10000

    # === 11. HMI ===
    Validate 'HMI' 'GetHmiProgramInfo' @{ softwarePath='HMI_KTP700_1' } 60000
    $screenJson = '{"Screen":{"Name":"Main","Width":800,"Height":480},"Items":[{"Type":"Button","Name":"BtnStart","Left":40,"Top":80,"Width":120,"Height":60,"Text":"START"}]}'
    Validate 'HMI-Builders' 'BuildClassicHmiScreenXml' @{ designJson=$screenJson } 10000
    $hmiTagJson = '{"Name":"HmiTags","Tags":[{"Name":"BtnStart","DataType":"Bool"}]}'
    Validate 'HMI-Builders' 'BuildClassicHmiTagTableXml' @{ tableJson=$hmiTagJson } 10000

    # === 12. Save + state ===
    Validate 'Project' 'SaveProject' @{} 180000
    Validate 'Portal' 'GetState'

    # === 13. Online ops: SKIP (may pop license/permission dialogs) ===
    Skip 'Online' 'GoOnline' 'avoid auth dialog'
    Skip 'Online' 'DownloadToPlc' 'avoid auth dialog'
    Skip 'Online' 'GetOnlineState' 'requires GoOnline first'

    # === 14. Disconnect ===
    Validate 'Portal' 'Disconnect' @{} 30000

    Write-Host '=== ALL VALIDATIONS DONE ===' -ForegroundColor Cyan
} catch {
    Write-Host "FATAL: $_" -ForegroundColor Red
} finally {
    try { $p.StandardInput.Close() } catch {}
    $p.WaitForExit(10000) | Out-Null
    if (-not $p.HasExited) { $p.Kill() }
    Write-Host "--- server exit: $($p.ExitCode) ---"

    # Build summary
    $byStatus = $script:results | Group-Object status | Sort-Object Name
    $byCat = $script:results | Group-Object category | Sort-Object Name
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# MCP Validation Summary")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format o)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## By status')
    foreach ($g in $byStatus) { [void]$sb.AppendLine("- $($g.Name): $($g.Count)") }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Detailed results')
    [void]$sb.AppendLine('| Category | Tool | Status | ms | Message |')
    [void]$sb.AppendLine('|---|---|---|---|---|')
    foreach ($r in $script:results) {
        $msg = ($r.message -replace '\|','/' -replace '\r?\n',' ')
        if ($msg.Length -gt 120) { $msg = $msg.Substring(0,120) + '...' }
        [void]$sb.AppendLine("| $($r.category) | $($r.tool) | $($r.status) | $($r.elapsedMs) | $msg |")
    }
    [System.IO.File]::WriteAllText($summary, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
    Write-Host "Summary written to: $summary" -ForegroundColor Cyan
    foreach ($g in $byStatus) { Write-Host (" {0}: {1}" -f $g.Name, $g.Count) }

    # Drain stderr (async task started at process launch)
    try {
        if ($stderrTask.Wait(5000)) {
            $errPath = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_full.stderr.log"
            [System.IO.File]::WriteAllText($errPath, $stderrTask.Result, [System.Text.UTF8Encoding]::new($false))
            Write-Host "Server stderr ($($stderrTask.Result.Length) chars) -> $errPath" -ForegroundColor DarkCyan
        }
    } catch {}
}
