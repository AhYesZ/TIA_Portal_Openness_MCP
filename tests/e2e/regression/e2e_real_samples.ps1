$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Debug\net48\TiaMcpServer.exe"
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$projDir = "C:\Users\XL626\Desktop\testtia\mcp-real_$ts"
$projName = "MCP_Real_Samples_$ts"
$ref = "C:\Users\XL626\Desktop\PID博途块\TMP_EXPORT\Source\5T车"
$summary = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_real_samples_summary.md"

if (-not (Test-Path "C:\Users\XL626\Desktop\testtia")) { New-Item -ItemType Directory -Path "C:\Users\XL626\Desktop\testtia" -Force | Out-Null }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$p = [System.Diagnostics.Process]::Start($psi)
$stderrTask = $p.StandardError.ReadToEndAsync()

$script:nextId = 1
$script:results = New-Object System.Collections.Generic.List[object]

function _RawSend($obj) { ($obj | ConvertTo-Json -Compress -Depth 30) | %{ $p.StandardInput.WriteLine($_); $p.StandardInput.Flush() } }
function Send-Request($method, $params, [int]$timeoutMs=10000) {
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
        if ($null -eq $line) { throw "stdout closed" }
        try { $j = $line | ConvertFrom-Json; if ($null -ne $j.id -and $j.id -eq $id) { return $j } } catch {}
    }
    throw "TIMEOUT"
}

function Step {
    param([string]$Cat,[string]$Tool,[hashtable]$ToolArgs=@{},[int]$TimeoutMs=120000,[string]$Note='')
    $start = [DateTime]::UtcNow
    $entry = [ordered]@{ category=$Cat; tool=$Tool; note=$Note; status='?'; ms=0; msg='' }
    try {
        $resp = Send-Request 'tools/call' @{ name=$Tool; arguments=$ToolArgs } $TimeoutMs
        $entry.ms = [int]([DateTime]::UtcNow - $start).TotalMilliseconds
        if ($resp.error) { $entry.status='FAIL'; $entry.msg="$($resp.error.message)" }
        elseif ($null -eq $resp.result) { $entry.status='FAIL'; $entry.msg='null result' }
        else {
            $text = ''
            if ($resp.result.content) { $text = ($resp.result.content | ?{$_.type -eq 'text'} | Select -First 1).text }
            if ($null -eq $text) { $text = '' }
            $isErr = $false
            if ($resp.result.PSObject.Properties.Name -contains 'isError' -and $resp.result.isError) { $isErr=$true }
            if (-not $isErr -and $text -like 'An error occurred*') { $isErr=$true }
            if ($isErr) {
                $entry.status='FAIL'
                # 提取核心错误描述（"...: rest"）
                if ($text -match ':\s*([^:]+?)(?:\s*$|\s*\.\s*$)') { $entry.msg = $matches[1].Trim() }
                else { $entry.msg = $text.Substring(0,[Math]::Min(180,$text.Length)) }
            } elseif ($text -match '"success"\s*:\s*false') { $entry.status='LOGIC_FAIL'; $entry.msg='success=false' }
            else { $entry.status='OK'; $entry.msg='OK' }
        }
    } catch { $entry.ms=[int]([DateTime]::UtcNow-$start).TotalMilliseconds; $entry.status=if("$_" -like '*TIMEOUT*'){'TIMEOUT'}else{'EXC'}; $entry.msg="$_" }
    $script:results.Add([pscustomobject]$entry)
    $col = switch ($entry.status) {'OK'{'Green'}'LOGIC_FAIL'{'Yellow'}default{'Red'}}
    $head = "[{0,3}] [{1,5}ms][{2,-10}] {3,-32}" -f $script:results.Count, $entry.ms, $entry.status, $Tool
    Write-Host "$head $Note  $($entry.msg)" -ForegroundColor $col
    return [pscustomobject]$entry
}

