# Prefix every [McpServerTool] Description with [L0]/[L1]/[L2] tag.
# Idempotent — already-prefixed lines are skipped.
$ErrorActionPreference = 'Stop'

$file = Resolve-Path "$PSScriptRoot\..\..\..\src\TiaMcpServer\ModelContextProtocol\McpServer.cs"
$text = [System.IO.File]::ReadAllText($file)

$L0 = @('Bootstrap','GetState','RunCapabilitySelfTest','RunOnlineMonitoringSafetySelfTest',
        'GenerateAcceptanceReport','GenerateErrorReport')

$L1 = @('Connect','Disconnect','AttachToOpenProject','OpenProject','CreateProject',
        'SaveProject','CloseProject','GetProjectTree','GetSoftwareTree','GetSoftwareInfo',
        'PlcBuildAndImport','CompileSoftware','CompileAndDiagnosePlc','DownloadToPlc',
        'CheckDownloadReadiness','GoOnline','GoOffline','GetOnlineState',
        'EnsureOpennessUserGroup','ListPortalProcessProjects','GetProject',
        'GetDevices','AddDeviceWithFallback','SearchHardwareCatalog','ImportBlock',
        'ImportType','ImportPlcTagTable','ConnectDeviceNodesToProfinetSubnet',
        'ValidateAutomationContext')

# Pass 1: single-line Description("...")
# Use ONLY named groups so .NET's mixed numbering does not bite us.
$pat1 = '(?<head>\[McpServerTool\(Name = "(?<name>\w+)"\), Description\(")(?<desc>(?!\[L\d\])[^"]*)(?<tail>"\)\])'
$count1 = @{ L0=0; L1=0; L2=0 }
$text = [regex]::Replace($text, $pat1, {
    param($m)
    $name = $m.Groups['name'].Value
    $head = $m.Groups['head'].Value
    $desc = $m.Groups['desc'].Value
    $tail = $m.Groups['tail'].Value
    $layer = if ($L0 -contains $name) { 'L0' }
             elseif ($L1 -contains $name) { 'L1' }
             else { 'L2' }
    $count1[$layer]++
    return "${head}[$layer]${desc}${tail}"
})

# Pass 2: multi-line Description with concatenated strings
#   [McpServerTool(Name="X"), Description(
#       "[Tag]..." +
#       "...")]
$pat2 = '(?m)(?<head>\[McpServerTool\(Name = "(?<name>\w+)"\), Description\(\s*\r?\n\s*")(?!\[L\d\])'
$count2 = @{ L0=0; L1=0; L2=0 }
$text = [regex]::Replace($text, $pat2, {
    param($m)
    $name = $m.Groups['name'].Value
    $head = $m.Groups['head'].Value
    $layer = if ($L0 -contains $name) { 'L0' }
             elseif ($L1 -contains $name) { 'L1' }
             else { 'L2' }
    $count2[$layer]++
    return "${head}[$layer]"
})

[System.IO.File]::WriteAllText($file, $text, [System.Text.UTF8Encoding]::new($false))

Write-Host ("pass1 single-line:  L0={0}  L1={1}  L2={2}" -f $count1.L0, $count1.L1, $count1.L2)
Write-Host ("pass2 multi-line :  L0={0}  L1={1}  L2={2}" -f $count2.L0, $count2.L1, $count2.L2)
