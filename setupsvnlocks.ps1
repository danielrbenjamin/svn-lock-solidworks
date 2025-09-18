# Enable strict mode for better error handling
Set-StrictMode -Version Latest

# Path to SVN config for current user
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
    # Replace commented line with uncommented
    $configContent = $configContent -replace '^\s*#\s*enable-auto-props\s*=\s*yes\s*$', 'enable-auto-props = yes'
}
elseif ($configContent -notmatch '^\s*enable-auto-props\s*=\s*yes\s*$') {
    # Add it if missing entirely
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
        # Normalize for comparison (remove extra spaces)
        $normalizedProp = [regex]::Escape($prop.Trim())
        if ($section -notmatch "^\s*$normalizedProp\s*$") {
            $section = $section.TrimEnd() + "$lineEnding$prop"
        }
    }
    $configContent = $configContent -replace [regex]::Escape($autoPropsMatch.Value), $section
}
else {
    # Add new [auto-props] section
    $configContent = $configContent.TrimEnd() + "$lineEnding" + "[auto-props]$lineEnding" + ($solidWorksProps -join $lineEnding) + $lineEnding
}

# Write updated config back
try {
    Set-Content -Path $svnConfig -Value $configContent -Encoding UTF8 -Force -ErrorAction Stop
}
catch {
    Write-Host "Error: Failed to write config file. $_" -ForegroundColor Red
    exit 1
}

# Success message
Write-Host "SolidWorks SVN auto-props have been successfully applied and enable-auto-props is enabled." -ForegroundColor Green

# Optional pause (controlled via parameter or environment)
if ($args -contains "-Pause") {
    Read-Host -Prompt "Press Enter to exit"
}