try {
    Start-Sleep -Seconds 3
    $init = Send-Request 'initialize' @{ protocolVersion='2026-05-10'; capabilities=@{}; clientInfo=@{ name='real-samples'; version='1.0' } } 30000
    Write-Host "init OK" -ForegroundColor Cyan
    _RawSend @{ jsonrpc='2.0'; method='notifications/initialized'; params=@{} }

    # === Setup ===
    $r = Step 'Portal' 'Connect' @{} 90000
    if ($r.status -ne 'OK') { throw "Connect 失败" }
    Step 'Project' 'CreateProject' @{ directoryPath=$projDir; projectName=$projName } 180000 | Out-Null
    Step 'HW' 'AddDeviceWithFallback' @{ preferredMlfb='6ES7211-1BE40-0XB0'; preferredVersion='V4.7'; deviceName='PLC_1'; family='S7-1200' } 180000 'CPU' | Out-Null

    Write-Host ""
    Write-Host "=== UDT 样本批量导入（$ref\Datatypes\）===" -ForegroundColor Cyan
    $udtFiles = @(Get-ChildItem -Path "$ref\Datatypes" -Filter '*.xml' -File)
    foreach ($f in $udtFiles) {
        Step 'UDT' 'ImportType' @{ softwarePath='PLC_1'; groupPath=''; importPath=$f.FullName } 90000 $f.Name | Out-Null
    }

    Write-Host ""
    Write-Host "=== Tag Table 样本批量导入（$ref\Tags\）===" -ForegroundColor Cyan
    $tagFiles = @(Get-ChildItem -Path "$ref\Tags" -Filter '*.xml' -File)
    foreach ($f in $tagFiles) {
        Step 'TagTable' 'ImportPlcTagTable' @{ softwarePath='PLC_1'; folderPath=''; importPath=$f.FullName } 90000 $f.Name | Out-Null
    }

    Write-Host ""
    Write-Host "=== Block 样本（精选 10 个，从 $ref\Blocks\）===" -ForegroundColor Cyan
    $picked = @(
        'Blocks\Cyclic interrupt.xml',
        'Blocks\Diagnostic error interrupt.xml',
        'Blocks\Time error interrupt.xml',
        'Blocks\01_手动控制\Control_FC.xml',
        'Blocks\02_数据接口\21_数据转换.xml',
        'Blocks\03_自动控制\Global_Data.xml',
        'Blocks\FB_DualLoopPID.xml',
        'Blocks\FB_AntiSway_SpeedCtl.xml',
        'Blocks\FB_Crane_AntiSway.xml',
        'Blocks\Main.xml'
    )
    foreach ($relPath in $picked) {
        $full = Join-Path $ref $relPath
        if (-not (Test-Path $full)) { Write-Host "  skip (missing): $relPath" -ForegroundColor DarkGray; continue }
        Step 'Block' 'ImportBlock' @{ softwarePath='PLC_1'; groupPath=''; importPath=$full } 120000 (Split-Path $relPath -Leaf) | Out-Null
    }

    Write-Host ""
    Write-Host "=== Compile（看导入后能不能编译）===" -ForegroundColor Cyan
    Step 'Compile' 'CompileSoftware' @{ softwarePath='PLC_1' } 240000 'final' | Out-Null

    Step 'Project' 'SaveProject' @{} 240000 | Out-Null
    Step 'Portal' 'Disconnect' @{} 30000 | Out-Null
    Write-Host "=== DONE ===" -ForegroundColor Cyan
} catch {
    Write-Host "EXCEPTION: $_" -ForegroundColor Red
} finally {
    try { $p.StandardInput.Close() } catch {}
    $p.WaitForExit(15000) | Out-Null
    if (-not $p.HasExited) { $p.Kill() }

    $by = $script:results | Group-Object status | Sort-Object Name
    foreach ($g in $by) { Write-Host (" {0}: {1}" -f $g.Name, $g.Count) }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Real-sample regression import")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format o)")
    [void]$sb.AppendLine("Project: $projName")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## By status")
    foreach ($g in $by) { [void]$sb.AppendLine("- $($g.Name): $($g.Count)") }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Detail")
    [void]$sb.AppendLine('| # | Cat | Tool | Status | ms | Note | Msg |')
    [void]$sb.AppendLine('|---|---|---|---|---|---|---|')
    $i = 1
    foreach ($r in $script:results) {
        $m = ($r.msg -replace '\|','/' -replace '\r?\n',' ')
        if ($m.Length -gt 110) { $m = $m.Substring(0,110)+'...' }
        [void]$sb.AppendLine("| $i | $($r.category) | $($r.tool) | $($r.status) | $($r.ms) | $($r.note) | $m |")
        $i++
    }
    [System.IO.File]::WriteAllText($summary, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Summary: $summary" -ForegroundColor Cyan

    try {
        if ($stderrTask.Wait(5000)) {
            $errPath = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_real_samples.stderr.log"
            [System.IO.File]::WriteAllText($errPath, $stderrTask.Result, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "Stderr: $errPath" -ForegroundColor DarkCyan
        }
    } catch {}
}
