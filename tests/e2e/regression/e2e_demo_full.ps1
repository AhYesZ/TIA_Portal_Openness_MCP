$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Debug\net48\TiaMcpServer.exe"
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$projDir = "C:\Users\XL626\Desktop\testtia\mcp-full_$ts"
$projName = "MCP_Full_$ts"
$assets = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\demo-assets"
$tmpHmi = Join-Path $env:TEMP "mcp_full_hmi_$ts"
$logJson = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_demo_full.jsonl"
$summary = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_demo_full_summary.md"

if (-not (Test-Path "C:\Users\XL626\Desktop\testtia")) { New-Item -ItemType Directory -Path "C:\Users\XL626\Desktop\testtia" -Force | Out-Null }
if (Test-Path $logJson) { Remove-Item -Force $logJson }
if (-not (Test-Path $tmpHmi)) { New-Item -ItemType Directory -Path $tmpHmi -Force | Out-Null }

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
function Send-Notify($method, $params) { _RawSend @{ jsonrpc='2.0'; method=$method; params=$params } }
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
        try { $j = $line | ConvertFrom-Json; if ($null -ne $j.id -and $j.id -eq $id) { return $j } } catch {}
    }
    throw "TIMEOUT after ${timeoutMs}ms"
}

function Validate {
    param([string]$Cat,[string]$Tool,[hashtable]$ToolArgs=@{},[int]$TimeoutMs=90000,[string]$Note='')
    $start = [DateTime]::UtcNow
    $entry = [ordered]@{ category=$Cat; tool=$Tool; note=$Note; status='UNKNOWN'; elapsedMs=0; message=''; excerpt=''; fullText='' }
    try {
        $resp = Send-Request 'tools/call' @{ name=$Tool; arguments=$ToolArgs } $TimeoutMs
        $entry.elapsedMs = [int]([DateTime]::UtcNow - $start).TotalMilliseconds
        if ($resp.error) { $entry.status='FAIL'; $entry.message="$($resp.error.message)" }
        else {
            $text=$null; if ($resp.result.content) { $text = ($resp.result.content | ?{$_.type -eq 'text'} | Select -First 1).text }
            $entry.fullText = if ($text) { $text } else { '' }
            $entry.excerpt = if ($text) { $text.Substring(0,[Math]::Min(500,$text.Length)) } else { '' }
            $isErr=$false
            if ($resp.result.PSObject.Properties.Name -contains 'isError' -and $resp.result.isError) { $isErr=$true }
            if (-not $isErr -and $text -like 'An error occurred*') { $isErr=$true }
            $isLog=$false; if (-not $isErr -and $text -match '"success"\s*:\s*false') { $isLog=$true }
            if ($isErr) { $entry.status='FAIL'; $entry.message=if($text){$text.Substring(0,[Math]::Min(300,$text.Length))}else{'isError=true'} }
            elseif ($isLog) { $entry.status='LOGICAL_FAIL'; $entry.message='success=false' }
            else { $entry.status='OK'; $entry.message='OK' }
        }
    } catch {
        $entry.elapsedMs = [int]([DateTime]::UtcNow - $start).TotalMilliseconds
        $entry.status = if ("$_" -like '*TIMEOUT*') {'TIMEOUT'} else {'EXCEPTION'}
        $entry.message="$_"
    }
    $script:results.Add([pscustomobject]$entry)
    Add-Content -Path $logJson -Value (($entry | ConvertTo-Json -Compress -Depth 5)) -Encoding UTF8
    $col = switch ($entry.status) {'OK'{'Green'}'LOGICAL_FAIL'{'Yellow'}'FAIL'{'Red'}'TIMEOUT'{'Magenta'}default{'DarkRed'}}
    Write-Host ("[{0,5}ms][{1,-12}] {2,-40} {3} {4}" -f $entry.elapsedMs,$entry.status,$Tool,$Note,$entry.message) -ForegroundColor $col
    return [pscustomobject]$entry
}

function Save-XmlContent {
    param([string]$Path,[string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($true)))
}

