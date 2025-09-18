# Enable strict mode for better error handling
Set-StrictMode -Version Latest

# Path to SVN config for current Windows user
$svnConfig = Join-Path $env:APPDATA "Subversion\config"

# Check if the config file exists
if (-not (Test-Path $svnConfig)) {
    Write-Host "Error: SVN configuration file not found at $svnConfig" -ForegroundColor Red
    exit 1
}

# Create a unique backup file name with timestamp
$backupPath = "${svnConfig}.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
try {
    Copy-Item -Path $svnConfig -Destination $backupPath -ErrorAction Stop
    Write-Host "Backup created at: $backupPath" -ForegroundColor Yellow
}
catch {
    Write-Host "Error: Failed to create backup. $_" -ForegroundColor Red
    exit 1
}

# Read current config with UTF-8 encoding
try {
    $configContent = Get-Content -Path $svnConfig -Raw -Encoding UTF8 -ErrorAction Stop
}
catch {
    Write-Host "Error: Failed to read config file. $_" -ForegroundColor Red
    exit 1
}

# Detect line ending style (CRLF or LF)
$lineEnding = if ($configContent -match "\r\n") { "`r`n" } else { "`n" }

# Uncomment or add enable-auto-props
if ($configContent -match '^\s*#\s*enable-auto-props\s*=\s*yes\s*$') {
    $configContent = $configContent -replace '\s*#\s*enable-auto-props\s*=\s*yes\s*$', 'enable-auto-props = yes'
}
elseif ($configContent -notmatch '^\s*enable-auto-props\s*=\s*yes\s*$') {
    $configContent = $configContent.TrimEnd() + "$lineEnding" + "enable-auto-props = yes$lineEnding"
}

# Define SolidWorks auto-props lines
$solidWorksProps = @(
    "*.sldprt = svn:needs-lock=yes",
    "*.sldasm = svn:needs-lock=yes",
    "*.slddrw = svn:needs-lock=yes"
)

# Insert SolidWorks entries into [auto-props] section
$autoPropsRegex = '\[auto-props\](?:\r?\n.*?)*?(?=\r?\n\[|\r?\n*$)'
$autoPropsMatch = [regex]::Match($configContent, $autoPropsRegex, [System.Text.RegularExpressions.RegexOptions]::Singleline)

if ($autoPropsMatch.Success) {
    $section = $autoPropsMatch.Value
    foreach ($prop in $solidWorksProps) {
        if ($section -notmatch "(?mi)^\s*\Q$prop\E\s*$") {
            $section = $section.TrimEnd() + "$lineEnding$prop"
        }
    }
    $configContent = $configContent -replace [regex]::Escape($autoPropsMatch.Value), $section
}
else {
    # Try to insert after [miscellany], else append at end
    $miscRegex = '(?mi)^\[miscellany\](?:\r?\n.*?)*?(?=\r?\n\[|\r?\n*$)'
    $miscMatch = [regex]::Match($configContent, $miscRegex, [System.Text.RegularExpressions.RegexOptions]::Singleline)

    $newSection = "[auto-props]$lineEnding" + ($solidWorksProps -join $lineEnding) + $lineEnding

    if ($miscMatch.Success) {
        # Insert right after [miscellany] block
        $insertPos = $miscMatch.Index + $miscMatch.Length
        $configContent = $configContent.Insert($insertPos, "$lineEnding$newSection")
    }
    else {
        # Append at end if [miscellany] not found
        $configContent = $configContent.TrimEnd() + "$lineEnding$newSection"
    }
}

# Write updated config back safely
try {
    $tempFile = "$svnConfig.tmp"
    Set-Content -Path $tempFile -Value $configContent -Encoding UTF8 -ErrorAction Stop
    Move-Item -Path $tempFile -Destination $svnConfig -Force
}
catch {
    Write-Host "Error: Failed to write config file. $_" -ForegroundColor Red
    exit 1
}

# Success message
Write-Host "SolidWorks SVN auto-props have been successfully applied and enable-auto-props is enabled." -ForegroundColor Green

# Optional pause (controlled via parameter)
if ($args -contains "-Pause") {
    Read-Host -Prompt "Press Enter to exit"
}
