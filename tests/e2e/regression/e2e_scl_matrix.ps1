$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Debug\net48\TiaMcpServer.exe"
$reportPath = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_scl_matrix.md"

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

$matrix = @()

function TestCase {
    param([string]$Name, [string]$ExpectedScl, [hashtable]$Json, [string[]]$AssertContainsXml)
    $stJson = $Json | ConvertTo-Json -Compress -Depth 20
    $entry = [ordered]@{ name=$Name; expected=$ExpectedScl; status='?'; missing=@(); xmlExcerpt='' }
    try {
        $r = Send-Request 'tools/call' @{ name='BuildStructuredTextXml'; arguments=@{ structuredTextJson=$stJson; innerOnly=$true } } 10000
        if ($r.error) {
            $entry.status = 'BUILDER_ERROR'
            $entry.missing = @($r.error.message)
        } else {
            $text = ($r.result.content | ?{$_.type -eq 'text'} | Select -First 1).text
            if ($text -like 'An error occurred*') {
                $entry.status = 'BUILDER_ERROR'
                $entry.missing = @($text.Substring(0,[Math]::Min(200,$text.Length)))
            } else {
                $obj = $text | ConvertFrom-Json
                $xml = $obj.xml
                $entry.xmlExcerpt = $xml.Substring(0,[Math]::Min(280,$xml.Length))
                $missing = @()
                foreach ($needle in $AssertContainsXml) {
                    if ($xml -notmatch $needle) { $missing += $needle }
                }
                if ($missing.Count -eq 0) {
                    $entry.status = 'PASS'
                } else {
                    $entry.status = 'XML_MISMATCH'
                    $entry.missing = $missing
                }
            }
        }
    } catch {
        $entry.status = 'EXCEPTION'
        $entry.missing = @("$_")
    }
    $script:matrix += [pscustomobject]$entry
    $color = switch ($entry.status) {'PASS'{'Green'} default {'Red'}}
    $head = "[{0,3}/{1,-3}] {2,-12} {3}" -f $script:matrix.Count, '30', $entry.status, $Name
    Write-Host $head -ForegroundColor $color
    if ($entry.status -ne 'PASS') {
        foreach ($m in $entry.missing) { Write-Host "      missing/error: $m" -ForegroundColor DarkYellow }
    }
}

