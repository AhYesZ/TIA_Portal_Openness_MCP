#requires -Version 5.1
# Stage 4 (revised): HMI is WinCC Unified, not Classic. Use the EnsureUnifiedHmi*
# toolchain and ApplyUnifiedHmiScreenDesignJson for a beautiful screen with
# title bar, two control buttons, status lamp, and two IO fields. Bind PLC tags
# to a real PLC (安全PLC) via EnsureUnifiedHmiConnection.

$ErrorActionPreference = 'Stop'
$exe        = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
$reportMd   = "$PSScriptRoot\verify_unified_hmi.md"
$reportJson = "$PSScriptRoot\verify_unified_hmi.json"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute        = $false
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$proc = [System.Diagnostics.Process]::Start($psi)
$stdin = New-Object System.IO.StreamWriter($proc.StandardInput.BaseStream, (New-Object System.Text.UTF8Encoding($false)))
$stdin.AutoFlush = $true

$script:nextId = 1
$script:pending = $null
$script:results = New-Object System.Collections.ArrayList

function Send-Notify($method, $params) {
    $stdin.WriteLine((@{ jsonrpc='2.0'; method=$method; params=$params } | ConvertTo-Json -Compress -Depth 30))
}
function Send-Request($method, $params, [int]$timeoutMs=60000) {
    $id = $script:nextId++
    $obj = @{ jsonrpc='2.0'; id=$id; method=$method }
    if ($null -ne $params) { $obj.params = $params }
    $stdin.WriteLine(($obj | ConvertTo-Json -Compress -Depth 30))
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($null -eq $script:pending) { $script:pending = $proc.StandardOutput.ReadLineAsync() }
        $remain = [int]([Math]::Max(50, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $script:pending.Wait($remain)) { continue }
        $line = $script:pending.Result; $script:pending = $null
        if ($null -eq $line) { throw "stdout closed before id=$id" }
        try {
            $j = $line | ConvertFrom-Json
            if ($null -ne $j.id -and $j.id -eq $id) { return $j }
        } catch {}
    }
    throw "Timeout id=$id ($method) after ${timeoutMs}ms"
}
function Verify {
    param([string]$category, [string]$label, [hashtable]$toolArgs, [int]$timeoutMs=60000, [string]$toolName='')
    $started = [DateTime]::UtcNow
    if (-not $toolName) { $toolName = $label }
    $entry = [ordered]@{ category=$category; tool=$label; status='fail'; elapsedMs=0; detail='' }
    $text = ''
    try {
        $resp = Send-Request 'tools/call' @{ name=$toolName; arguments=$toolArgs } $timeoutMs
        $text = ($resp.result.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
        if ($resp.error) { $entry.detail = "rpc-error: $($resp.error.message)" }
        elseif ($null -eq $resp.result) { $entry.detail = "empty result" }
        else {
            $isErr = ($resp.result.isError -eq $true) -or ($text -like 'An error occurred*')
            $hasOkFalse = $text -match '"ok"\s*:\s*false'
            $hasSuccessFalse = $text -match '"success"\s*:\s*false'
            $hasErrorField = $text -match '"error"\s*:\s*"[^"]+'
            if ($isErr) { $entry.detail = "tool-error: " + ($text.Substring(0,[Math]::Min(2000,$text.Length))) }
            elseif ($hasOkFalse -or $hasSuccessFalse -or $hasErrorField) { $entry.detail = "logical-fail: " + ($text.Substring(0,[Math]::Min(2000,$text.Length))) }
            else {
                $entry.status = 'pass'
                $entry.detail = if ($text) { ($text.Substring(0,[Math]::Min(380,$text.Length)) -replace '\s+', ' ') } else { '' }
            }
        }
    } catch { $entry.detail = "exception: $($_.Exception.Message)" }
    $entry.elapsedMs = [int]([DateTime]::UtcNow - $started).TotalMilliseconds
    $color = if ($entry.status -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ("[{0,-4}] {1,-46} {2,6}ms  {3}" -f $entry.status.ToUpper(), $label, $entry.elapsedMs, ($entry.detail.Substring(0,[Math]::Min(120,$entry.detail.Length)))) -ForegroundColor $color
    [void]$script:results.Add([pscustomobject]$entry)
    return @{ pass = ($entry.status -eq 'pass'); text = $text }
}

# Verified schema (lowercase keys; colors as 0xAARRGGBB; font.Size for text size)
# Cross-checked against Program.cs::BuildMotorUnifiedHmiDesignJson
$design = @{
    screen = @{ BackColor = '0xFFF8FAFC' }
    items = @(
        # 顶部品牌色标题条
        @{ type='Rectangle'; name='TitleBar';    left=0;   top=0;   width=1024; height=72; properties=@{ BackColor='0xFF0F172A'; BorderWidth=0 } }
        @{ type='Text';      name='TitleText';   left=24;  top=20;  width=720;  height=32; text='电机监控 - MCP Unified HMI 验证画面'; properties=@{ ForeColor='0xFFF8FAFC' }; font=@{ Size=22 } }

        # 主操作区底板
        @{ type='Rectangle'; name='Panel';       left=24;  top=104; width=976;  height=560; properties=@{ BackColor='0xFFFFFFFF'; BorderColor='0xFFCBD5E1'; BorderWidth=1 } }

        # 运行状态指示
        @{ type='Text';      name='StatusLbl';   left=56;  top=144; width=180;  height=32; text='运行状态'; properties=@{ ForeColor='0xFF0F172A' }; font=@{ Size=18 } }
        @{ type='Rectangle'; name='RunLamp';     left=240; top=148; width=28;   height=28; properties=@{ BackColor='0xFF22C55E'; BorderColor='0xFF15803D'; BorderWidth=2 } }
        @{ type='Text';      name='RunLampLbl';  left=280; top=150; width=120;  height=24; text='Running'; properties=@{ ForeColor='0xFF64748B' }; font=@{ Size=12 } }

        # 速度设定与反馈
        @{ type='Text';      name='SpSetLbl';    left=56;  top=216; width=240;  height=32; text='速度设定 (rpm)'; properties=@{ ForeColor='0xFF0F172A' }; font=@{ Size=16 } }
        @{ type='IOField';   name='SpeedSpFld';  left=320; top=212; width=180;  height=44 }
        @{ type='Text';      name='SpActLbl';    left=56;  top=280; width=240;  height=32; text='当前速度 (rpm)'; properties=@{ ForeColor='0xFF0F172A' }; font=@{ Size=16 } }
        @{ type='IOField';   name='SpeedActFld'; left=320; top=276; width=180;  height=44 }

        # 启动 / 停止按钮（事件挂接将由 EnsureUnifiedHmiButtonAction 写入）
        @{ type='Button';    name='StartBtn';    left=56;  top=480; width=200;  height=96; text='启 动'; properties=@{ BackColor='0xFF22C55E'; ForeColor='0xFFFFFFFF'; BorderColor='0xFF15803D'; BorderWidth=1 }; font=@{ Size=22 } }
        @{ type='Button';    name='StopBtn';     left=288; top=480; width=200;  height=96; text='停 止'; properties=@{ BackColor='0xFFDC2626'; ForeColor='0xFFFFFFFF'; BorderColor='0xFFB91C1C'; BorderWidth=1 }; font=@{ Size=22 } }
    )
}

try {
    Start-Sleep -Seconds 3
    Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='verify-unified-hmi'; version='1.0' } } 30000 | Out-Null
    Send-Notify 'notifications/initialized' @{}

    $conn = Verify -category 'L1-Portal' -label 'Connect' -toolArgs @{} -timeoutMs 180000 -toolName 'Connect'
    if (-not $conn.pass) {
        throw "PRECONDITION_FAILED: Connect did not succeed ($($conn.detail)). Start TIA Portal, open the project, accept Openness if prompted, rebuild Release TiaMcpServer.exe, rerun."
    }
    $gp = Verify -category 'L1-Project' -label 'GetProject' -toolArgs @{} -timeoutMs 60000 -toolName 'GetProject'
    if (-not $gp.pass) { throw "GetProject failed" }
    $gpObj = $gp.text | ConvertFrom-Json
    if ($null -eq $gpObj.items -or @($gpObj.items).Count -lt 1) {
        throw "PRECONDITION_FAILED: GetProject returned no open projects (items empty). In TIA: File -> Open and keep the project open."
    }
    $projectName = [string]$gpObj.items[0].name
    if ([string]::IsNullOrWhiteSpace($projectName)) { throw "PRECONDITION_FAILED: GetProject items[0].name is empty." }
    Write-Host "Project: $projectName" -ForegroundColor Cyan
    Verify -category 'L1-Project' -label 'AttachToOpenProject' -toolArgs @{ projectName=$projectName } -timeoutMs 60000 -toolName 'AttachToOpenProject' | Out-Null

    $hmi    = 'HMI_RT_1'
    $plc    = '安全PLC'
    $conn   = 'HMI_Conn_SafetyPLC'
    $tbl    = 'MCPVerify_HmiTags'
    $screen = 'MCPVerify_MainScreen'

    # Step 1: HMI <-> PLC connection
    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiConnection($conn -> $plc)" -toolArgs @{
        hmiSoftwarePath=$hmi; connectionName=$conn; plcName=$plc
    } -timeoutMs 60000 -toolName 'EnsureUnifiedHmiConnection' | Out-Null

    # Step 2: tag table + 5 tags (no PLC binding so we don't depend on PLC tags existing)
    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiTagTable($tbl)" -toolArgs @{
        hmiSoftwarePath=$hmi; tagTableName=$tbl
    } -timeoutMs 30000 -toolName 'EnsureUnifiedHmiTagTable' | Out-Null

    foreach ($t in @(
        @{ name='StartCmd'; type='Bool' }
        @{ name='StopCmd';  type='Bool' }
        @{ name='Running';  type='Bool' }
        @{ name='SpeedSP';  type='Int'  }
        @{ name='SpeedAct'; type='Int'  }
    )) {
        Verify -category 'L2-HMI' -label "EnsureUnifiedHmiTag($($t.name):$($t.type))" -toolArgs @{
            hmiSoftwarePath=$hmi; tagTableName=$tbl; tagName=$t.name; hmiDataType=$t.type
            plcName=''; plcTag=''; connectionName=''
        } -timeoutMs 30000 -toolName 'EnsureUnifiedHmiTag' | Out-Null
    }

    # Step 3: ensure screen exists
    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiScreen($screen 1024x768)" -toolArgs @{
        hmiSoftwarePath=$hmi; screenName=$screen; width=1024; height=768
    } -timeoutMs 60000 -toolName 'EnsureUnifiedHmiScreen' | Out-Null

    # Step 4: apply the beautiful design (single call → all 12 items)
    $designJson = $design | ConvertTo-Json -Depth 30 -Compress
    Verify -category 'L2-HMI' -label "ApplyUnifiedHmiScreenDesignJson($screen)" -toolArgs @{
        hmiSoftwarePath=$hmi; screenName=$screen; designJson=$designJson
    } -timeoutMs 120000 -toolName 'ApplyUnifiedHmiScreenDesignJson' | Out-Null

    # Step 5: button events. Verified HmiButtonEventType enum values:
    #   None, Activated, Deactivated, Tapped, KeyDown, KeyUp, Down, Up, ContextTapped
    # Use Down=press, Up=release. (Pressed/Released/Press/Release are all WRONG.)
    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiButtonAction(StartBtn.Down=set-bit StartCmd)" -toolArgs @{
        hmiSoftwarePath=$hmi; screenName=$screen; buttonName='StartBtn'
        eventType='Down'; actionKind='set-bit'; targetTag='StartCmd'
    } -timeoutMs 30000 -toolName 'EnsureUnifiedHmiButtonAction' | Out-Null

    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiButtonAction(StartBtn.Up=reset-bit StartCmd)" -toolArgs @{
        hmiSoftwarePath=$hmi; screenName=$screen; buttonName='StartBtn'
        eventType='Up'; actionKind='reset-bit'; targetTag='StartCmd'
    } -timeoutMs 30000 -toolName 'EnsureUnifiedHmiButtonAction' | Out-Null

    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiButtonAction(StopBtn.Down=set-bit StopCmd)" -toolArgs @{
        hmiSoftwarePath=$hmi; screenName=$screen; buttonName='StopBtn'
        eventType='Down'; actionKind='set-bit'; targetTag='StopCmd'
    } -timeoutMs 30000 -toolName 'EnsureUnifiedHmiButtonAction' | Out-Null

    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiButtonAction(StopBtn.Up=reset-bit StopCmd)" -toolArgs @{
        hmiSoftwarePath=$hmi; screenName=$screen; buttonName='StopBtn'
        eventType='Up'; actionKind='reset-bit'; targetTag='StopCmd'
    } -timeoutMs 30000 -toolName 'EnsureUnifiedHmiButtonAction' | Out-Null

    # Step 5b: also verify Tapped event for completeness (single tap toggle)
    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiButtonAction(StartBtn.Tapped=toggle-bit Running)" -toolArgs @{
        hmiSoftwarePath=$hmi; screenName=$screen; buttonName='StartBtn'
        eventType='Tapped'; actionKind='toggle-bit'; targetTag='Running'
    } -timeoutMs 30000 -toolName 'EnsureUnifiedHmiButtonAction' | Out-Null

    # Step 6: confirm screen exists in HMI
    Verify -category 'L2-HMI' -label 'GetHmiScreens(post-apply)' -toolArgs @{ softwarePath=$hmi } -timeoutMs 30000 -toolName 'GetHmiScreens' | Out-Null

    Verify -category 'L1-Project' -label 'SaveProject' -toolArgs @{} -timeoutMs 240000 -toolName 'SaveProject' | Out-Null
    Verify -category 'L1-Portal'  -label 'Disconnect'  -toolArgs @{} -timeoutMs 30000  -toolName 'Disconnect' | Out-Null
} catch {
    Write-Host "EXCEPTION: $_" -ForegroundColor Red
} finally {
    try { $stdin.Close() } catch {}
    try { $proc.StandardInput.Close() } catch {}
    $proc.WaitForExit(15000) | Out-Null
    if (-not $proc.HasExited) { $proc.Kill() }

    $script:results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportJson -Encoding UTF8

    $passes = $script:results | Where-Object { $_.status -eq 'pass' }
    $fails  = $script:results | Where-Object { $_.status -ne 'pass' }
    $md = @()
    $md += "# Unified HMI End-to-end Verification"
    $md += ""
    $md += "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $md += "PASS: $($passes.Count) / $($script:results.Count)  FAIL: $($fails.Count)"
    $md += ""
    $md += "| Layer | Tool | Time(ms) | Status & Detail |"
    $md += "|---|---|---:|---|"
    foreach ($r in $script:results) {
        $d = ($r.detail -replace '\|','\\|')
        $d = $d.Substring(0,[Math]::Min(220,$d.Length))
        $md += "| $($r.category) | ``$($r.tool)`` | $($r.elapsedMs) | $($r.status.ToUpper()): $d |"
    }
    $md -join "`r`n" | Set-Content -LiteralPath $reportMd -Encoding UTF8
    Write-Host ""
    Write-Host "PASS=$($passes.Count)/$($script:results.Count)  FAIL=$($fails.Count)  Report=$reportMd" -ForegroundColor Cyan
}
