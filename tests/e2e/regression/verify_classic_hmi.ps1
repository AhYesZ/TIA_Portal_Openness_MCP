#requires -Version 5.1
# Stage 4: build a minimal "美观" Classic/Basic HMI package (TagTable + Screen
# with title bar, two control buttons, one indicator lamp, one IO value field,
# events wired to HMI tags), import it into the live HMI software, then
# CompileSoftware HMI_RT_1 and require errorCount=0.

$ErrorActionPreference = 'Stop'
$exe        = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
$pkgDir     = "C:\Users\XL626\Desktop\testtia\hmi_classic_verify"
$reportMd   = "$PSScriptRoot\verify_classic_hmi.md"
$reportJson = "$PSScriptRoot\verify_classic_hmi.json"

if (-not (Test-Path $pkgDir)) { New-Item -ItemType Directory -Force $pkgDir | Out-Null }

$package = [ordered]@{
    Name = 'MCPVerify_HmiPackage'
    TagTable = @{
        Name = 'MCPVerify_HmiTags'
        Tags = @(
            @{ Name='StartCmd';  DataType='Bool' }
            @{ Name='StopCmd';   DataType='Bool' }
            @{ Name='Running';   DataType='Bool' }
            @{ Name='SpeedSP';   DataType='Int';  Length='2' }
            @{ Name='SpeedAct';  DataType='Int';  Length='2' }
        )
    }
    ScreenDesign = @{
        Screen = @{
            Name      = 'MCPVerify_MainScreen'
            Number    = 99
            Width     = 800
            Height    = 480
            BackColor = '15, 23, 42'  # 深色背景
        }
        Items = @(
            # 顶部标题条
            @{
                Type='Rectangle'; Name='TitleBar'
                Left=0; Top=0; Width=800; Height=56
                BackColor='30, 41, 59'
                Properties=@{ BorderWidth=0 }
            }
            # 标题文字
            @{
                Type='Text'; Name='TitleText'
                Left=24; Top=14; Width=560; Height=28
                Text='电机监控 — MCP 验证画面'
                BackColor='30, 41, 59'
                Properties=@{ ForeColor='248, 250, 252'; FontSize=20 }
            }
            # 状态指示
            @{
                Type='Text'; Name='StatusLabel'
                Left=24; Top=88; Width=120; Height=26
                Text='运行状态'
                BackColor='15, 23, 42'
                Properties=@{ ForeColor='248, 250, 252'; FontSize=14 }
            }
            # 运行指示灯（Lamp 绑定 Running）
            @{
                Type='Lamp'; Name='RunLamp'
                Left=160; Top=88; Width=28; Height=28
                BackColor='34, 197, 94'  # 绿色 = 运行
                Tag='Running'
                Properties=@{ BorderColor='15, 118, 110'; BorderWidth=2 }
            }
            # 速度设定值标签
            @{
                Type='Text'; Name='SpSetLabel'
                Left=24; Top=140; Width=140; Height=26
                Text='速度设定 (rpm)'
                BackColor='15, 23, 42'
                Properties=@{ ForeColor='248, 250, 252'; FontSize=14 }
            }
            # 速度设定 IOField (输入)
            @{
                Type='IOField'; Name='SpeedSpField'
                Left=180; Top=136; Width=140; Height=36
                Tag='SpeedSP'
                BackColor='248, 250, 252'
                Properties=@{ ForeColor='15, 23, 42'; FontSize=16; Mode='InOutput' }
            }
            # 速度反馈标签
            @{
                Type='Text'; Name='SpActLabel'
                Left=24; Top=190; Width=140; Height=26
                Text='当前速度 (rpm)'
                BackColor='15, 23, 42'
                Properties=@{ ForeColor='248, 250, 252'; FontSize=14 }
            }
            # 速度反馈 IOField (只读)
            @{
                Type='IOField'; Name='SpeedActField'
                Left=180; Top=186; Width=140; Height=36
                Tag='SpeedAct'
                BackColor='30, 41, 59'
                Properties=@{ ForeColor='248, 250, 252'; FontSize=16; Mode='Output' }
            }
            # 启动按钮 — 按下置位 StartCmd
            @{
                Type='Button'; Name='StartBtn'
                Left=24; Top=320; Width=160; Height=72
                Text='启 动'
                BackColor='34, 197, 94'
                Properties=@{ ForeColor='255, 255, 255'; FontSize=20 }
                Actions = @(
                    @{ Event='PressEvent';   ActionKind='SetBit';   TargetTag='StartCmd' }
                    @{ Event='ReleaseEvent'; ActionKind='ResetBit'; TargetTag='StartCmd' }
                )
            }
            # 停止按钮 — 按下置位 StopCmd
            @{
                Type='Button'; Name='StopBtn'
                Left=200; Top=320; Width=160; Height=72
                Text='停 止'
                BackColor='220, 38, 38'
                Properties=@{ ForeColor='255, 255, 255'; FontSize=20 }
                Actions = @(
                    @{ Event='PressEvent';   ActionKind='SetBit';   TargetTag='StopCmd' }
                    @{ Event='ReleaseEvent'; ActionKind='ResetBit'; TargetTag='StopCmd' }
                )
            }
        )
    }
}

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
    Write-Host ("[{0,-4}] {1,-44} {2,6}ms  {3}" -f $entry.status.ToUpper(), $label, $entry.elapsedMs, ($entry.detail.Substring(0,[Math]::Min(120,$entry.detail.Length)))) -ForegroundColor $color
    [void]$script:results.Add([pscustomobject]$entry)
    return @{ pass = ($entry.status -eq 'pass'); text = $text }
}

