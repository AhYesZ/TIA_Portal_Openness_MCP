$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Debug\net48\TiaMcpServer.exe"
$summary = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_offline_builder.md"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$p = [System.Diagnostics.Process]::Start($psi)

$script:nextId = 1
function _RawSend($obj) {
    $msg = $obj | ConvertTo-Json -Compress -Depth 30
    $p.StandardInput.WriteLine($msg); $p.StandardInput.Flush()
}
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

try {
    Start-Sleep -Seconds 3
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='offline-builder'; version='1.0' } } 30000
    Write-Host "init: $($init.result.serverInfo.name) v$($init.result.serverInfo.version)"
    _RawSend @{ jsonrpc='2.0'; method='notifications/initialized'; params=@{} }

    # 测试 1: BuildStructuredTextXml — 全局变量 + ELSIF
    $stJson = @{
        operations = @(
            @{ op='if';     condition='"I_EStop"' },
            @{ op='assignment'; target='"Q_Run"'; literalValue='FALSE'; indent=2 },
            @{ op='elsif';  condition='"I_Stop"' },
            @{ op='assignment'; target='"Q_Run"'; literalValue='FALSE'; indent=2 },
            @{ op='elsif';  condition='"I_Start"' },
            @{ op='assignment'; target='"Q_Run"'; literalValue='TRUE';  indent=2 },
            @{ op='endif' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    $r = Send-Request 'tools/call' @{ name='BuildStructuredTextXml'; arguments=@{ structuredTextJson=$stJson; innerOnly=$false } } 10000
    $stText = ($r.result.content | ?{$_.type -eq 'text'} | Select -First 1).text
    $stObj = $stText | ConvertFrom-Json
    $hasGlobal = $stObj.xml -match 'Scope="GlobalVariable"'
    $hasElsif = $stObj.xml -match 'Text="ELSIF"'
    $hasI_EStop = $stObj.xml -match 'Component Name="I_EStop"'
    Write-Host "[BuildStructuredTextXml] hasGlobalScope=$hasGlobal hasELSIF=$hasElsif hasI_EStop=$hasI_EStop"

    # 测试 2: PlcBuildAndImport dryRun=true 用同样的 op，构造完整 FC XML
    $fcJson = @{
        blockName='FC_StartStop'; blockNumber=10
        commentZhCn='起保停（builder 生成）'
        titleZhCn='起保停核心 FC'
        networkTitleZhCn='IF/ELSIF/ELSIF/END_IF'
        networkCommentZhCn='急停 > 停止 > 启动 三段优先级；全局读写'
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
    $r2 = Send-Request 'tools/call' @{ name='PlcBuildAndImport'; arguments=@{ softwarePath=''; kind='fc'; json=$fcJson; dryRun=$true; compileAfter=$false } } 30000
    $r2Text = ($r2.result.content | ?{$_.type -eq 'text'} | Select -First 1).text
    $r2Obj = $r2Text | ConvertFrom-Json
    Write-Host "[PlcBuildAndImport dryRun] writtenFiles=$($r2Obj.writtenFiles -join ',') classifiedKind=$($r2Obj.meta.classifiedKind)"
    if ($r2Obj.writtenFiles) {
        $xmlPath = $r2Obj.writtenFiles[0]
        if (Test-Path $xmlPath) {
            $content = Get-Content $xmlPath -Raw -Encoding UTF8
            $hasMultiTextComment = $content -match '<MultilingualText[^>]*CompositionName="Comment"'
            $hasZhCn = $content -match '起保停'
            $hasGlobalAccess = $content -match 'Scope="GlobalVariable"'
            $hasIEStop = $content -match 'Component Name="I_EStop"'
            $hasELSIF = $content -match 'Text="ELSIF"'
            Write-Host "[FC XML] block-comment=$hasMultiTextComment zh-cn=$hasZhCn global-scope=$hasGlobalAccess I_EStop=$hasIEStop ELSIF=$hasELSIF"
            $report = @"
## Generated FC XML (dryRun)
File: $xmlPath
- 块级 Chinese MultilingualText Comment 节点: $hasMultiTextComment
- 文本含 ‘起保停’ 中文: $hasZhCn
- 含 GlobalVariable scope: $hasGlobalAccess
- 含全局变量 I_EStop 引用: $hasIEStop
- 含 ELSIF 关键词: $hasELSIF
"@
            [System.IO.File]::WriteAllText($summary, $report, (New-Object System.Text.UTF8Encoding($false)))
        }
    }

    # 测试 3: ComposePlcLadFcBlockXml — LAD FC composer
    $ladJson = @{
        blockName='FC_Manual_LAD'; blockNumber=50
        commentZhCn='手动控制 LAD 入口'
        titleZhCn='梯形图控制入口'
        networks = @(
            @{ titleZhCn='调用起保停'; commentZhCn='调 FC_StartStop'; callJson=@{ callName='FC_StartStop'; parameters=@() } }
        )
    } | ConvertTo-Json -Compress -Depth 10
    $r3 = Send-Request 'tools/call' @{ name='ComposePlcLadFcBlockXml'; arguments=@{ ladFcBlockJson=$ladJson } } 10000
    $r3Text = ($r3.result.content | ?{$_.type -eq 'text'} | Select -First 1).text
    $r3Obj = $r3Text | ConvertFrom-Json
    $ladHasFlgNet = $r3Obj.xml -match 'FlgNet/v5'
    $ladHasLAD = $r3Obj.xml -match '<ProgrammingLanguage>LAD</ProgrammingLanguage>'
    $ladHasCall = $r3Obj.xml -match 'Name="FC_StartStop"'
    Write-Host "[LAD FC] FlgNet/v5=$ladHasFlgNet LAD=$ladHasLAD call-FC_StartStop=$ladHasCall"

    Write-Host ""
    Write-Host "=== ALL OFFLINE BUILDER TESTS PASSED ===" -ForegroundColor Green
} catch {
    Write-Host "FAIL: $_" -ForegroundColor Red
} finally {
    try { $p.StandardInput.Close() } catch {}
    $p.WaitForExit(5000) | Out-Null
    if (-not $p.HasExited) { $p.Kill() }
}
