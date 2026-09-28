# claudepack installer — Windows PowerShell
# Usage: iwr https://raw.githubusercontent.com/YOUR_USERNAME/claudepack/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$commandsDir = "$env:USERPROFILE\.claude\commands"
$baseUrl = "https://raw.githubusercontent.com/YOUR_USERNAME/claudepack/main/commands"

Write-Host "Installing claudepack..."
New-Item -ItemType Directory -Path $commandsDir -Force | Out-Null

Invoke-WebRequest -Uri "$baseUrl/pack.md"   -OutFile "$commandsDir\pack.md"
Invoke-WebRequest -Uri "$baseUrl/unpack.md" -OutFile "$commandsDir\unpack.md"

Write-Host ""
Write-Host "✅ Installed:"
Write-Host "   $commandsDir\pack.md"
Write-Host "   $commandsDir\unpack.md"
Write-Host ""
Write-Host "Restart Claude Code, then use /pack and /unpack."
