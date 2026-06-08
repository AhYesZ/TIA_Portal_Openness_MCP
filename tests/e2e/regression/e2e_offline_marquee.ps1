$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Debug\net48\TiaMcpServer.exe"

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
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='offline-marquee'; version='1.0' } } 30000
    Write-Host "init: $($init.result.serverInfo.name)"
    _RawSend @{ jsonrpc='2.0'; method='notifications/initialized'; params=@{} }

    # 跑马灯 FC（位移逻辑），用 builder 表达：
    #   IF "Q_Run" THEN
    #      "Q_RunLamp4" := "Q_RunLamp3";   <- 符号→符号赋值
    #      "Q_RunLamp3" := "Q_RunLamp2";
    #      "Q_RunLamp2" := "Q_RunLamp1";
    #      "Q_RunLamp1" := NOT ("Q_RunLamp1" OR "Q_RunLamp2" OR "Q_RunLamp3" OR "Q_RunLamp4");  <- 自由表达式
    #   ELSE
    #      "Q_RunLamp1" := FALSE; ...
    #   END_IF;
    $marqueeJson = @{
        blockName='FC_Marquee'; blockNumber=20
        commentZhCn='跑马灯（4 位 Q_RunLamp 位移）：Q_Run=TRUE 时按位轮转；Q_Run=FALSE 时全清零。
位移依赖 builder 的 assignment.source（符号→符号）+ line op（自由表达式）能力。'
        titleZhCn='4 位跑马灯位移逻辑'
        networkTitleZhCn='IF Q_Run THEN 位移 ELSE 清零 END_IF'
        inputs = @(); outputs = @()
        structuredText = @{
            operations = @(
                @{ op='if'; condition='"Q_Run"' },
                @{ op='assignment'; target='"Q_RunLamp4"'; source='"Q_RunLamp3"'; indent=2 },
                @{ op='assignment'; target='"Q_RunLamp3"'; source='"Q_RunLamp2"'; indent=2 },
                @{ op='assignment'; target='"Q_RunLamp2"'; source='"Q_RunLamp1"'; indent=2 },
                @{ op='line'; indent=2; items=@(
                    @{ sym='"Q_RunLamp1"' }, @{ token=':=' }, @{ token='NOT' }, @{ token='(' },
                    @{ sym='"Q_RunLamp1"' }, @{ token='OR' }, @{ sym='"Q_RunLamp2"' }, @{ token='OR' },
                    @{ sym='"Q_RunLamp3"' }, @{ token='OR' }, @{ sym='"Q_RunLamp4"' }, @{ token=')' }, @{ token=';' }
                )},
                @{ op='else' },
                @{ op='assignment'; target='"Q_RunLamp1"'; literalValue='FALSE'; indent=2 },
                @{ op='assignment'; target='"Q_RunLamp2"'; literalValue='FALSE'; indent=2 },
                @{ op='assignment'; target='"Q_RunLamp3"'; literalValue='FALSE'; indent=2 },
                @{ op='assignment'; target='"Q_RunLamp4"'; literalValue='FALSE'; indent=2 },
                @{ op='endif' }
            )
        }
    } | ConvertTo-Json -Compress -Depth 10
    $r = Send-Request 'tools/call' @{ name='PlcBuildAndImport'; arguments=@{ softwarePath=''; kind='fc'; json=$marqueeJson; dryRun=$true; compileAfter=$false } } 30000
    $rText = ($r.result.content | ?{$_.type -eq 'text'} | Select -First 1).text
    $rObj = $rText | ConvertFrom-Json
    if ($rObj.writtenFiles) {
        $xmlPath = $rObj.writtenFiles[0]
        $xml = Get-Content $xmlPath -Raw -Encoding UTF8
        $hasAllLamps = ($xml -match 'Component Name="Q_RunLamp1"') -and ($xml -match 'Component Name="Q_RunLamp2"') -and ($xml -match 'Component Name="Q_RunLamp3"') -and ($xml -match 'Component Name="Q_RunLamp4"')
        $hasNot = $xml -match 'Text="NOT"'
        $hasOr  = $xml -match 'Text="OR"'
        $hasParens = ($xml -match 'Text="\("') -and ($xml -match 'Text="\)"')
        $hasIfElse = ($xml -match 'Text="IF"') -and ($xml -match 'Text="ELSE"') -and ($xml -match 'Text="END_IF"')
        $hasFalse = $xml -match '<ConstantValue[^>]*>FALSE</ConstantValue>'
        $hasMultilingual = $xml -match '<MultilingualText[^>]*CompositionName="Comment"'
        $hasMarqueeChinese = $xml -match '跑马灯'
        Write-Host "=== 跑马灯 FC offline build ==="
        Write-Host "  all 4 lamps as globals : $hasAllLamps"
        Write-Host "  NOT/OR/parens          : $hasNot/$hasOr/$hasParens"
        Write-Host "  IF/ELSE/END_IF         : $hasIfElse"
        Write-Host "  FALSE literals (清零)   : $hasFalse"
        Write-Host "  block-level Comment    : $hasMultilingual"
        Write-Host "  Chinese 跑马灯 in XML  : $hasMarqueeChinese"
        Write-Host ""
        Write-Host "File: $xmlPath"

        if ($hasAllLamps -and $hasNot -and $hasOr -and $hasParens -and $hasIfElse -and $hasFalse -and $hasMultilingual -and $hasMarqueeChinese) {
            Write-Host "=== 跑马灯 FC ALL CHECKS PASSED ===" -ForegroundColor Green
        } else {
            Write-Host "=== Some checks failed; see details above ===" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "FAIL: $_" -ForegroundColor Red
} finally {
    try { $p.StandardInput.Close() } catch {}
    $p.WaitForExit(5000) | Out-Null
    if (-not $p.HasExited) { $p.Kill() }
}
