# Path to SVN config for current user
$svnConfig = "$env:APPDATA\Subversion\config"

# Backup existing config
Copy-Item -Path $svnConfig -Destination "${svnConfig}.backup" -Force

# Read current config as a single string
$configContent = Get-Content $svnConfig -Raw

# Uncomment enable-auto-props if it exists, otherwise add it
if ($configContent -match '^\s*#\s*enable-auto-props\s*=\s*yes') {
    # Replace commented line with uncommented
    $configContent = $configContent -replace '^\s*#\s*enable-auto-props\s*=\s*yes', 'enable-auto-props = yes'
} elseif ($configContent -notmatch '^\s*enable-auto-props\s*=\s*yes') {
    # Add it if missing entirely
    $configContent += "`r`nenable-auto-props = yes"
}

# Define SolidWorks auto-props lines
$solidWorksProps = @(
    "*.sldprt = svn:needs-lock=yes",
    "*.sldasm = svn:needs-lock=yes",
    "*.slddrw = svn:needs-lock=yes"
)

# Insert SolidWorks entries inside existing [auto-props] section
$autoPropsMatch = [regex]::Match($configContent, '(\[auto-props\](?:\r?\n.*?)*?)(?=(?:\r?\n\[|$))', [System.Text.RegularExpressions.RegexOptions]::Singleline)

if ($autoPropsMatch.Success) {
    $section = $autoPropsMatch.Groups[1].Value
    foreach ($line in $solidWorksProps) {
        if ($section -notmatch [regex]::Escape($line)) {
            $section += "`r`n$line"
        }
    }
    $configContent = $configContent -replace [regex]::Escape($autoPropsMatch.Groups[1].Value), $section
} else {
    $configContent += "`r`n[auto-props]`r`n" + ($solidWorksProps -join "`r`n")
}

# Write updated config back
Set-Content -Path $svnConfig -Value $configContent -Force

# Success message
Write-Host "`n✅ SolidWorks SVN auto-props have been successfully appended and enable-auto-props is uncommented." -ForegroundColor Green
Write-Host "Backup of original config created at: $env:APPDATA\Subversion\config.backup" -ForegroundColor Yellow

# Pause so user can read message
Read-Host -Prompt "Press Enter to exit"
