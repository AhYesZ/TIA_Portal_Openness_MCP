#requires -Version 5.1
# Cold-start: CreateProject -> PLC + Unified HMI -> tag table + DB + FC_StartStop (SCL builder)
# -> external SCL (>50 lines) Import+Generate -> LAD FC with 22 networks (each calls FC_StartStop)
# -> Unified HMI connection + tags (DB1.DBX absolute) + MotorCtrl screen/actions
# -> CompileSoftware(PLC_1) errorCount=0 -> SaveProject.
# Report: e2e_cold_full_lad_scl_hmi_verify.md / .json

$ErrorActionPreference = 'Stop'

$tiaportalRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$exe = Join-Path $tiaportalRoot 'src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Missing TiaMcpServer.exe (build Release first): $exe" }

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$projDir = "C:\Users\XL626\Desktop\testtia\mcp-cold-full-verify_$ts"
$projName = "MCP_Cold_FullVerify_$ts"

$reportMd   = "$PSScriptRoot\e2e_cold_full_lad_scl_hmi_verify.md"
$reportJson = "$PSScriptRoot\e2e_cold_full_lad_scl_hmi_verify.json"

$extSclName = 'MCPVerify_FC_MultiLine.scl'
$sclStaging = Join-Path $env:TEMP "mcp_cold_full_$ts"
New-Item -ItemType Directory -Force -Path $sclStaging | Out-Null
$sclPath = Join-Path $sclStaging $extSclName

# External SCL: >50 lines, S7-1200 compatible (UTF-8 BOM written below).
$sclSource = @'
FUNCTION "MCPVerify_FC_MultiLine" : Void
{ S7_Optimized_Access := 'TRUE' }
VERSION : 0.1
   VAR_INPUT 
      InX : Int;
   END_VAR
   VAR_OUTPUT 
      OutY : DInt;
   END_VAR
   VAR_TEMP 
      a : Int;
      b : Int;
      c : Int;
      d : Int;
      e : Int;
      acc : DInt;
      i : Int;
      j : Int;
      k : Int;
   END_VAR
BEGIN
	a := InX;
	b := a + 1;
	c := b + 1;
	d := c + 1;
	e := d + 1;
	acc := 0;
	FOR i := 1 TO 8 DO
	    acc := acc + i;
	END_FOR;
	IF a > 100 THEN
	    acc := acc + 1000;
	ELSIF a > 50 THEN
	    acc := acc + 500;
	ELSIF a > 10 THEN
	    acc := acc + 100;
	ELSE
	    acc := acc + 10;
	END_IF;
	CASE InX OF
	    0:
	        acc := acc + 1;
	    1:
	        acc := acc + 2;
	    2:
	        acc := acc + 3;
	    3:
	        acc := acc + 4;
	    4:
	        acc := acc + 5;
	ELSE
	    acc := acc + 9;
	END_CASE;
	j := 0;
	WHILE j < 4 DO
	    acc := acc + j;
	    j := j + 1;
	END_WHILE;
	k := 0;
	REPEAT
	    acc := acc + 1;
	    k := k + 1;
	UNTIL k > 2
	END_REPEAT;
	OutY := acc + e;
END_FUNCTION
'@
[System.IO.File]::WriteAllText($sclPath, $sclSource, (New-Object System.Text.UTF8Encoding($true)))
$sclLineCount = (@($sclSource -split "`n")).Count
if ($sclLineCount -lt 51) { throw "SCL artifact must exceed 50 lines (got $sclLineCount)." }

