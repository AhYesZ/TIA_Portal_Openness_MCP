$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Debug\net48\TiaMcpServer.exe"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$proc = [System.Diagnostics.Process]::Start($psi)

$script:nextId = 1
function _RawSend($obj) { $msg = $obj | ConvertTo-Json -Compress -Depth 30; $proc.StandardInput.WriteLine($msg); $proc.StandardInput.Flush() }
function Send-Request($method, $params, [int]$timeoutMs=10000) {
    $id = $script:nextId++
    $obj = @{ jsonrpc='2.0'; id=$id; method=$method }
    if ($null -ne $params) { $obj.params = $params }
    _RawSend $obj
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    while ([DateTime]::UtcNow -lt $deadline) {
        $task = $proc.StandardOutput.ReadLineAsync()
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
    Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='schema'; version='1.0' } } 30000 | Out-Null
    _RawSend @{ jsonrpc='2.0'; method='notifications/initialized'; params=@{} }

    # 测：DB.member 写法 → 期待 Symbol 中有 <Token Text="."/>
    $j = @{ operations=@(@{ op='line'; items=@(
        @{ sym='"DB_Tank".CycleCount' }, @{ token=':=' },
        @{ sym='"DB_Tank".CycleCount' }, @{ token='+' }, @{ lit='1' }, @{ token=';' }
    )})} | ConvertTo-Json -Compress -Depth 10
    $r = Send-Request 'tools/call' @{ name='BuildStructuredTextXml'; arguments=@{ structuredTextJson=$j; innerOnly=$true } } 10000
    $xml = (($r.result.content | ?{$_.type -eq 'text'} | Select -First 1).text | ConvertFrom-Json).xml

    Write-Host "=== Symbol XML（DB.member）====" -ForegroundColor Cyan
    Write-Host $xml.Substring(0, [Math]::Min(700, $xml.Length))

    Write-Host ""
    $hasTokenDot = $xml -match '<Symbol[^>]*>\s*<Component[^>]*>\s*<Token Text="\."'
    $hasComp1 = $xml -match 'Component Name="DB_Tank"'
    $hasComp2 = $xml -match 'Component Name="CycleCount"'
    Write-Host ("  Symbol → Component → Token .  : {0}" -f $hasTokenDot)
    Write-Host ("  Component Name='DB_Tank'      : {0}" -f $hasComp1)
    Write-Host ("  Component Name='CycleCount'   : {0}" -f $hasComp2)

    # 单段全局：期待 HasQuotes=true
    $j2 = @{ operations=@(@{ op='assignment'; target='"Q_Run"'; literalValue='TRUE' })} | ConvertTo-Json -Compress -Depth 10
    $r2 = Send-Request 'tools/call' @{ name='BuildStructuredTextXml'; arguments=@{ structuredTextJson=$j2; innerOnly=$true } } 10000
    $xml2 = (($r2.result.content | ?{$_.type -eq 'text'} | Select -First 1).text | ConvertFrom-Json).xml
    Write-Host ""
    Write-Host "=== 单段全局 XML（'Q_Run'）====" -ForegroundColor Cyan
    Write-Host $xml2.Substring(0, [Math]::Min(500, $xml2.Length))
    $hasHasQuotes = $xml2 -match 'BooleanAttribute Name="HasQuotes"[^>]*>true</BooleanAttribute>'
    Write-Host ("  HasQuotes=true               : {0}" -f $hasHasQuotes)
} catch { Write-Host "FAIL: $_" -ForegroundColor Red }
finally { try { $proc.StandardInput.Close() } catch {}; $proc.WaitForExit(5000) | Out-Null; if (-not $proc.HasExited) { $proc.Kill() } }
