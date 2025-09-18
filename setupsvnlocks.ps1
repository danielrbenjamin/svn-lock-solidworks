# Path to SVN config file
$svnConfig = "$env:APPDATA\Subversion\config"

# Backup existing config
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

# --- 2. Ensure SolidWorks auto-props ---
$autoProps = @(
    '*.sldprt = svn:needs-lock=yes',
    '*.sldasm = svn:needs-lock=yes',
    '*.slddrw = svn:needs-lock=yes'
)

foreach ($prop in $autoProps) {
    $pattern = '^\s*#?\s*' + [regex]::Escape($prop.Split('=')[0].Trim()) + '\s*='
    $existingIndex = $null

    for ($i = 0; $i -lt $config.Length; $i++) {
        if ($config[$i] -match $pattern) {
            $existingIndex = $i
            break
        }
    }

    if ($null -ne $existingIndex) {
        # Replace existing (commented or different value)
        $config[$existingIndex] = $prop
    } else {
        # Insert into [auto-props] section if present
        $idx = ($config | Select-String '^\[auto-props\]').LineNumber
        if ($idx) {
            # LineNumber is 1-based, so subtract 1 for array index
            $insertAt = $idx     # this points to the [auto-props] line
            $config = $config[0..$insertAt] + $prop + $config[($insertAt+1)..($config.Length-1)]
        } else {
            # Append a new section at the end
            $config += '[auto-props]'
            $config += $prop
        }
    }
}

# --- Write back safely ---
Set-Content -Path $svnConfig -Value $config -Encoding UTF8
Write-Host "Config file patched successfully. Safe to re-run (idempotent)."

