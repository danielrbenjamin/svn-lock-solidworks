<#
.SYNOPSIS
    Configures Subversion (SVN) to enable auto-props and add specific rules for SolidWorks files.

.DESCRIPTION
    This script updates the user's SVN configuration file to:
    - Enable the 'enable-auto-props' option.
    - Add SVN auto-props for SolidWorks files (*.sldprt, *.sldasm, *.slddrw) to require locking.

    The script creates a timestamped backup before making changes and handles errors gracefully.

.PARAMETER Pause
    If specified, pauses at the end and waits for user input before exiting.

.EXAMPLE
    .\Enable-SolidWorksSvnAutoProps.ps1
    Runs the script without pausing.

.EXAMPLE
    .\Enable-SolidWorksSvnAutoProps.ps1 -Pause
    Runs the script and pauses at the end.

.NOTES
    Requires PowerShell 3.0 or later.
    Author: [Your Name]
    Date: September 18, 2025
#>

[CmdletBinding()]
param(
    [switch]$Pause
)

# Enable strict mode for better error handling
Set-StrictMode -Version Latest

# Define constants
$ConfigPath = Join-Path $env:APPDATA 'Subversion\config'
$EnableAutoPropsKey = 'enable-auto-props'
$EnableAutoPropsValue = 'yes'
$SvnProps = @(
    '*.sldprt = svn:needs-lock=yes',
    '*.sldasm = svn:needs-lock=yes',
    '*.slddrw = svn:needs-lock=yes'
)

# Function to write colored host messages
function Write-ColorHost {
    param(
        [string]$Message,
        [System.ConsoleColor]$ForegroundColor = 'White'
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function to exit with error
function Exit-WithError {
    param([string]$Message)
    Write-ColorHost $Message -ForegroundColor Red
    exit 1
}

# Validate config file existence
if (-not (Test-Path $ConfigPath)) {
    Exit-WithError "SVN configuration file not found at: $ConfigPath"
}

# Create timestamped backup
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$BackupPath = "${ConfigPath}.backup.$Timestamp"
try {
    Copy-Item -Path $ConfigPath -Destination $BackupPath -ErrorAction Stop
    Write-ColorHost "Backup created at: $BackupPath" -ForegroundColor Yellow
} catch {
    Exit-WithError "Failed to create backup: $($_.Exception.Message)"
}

# Read config content
try {
    $ConfigContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 -ErrorAction Stop
} catch {
    Exit-WithError "Failed to read config file: $($_.Exception.Message)"
}

# Detect line ending
$LineEnding = if ($ConfigContent -match "`r`n") { "`r`n" } else { "`n" }

# Update or add enable-auto-props
$CommentedPattern = '^\s*#\s*' + [regex]::Escape($EnableAutoPropsKey) + '\s*=\s*' + [regex]::Escape($EnableAutoPropsValue) + '\s*$'
$UncommentedPattern = '^\s*' + [regex]::Escape($EnableAutoPropsKey) + '\s*=\s*' + [regex]::Escape($EnableAutoPropsValue) + '\s*$'

if ($ConfigContent -match $CommentedPattern) {
    $ConfigContent = $ConfigContent -replace $CommentedPattern, "$EnableAutoPropsKey = $EnableAutoPropsValue"
} elseif ($ConfigContent -notmatch $UncommentedPattern) {
    # Find a suitable insertion point (after a section header or at the end)
    $InsertionPointPattern = '(?m)^\s*\[\w+.*?\](?=\s*(?:\[|\Z))|(?=\Z)'
    if ($ConfigContent -match $InsertionPointPattern) {
        $ConfigContent = $ConfigContent -replace $InsertionPointPattern, "`${0}${LineEnding}${EnableAutoPropsKey} = $EnableAutoPropsValue${LineEnding}"
    } else {
        $ConfigContent = $ConfigContent.TrimEnd() + $LineEnding + "${EnableAutoPropsKey} = $EnableAutoPropsValue$LineEnding"
    }
}

# Handle [auto-props] section
$SectionPattern = '\[auto-props\](?:(?!\[).)*?(?=\[|\Z)'
$SectionMatch = [regex]::Match($ConfigContent, $SectionPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

if ($SectionMatch.Success) {
    $SectionContent = $SectionMatch.Value
    $UpdatedSection = $SectionContent
    foreach ($Prop in $SvnProps) {
        $EscapedProp = [regex]::Escape($Prop)
        $PropPattern = '^\s*' + $EscapedProp + '\s*$'
        if ($SectionContent -notmatch $PropPattern) {
            $UpdatedSection += $LineEnding + $Prop
        }
    }
    if ($UpdatedSection -ne $SectionContent) {
        $ConfigContent = $ConfigContent -replace [regex]::Escape($SectionMatch.Value), $UpdatedSection.TrimEnd()
    }
} else {
    # Add new [auto-props] section at the end
    $NewSection = "[auto-props]$LineEnding" + ($SvnProps -join $LineEnding) + $LineEnding
    $ConfigContent = $ConfigContent.TrimEnd() + $LineEnding + $NewSection
}

# Write updated config
try {
    Set-Content -Path $ConfigPath -Value $ConfigContent -Encoding UTF8 -ErrorAction Stop
    Write-ColorHost "SVN configuration updated successfully. Auto-props for SolidWorks files enabled." -ForegroundColor Green
} catch {
    Exit-WithError "Failed to write config file: $($_.Exception.Message)"
}

# Optional pause
if ($Pause) {
    Read-Host -Prompt "Press Enter to exit"
}
