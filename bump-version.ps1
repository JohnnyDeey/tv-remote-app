$now = Get-Date
$year = $now.Year - 2025
$month = $now.Month.ToString("D2")
$hour = $now.Hour.ToString("D2")
$minute = $now.Minute.ToString("D2")
$version = "$year.$month.$hour$minute"

Write-Host "New version: v$version"

# Update index.html
$html = Get-Content "www\index.html" -Raw
$html = $html -replace "content=""[\d.]+""(?=.*app-version)", "content=""$version"""
$html = $html -replace "const CURRENT_VERSION = '[\d.]+'", "const CURRENT_VERSION = '$version'"
[System.IO.File]::WriteAllText("$PSScriptRoot\www\index.html", $html, [System.Text.Encoding]::UTF8)

Write-Host "Version updated to $version in index.html"