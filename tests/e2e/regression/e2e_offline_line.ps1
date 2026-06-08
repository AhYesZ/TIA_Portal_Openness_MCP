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
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='offline-line'; version='1.0' } } 30000
    Write-Host "init: $($init.result.serverInfo.name)"
    _RawSend @{ jsonrpc='2.0'; method='notifications/initialized'; params=@{} }

    # 测试 1：起保停经典表达式 Q_Run := (I_Start OR Q_Run) AND NOT I_Stop
    $jsonA = @{
        operations = @(
            @{ op='line'; items=@(
                @{ sym='"Q_Run"' },
                @{ token=':=' },
                @{ token='(' },
                @{ sym='"I_Start"' },
                @{ token='OR' },
                @{ sym='"Q_Run"' },
                @{ token=')' },
                @{ token='AND' },
                @{ token='NOT' },
                @{ sym='"I_Stop"' },
                @{ token=';' }
            )}
        )
    } | ConvertTo-Json -Compress -Depth 10
    $r = Send-Request 'tools/call' @{ name='BuildStructuredTextXml'; arguments=@{ structuredTextJson=$jsonA; innerOnly=$false } } 10000
    $xmlA = ($r.result.content | ?{$_.type -eq 'text'} | Select -First 1).text | ConvertFrom-Json
    Write-Host "=== Test A: 起保停表达式 ==="
    $hasOR = $xmlA.xml -match 'Text="OR"'
    $hasAND = $xmlA.xml -match 'Text="AND"'
    $hasNOT = $xmlA.xml -match 'Text="NOT"'
    $hasParen = $xmlA.xml -match 'Text="\("' -and $xmlA.xml -match 'Text="\)"'
    $hasGlobals = ($xmlA.xml -match 'Component Name="Q_Run"') -and ($xmlA.xml -match 'Component Name="I_Start"') -and ($xmlA.xml -match 'Component Name="I_Stop"')
    Write-Host "  OR=$hasOR AND=$hasAND NOT=$hasNOT parens=$hasParen all-globals=$hasGlobals"

    # 测试 2：DB 成员算术 DB_Motor.Counter := DB_Motor.Counter + 1
    $jsonB = @{
        operations = @(
            @{ op='line'; items=@(
                @{ sym='"DB_Motor.Counter"' },
                @{ token=':=' },
                @{ sym='"DB_Motor.Counter"' },
                @{ token='+' },
                @{ lit='1' },
                @{ token=';' }
            )}
        )
    } | ConvertTo-Json -Compress -Depth 10
    $r2 = Send-Request 'tools/call' @{ name='BuildStructuredTextXml'; arguments=@{ structuredTextJson=$jsonB; innerOnly=$false } } 10000
    $xmlB = ($r2.result.content | ?{$_.type -eq 'text'} | Select -First 1).text | ConvertFrom-Json
    Write-Host "=== Test B: DB 成员算术 ==="
    $hasDb = $xmlB.xml -match 'Component Name="DB_Motor".*Component Name="Counter"'
    $hasPlus = $xmlB.xml -match 'Text="\+"'
    $hasOne = $xmlB.xml -match '<ConstantValue[^>]*>1</ConstantValue>'
    Write-Host "  DB.member-path=$hasDb plus=$hasPlus literal-1=$hasOne"
    Write-Host ""
    Write-Host "Sample DB expression XML excerpt:"
    Write-Host ($xmlB.xml.Substring(0,[Math]::Min(800,$xmlB.xml.Length)))

    Write-Host ""
    Write-Host "=== ALL line-op TESTS PASSED ===" -ForegroundColor Green
} catch {
    Write-Host "FAIL: $_" -ForegroundColor Red
} finally {
    try { $p.StandardInput.Close() } catch {}
    $p.WaitForExit(5000) | Out-Null
    if (-not $p.HasExited) { $p.Kill() }
}