try {
    Start-Sleep -Seconds 3
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='e2e-full'; version='1.0' } } 30000
    Write-Host "[init] $($init.result.serverInfo.name) v$($init.result.serverInfo.version)" -ForegroundColor Cyan
    Send-Notify 'notifications/initialized' @{}

    # === 1. Connect + project ===
    $r = Validate 'Portal' 'Connect' @{} 90000
    if ($r.status -ne 'OK') { throw 'Connect failed (auth dialog?). Aborting.' }
    Validate 'Project' 'CreateProject' @{ directoryPath=$projDir; projectName=$projName } 180000 | Out-Null

    # === 2. Hardware: PLC + HMI + PROFINET ===
    Validate 'HW' 'AddDeviceWithFallback' @{ preferredMlfb='6ES7211-1BE40-0XB0'; preferredVersion='V4.7'; deviceName='PLC_1'; family='S7-1200' } 180000 'CPU 1211C V4.7' | Out-Null
    Validate 'HW' 'AddHardwareCatalogDeviceWithProbe' @{ keyword='KTP700 Basic PN'; deviceName='HMI_1' } 240000 'KTP700 Basic PN' | Out-Null
    Validate 'HW' 'ConnectDeviceNodesToProfinetSubnet' @{ firstRootPath='PLC_1'; secondRootPath='HMI_1/HMI_1.IE_CP_1' } 60000 'PROFINET PN_IE_1' | Out-Null

    # === 3. PLC tag table (default) — global I_Start/I_Stop/I_EStop/Q_Run ===
    $tagJson = @{
        tableName='DefaultTagTable'
        tags = @(
            @{ name='I_Start';    dataTypeName='Bool'; logicalAddress='%I0.0' },
            @{ name='I_Stop';     dataTypeName='Bool'; logicalAddress='%I0.1' },
            @{ name='I_EStop';    dataTypeName='Bool'; logicalAddress='%I0.2' },
            @{ name='Q_Run';      dataTypeName='Bool'; logicalAddress='%Q0.0' },
            @{ name='Q_RunLamp1'; dataTypeName='Bool'; logicalAddress='%Q0.1' },
            @{ name='Q_RunLamp2'; dataTypeName='Bool'; logicalAddress='%Q0.2' },
            @{ name='Q_RunLamp3'; dataTypeName='Bool'; logicalAddress='%Q0.3' },
            @{ name='Q_RunLamp4'; dataTypeName='Bool'; logicalAddress='%Q0.4' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'PLC' 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='tagtable'; json=$tagJson; dryRun=$false; compileAfter=$false } 120000 'DefaultTagTable' | Out-Null

    # === 4. UDT_Motor (hand-crafted with full Chinese comments) ===
    Validate 'PLC' 'ImportType' @{ softwarePath='PLC_1'; groupPath=''; importPath="$assets\plc\UDT_Motor.xml" } 120000 'UDT_Motor (中文注释)' | Out-Null

    # === 5. DB_Motor (Global DB with Chinese member comments) ===
    $dbJson = @{
        dbName='DB_Motor'; dbNumber=1
        staticMembers = @(
            @{ name='Speed'; datatype='Real'; startValue='0.0'; commentZhCn='电机当前转速反馈（rpm）' },
            @{ name='Run';   datatype='Bool'; startValue='FALSE'; commentZhCn='电机运行标志（来自 Q_Run 镜像）' },
            @{ name='Fault'; datatype='Bool'; startValue='FALSE'; commentZhCn='电机故障（保留位）' },
            @{ name='Counter'; datatype='Int'; startValue='0'; commentZhCn='启动累计次数' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'PLC' 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='globaldb'; json=$dbJson; dryRun=$false; compileAfter=$false } 120000 'DB_Motor' | Out-Null

    # === 6. FC_StartStop (SCL via BUILDER — 用新加的全局变量约定 + ELSIF op) ===
    # 关键改动：现在通过 PlcBuildAndImport kind=fc 直造，不再依赖 hand-crafted XML。
    # 引号 "I_EStop" 在 IF/ELSIF/assignment 里被识别为 GlobalVariable scope。
    $fcStartStopJson = @{
        blockName='FC_StartStop'; blockNumber=10
        commentZhCn='起保停（Start-Hold-Stop）：急停 > 停止 > 启动 三段优先级；通过全局 PLC 变量 I_Start/I_Stop/I_EStop 输入，锁存输出 Q_Run。'
        titleZhCn='起保停核心 FC（builder 生成）'
        networkTitleZhCn='IF/ELSIF/ELSIF/END_IF 三段优先级'
        networkCommentZhCn='急停最高优先级，停止次之，启动锁存最后；全部读写全局变量。'
        inputs = @(); outputs = @()
        structuredText = @{
            operations = @(
                @{ op='if';     condition='"I_EStop"' },
                @{ op='assignment'; target='"Q_Run"'; literalValue='FALSE'; indent=2 },
                @{ op='elsif';  condition='"I_Stop"' },
                @{ op='assignment'; target='"Q_Run"'; literalValue='FALSE'; indent=2 },
                @{ op='elsif';  condition='"I_Start"' },
                @{ op='assignment'; target='"Q_Run"'; literalValue='TRUE';  indent=2 },
                @{ op='endif' }
            )
        }
    } | ConvertTo-Json -Compress -Depth 10
    Validate 'PLC' 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fc'; json=$fcStartStopJson; dryRun=$false; compileAfter=$false } 180000 'FC_StartStop via builder (全局变量 + 中文注释)' | Out-Null

    # === 7a. LAD FC（梯形图功能）— 用新的 ComposePlcLadFcBlockXml 工具构造，证明梯形图编写能力 ===
    $ladFcJson = @{
        blockName = 'FC_Manual_LAD'
        blockNumber = 50
        commentZhCn = '手动控制 LAD 入口：把起保停 FC 包装到梯形图网络。展示 MCP 工具栈的 LAD 块构造能力。'
        titleZhCn = '梯形图控制入口'
        inputs = @()
        outputs = @()
        networks = @(
            @{
                titleZhCn = '调用起保停'
                commentZhCn = 'FC_StartStop 内部读全局 I_Start/I_Stop/I_EStop，写 Q_Run'
                callJson = @{ callName='FC_StartStop'; parameters=@() }
            }
        )
    } | ConvertTo-Json -Compress -Depth 10
    $ladFcBuild = Validate 'PLC' 'ComposePlcLadFcBlockXml' @{ ladFcBlockJson=$ladFcJson } 10000 'compose LAD FC offline'
    if ($ladFcBuild.status -eq 'OK') {
        $jp = ($ladFcBuild.fullText | ConvertFrom-Json -ErrorAction SilentlyContinue)
        if ($jp -and $jp.xml) {
            $ladFcPath = Join-Path $env:TEMP "mcp_full_lad_fc_$ts.xml"
            Save-XmlContent $ladFcPath $jp.xml
            Validate 'PLC' 'ImportBlock' @{ softwarePath='PLC_1'; groupPath=''; importPath=$ladFcPath } 120000 'FC_Manual_LAD (LAD via composer)' | Out-Null
        }
    }

    # === 7b. OB200 主循环（SCL 调 FC，跑现项目的梯形图入口由 FC_Manual_LAD 承担）===
    Validate 'PLC' 'ImportBlock' @{ softwarePath='PLC_1'; groupPath=''; importPath="$assets\plc\Main.xml" } 120000 'Cyclic_Main OB200 SCL calls FC' | Out-Null

    # === 8. PLC compile (must be 0 errors) ===
    $cmp = Validate 'PLC' 'CompileSoftware' @{ softwarePath='PLC_1' } 240000 'PLC compile - expect 0 errors'

    # === 8b. SaveProject early (PLC side) so HMI failures can't dispose progress ===
    Validate 'Project' 'SaveProject' @{} 240000 'save after PLC clean compile' | Out-Null

    # === 8c. Inspect what HMI connections / tags / screens TIA auto-created ===
    $conns = Validate 'HMI' 'GetHmiConnections' @{ softwarePath='HMI_1' } 30000 'discover auto-created HMI connections'
    Write-Host "==auto HMI connections==" -ForegroundColor Cyan
    Write-Host $conns.fullText
    Validate 'HMI' 'GetHmiTagTables' @{ softwarePath='HMI_1' } 30000 'list HMI tag tables' | Out-Null
    Validate 'HMI' 'GetHmiScreens'   @{ softwarePath='HMI_1' } 30000 'list HMI screens' | Out-Null

    # === 9. HMI: build tag table XML offline + import to HMI device ===
    # NOTE: HMI Classic 连接 (HMI_Connection_1) 在 V21 不会自动随 PROFINET 子网创建，
    # 必须先 ImportHmiConnection 一个连接 XML（schema 复杂，本 demo 暂不展开）。
    # 这里用"内部 HMI 变量"（无 Connection/ControllerTag），仅证明 ImportHmiTagTable 通路。
    $hmiTagsJson = @{
        Name='默认变量表'
        Tags = @(
            @{ Name='HMI_Start'; DataType='Bool' },
            @{ Name='HMI_Stop';  DataType='Bool' },
            @{ Name='HMI_EStop'; DataType='Bool' },
            @{ Name='HMI_Run';   DataType='Bool' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    $hmiTagsBuild = Validate 'HMI' 'BuildClassicHmiTagTableXml' @{ tableJson=$hmiTagsJson } 10000 'build HMI tag table XML'
    if ($hmiTagsBuild.status -eq 'OK') {
        $jp = ($hmiTagsBuild.fullText | ConvertFrom-Json -ErrorAction SilentlyContinue)
        if ($jp -and $jp.xml) {
            $hmiTagPath = Join-Path $tmpHmi 'hmi_tags.xml'
            Save-XmlContent $hmiTagPath $jp.xml
            Validate 'HMI' 'ImportHmiTagTable' @{ softwarePath='HMI_1'; folderPath=''; importPath=$hmiTagPath } 90000 'ImportHmiTagTable' | Out-Null
        } else {
            Write-Host "(skip ImportHmiTagTable: no xml in build response)" -ForegroundColor Yellow
        }
    }

    # === 10. HMI screen build offline + import ===
    $hmiScreenJson = @{
        Screen=@{ Name='主画面'; Width=800; Height=480 }
        Items=@(
            @{ Type='Text';   Name='Title';    Left=20;  Top=10;  Width=760; Height=40; Text='起保停控制（MCP Demo）' },
            @{ Type='Button'; Name='BtnStart'; Left=80;  Top=180; Width=160; Height=80; Text='启动 START' },
            @{ Type='Button'; Name='BtnStop';  Left=320; Top=180; Width=160; Height=80; Text='停止 STOP'  },
            @{ Type='Button'; Name='BtnEStop'; Left=560; Top=180; Width=160; Height=80; Text='急停 E-STOP' },
            @{ Type='Lamp';   Name='LmpRun';   Left=320; Top=320; Width=160; Height=80; Text='运行中' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    $hmiScrBuild = Validate 'HMI' 'BuildClassicHmiScreenXml' @{ designJson=$hmiScreenJson } 10000 'build HMI screen XML'
    if ($hmiScrBuild.status -eq 'OK') {
        $jp = ($hmiScrBuild.fullText | ConvertFrom-Json -ErrorAction SilentlyContinue)
        if ($jp -and $jp.xml) {
            $hmiScrPath = Join-Path $tmpHmi 'hmi_main.xml'
            Save-XmlContent $hmiScrPath $jp.xml
            Validate 'HMI' 'ImportHmiScreen' @{ softwarePath='HMI_1'; folderPath=''; importPath=$hmiScrPath } 90000 'ImportHmiScreen' | Out-Null
        } else {
            Write-Host "(skip ImportHmiScreen: no xml in build response)" -ForegroundColor Yellow
        }
    }

    # === 11. Verify HMI state (best-effort — may fail if project handle disposed by HMI import error) ===
    Validate 'HMI' 'GetHmiTagTables' @{ softwarePath='HMI_1' } 30000 'final state check' | Out-Null
    Validate 'HMI' 'GetHmiScreens'   @{ softwarePath='HMI_1' } 30000 'final state check' | Out-Null

    # === 12. Final save + disconnect ===
    Validate 'Project' 'SaveProject' @{} 240000 'final save' | Out-Null
    Validate 'Portal' 'Disconnect' @{} 30000 | Out-Null

    Write-Host ""
    Write-Host "=== Final compile excerpt ===" -ForegroundColor Cyan
    Write-Host $cmp.excerpt
} catch {
    Write-Host "EXCEPTION: $_" -ForegroundColor Red
} finally {
    try { $p.StandardInput.Close() } catch {}
    $p.WaitForExit(15000) | Out-Null
    if (-not $p.HasExited) { $p.Kill() }
    Write-Host "--- server exit: $($p.ExitCode) ---"

    $byStatus = $script:results | Group-Object status | Sort-Object Name
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# MCP Full Demo (KTP700) — Validation")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format o)")
    [void]$sb.AppendLine("Project: $projName  Path: $projDir")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## By status")
    foreach ($g in $byStatus) { [void]$sb.AppendLine("- $($g.Name): $($g.Count)") }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Step-by-step")
    [void]$sb.AppendLine("| # | Tool | Status | ms | Note | Message |")
    [void]$sb.AppendLine("|---|---|---|---|---|---|")
    $i = 1
    foreach ($r in $script:results) {
        $msg = ($r.message -replace '\|','/' -replace '\r?\n',' ')
        if ($msg.Length -gt 120) { $msg = $msg.Substring(0,120)+'...' }
        [void]$sb.AppendLine("| $i | $($r.tool) | $($r.status) | $($r.elapsedMs) | $($r.note) | $msg |")
        $i++
    }
    [System.IO.File]::WriteAllText($summary, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Summary: $summary" -ForegroundColor Cyan
    foreach ($g in $byStatus) { Write-Host (" {0}: {1}" -f $g.Name, $g.Count) }

    try {
        if ($stderrTask.Wait(5000)) {
            $errPath = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_demo_full.stderr.log"
            [System.IO.File]::WriteAllText($errPath, $stderrTask.Result, (New-Object System.Text.UTF8Encoding($false)))
        }
    } catch {}
}
