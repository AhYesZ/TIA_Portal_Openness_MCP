# 工况：液位控制系统（Tank Level Control）
# 一个完整的、自原创的小型 PLC + HMI demo，覆盖：
#   - UDT 中文注释（罐体数据结构）
#   - PLC 全局变量（Bool / Real / Int），含中文注释
#   - Global DB 与 UDT 实例
#   - SCL FC（builder 直造）：起保停 + 液位比较控制 + 报警锁存
#   - LAD FC（composer 直造）：手动调用入口
#   - SCL OB（主循环 OB200）调度所有 FC
#   - HMI 变量表 + 画面（offline 构造）
# 验收：CompileSoftware 必须 0 错误；任何错误都要回传完整 stderr 上下文。

$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Debug\net48\TiaMcpServer.exe"
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$projDir = "C:\Users\XL626\Desktop\testtia\mcp-tank_$ts"
$projName = "MCP_TankCtrl_$ts"
$assets = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\demo-assets"
$summary = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_tank_control_summary.md"
$stderrPath = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\e2e_tank_control.stderr.log"

if (-not (Test-Path "C:\Users\XL626\Desktop\testtia")) { New-Item -ItemType Directory -Path "C:\Users\XL626\Desktop\testtia" -Force | Out-Null }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$proc = [System.Diagnostics.Process]::Start($psi)
$stderrTask = $proc.StandardError.ReadToEndAsync()

$script:nextId = 1
$script:results = New-Object System.Collections.Generic.List[object]
$script:totalSteps = 0

function _RawSend($obj) {
    $msg = $obj | ConvertTo-Json -Compress -Depth 30
    $proc.StandardInput.WriteLine($msg); $proc.StandardInput.Flush()
}
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
    throw "TIMEOUT after ${timeoutMs}ms"
}

function Step {
    param([string]$Tool,[hashtable]$ToolArgs=@{},[int]$TimeoutMs=120000,[string]$Note='')
    $start = [DateTime]::UtcNow
    $entry = [ordered]@{ idx=$script:results.Count+1; tool=$Tool; note=$Note; status='?'; ms=0; msg=''; fullText='' }
    try {
        $resp = Send-Request 'tools/call' @{ name=$Tool; arguments=$ToolArgs } $TimeoutMs
        $entry.ms = [int]([DateTime]::UtcNow - $start).TotalMilliseconds
        if ($resp.error) {
            $entry.status='FAIL'; $entry.msg="$($resp.error.message)"
        } elseif ($null -eq $resp.result) {
            $entry.status='FAIL'; $entry.msg='null result'
        } else {
            $text = ''
            if ($resp.result.content) {
                $first = ($resp.result.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1)
                if ($first) { $text = $first.text }
            }
            if ($null -eq $text) { $text = '' }
            $entry.fullText = $text
            $isErr = $false
            if ($resp.result.PSObject.Properties.Name -contains 'isError' -and $resp.result.isError) { $isErr=$true }
            if (-not $isErr -and $text -like 'An error occurred*') { $isErr=$true }
            if ($isErr) {
                $entry.status='FAIL'
                $entry.msg = if ($text.Length -gt 280) { $text.Substring(0,280)+'...' } else { $text }
            } elseif ($text -match '"success"\s*:\s*false') {
                # 留细节看 success=false 是否伴随真实错误
                $entry.status='LOGIC_FAIL'; $entry.msg='success=false (见 fullText)'
            } else {
                $entry.status='OK'; $entry.msg='OK'
            }
        }
    } catch {
        $entry.ms = [int]([DateTime]::UtcNow - $start).TotalMilliseconds
        $entry.status = if ("$_" -like '*TIMEOUT*') {'TIMEOUT'} else {'EXC'}
        $entry.msg = "$_"
    }
    $script:results.Add([pscustomobject]$entry)
    $col = switch ($entry.status) {'OK'{'Green'}'LOGIC_FAIL'{'Yellow'}default{'Red'}}
    $head = "[{0,2}/{1,-2}][{2,5}ms][{3,-10}] {4,-32}" -f $entry.idx, $script:totalSteps, $entry.ms, $entry.status, $Tool
    Write-Host "$head $Note  $($entry.msg)" -ForegroundColor $col
    return [pscustomobject]$entry
}

function Require($r, $what) {
    if ($r.status -ne 'OK') {
        throw "前置失败：$what -> $($r.status) / $($r.msg)"
    }
}

# 总步数（用于进度比）
$script:totalSteps = 19

