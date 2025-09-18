# Path to SVN config file
$svnConfig = "$env:APPDATA\Subversion\config"

# Backup existing config with timestamp
$backupPath = "${svnConfig}.bak_$(Get-Date -Format 'yyyyMMddHHmmss')"
Copy-Item -Path $svnConfig -Destination $backupPath -Force
Write-Host "Backup created at: $backupPath"

# Read file into array
$config = Get-Content -Path $svnConfig

# --- 1. Ensure enable-auto-props = yes ---
$foundEnable = $false
for ($i = 0; $i -lt $config.Length; $i++) {
    if ($config[$i] -match '^\s*#?\s*enable-auto-props\s*=') {
        $config[$i] = 'enable-auto-props = yes'
        $foundEnable = $true
        break
    }
}
if (-not $foundEnable) {
    $idx = ($config | Select-String '^\[miscellany\]').LineNumber
    if ($idx) {
        $config = $config[0..$idx] + 'enable-auto-props = yes' + $config[($idx+1)..($config.Length-1)]
    } else {
        $config += 'enable-auto-props = yes'
    }
}

# --- 2. SolidWorks rules handling ---
$rules = @(
    '*.sldprt = svn:needs-lock=yes',
    '*.sldasm = svn:needs-lock=yes',
    '*.slddrw = svn:needs-lock=yes'
)

# Track which rules already exist
$missingRules = @()
foreach ($rule in $rules) {
    $pattern = '^\s*' + [regex]::Escape($rule.Split('=')[0].Trim()) + '\s*='
    if (-not ($config -match $pattern)) {
        $missingRules += $rule
    }
}

if ($missingRules.Count -gt 0) {
    # Find [auto-props] section
    $autoPropsIdx = ($config | Select-String '^\[auto-props\]').LineNumber

    if ($autoPropsIdx) {
        # Look for "# Makefile = svn:eol-style=native" marker
        $markerIdx = ($config | Select-String '^\s*#\s*Makefile\s*=\s*svn:eol-style=native').LineNumber
        if ($markerIdx) {
            # Insert immediately after the marker
            $before = $config[0..$markerIdx]
            $after = $config[($markerIdx+1)..($config.Length-1)]
            $config = $before + $missingRules + '' + $after
        } else {
            # No marker, so append at the end of [auto-props]
            # Find where the section ends (next [section] or EOF)
            $endIdx = ($config | Select-String '^\[' | Where-Object { $_.LineNumber -gt $autoPropsIdx } | Select-Object -First 1).LineNumber
            if ($endIdx) {
                $before = $config[0..($endIdx-2)]
                $after = $config[($endIdx-1)..($config.Length-1)]
                $config = $before + $missingRules + '' + $after
            } else {
                # [auto-props] is the last section, append at end
                $config += $missingRules
                $config += ''
            }
        }
    } else {
        # No [auto-props], append fresh section at EOF
        $config += '[auto-props]'
        $config += '# Makefile = svn:eol-style=native'
        $config += $missingRules
        $config += ''
    }
}

# --- Write back safely ---
Set-Content -Path $svnConfig -Value $config -Encoding UTF8
Write-Host "Config patched successfully."