$ladNetworkCount = 22
if ($ladNetworkCount -le 20) { throw "LAD networks must exceed 20 (got $ladNetworkCount)." }

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
                $entry.detail = if ($text) { ($text.Substring(0,[Math]::Min(420,$text.Length)) -replace '\s+', ' ') } else { '' }
            }
        }
    } catch { $entry.detail = "exception: $($_.Exception.Message)" }
    $entry.elapsedMs = [int]([DateTime]::UtcNow - $started).TotalMilliseconds
    $color = if ($entry.status -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ("[{0,-4}] {1,-54} {2,6}ms  {3}" -f $entry.status.ToUpper(), $label, $entry.elapsedMs, ($entry.detail.Substring(0,[Math]::Min(150,$entry.detail.Length)))) -ForegroundColor $color
    [void]$script:results.Add([pscustomobject]$entry)
    return @{ pass = ($entry.status -eq 'pass'); text = $text }
}

try {
    Start-Sleep -Seconds 3
    Send-Request 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='e2e-cold-full-lad-scl-hmi'; version='1.0' } } 30000 | Out-Null
    Send-Notify 'notifications/initialized' @{}

    $conn = Verify -category 'L1-Portal' -label 'Connect' -toolArgs @{} -timeoutMs 180000 -toolName 'Connect'
    if (-not $conn.pass) { throw "PRECONDITION_FAILED: Connect did not succeed. Likely Openness auth dialog needs click in TIA." }

    Verify -category 'L1-Project' -label "CreateProject($projName)" -toolArgs @{ directoryPath=$projDir; projectName=$projName } -timeoutMs 180000 -toolName 'CreateProject' | Out-Null

    Verify -category 'L1-HW' -label 'AddDevice PLC_1 (S7-1200 1211C V4.7)' -toolArgs @{ preferredMlfb='6ES7211-1BE40-0XB0'; preferredVersion='V4.7'; deviceName='PLC_1'; family='S7-1200' } -timeoutMs 240000 -toolName 'AddDeviceWithFallback' | Out-Null

    $hmiSoftware = 'HMI_1'
    $hmiAdd = $null
    $keywords = @(
        'WinCC Unified Comfort',
        'WinCC Unified Comfort Panel',
        'Unified Comfort Panel',
        'TP700 Unified',
        'TP700 Comfort Unified',
        'TP700 Comfort'
    )
    foreach ($kw in $keywords) {
        $hmiAdd = Verify -category 'L1-HW' -label "AddDevice $hmiSoftware ($kw)" -toolArgs @{ keyword=$kw; deviceName=$hmiSoftware } -timeoutMs 240000 -toolName 'AddHardwareCatalogDeviceWithProbe'
        if ($hmiAdd.pass) { break }
    }
    if (-not $hmiAdd -or -not $hmiAdd.pass) {
        throw "HMI_UNIFIED_MISSING: Failed to add an HMI device. Ensure WinCC Unified option is installed, then retry."
    }

    $tagJson = @{
        tableName='DefaultTagTable'
        tags = @(
            @{ name='I_Start'; dataTypeName='Bool'; logicalAddress='%I0.0' },
            @{ name='I_Stop';  dataTypeName='Bool'; logicalAddress='%I0.1' },
            @{ name='I_EStop'; dataTypeName='Bool'; logicalAddress='%I0.2' },
            @{ name='Q_Run';   dataTypeName='Bool'; logicalAddress='%Q0.0' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Verify -category 'L2-PLC' -label 'PlcBuildAndImport(DefaultTagTable)' -toolArgs @{ softwarePath='PLC_1'; kind='tagtable'; json=$tagJson; dryRun=$false; compileAfter=$false } -timeoutMs 180000 -toolName 'PlcBuildAndImport' | Out-Null

    $dbJson = @{
        dbName = 'DB_MotorData'
        dbNumber = 1
        staticMembers = @(
            @{ name='StartCmd'; datatype='Bool'; startValue='FALSE' }
            @{ name='StopCmd';  datatype='Bool'; startValue='FALSE' }
            @{ name='RunOut';   datatype='Bool'; startValue='FALSE' }
        )
    } | ConvertTo-Json -Compress -Depth 10
    Verify -category 'L2-PLC' -label 'PlcBuildAndImport(DB_MotorData)' -toolArgs @{ softwarePath='PLC_1'; kind='globaldb'; json=$dbJson; dryRun=$false; compileAfter=$false } -timeoutMs 180000 -toolName 'PlcBuildAndImport' | Out-Null

    $fcStartStopJson = @{
        blockName='FC_StartStop'; blockNumber=10
        commentZhCn='起保停：全局 I_Start/I_Stop/I_EStop -> Q_Run'
        titleZhCn='FC_StartStop'
        networkTitleZhCn='IF/ELSIF'
        networkCommentZhCn='三段优先级'
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
    Verify -category 'L2-PLC' -label 'PlcBuildAndImport(FC_StartStop)' -toolArgs @{ softwarePath='PLC_1'; kind='fc'; json=$fcStartStopJson; dryRun=$false; compileAfter=$false } -timeoutMs 180000 -toolName 'PlcBuildAndImport' | Out-Null

    Verify -category 'L2-PLC' -label "DeletePlcExternalSource($extSclName)" -toolArgs @{
        softwarePath='PLC_1'; externalSourceName=$extSclName
    } -timeoutMs 60000 -toolName 'DeletePlcExternalSource' | Out-Null

    Verify -category 'L2-PLC' -label "ImportPlcExternalSource($extSclName)" -toolArgs @{
        softwarePath='PLC_1'; groupPath=''; filePath=$sclPath
    } -timeoutMs 60000 -toolName 'ImportPlcExternalSource' | Out-Null

    Verify -category 'L2-PLC' -label "GenerateBlocksFromExternalSource($extSclName)" -toolArgs @{
        softwarePath='PLC_1'; externalSourceName=$extSclName
    } -timeoutMs 180000 -toolName 'GenerateBlocksFromExternalSource' | Out-Null

    $ladNetworks = @(1..$ladNetworkCount | ForEach-Object {
        @{
            titleZhCn = "LAD_N$_"
            commentZhCn = "Network $_ : call FC_StartStop"
            callJson = @{ callName = 'FC_StartStop'; parameters = @() }
        }
    })
    $ladFcJson = @{
        blockName = 'FC_MCP_22Lad'
        blockNumber = 81
        commentZhCn = "Cold full verify: $ladNetworkCount LAD networks calling FC_StartStop"
        titleZhCn = 'LAD multi-network'
        inputs = @()
        outputs = @()
        networks = $ladNetworks
    } | ConvertTo-Json -Compress -Depth 30

    $ladCompose = Verify -category 'L2-PLC' -label 'ComposePlcLadFcBlockXml(FC_MCP_22Lad)' -toolArgs @{ ladFcBlockJson=$ladFcJson } -timeoutMs 60000 -toolName 'ComposePlcLadFcBlockXml'
    if (-not $ladCompose.pass) { throw "ComposePlcLadFcBlockXml failed: $($ladCompose.detail)" }
    $jp = $ladCompose.text | ConvertFrom-Json
    if (-not $jp.xml) { throw "ComposePlcLadFcBlockXml returned no xml field" }
    $ladXmlPath = Join-Path $sclStaging "FC_MCP_22Lad_$ts.xml"
    [System.IO.File]::WriteAllText($ladXmlPath, [string]$jp.xml, (New-Object System.Text.UTF8Encoding($true)))
    Verify -category 'L2-PLC' -label 'ImportBlock(FC_MCP_22Lad.xml)' -toolArgs @{ softwarePath='PLC_1'; groupPath=''; importPath=$ladXmlPath } -timeoutMs 120000 -toolName 'ImportBlock' | Out-Null

    $hinfo = Verify -category 'L2-HMI' -label "GetHmiProgramInfo($hmiSoftware)" -toolArgs @{ softwarePath=$hmiSoftware } -timeoutMs 60000 -toolName 'GetHmiProgramInfo'
    if ($hinfo.pass) {
        try {
            $o = $hinfo.text | ConvertFrom-Json
            if ($o.programType -and $o.programType -ne 'Unified') {
                throw "HMI_NOT_UNIFIED: HMI '$hmiSoftware' programType=$($o.programType). This test requires WinCC Unified."
            }
        } catch { throw }
    }
    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiConnection(HMI_Connection_1 -> PLC_1)" -toolArgs @{ hmiSoftwarePath=$hmiSoftware; connectionName='HMI_Connection_1'; plcName='PLC_1' } -timeoutMs 120000 -toolName 'EnsureUnifiedHmiConnection' | Out-Null
    Verify -category 'L2-HMI' -label "EnsureUnifiedHmiTagTable(MCP_LinkTags)" -toolArgs @{ hmiSoftwarePath=$hmiSoftware; tagTableName='MCP_LinkTags' } -timeoutMs 60000 -toolName 'EnsureUnifiedHmiTagTable' | Out-Null

    foreach ($t in @(
        @{ name='StartCmd'; plc='DB1.DBX0.0' }
        @{ name='StopCmd';  plc='DB1.DBX0.1' }
        @{ name='RunOut';   plc='DB1.DBX0.2' }
    )) {
        Verify -category 'L2-HMI' -label "EnsureUnifiedHmiTag($($t.name) -> $($t.plc))" -toolArgs @{
            hmiSoftwarePath=$hmiSoftware; tagTableName='MCP_LinkTags'; tagName=$t.name; hmiDataType='Bool'
            plcName='PLC_1'; plcTag=$t.plc; connectionName='HMI_Connection_1'
        } -timeoutMs 60000 -toolName 'EnsureUnifiedHmiTag' | Out-Null
    }

    Verify -category 'L2-HMI' -label 'EnsureUnifiedHmiScreen(MotorCtrl)' -toolArgs @{ hmiSoftwarePath=$hmiSoftware; screenName='MotorCtrl'; width=1024; height=768 } -timeoutMs 120000 -toolName 'EnsureUnifiedHmiScreen' | Out-Null
    $design = @{
        screen = @{ BackColor = '0xFFF8FAFC' }
        items = @(
            @{ type='Button'; name='StartBtn'; left=56; top=120; width=220; height=96; text='Start'; properties=@{ BackColor='0xFF22C55E'; ForeColor='0xFFFFFFFF'; BorderColor='0xFF15803D'; BorderWidth=1 }; font=@{ Size=22 } }
            @{ type='Button'; name='StopBtn';  left=304; top=120; width=220; height=96; text='Stop'; properties=@{ BackColor='0xFFDC2626'; ForeColor='0xFFFFFFFF'; BorderColor='0xFFB91C1C'; BorderWidth=1 }; font=@{ Size=22 } }
            @{ type='Rectangle'; name='Lamp';  left=56; top=260; width=28; height=28; properties=@{ BackColor='0xFF22C55E'; BorderColor='0xFF15803D'; BorderWidth=2 } }
        )
    } | ConvertTo-Json -Compress -Depth 30
    $apply = Verify -category 'L2-HMI' -label 'ApplyUnifiedHmiScreenDesignJson(MotorCtrl)' -toolArgs @{ hmiSoftwarePath=$hmiSoftware; screenName='MotorCtrl'; designJson=$design } -timeoutMs 120000 -toolName 'ApplyUnifiedHmiScreenDesignJson'
    if ($apply.pass) {
        try {
            $jo = $apply.text | ConvertFrom-Json
            $failed = @($jo.meta.failed)
            if ($failed.Count -gt 0) {
                [void]$script:results.Add([pscustomobject]@{ category='L2-HMI'; tool='ApplyUnifiedHmiScreenDesignJson(meta.failed=0)'; status='fail'; elapsedMs=0; detail=("failedCount=" + $failed.Count) })
            }
        } catch { }
    }

    Verify -category 'L2-HMI' -label 'EnsureUnifiedHmiButtonAction(StartBtn.Down set-bit StartCmd)' -toolArgs @{ hmiSoftwarePath=$hmiSoftware; screenName='MotorCtrl'; buttonName='StartBtn'; eventType='Down'; actionKind='set-bit'; targetTag='StartCmd' } -timeoutMs 60000 -toolName 'EnsureUnifiedHmiButtonAction' | Out-Null
    Verify -category 'L2-HMI' -label 'EnsureUnifiedHmiButtonAction(StartBtn.Up reset-bit StartCmd)' -toolArgs @{ hmiSoftwarePath=$hmiSoftware; screenName='MotorCtrl'; buttonName='StartBtn'; eventType='Up'; actionKind='reset-bit'; targetTag='StartCmd' } -timeoutMs 60000 -toolName 'EnsureUnifiedHmiButtonAction' | Out-Null
    Verify -category 'L2-HMI' -label 'EnsureUnifiedHmiButtonAction(StopBtn.Down set-bit StopCmd)' -toolArgs @{ hmiSoftwarePath=$hmiSoftware; screenName='MotorCtrl'; buttonName='StopBtn'; eventType='Down'; actionKind='set-bit'; targetTag='StopCmd' } -timeoutMs 60000 -toolName 'EnsureUnifiedHmiButtonAction' | Out-Null
    Verify -category 'L2-HMI' -label 'EnsureUnifiedHmiButtonAction(StopBtn.Up reset-bit StopCmd)' -toolArgs @{ hmiSoftwarePath=$hmiSoftware; screenName='MotorCtrl'; buttonName='StopBtn'; eventType='Up'; actionKind='reset-bit'; targetTag='StopCmd' } -timeoutMs 60000 -toolName 'EnsureUnifiedHmiButtonAction' | Out-Null

    $cmp = Verify -category 'L2-PLC' -label 'CompileSoftware(PLC_1)' -toolArgs @{ softwarePath='PLC_1' } -timeoutMs 240000 -toolName 'CompileSoftware'
    if ($cmp.pass) {
        try {
            $jo = $cmp.text | ConvertFrom-Json
            $ec = [int]$jo.errorCount
            if ($ec -gt 0) {
                [void]$script:results.Add([pscustomobject]@{ category='L2-PLC'; tool='CompileSoftware(errorCount=0)'; status='fail'; elapsedMs=0; detail="errorCount=$ec" })
            }
        } catch { }
    }

    Verify -category 'L1-Project' -label 'SaveProject' -toolArgs @{} -timeoutMs 240000 -toolName 'SaveProject' | Out-Null
    Verify -category 'L1-Portal' -label 'Disconnect' -toolArgs @{} -timeoutMs 60000 -toolName 'Disconnect' | Out-Null
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
    $md += "# Cold-start full verify (LAD>20 nets, SCL>50 lines, Unified HMI DB1)"
    $md += ""
    $md += "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $md += "ProjectDir: $projDir"
    $md += "LAD networks (each FC call): $ladNetworkCount (require >20)"
    $md += "External SCL lines (source string): $sclLineCount (require >50)"
    $md += "HMI tags: StartCmd/StopCmd/RunOut -> DB1.DBX0.0 / 0.1 / 0.2 (absolute)"
    $md += "PASS: $($passes.Count) / $($script:results.Count)  FAIL: $($fails.Count)"
    $md += ""
    $md += "| Layer | Tool | Time(ms) | Status & Detail |"
    $md += "|---|---|---:|---|"
    foreach ($r in $script:results) {
        $escPipe = ([string][char]92) + '|'
        $d = ([string]$r.detail).Replace('|', $escPipe)
        $d = $d.Substring(0,[Math]::Min(220,$d.Length))
        $md += "| $($r.category) | ``$($r.tool)`` | $($r.elapsedMs) | $($r.status.ToUpper()): $d |"
    }
    $md -join "`r`n" | Set-Content -LiteralPath $reportMd -Encoding UTF8
    Write-Host ""
    Write-Host "PASS=$($passes.Count)/$($script:results.Count)  FAIL=$($fails.Count)  Report=$reportMd" -ForegroundColor Cyan
}