try {
    Start-Sleep -Seconds 3
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='scl-matrix'; version='1.0' } } 30000
    Write-Host "init: $($init.result.serverInfo.name)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "=== SCL 指令矩阵（共 20 项）===" -ForegroundColor Cyan
    _RawSend @{ jsonrpc='2.0'; method='notifications/initialized'; params=@{} }

    # 1 简单赋值（局部）
    TestCase '1. 局部变量赋字面' '#x := FALSE;' `
        @{ operations=@(@{op='assignment'; target='x'; literalValue='FALSE'}) } `
        @('Scope="LocalVariable"', 'Component Name="x"', 'ConstantValue[^>]*>FALSE')

    # 2 简单赋值（全局）
    TestCase '2. 全局变量赋字面' '"Q_Run" := TRUE;' `
        @{ operations=@(@{op='assignment'; target='"Q_Run"'; literalValue='TRUE'}) } `
        @('Scope="GlobalVariable"', 'Component Name="Q_Run"', 'ConstantValue[^>]*>TRUE')

    # 3 IF/ELSE/END_IF
    TestCase '3. IF/ELSE/END_IF（局部）' 'IF x THEN ... ELSE ... END_IF;' `
        @{ operations=@(
            @{op='if'; condition='x'},
            @{op='assignment'; target='y'; literalValue='1'; indent=2},
            @{op='else'},
            @{op='assignment'; target='y'; literalValue='0'; indent=2},
            @{op='endif'}
        )} `
        @('Text="IF"', 'Text="ELSE"', 'Text="END_IF"')

    # 4 ELSIF 链
    TestCase '4. IF/ELSIF/ELSIF/END_IF' '起保停三段优先级' `
        @{ operations=@(
            @{op='if'; condition='"I_EStop"'},
            @{op='assignment'; target='"Q_Run"'; literalValue='FALSE'; indent=2},
            @{op='elsif'; condition='"I_Stop"'},
            @{op='assignment'; target='"Q_Run"'; literalValue='FALSE'; indent=2},
            @{op='elsif'; condition='"I_Start"'},
            @{op='assignment'; target='"Q_Run"'; literalValue='TRUE'; indent=2},
            @{op='endif'}
        )} `
        @('Text="IF"', 'Text="ELSIF"', 'Component Name="I_EStop"')

    # 5 符号到符号赋值
    TestCase '5. 符号位移赋值 a := b' '"Q4" := "Q3";' `
        @{ operations=@(@{op='assignment'; target='"Q4"'; source='"Q3"'}) } `
        @('Component Name="Q4"', 'Component Name="Q3"')

    # 6 算术：+
    TestCase '6. 算术加 (+)' 'Counter := Counter + 1;' `
        @{ operations=@(@{op='line'; items=@(
            @{sym='"DB_Motor.Counter"'}, @{token=':='}, @{sym='"DB_Motor.Counter"'}, @{token='+'}, @{lit='1'}, @{token=';'}
        )})} `
        @('Component Name="DB_Motor"', 'Component Name="Counter"', 'Text="\+"', 'ConstantValue[^>]*>1<')

    # 7 比较运算 >=
    TestCase '7. 比较 >=' 'IF Counter >= 1000 THEN' `
        @{ operations=@(@{op='line'; items=@(
            @{token='IF'}, @{sym='"DB_Motor.Counter"'}, @{token='>='}, @{lit='1000'}, @{token='THEN'}
        )})} `
        @('Text="IF"', 'Text="THEN"', 'Text="&gt;="')

    # 8 逻辑 AND OR NOT
    TestCase '8. AND / OR / NOT 表达式' 'Q := (a OR b) AND NOT c;' `
        @{ operations=@(@{op='line'; items=@(
            @{sym='"Q_Run"'}, @{token=':='},
            @{token='('}, @{sym='"I_Start"'}, @{token='OR'}, @{sym='"Q_Run"'}, @{token=')'},
            @{token='AND'}, @{token='NOT'}, @{sym='"I_Stop"'}, @{token=';'}
        )})} `
        @('Text="OR"', 'Text="AND"', 'Text="NOT"', 'Text="\("', 'Text="\)"')

    # 9 DB 多段成员路径
    TestCase '9. DB 成员链路径访问' '"DB.member" 多段 Component' `
        @{ operations=@(@{op='global'; name='DB_Motor.Speed'}, @{op='token'; text=';'}, @{op='newline'})} `
        @('Component Name="DB_Motor"', 'Component Name="Speed"', 'Scope="GlobalVariable"')

    # 10 TIME 字面常量
    TestCase '10. TIME 字面 T#1S' 'PT := T#1S' `
        @{ operations=@(@{op='line'; items=@(
            @{token='PT'}, @{token=':='}, @{lit='T#1S'}, @{token=';'}
        )})} `
        @('ConstantValue[^>]*>T#1S<')

    # 11 函数调用 REAL_TO_INT(x)
    TestCase '11. 类型转换函数调用' 'a := REAL_TO_INT(b);' `
        @{ operations=@(@{op='line'; items=@(
            @{sym='a'}, @{token=':='}, @{token='REAL_TO_INT'}, @{raw='('}, @{sym='b'}, @{raw=')'}, @{token=';'}
        )})} `
        @('Text="REAL_TO_INT"', 'Component Name="a"', 'Component Name="b"')

    # 12 数学函数 SQRT
    TestCase '12. SQRT 函数调用' 'a := SQRT(b);' `
        @{ operations=@(@{op='line'; items=@(
            @{sym='a'}, @{token=':='}, @{token='SQRT'}, @{raw='('}, @{sym='b'}, @{raw=')'}, @{token=';'}
        )})} `
        @('Text="SQRT"')

    # 13 MIN/MAX
    TestCase '13. MIN(a,b)' 'r := MIN(a,b);' `
        @{ operations=@(@{op='line'; items=@(
            @{sym='r'}, @{token=':='}, @{token='MIN'}, @{raw='('}, @{sym='a'}, @{raw=','}, @{sym='b'}, @{raw=')'}, @{token=';'}
        )})} `
        @('Text="MIN"', 'Text=","')

    # 14 ABS
    TestCase '14. ABS(x)' 'r := ABS(x);' `
        @{ operations=@(@{op='line'; items=@(
            @{sym='r'}, @{token=':='}, @{token='ABS'}, @{raw='('}, @{sym='x'}, @{raw=')'}, @{token=';'}
        )})} `
        @('Text="ABS"')

    # 15 多语句 / 多 IF
    TestCase '15. 多 IF 串联' '两个 IF 块串联' `
        @{ operations=@(
            @{op='if'; condition='a'},
            @{op='assignment'; target='b'; literalValue='1'; indent=2},
            @{op='endif'},
            @{op='if'; condition='c'},
            @{op='assignment'; target='d'; literalValue='2'; indent=2},
            @{op='endif'}
        )} `
        @('Text="IF"', 'Text="END_IF"', 'Component Name="a"', 'Component Name="c"')

    # 16 嵌套 IF
    TestCase '16. 嵌套 IF（缩进 2/4/2）' 'IF a THEN IF b THEN ...' `
        @{ operations=@(
            @{op='if'; condition='a'},
            @{op='if'; condition='b'; indent=2},
            @{op='assignment'; target='c'; literalValue='TRUE'; indent=4},
            @{op='endif'; indent=2},
            @{op='endif'}
        )} `
        @('Text="IF"', 'Text="END_IF"')

    # 17 NOT 一元
    TestCase '17. NOT 一元（取反赋值）' 'r := NOT b;' `
        @{ operations=@(@{op='line'; items=@(
            @{sym='r'}, @{token=':='}, @{token='NOT'}, @{sym='b'}, @{token=';'}
        )})} `
        @('Text="NOT"')

    # 18 多种运算混合
    TestCase '18. 混合算术 + 逻辑' 'r := (a + b) * c;' `
        @{ operations=@(@{op='line'; items=@(
            @{sym='r'}, @{token=':='}, @{token='('}, @{sym='a'}, @{token='+'}, @{sym='b'}, @{token=')'}, @{token='*'}, @{sym='c'}, @{token=';'}
        )})} `
        @('Text="\+"', 'Text="\*"', 'Text="\("', 'Text="\)"')

    # 19 字符串字面（限制：可能被截断；先 best-effort）
    TestCase '19. 字符串字面 "abc"' "msg := 'abc';" `
        @{ operations=@(@{op='line'; items=@(
            @{sym='msg'}, @{token=':='}, @{lit="'abc'"}, @{token=';'}
        )})} `
        @("ConstantValue[^>]*>&apos;abc&apos;<")

    # 20 整型字面 + 浮点字面
    TestCase '20. 整型 / 浮点字面' 'a := 100; b := 3.14;' `
        @{ operations=@(
            @{op='line'; items=@(@{sym='a'}, @{token=':='}, @{lit='100'}, @{token=';'})},
            @{op='line'; items=@(@{sym='b'}, @{token=':='}, @{lit='3.14'}, @{token=';'})}
        )} `
        @('ConstantValue[^>]*>100<', 'ConstantValue[^>]*>3.14<')

    # === Tier 2: 高级 / 控制流 ===

    # 21 CASE 语句
    TestCase '21. CASE OF / END_CASE' 'CASE x OF 1: ...; 2: ...; END_CASE;' `
        @{ operations=@(
            @{op='line'; items=@(@{token='CASE'}, @{sym='x'}, @{token='OF'})},
            @{op='line'; items=@(@{lit='1'}, @{raw=':'}, @{sym='y'}, @{token=':='}, @{lit='10'}, @{token=';'})},
            @{op='line'; items=@(@{lit='2'}, @{raw=':'}, @{sym='y'}, @{token=':='}, @{lit='20'}, @{token=';'})},
            @{op='line'; items=@(@{token='END_CASE'})}
        )} `
        @('Text="CASE"', 'Text="OF"', 'Text="END_CASE"')

    # 22 FOR 循环
    TestCase '22. FOR i := 1 TO N DO / END_FOR' 'FOR loop' `
        @{ operations=@(
            @{op='line'; items=@(@{token='FOR'}, @{sym='i'}, @{token=':='}, @{lit='1'}, @{token='TO'}, @{lit='10'}, @{token='DO'})},
            @{op='assignment'; target='sum'; source='i'; indent=2},
            @{op='line'; items=@(@{token='END_FOR'})}
        )} `
        @('Text="FOR"', 'Text="TO"', 'Text="DO"', 'Text="END_FOR"')

    # 23 WHILE 循环
    TestCase '23. WHILE / END_WHILE' 'WHILE x < 10 DO ...' `
        @{ operations=@(
            @{op='line'; items=@(@{token='WHILE'}, @{sym='x'}, @{token='<'}, @{lit='10'}, @{token='DO'})},
            @{op='line'; items=@(@{sym='x'}, @{token=':='}, @{sym='x'}, @{token='+'}, @{lit='1'}, @{token=';'}); indent=2},
            @{op='line'; items=@(@{token='END_WHILE'})}
        )} `
        @('Text="WHILE"', 'Text="DO"', 'Text="END_WHILE"', 'Text="&lt;"')

    # 24 RETURN
    TestCase '24. RETURN 提前退出' 'RETURN;' `
        @{ operations=@(@{op='line'; items=@(@{token='RETURN'})})} `
        @('Text="RETURN"')

    # 25 EXIT（FOR/WHILE 提前退出）
    TestCase '25. EXIT' 'EXIT;' `
        @{ operations=@(@{op='line'; items=@(@{token='EXIT'})})} `
        @('Text="EXIT"')

    # 26 局部变量多段成员（#trig.Q 这种）—— 当前 Symbol() 不识别 “#var.member”，
    # 需要用 raw token 拼，或后续扩展 LocalVariable 支持多 Component
    TestCase '26. 局部变量成员 #trig.Q' 'IF #trig.Q THEN' `
        @{ operations=@(@{op='line'; items=@(
            @{token='IF'},
            @{sym='trig.Q'},  # 当前 Symbol 视为 local，但只取整体名称 "trig.Q" — 验证生成什么
            @{token='THEN'}
        )})} `
        @('Text="IF"', 'Component Name="trig"', 'Component Name="Q"')

    # 27 多实例 FB 调用（#trig(CLK := #x);）—— 现在用 raw token 表达
    TestCase '27. 多实例 FB 调用语法（raw 拼接）' '#trig(CLK := #x);' `
        @{ operations=@(@{op='line'; items=@(
            @{sym='trig'}, @{raw='('}, @{token='CLK'}, @{token=':='}, @{sym='x'}, @{raw=')'}, @{token=';'}
        )})} `
        @('Component Name="trig"', 'Text="CLK"', 'Text=":="', 'Component Name="x"')

    # 28 比较 <
    TestCase '28. 比较 <' 'a < 10' `
        @{ operations=@(@{op='line'; items=@(@{sym='a'}, @{token='<'}, @{lit='10'})})} `
        @('Text="&lt;"')

    # 29 比较 <>
    TestCase '29. 比较 <> 不等于' 'a <> b' `
        @{ operations=@(@{op='line'; items=@(@{sym='a'}, @{token='<>'}, @{sym='b'})})} `
        @('Text="&lt;&gt;"')

    # 30 多语句赋值序列
    TestCase '30. 多语句串联' 'a := 1; b := 2; c := a + b;' `
        @{ operations=@(
            @{op='assignment'; target='a'; literalValue='1'},
            @{op='assignment'; target='b'; literalValue='2'},
            @{op='line'; items=@(@{sym='c'}, @{token=':='}, @{sym='a'}, @{token='+'}, @{sym='b'}, @{token=';'})}
        )} `
        @('Component Name="a"', 'Component Name="b"', 'Component Name="c"')

    Write-Host ""
    $passed = ($matrix | ?{$_.status -eq 'PASS'}).Count
    Write-Host ("=== {0} / {1} 通过 ===" -f $passed, $matrix.Count) -ForegroundColor Cyan

    # write report
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# SCL Builder 指令矩阵测试")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format o)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**$passed / $($matrix.Count) 通过**")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('| # | Pattern | Status | Note |')
    [void]$sb.AppendLine('|---|---|---|---|')
    $i = 1
    foreach ($e in $matrix) {
        $note = ($e.missing -join '; ')
        if ($note.Length -gt 100) { $note = $note.Substring(0,100) + '...' }
        [void]$sb.AppendLine("| $i | $($e.name) | $($e.status) | $note |")
        $i++
    }
    [System.IO.File]::WriteAllText($reportPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Report: $reportPath" -ForegroundColor Cyan
} catch {
    Write-Host "FAIL: $_" -ForegroundColor Red
} finally {
    try { $p.StandardInput.Close() } catch {}
    $p.WaitForExit(5000) | Out-Null
    if (-not $p.HasExited) { $p.Kill() }
}
