$ErrorActionPreference = 'Stop'
$tiaportalRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$exe = Join-Path $tiaportalRoot 'src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Missing TiaMcpServer.exe (build Release first): $exe" }
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$projDir = "C:\Users\XL626\Desktop\testtia\mcp-e2e-smoke_$ts"
$projName = "MCP_E2E_Smoke_$ts"

if (-not (Test-Path "C:\Users\XL626\Desktop\testtia")) { New-Item -ItemType Directory -Path "C:\Users\XL626\Desktop\testtia" -Force | Out-Null }
# Do not attempt to delete previous projects (TIA may hold SearchIndex locks).

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
$p = [System.Diagnostics.Process]::Start($psi)

$script:nextId = 1

function Send-Notify($method, $params) {
    $msg = @{ jsonrpc='2.0'; method=$method; params=$params } | ConvertTo-Json -Compress -Depth 20
    $p.StandardInput.WriteLine($msg)
    $p.StandardInput.Flush()
}
function Send-Request($method, $params, [int]$timeoutMs=30000) {
    $id = $script:nextId++
    $obj = @{ jsonrpc='2.0'; id=$id; method=$method }
    if ($null -ne $params) { $obj.params = $params }
    $msg = $obj | ConvertTo-Json -Compress -Depth 20
    $p.StandardInput.WriteLine($msg)
    $p.StandardInput.Flush()
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    while ([DateTime]::UtcNow -lt $deadline) {
        # ReadLine blocks; use Peek-like via async task with timeout
        $task = $p.StandardOutput.ReadLineAsync()
        $remain = [int]([Math]::Max(50, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $task.Wait($remain)) { continue }
        $line = $task.Result
        if ($null -eq $line) { throw "Server stdout closed before id=$id" }
        try {
            $j = $line | ConvertFrom-Json
            if ($null -ne $j.id -and $j.id -eq $id) { return $j }
        } catch {}
    }
    throw "Timeout waiting for id=$id ($method)"
}
function Call-Tool($name, $tArgs, [int]$timeoutMs=60000) {
    return Send-Request 'tools/call' @{ name=$name; arguments=$tArgs } $timeoutMs
}
function Show($label, $resp) {
    if ($resp.error) {
        Write-Host "[$label] ERROR: $($resp.error.message)" -ForegroundColor Red
        return $false
    }
    $text = $null
    if ($resp.result -and $resp.result.content) {
        $text = ($resp.result.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
    }
    # Treat MCP tool error shapes as failure (many tools return isError/success=false instead of JSON-RPC error).
    try {
        if ($resp.result -and ($resp.result.PSObject.Properties.Name -contains 'isError') -and $resp.result.isError) {
            Write-Host "[$label] TOOL_ERROR (isError=true)" -ForegroundColor Red
            if ($text) { Write-Host "    $text" -ForegroundColor DarkGray }
            return $false
        }
    } catch {}
    if ($text) {
        if ($text -like 'An error occurred*') {
            Write-Host "[$label] TOOL_ERROR: $text" -ForegroundColor Red
            return $false
        }
        if ($text -match '"success"\s*:\s*false') {
            Write-Host "[$label] LOGICAL_FAIL: $text" -ForegroundColor Yellow
            return $false
        }
        if ($text.Length -gt 500) { $text = $text.Substring(0,500) + '...(truncated)' }
        Write-Host "[$label] OK: $text" -ForegroundColor Green
    } else {
        Write-Host "[$label] OK" -ForegroundColor Green
    }
    return $true
}

try {
    Start-Sleep -Seconds 3

    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='e2e-smoke'; version='1.0' } } 30000
    Write-Host "[initialize] server=$($init.result.serverInfo.name) v$($init.result.serverInfo.version)" -ForegroundColor Cyan
    Send-Notify 'notifications/initialized' @{}

    $r = Call-Tool 'GetState' @{} 5000;                                                                     Show 'GetState (pre)' $r | Out-Null
    $r = Call-Tool 'Connect' @{} 60000;                                                                     if (-not (Show 'Connect' $r)) { throw 'Connect failed' }
    $r = Call-Tool 'CreateProject' @{ directoryPath=$projDir; projectName=$projName } 180000;              if (-not (Show 'CreateProject' $r)) { throw 'CreateProject failed' }
    $r = Call-Tool 'AddDeviceWithFallback' @{ preferredMlfb='6ES7211-1BE40-0XB0'; preferredVersion='V4.7'; deviceName='PLC_1'; family='S7-1200' } 180000; Show 'AddDevice CPU' $r | Out-Null
    $r = Call-Tool 'AddHardwareCatalogDeviceWithProbe' @{ keyword='KTP700 Basic PN'; deviceName='HMI_KTP700_1' } 240000; Show 'AddDevice HMI (KTP700)' $r | Out-Null
    $r = Call-Tool 'GetDevices' @{} 30000;                                                                  Show 'GetDevices' $r | Out-Null
    $r = Call-Tool 'GetProjectTree' @{} 30000;                                                              Show 'GetProjectTree' $r | Out-Null
    # Best-effort: catalog/HMI nodes vary across environments; do not fail smoke on this.
    $r = Call-Tool 'ConnectDeviceNodesToProfinetSubnet' @{ firstRootPath='PLC_1'; secondRootPath='HMI_KTP700_1' } 60000
    if (-not (Show 'ConnectDeviceNodesToProfinetSubnet (best-effort)' $r)) { Write-Host "[ConnectDeviceNodesToProfinetSubnet] skipped as non-fatal" -ForegroundColor DarkYellow }
    $r = Call-Tool 'CompileSoftware' @{ softwarePath='PLC_1' } 240000;                                      Show 'CompileSoftware PLC_1' $r | Out-Null

    $tagTableJson = '{"tableName":"DefaultTagTable","tags":[{"name":"Start","dataTypeName":"Bool","logicalAddress":"%I0.0"},{"name":"Stop","dataTypeName":"Bool","logicalAddress":"%I0.1"},{"name":"RunOut","dataTypeName":"Bool","logicalAddress":"%Q0.0"}]}'
    $r = Call-Tool 'BuildPlcTagTableXml' @{ tagTableJson=$tagTableJson } 10000;                             if (-not (Show 'BuildPlcTagTableXml (offline)' $r)) { throw 'BuildPlcTagTableXml failed' }

    $designJson = '{\"Screen\":{\"Name\":\"Main\",\"Width\":800,\"Height\":480},\"Items\":[{\"Type\":\"Button\",\"Name\":\"BtnStart\",\"Left\":40,\"Top\":80,\"Width\":120,\"Height\":60,\"Text\":\"START\"},{\"Type\":\"Button\",\"Name\":\"BtnStop\",\"Left\":200,\"Top\":80,\"Width\":120,\"Height\":60,\"Text\":\"STOP\"}]}' 
    $r = Call-Tool 'BuildClassicHmiScreenXml' @{ designJson=$designJson } 10000;                            if (-not (Show 'BuildClassicHmiScreenXml (offline)' $r)) { throw 'BuildClassicHmiScreenXml failed' }

    $r = Call-Tool 'SaveProject' @{} 180000;                                                                Show 'SaveProject' $r | Out-Null
    $r = Call-Tool 'GetState' @{} 5000;                                                                     Show 'GetState (post)' $r | Out-Null
    $r = Call-Tool 'Disconnect' @{} 30000;                                                                  Show 'Disconnect' $r | Out-Null

    Write-Host '=== ALL STEPS DONE ===' -ForegroundColor Cyan

} catch {
    Write-Host "EXCEPTION: $_" -ForegroundColor Red
} finally {
    try { $p.StandardInput.Close() } catch {}
    $p.WaitForExit(10000) | Out-Null
    if (-not $p.HasExited) { $p.Kill() }
    Write-Host "--- exit code: $($p.ExitCode) ---"
    # Drain stderr now (synchronous read until EOF)
    Write-Host '=== STDERR (server log, last 60 lines) ===' -ForegroundColor Yellow
    $errAll = $p.StandardError.ReadToEnd()
    $errLines = $errAll -split "`r?`n"
    $tail = $errLines | Select-Object -Last 60
    $tail | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
}
