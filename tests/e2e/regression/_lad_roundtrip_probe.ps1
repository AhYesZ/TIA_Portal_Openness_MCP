#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$exe = "C:\Users\XL626\Desktop\PID博途块\tools\tiaportal-mcp\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
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
$id = 0
$pending = $null
function Call($method, $params) {
  $script:id++
  $stdin.WriteLine((@{ jsonrpc='2.0'; id=$script:id; method=$method; params=$params } | ConvertTo-Json -Compress -Depth 20))
  while ($true) {
    if ($null -eq $script:pending) { $script:pending = $proc.StandardOutput.ReadLineAsync() }
    if (-not $script:pending.Wait(60000)) { throw "timeout $method" }
    $line = $script:pending.Result; $script:pending = $null
    try { $j = $line | ConvertFrom-Json } catch { continue }
    if ($j.id -eq $script:id) { return $j }
  }
}
function Notify($method, $params) {
  $stdin.WriteLine((@{ jsonrpc='2.0'; method=$method; params=$params } | ConvertTo-Json -Compress -Depth 20))
}
try {
  Start-Sleep -s 2
  Call 'initialize' @{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='probe'; version='1' } } | Out-Null
  Notify 'notifications/initialized' @{}
  Call 'tools/call' @{ name='Connect'; arguments=@{} } | Out-Null
  $gp = Call 'tools/call' @{ name='GetProject'; arguments=@{} }
  $pn = (($gp.result.content[0].text | ConvertFrom-Json).items[0].name)
  Call 'tools/call' @{ name='AttachToOpenProject'; arguments=@{ projectName=$pn } } | Out-Null
  $exp = Call 'tools/call' @{ name='ExportBlock'; arguments=@{
    softwarePath='安全PLC'; blockName='MCPVerify_FC_LAD';
    exportPath='C:\Users\XL626\Desktop\testtia\lad_native_verify\MCPVerify_FC_LAD_roundtrip.xml';
    preserveFormatting=$true
  } }
  Write-Host ($exp.result.content[0].text)
  Call 'tools/call' @{ name='Disconnect'; arguments=@{} } | Out-Null
} finally {
  $stdin.Close(); $proc.WaitForExit(8000) | Out-Null
  if (-not $proc.HasExited) { $proc.Kill() }
}