try {
    Start-Sleep -Seconds 3
    Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='verify-classic-hmi'; version='1.0' } } 30000 | Out-Null
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

    $hmi = 'HMI_RT_1'

    # Confirm HMI type before choosing import path
    $info = Verify -category 'L2-HMI' -label 'GetHmiProgramInfo' -toolArgs @{ softwarePath=$hmi } -timeoutMs 30000 -toolName 'GetHmiProgramInfo'
    if ($info.pass) {
        try {
            $i = $info.text | ConvertFrom-Json
            Write-Host ("    -> hmi type={0} version={1} screens={2}" -f $i.softwareType, $i.version, $i.screenCount) -ForegroundColor Cyan
        } catch {}
    }

    # Step 1: build & write the package files (offline-only, no project changes)
    $pkgJson = $package | ConvertTo-Json -Depth 30 -Compress
    $writePkg = Verify -category 'L2-HMI' -label 'WriteClassicHmiMinimalPackageFiles' -toolArgs @{
        packageJson     = $pkgJson
        outputDirectory = $pkgDir
    } -timeoutMs 30000 -toolName 'WriteClassicHmiMinimalPackageFiles'
    if (-not $writePkg.pass) { throw "Package write failed" }

    # Discover the actual file paths on disk
    $tagXml = (Get-ChildItem "$pkgDir\*.xml" | Where-Object { $_.Name -like '*ag*able*' -or $_.Name -like '*ags*' } | Select-Object -First 1).FullName
    $scrXml = (Get-ChildItem "$pkgDir\*.xml" | Where-Object { $_.Name -notlike '*ag*able*' -and $_.Name -notlike '*ags*' } | Select-Object -First 1).FullName
    if (-not $tagXml -or -not $scrXml) {
        Write-Host "    -> files in pkg dir:" -ForegroundColor Yellow
        Get-ChildItem $pkgDir | ForEach-Object { Write-Host "         $($_.Name)" }
        throw "Could not locate generated tag/screen XML in $pkgDir"
    }
    Write-Host "    -> tagXml = $tagXml" -ForegroundColor Cyan
    Write-Host "    -> scrXml = $scrXml" -ForegroundColor Cyan

    # Step 2: import tag table
    Verify -category 'L2-HMI' -label 'ImportHmiTagTable(MCPVerify_HmiTags)' -toolArgs @{
        softwarePath = $hmi
        folderPath   = ''
        importPath   = $tagXml
    } -timeoutMs 60000 -toolName 'ImportHmiTagTable' | Out-Null

    # Step 3: import screen
    Verify -category 'L2-HMI' -label 'ImportHmiScreen(MCPVerify_MainScreen)' -toolArgs @{
        softwarePath = $hmi
        folderPath   = ''
        importPath   = $scrXml
    } -timeoutMs 60000 -toolName 'ImportHmiScreen' | Out-Null

    # Step 4: list HMI screens to confirm import landed
    Verify -category 'L2-HMI' -label 'GetHmiScreens(post-import)' -toolArgs @{ softwarePath=$hmi } -timeoutMs 30000 -toolName 'GetHmiScreens' | Out-Null

    # Step 5: compile HMI software
    $cmp = Verify -category 'L2-HMI' -label 'CompileSoftware(HMI_RT_1)' -toolArgs @{ softwarePath=$hmi } -timeoutMs 240000 -toolName 'CompileSoftware'
    if ($cmp.pass) {
        try {
            $c = $cmp.text | ConvertFrom-Json
            Write-Host ("    -> errorCount={0} warningCount={1} state={2}" -f $c.errorCount, $c.warningCount, $c.state) -ForegroundColor Cyan
        } catch {}
    }

    Verify -category 'L1-Project' -label 'SaveProject' -toolArgs @{} -timeoutMs 240000 -toolName 'SaveProject' | Out-Null
    Verify -category 'L1-Portal'  -label 'Disconnect'  -toolArgs @{} -timeoutMs 30000 -toolName 'Disconnect' | Out-Null
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
    $md += "# Classic HMI End-to-end Verification"
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
