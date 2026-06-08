param([Parameter(Mandatory=$true)][string]$Path)
$content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($Path, $content, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "BOM added to $Path"
