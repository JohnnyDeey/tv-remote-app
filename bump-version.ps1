$now = Get-Date
$year = $now.Year - 2025
$month = $now.Month.ToString("D2")
$hour = $now.Hour.ToString("D2")
$minute = $now.Minute.ToString("D2")
# Get latest version from GitHub
$latestTag = '1.0.0'
try {
  $release = Invoke-RestMethod 'https://api.github.com/repos/JohnnyDeey/tv-remote-app/releases/latest'
  $latestTag = $release.tag_name -replace 'v', ''
} catch {}

# Parse and increment
$parts = $latestTag.Split('.')
$major = [int]$parts[0]
$minor = if ($parts.Length -gt 1) { [int]$parts[1] } else { 0 }
$patch = if ($parts.Length -gt 2) { [int]$parts[2] } else { 0 }
$patch++
if ($patch -gt 999) { $patch = 0; $minor++ }
if ($minor -gt 999) { $minor = 0; $major++ }
$version = "$major.$minor.$patch"

Write-Host "New version: v$version"

# Copy fresh from PWA
Copy-Item "$PSScriptRoot\..\Tizen-remmote\tv-remote\index.html" "$PSScriptRoot\www\index.html"

# Read the file
$html = [System.IO.File]::ReadAllText("$PSScriptRoot\www\index.html", [System.Text.Encoding]::UTF8)

# Inject update checker before </body>
$updateChecker = @"

  // --- UPDATE CHECKER ---
  const CURRENT_VERSION = '$version';
  let latestApkUrl = '';
  async function checkForUpdates() {
    try {
      const res = await fetch('https://api.github.com/repos/JohnnyDeey/tv-remote-app/releases/latest');
      const data = await res.json();
      const latest = data.tag_name?.replace('v', '') || '0';
      const parseVer = v => v.split('.').map(Number);
      const isNewer = (a, b) => {
        const av = parseVer(a), bv = parseVer(b);
        for (let i = 0; i < Math.max(av.length, bv.length); i++) {
          const d = (av[i]||0) - (bv[i]||0);
          if (d > 0) return true;
          if (d < 0) return false;
        }
        return false;
      };
      if (isNewer(latest, CURRENT_VERSION)) {
        latestApkUrl = data.assets?.find(a => a.name.endsWith('.apk'))?.browser_download_url || data.html_url;
        const btn = document.getElementById('update-btn');
        if (btn) btn.style.display = 'flex';
      }
    } catch(e) {}
  }
  function downloadUpdate() {
    if (!latestApkUrl) return;
    const a = document.createElement('a');
    a.href = latestApkUrl;
    a.target = '_blank';
    a.rel = 'noopener';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  }
  setTimeout(checkForUpdates, 5000);
  setInterval(checkForUpdates, 30 * 60 * 1000);
"@

$html = $html -replace '</script>\s*</body>', "$updateChecker`n</script>`n</body>"

# Save
[System.IO.File]::WriteAllText("$PSScriptRoot\www\index.html", $html, [System.Text.Encoding]::UTF8)
Write-Host "Version updated to $version in index.html"

# Inject update button
$html = [System.IO.File]::ReadAllText("$PSScriptRoot\www\index.html", [System.Text.Encoding]::UTF8)
$updateBtn = '<button id="update-btn" onclick="downloadUpdate()" style="display:none;background:#4fc3f7;border:none;border-radius:8px;color:#000;font-size:11px;font-weight:700;padding:4px 8px;cursor:pointer;align-items:center;">Update</button>'
$html = $html -replace '(<button onclick="showSettings\(\)")', "$updateBtn`n    `$1"
[System.IO.File]::WriteAllText("$PSScriptRoot\www\index.html", $html, [System.Text.Encoding]::UTF8)
Write-Host "Update button injected"
# Update Android version in build.gradle
$buildGradle = Get-Content "android\app\build.gradle" -Raw
$buildGradle = $buildGradle -replace 'versionName "[\d.]+"', "versionName `"$version`""
$buildGradle = $buildGradle -replace 'versionCode \d+', "versionCode $([int]($now.ToString('MMddHHmm')))"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PSScriptRoot\android\app\build.gradle", $buildGradle, $utf8NoBom)
Write-Host "Android version updated"