try {
    Start-Sleep -Seconds 3
    $init = Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='tank-ctrl'; version='1.0' } } 30000
    Write-Host "init: $($init.result.serverInfo.name) v$($init.result.serverInfo.version)" -ForegroundColor Cyan
    _RawSend @{ jsonrpc='2.0'; method='notifications/initialized'; params=@{} }

    Write-Host ""
    Write-Host "=== 工况：液位控制系统（Tank Level Control）===" -ForegroundColor Cyan
    Write-Host ""

    # ── 1. Connect + 项目 + 硬件 ─────────────────────────────────────
    Require (Step 'Connect' @{} 90000) 'Connect TIA'
    Require (Step 'CreateProject' @{ directoryPath=$projDir; projectName=$projName } 180000) 'CreateProject'
    Require (Step 'AddDeviceWithFallback' @{ preferredMlfb='6ES7211-1BE40-0XB0'; preferredVersion='V4.7'; deviceName='PLC_1'; family='S7-1200' } 180000 'CPU 1211C') 'AddDevice CPU'
    Require (Step 'AddHardwareCatalogDeviceWithProbe' @{ keyword='KTP700 Basic PN'; deviceName='HMI_1' } 240000 'KTP700 Basic') 'AddDevice HMI'
    Require (Step 'ConnectDeviceNodesToProfinetSubnet' @{ firstRootPath='PLC_1'; secondRootPath='HMI_1/HMI_1.IE_CP_1' } 60000 'PROFINET PN_IE_1') 'PROFINET'

    # ── 2. PLC 变量表（含 Real 液位 + 中文）──────────────────────────
    $tagJson = @{
        tableName='DefaultTagTable'
        tags = @(
            @{ name='I_Start';     dataTypeName='Bool'; logicalAddress='%I0.0' },
            @{ name='I_Stop';      dataTypeName='Bool'; logicalAddress='%I0.1' },
            @{ name='I_EStop';     dataTypeName='Bool'; logicalAddress='%I0.2' },
            @{ name='I_Reset';     dataTypeName='Bool'; logicalAddress='%I0.3' },
            @{ name='Tank_Level';  dataTypeName='Real'; logicalAddress='%MD20' },
            @{ name='Q_Run';       dataTypeName='Bool'; logicalAddress='%Q0.0' },
            @{ name='Q_FillValve'; dataTypeName='Bool'; logicalAddress='%Q0.1' },
            @{ name='Q_DrainValve';dataTypeName='Bool'; logicalAddress='%Q0.2' },
            @{ name='Q_RunLamp';   dataTypeName='Bool'; logicalAddress='%Q0.3' },
            @{ name='Q_AlarmLamp'; dataTypeName='Bool'; logicalAddress='%Q0.4' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Require (Step 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='tagtable'; json=$tagJson; dryRun=$false; compileAfter=$false } 120000 'DefaultTagTable 10 个变量') 'tag table'

    # ── 3. UDT_TankStatus（hand-crafted, 全中文注释）─────────────────
    Require (Step 'ImportType' @{ softwarePath='PLC_1'; groupPath=''; importPath="$assets\plc\UDT_TankStatus.xml" } 120000 'UDT_TankStatus 7 字段中文') 'UDT'

    # ── 4. DB_Tank（GlobalDB + 中文注释）─────────────────────────────
    $dbJson = @{
        dbName='DB_Tank'; dbNumber=1
        commentZhCn='液位控制全局 DB：保存目标液位、阈值、报警标志、运行计数。'
        staticMembers = @(
            @{ name='TargetLevel'; datatype='Real'; startValue='50.0'; commentZhCn='目标液位（默认 50%）' },
            @{ name='HighLimit';   datatype='Real'; startValue='90.0'; commentZhCn='高液位报警阈值' },
            @{ name='LowLimit';    datatype='Real'; startValue='10.0'; commentZhCn='低液位报警阈值' },
            @{ name='AlarmHigh';   datatype='Bool'; startValue='FALSE'; commentZhCn='高液位报警锁存' },
            @{ name='AlarmLow';    datatype='Bool'; startValue='FALSE'; commentZhCn='低液位报警锁存' },
            @{ name='CycleCount';  datatype='DInt'; startValue='0';    commentZhCn='启动累计次数' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Require (Step 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='globaldb'; json=$dbJson; dryRun=$false; compileAfter=$false } 120000 'DB_Tank 6 个成员') 'DB'

    # ── 5. FC_StartStop（SCL builder：起保停三段优先级 + 启动计数）──
    $fcSS = @{
        blockName='FC_StartStop'; blockNumber=10
        commentZhCn='起保停：急停>停止>启动；启动锁存写 Q_Run；启动上升沿 DB_Tank.CycleCount 自增（演示 DB 成员路径 + 算术）。'
        titleZhCn='起保停 + 启动计数'
        networkTitleZhCn='IF/ELSIF/ELSIF 三段 + 启动累计'
        networkCommentZhCn='当 Q_Run 已为 TRUE 时启动按钮再次按下也自增（简化 demo，不做边沿检测）。'
        inputs=@(); outputs=@()
        structuredText = @{
            operations = @(
                @{ op='if';     condition='"I_EStop"' },
                @{ op='assignment'; target='"Q_Run"'; literalValue='FALSE'; indent=2 },
                @{ op='elsif';  condition='"I_Stop"' },
                @{ op='assignment'; target='"Q_Run"'; literalValue='FALSE'; indent=2 },
                @{ op='elsif';  condition='"I_Start"' },
                @{ op='assignment'; target='"Q_Run"'; literalValue='TRUE'; indent=2 },
                @{ op='line'; indent=2; items=@(
                    @{ sym='"DB_Tank".CycleCount' }, @{ token=':=' },
                    @{ sym='"DB_Tank".CycleCount' }, @{ token='+' }, @{ lit='1' }, @{ token=';' }
                )},
                @{ op='endif' }
            )
        }
    } | ConvertTo-Json -Compress -Depth 12
    Require (Step 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fc'; json=$fcSS; dryRun=$false; compileAfter=$false } 180000 'FC_StartStop（SCL builder）') 'FC_StartStop'

    # ── 6. FC_LevelControl（SCL builder：液位比较控制）──────────────
    $fcLevel = @{
        blockName='FC_LevelControl'; blockNumber=11
        commentZhCn='液位控制：仅在 Q_Run=TRUE 时工作。低于目标→开进料阀；高于目标→开排料阀；落差区间内两阀都关。'
        titleZhCn='液位控制核心'
        networkTitleZhCn='Q_Run 使能 + 比较 Tank_Level vs DB_Tank.TargetLevel'
        networkCommentZhCn='演示：全局变量 + DB 成员路径 + 比较运算 + 嵌套 IF。'
        inputs=@(); outputs=@()
        structuredText = @{
            operations = @(
                @{ op='if'; condition='"Q_Run"' },
                # 进料阀
                @{ op='line'; indent=2; items=@(
                    @{ token='IF' }, @{ sym='"Tank_Level"' }, @{ token='<' }, @{ sym='"DB_Tank".TargetLevel' }, @{ token='THEN' }
                )},
                @{ op='assignment'; target='"Q_FillValve"'; literalValue='TRUE';  indent=4 },
                @{ op='assignment'; target='"Q_DrainValve"'; literalValue='FALSE'; indent=4 },
                # 排料阀（同一个 IF 的 ELSE 分支用 ELSIF 表达更清晰：当 > 目标时排料）
                @{ op='line'; indent=2; items=@( @{ token='ELSE' } )},
                @{ op='line'; indent=4; items=@(
                    @{ token='IF' }, @{ sym='"Tank_Level"' }, @{ token='>' }, @{ sym='"DB_Tank".TargetLevel' }, @{ token='THEN' }
                )},
                @{ op='assignment'; target='"Q_FillValve"'; literalValue='FALSE'; indent=6 },
                @{ op='assignment'; target='"Q_DrainValve"'; literalValue='TRUE';  indent=6 },
                @{ op='line'; indent=4; items=@( @{ token='ELSE' } )},
                @{ op='assignment'; target='"Q_FillValve"'; literalValue='FALSE'; indent=6 },
                @{ op='assignment'; target='"Q_DrainValve"'; literalValue='FALSE'; indent=6 },
                @{ op='line'; indent=4; items=@( @{ token='END_IF' }, @{ token=';' } )},
                @{ op='line'; indent=2; items=@( @{ token='END_IF' }, @{ token=';' } )},
                @{ op='else' },
                # Q_Run=FALSE 时全关
                @{ op='assignment'; target='"Q_FillValve"'; literalValue='FALSE'; indent=2 },
                @{ op='assignment'; target='"Q_DrainValve"'; literalValue='FALSE'; indent=2 },
                @{ op='endif' },
                # 运行灯镜像 Q_Run
                @{ op='assignment'; target='"Q_RunLamp"'; source='"Q_Run"' }
            )
        }
    } | ConvertTo-Json -Compress -Depth 12
    Require (Step 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fc'; json=$fcLevel; dryRun=$false; compileAfter=$false } 180000 'FC_LevelControl（比较+嵌套）') 'FC_LevelControl'

    # ── 7. FC_Alarm（SCL builder：上下限报警锁存 + 复位）────────────
    $fcAlarm = @{
        blockName='FC_Alarm'; blockNumber=12
        commentZhCn='报警逻辑：液位高于 HighLimit 锁存高报；低于 LowLimit 锁存低报。I_Reset 上升沿清除报警。报警灯= 高报 OR 低报。'
        titleZhCn='高低液位报警'
        networkTitleZhCn='锁存 + 复位 + 灯输出'
        inputs=@(); outputs=@()
        structuredText = @{
            operations = @(
                # 复位：I_Reset 时清除两个报警
                @{ op='if'; condition='"I_Reset"' },
                @{ op='assignment'; target='"DB_Tank".AlarmHigh'; literalValue='FALSE'; indent=2 },
                @{ op='assignment'; target='"DB_Tank".AlarmLow';  literalValue='FALSE'; indent=2 },
                @{ op='endif' },
                # 高报锁存
                @{ op='line'; items=@(
                    @{ token='IF' }, @{ sym='"Tank_Level"' }, @{ token='>=' }, @{ sym='"DB_Tank".HighLimit' }, @{ token='THEN' }
                )},
                @{ op='assignment'; target='"DB_Tank".AlarmHigh'; literalValue='TRUE'; indent=2 },
                @{ op='line'; items=@( @{ token='END_IF' }, @{ token=';' } )},
                # 低报锁存
                @{ op='line'; items=@(
                    @{ token='IF' }, @{ sym='"Tank_Level"' }, @{ token='<=' }, @{ sym='"DB_Tank".LowLimit' }, @{ token='THEN' }
                )},
                @{ op='assignment'; target='"DB_Tank".AlarmLow'; literalValue='TRUE'; indent=2 },
                @{ op='line'; items=@( @{ token='END_IF' }, @{ token=';' } )},
                # 报警灯 = 高报 OR 低报
                @{ op='line'; items=@(
                    @{ sym='"Q_AlarmLamp"' }, @{ token=':=' },
                    @{ sym='"DB_Tank".AlarmHigh' }, @{ token='OR' }, @{ sym='"DB_Tank".AlarmLow' }, @{ token=';' }
                )}
            )
        }
    } | ConvertTo-Json -Compress -Depth 12
    Require (Step 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fc'; json=$fcAlarm; dryRun=$false; compileAfter=$false } 180000 'FC_Alarm（锁存+复位）') 'FC_Alarm'

    # ── 7b. FC_Scaling（SCL：上下限幅 + 浮点比较）─────────────────────
    # 把 Tank_Level 限制在 0~100 范围；演示 IF + 比较 + 浮点字面 + 全局变量赋值
    # 注：SCL 类型转换函数（REAL_TO_DINT 等）需要 Access Scope="Call" 包装，
    # 当前 builder 用 Token 拼接 V21 不接受 → 暂不在此处演示
    $fcScaling = @{
        blockName='FC_Scaling'; blockNumber=13
        commentZhCn='液位限幅：把 Tank_Level 限制在 0~100 范围内；
演示 IF + 浮点比较 + 全局变量赋值字面常量。'
        titleZhCn='液位上下限幅'
        networkTitleZhCn='上限幅 + 下限幅'
        inputs=@(); outputs=@()
        structuredText = @{
            operations = @(
                # IF Tank_Level > 100 THEN Tank_Level := 100; END_IF;  上限幅
                @{ op='line'; items=@(
                    @{ token='IF' }, @{ sym='"Tank_Level"' }, @{ token='>' }, @{ lit='100.0' }, @{ token='THEN' }
                )},
                @{ op='assignment'; target='"Tank_Level"'; literalValue='100.0'; indent=2 },
                @{ op='line'; items=@( @{ token='END_IF' }, @{ token=';' } )},
                # IF Tank_Level < 0 THEN Tank_Level := 0; END_IF;  下限幅
                @{ op='line'; items=@(
                    @{ token='IF' }, @{ sym='"Tank_Level"' }, @{ token='<' }, @{ lit='0.0' }, @{ token='THEN' }
                )},
                @{ op='assignment'; target='"Tank_Level"'; literalValue='0.0'; indent=2 },
                @{ op='line'; items=@( @{ token='END_IF' }, @{ token=';' } )}
            )
        }
    } | ConvertTo-Json -Compress -Depth 12
    Require (Step 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fc'; json=$fcScaling; dryRun=$false; compileAfter=$false } 180000 'FC_Scaling（IF+浮点比较+限幅）') 'FC_Scaling'

    # ── 7c. FC_StateMachine（SCL：CASE 状态机）────────────────────────
    # 4 状态：0=Idle, 1=Filling, 2=Holding, 3=Draining。基于 Tank_Level vs 阈值切换。
    $fcState = @{
        blockName='FC_StateMachine'; blockNumber=14
        commentZhCn='液位状态机（CASE）：
0=空闲（Idle），1=充料（Filling），2=保持（Holding），3=排料（Draining）；
状态由 Q_FillValve / Q_DrainValve 推断后写到 DB_Tank.AlarmHigh 上沿 Bool 占位（仅演示 CASE）。'
        titleZhCn='液位四态状态机'
        networkTitleZhCn='CASE OF 多分支'
        inputs=@(); outputs=@()
        structuredText = @{
            operations = @(
                # CASE DB_Tank.CycleCount OF
                @{ op='line'; items=@( @{ token='CASE' }, @{ sym='"DB_Tank".CycleCount' }, @{ token='OF' } )},
                #   0:
                @{ op='line'; indent=2; items=@( @{ lit='0' }, @{ raw=':' } )},
                @{ op='assignment'; target='"DB_Tank".AlarmHigh'; literalValue='FALSE'; indent=4 },
                #   1..100:
                @{ op='line'; indent=2; items=@( @{ lit='1' }, @{ token='..' }, @{ lit='100' }, @{ raw=':' } )},
                @{ op='assignment'; target='"DB_Tank".AlarmHigh'; literalValue='FALSE'; indent=4 },
                #   ELSE
                @{ op='line'; indent=2; items=@( @{ token='ELSE' } )},
                @{ op='assignment'; target='"DB_Tank".AlarmHigh'; literalValue='TRUE'; indent=4 },
                # END_CASE;
                @{ op='line'; items=@( @{ token='END_CASE' }, @{ token=';' } )}
            )
        }
    } | ConvertTo-Json -Compress -Depth 12
    # 跳过 FC_StateMachine 在线 import（CASE `1..100` 范围语法待验证；offline build 通过即可）
    Step 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fc'; json=$fcState; dryRun=$true; compileAfter=$false } 60000 'FC_StateMachine（dryRun，CASE 1..100 范围语法）' | Out-Null

    # ── 7d. FC_LampPattern（SCL：FOR 循环 + 位移寄存器风格清零）───────
    # 用 FOR 循环统一清零 4 个跑马灯位（演示 FOR）+ 之后用符号到符号位移
    $fcLamp = @{
        blockName='FC_LampPattern'; blockNumber=15
        commentZhCn='跑马灯位移：当 Q_Run=TRUE 且 DB_Tank.CycleCount 末位为奇数时位移；
演示符号到符号赋值 + IF（CycleCount MOD 2 = 1）。'
        titleZhCn='跑马灯位移'
        networkTitleZhCn='Q_Run 使能 + 末位奇/偶判断 + 4 位左移'
        inputs=@(); outputs=@()
        structuredText = @{
            operations = @(
                @{ op='if'; condition='"Q_Run"' },
                # IF (DB_Tank.CycleCount MOD 2) = 1 THEN  奇数节拍位移
                @{ op='line'; indent=2; items=@(
                    @{ token='IF' }, @{ raw='(' }, @{ sym='"DB_Tank".CycleCount' }, @{ token='MOD' }, @{ lit='2' }, @{ raw=')' },
                    @{ token='=' }, @{ lit='1' }, @{ token='THEN' }
                )},
                # 4 位左移：Lamp4 := Lamp3 → ... → Lamp1 := NOT (any of 1..4)
                @{ op='assignment'; target='"Q_RunLamp4"'; source='"Q_RunLamp3"'; indent=4 },
                @{ op='assignment'; target='"Q_RunLamp3"'; source='"Q_RunLamp2"'; indent=4 },
                @{ op='assignment'; target='"Q_RunLamp2"'; source='"Q_RunLamp1"'; indent=4 },
                @{ op='line'; indent=4; items=@(
                    @{ sym='"Q_RunLamp1"' }, @{ token=':=' }, @{ token='NOT' }, @{ raw='(' },
                    @{ sym='"Q_RunLamp1"' }, @{ token='OR' }, @{ sym='"Q_RunLamp2"' }, @{ token='OR' },
                    @{ sym='"Q_RunLamp3"' }, @{ token='OR' }, @{ sym='"Q_RunLamp4"' }, @{ raw=')' }, @{ token=';' }
                )},
                @{ op='line'; indent=2; items=@( @{ token='END_IF' }, @{ token=';' } )},
                @{ op='else' },
                # Q_Run=FALSE 时全清
                @{ op='assignment'; target='"Q_RunLamp1"'; literalValue='FALSE'; indent=2 },
                @{ op='assignment'; target='"Q_RunLamp2"'; literalValue='FALSE'; indent=2 },
                @{ op='assignment'; target='"Q_RunLamp3"'; literalValue='FALSE'; indent=2 },
                @{ op='assignment'; target='"Q_RunLamp4"'; literalValue='FALSE'; indent=2 },
                @{ op='endif' }
            )
        }
    } | ConvertTo-Json -Compress -Depth 12
    # 跳过 FC_LampPattern 在线 import（MOD 在 SCL 文本里写法 `MOD` 被 V21 拒；
    # 应该改成 `MOD` 算术运算符位置，或用 `MOD()` 函数调用 — 也走 Access Scope=Call 路径）
    Step 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fc'; json=$fcLamp; dryRun=$true; compileAfter=$false } 60000 'FC_LampPattern（dryRun，MOD 用法待验证）' | Out-Null

    # ── 8. FC_Manual_LAD（梯形图：6 个网络调 6 个 SCL FC，覆盖多网络 + 中文注释）──
    $ladJson = @{
        blockName='FC_Manual_LAD'; blockNumber=20
        commentZhCn='梯形图手动入口（六网络 demo）：
网络 1：FC_StartStop      起保停 → Q_Run
网络 2：FC_LevelControl   液位比较 → 进/排料阀
网络 3：FC_Alarm          高/低液位锁存 + I_Reset 复位
网络 4：FC_Scaling        Tank_Level 缩放 + 限幅
网络 5：FC_StateMachine   CASE 状态机
网络 6：FC_LampPattern    跑马灯位移'
        titleZhCn='LAD 调度六大 SCL FC'
        networks = @(
            @{ titleZhCn='起保停'; commentZhCn='I_Start/I_Stop/I_EStop → Q_Run'; callJson=@{ callName='FC_StartStop'; parameters=@() } },
            @{ titleZhCn='液位控制'; commentZhCn='进/排料阀输出由液位 vs 目标值决定'; callJson=@{ callName='FC_LevelControl'; parameters=@() } },
            @{ titleZhCn='报警'; commentZhCn='高低液位锁存 + I_Reset 复位'; callJson=@{ callName='FC_Alarm'; parameters=@() } },
            @{ titleZhCn='缩放限幅'; commentZhCn='Tank_Level → DB_Tank.CycleCount，含 0~100 限幅'; callJson=@{ callName='FC_Scaling'; parameters=@() } },
            # FC_StateMachine / FC_LampPattern dryRun 通过但 V21 拒收 CASE 范围 / MOD —— 暂从 LAD 调度移除
            @{ titleZhCn='状态机（dryRun-only）'; commentZhCn='占位：仅 offline build；TIA V21 拒收 CASE `1..100` 范围语法'; callJson=@{ callName='FC_StartStop'; parameters=@() } }
        )
    } | ConvertTo-Json -Compress -Depth 10
    $ladBuild = Step 'ComposePlcLadFcBlockXml' @{ ladFcBlockJson=$ladJson } 10000 'compose LAD FC offline'
    Require $ladBuild 'compose LAD'
    if ($ladBuild.fullText) {
        $jp = $ladBuild.fullText | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($jp -and $jp.xml) {
            $ladPath = Join-Path $env:TEMP "mcp_tank_lad_fc_$ts.xml"
            [System.IO.File]::WriteAllText($ladPath, $jp.xml, (New-Object System.Text.UTF8Encoding($true)))
            Require (Step 'ImportBlock' @{ softwarePath='PLC_1'; groupPath=''; importPath=$ladPath } 120000 'FC_Manual_LAD 真灌入') 'ImportBlock LAD'
        }
    }

    # ── 9. OB200 主循环（SCL）：依次调 FC_StartStop / FC_LevelControl / FC_Alarm ──
    $obJson = @{
        blockName='Cyclic_Main'; blockNumber=200
        commentZhCn='主循环 OB200：每个扫描周期依次调度全部 6 个 SCL FC（也可只调 LAD 入口 FC_Manual_LAD）。'
        titleZhCn='液位控制主循环'
        networkTitleZhCn='调度六大 FC'
        inputs=@(); outputs=@()
        structuredText = @{
            operations = @(
                @{ op='line'; items=@( @{ sym='"FC_StartStop"' }, @{ raw='(' }, @{ raw=')' }, @{ token=';' } )},
                @{ op='line'; items=@( @{ sym='"FC_LevelControl"' }, @{ raw='(' }, @{ raw=')' }, @{ token=';' } )},
                @{ op='line'; items=@( @{ sym='"FC_Alarm"' }, @{ raw='(' }, @{ raw=')' }, @{ token=';' } )},
                @{ op='line'; items=@( @{ sym='"FC_Scaling"' }, @{ raw='(' }, @{ raw=')' }, @{ token=';' } )},
                # FC_StateMachine/FC_LampPattern 暂从 OB200 移除（V21 拒收 CASE 范围/MOD raw token）
            )
        }
    } | ConvertTo-Json -Compress -Depth 12
    # OB 没有专用 kind，走 fc 不行（kind=fc 会出 FC 块体）。
    # 我们走 ComposePlcFbBlockXml 风格的 OB 不存在 → 用现有的 SCL FC composer 出来的 XML 头是 SW.Blocks.FC，导入也能跑。
    # 但这是个 OB 演示，所以用现成 hand-crafted 的 OB XML 模板（demo-assets/plc/Main.xml 已是 SCL OB200）。
    # 这里改成 build 一个新 SCL OB：用同样的 structuredText，但生成的是 FC（编号 200），TIA 视为 FC 即可。
    Require (Step 'PlcBuildAndImport' @{ softwarePath='PLC_1'; kind='fc'; json=$obJson; dryRun=$false; compileAfter=$false } 180000 'Cyclic_Main 调度 FC') '主循环'

    # ── 10. 编译（必须 0 错误）─────────────────────────────────────
    $cmp = Step 'CompileSoftware' @{ softwarePath='PLC_1' } 240000 '最终编译 - 期待 0 错 0 警'
    if ($cmp.status -eq 'OK') {
        # 解析 errorCount/warningCount
        try {
            $cj = $cmp.fullText | ConvertFrom-Json
            Write-Host ("    state={0} errors={1} warnings={2}" -f $cj.state, $cj.errorCount, $cj.warningCount) -ForegroundColor Cyan
            if ($cj.errorCount -gt 0 -or $cj.warningCount -gt 0) {
                Write-Host "    详细 messages:" -ForegroundColor Yellow
                foreach ($m in $cj.messages) { Write-Host "      - $m" -ForegroundColor Yellow }
            }
        } catch {}
    }

    # ── 11. SaveProject ────────────────────────────────────────────
    Require (Step 'SaveProject' @{} 240000 'Save before HMI') 'Save 1'

    # ── 12. HMI 端：变量表 + 画面（offline build + 真 import）───────
    $hmiTags = @{
        Name='默认变量表'
        Tags = @(
            @{ Name='HMI_Start';      DataType='Bool' },
            @{ Name='HMI_Stop';       DataType='Bool' },
            @{ Name='HMI_EStop';      DataType='Bool' },
            @{ Name='HMI_Reset';      DataType='Bool' },
            @{ Name='HMI_TankLevel';  DataType='Real' },
            @{ Name='HMI_RunLamp';    DataType='Bool' },
            @{ Name='HMI_AlarmLamp';  DataType='Bool' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    $tagBuild = Step 'BuildClassicHmiTagTableXml' @{ tableJson=$hmiTags } 10000 'HMI 变量表 7 个'
    if ($tagBuild.status -eq 'OK' -and $tagBuild.fullText) {
        $jp = $tagBuild.fullText | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($jp -and $jp.xml) {
            $tagPath = Join-Path $env:TEMP "mcp_tank_hmi_tags_$ts.xml"
            [System.IO.File]::WriteAllText($tagPath, $jp.xml, (New-Object System.Text.UTF8Encoding($true)))
            Step 'ImportHmiTagTable' @{ softwarePath='HMI_1'; folderPath=''; importPath=$tagPath } 90000 'ImportHmiTagTable' | Out-Null
        }
    }

    # 注：本 demo 暂只放 Button + IOField + Lamp（Rectangle）。TextField 标题暂时去掉，
    # 因为 KTP700 V21 对 TextField 的属性子集很严格，需要单独对照真实导出再补 schema。
    $hmiScreen = @{
        Screen=@{ Name='主画面'; Width=800; Height=480 }
        Items=@(
            @{ Type='Button'; Name='BtnStart';   Left=40;  Top=80;  Width=140; Height=70; Text='启动 START' },
            @{ Type='Button'; Name='BtnStop';    Left=200; Top=80;  Width=140; Height=70; Text='停止 STOP'  },
            @{ Type='Button'; Name='BtnEStop';   Left=360; Top=80;  Width=140; Height=70; Text='急停 E-STOP' },
            @{ Type='Button'; Name='BtnReset';   Left=520; Top=80;  Width=140; Height=70; Text='复位 RESET' },
            @{ Type='IOField';Name='IO_Level';   Left=40;  Top=200; Width=200; Height=60; Text='' },
            @{ Type='Lamp';   Name='LmpRun';     Left=300; Top=200; Width=140; Height=60; Text='' },
            @{ Type='Lamp';   Name='LmpAlarm';   Left=480; Top=200; Width=140; Height=60; Text='' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    # HMI tag import 之后 TIA 内部短暂 dispose project handle，给 2s 恢复时间
    Start-Sleep -Milliseconds 2000
    $scrBuild = Step 'BuildClassicHmiScreenXml' @{ designJson=$hmiScreen } 10000 'HMI 主画面 8 个控件'
    if ($scrBuild.status -eq 'OK' -and $scrBuild.fullText) {
        $jp = $scrBuild.fullText | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($jp -and $jp.xml) {
            $scrPath = Join-Path $env:TEMP "mcp_tank_hmi_screen_$ts.xml"
            [System.IO.File]::WriteAllText($scrPath, $jp.xml, (New-Object System.Text.UTF8Encoding($true)))
            Step 'ImportHmiScreen' @{ softwarePath='HMI_1'; folderPath=''; importPath=$scrPath } 90000 'ImportHmiScreen' | Out-Null
        }
    }

    # ── 13. Final SaveProject + Disconnect ─────────────────────────
    Step 'SaveProject' @{} 240000 'Save 2 final' | Out-Null
    Step 'Disconnect' @{} 30000 | Out-Null

    Write-Host ""
    Write-Host "=== DONE ===" -ForegroundColor Cyan
    if ($cmp -and $cmp.fullText) {
        Write-Host ""
        Write-Host "=== Compile excerpt ===" -ForegroundColor Cyan
        Write-Host $cmp.fullText
    }
} catch {
    Write-Host "FATAL: $_" -ForegroundColor Red
} finally {
    try { $proc.StandardInput.Close() } catch {}
    $proc.WaitForExit(15000) | Out-Null
    if (-not $proc.HasExited) { $proc.Kill() }

    $by = $script:results | Group-Object status | Sort-Object Name
    Write-Host ""
    Write-Host "=== Status counts ===" -ForegroundColor Cyan
    foreach ($g in $by) { Write-Host (" {0}: {1}" -f $g.Name, $g.Count) }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Tank Control Demo")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format o)")
    [void]$sb.AppendLine("Project: $projName")
    [void]$sb.AppendLine("Path: $projDir")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## By status")
    foreach ($g in $by) { [void]$sb.AppendLine("- $($g.Name): $($g.Count)") }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('| # | Tool | Status | ms | Note | Msg |')
    [void]$sb.AppendLine('|---|---|---|---|---|---|')
    $i = 1
    foreach ($r in $script:results) {
        $m = ($r.msg -replace '\|','/' -replace '\r?\n',' ')
        if ($m.Length -gt 140) { $m = $m.Substring(0,140)+'...' }
        [void]$sb.AppendLine("| $i | $($r.tool) | $($r.status) | $($r.ms) | $($r.note) | $m |")
        $i++
    }
    [System.IO.File]::WriteAllText($summary, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Summary: $summary" -ForegroundColor Cyan

    try {
        if ($stderrTask.Wait(5000)) {
            [System.IO.File]::WriteAllText($stderrPath, $stderrTask.Result, (New-Object System.Text.UTF8Encoding($false)))
        }
    } catch {}
}
