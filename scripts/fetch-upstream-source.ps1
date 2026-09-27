$ErrorActionPreference = 'Stop'
$Url = 'https://gitlab.com/coringao/roadfighter/-/archive/1.0.0/roadfighter-1.0.0.zip'
$Out = Join-Path $PSScriptRoot '..\roadfighter-upstream-1.0.0.zip'
Invoke-WebRequest -Uri $Url -OutFile $Out
Write-Host "Saved upstream source archive to $Out"
