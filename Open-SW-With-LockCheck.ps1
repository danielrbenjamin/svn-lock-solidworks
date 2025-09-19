param(
    [string[]]$FilePaths
)

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

# Path to SolidWorks shell launcher (from registry open command)
$swLauncher = "C:\PROGRA~1\COMMON~1\SOLIDW~1\SWSHEL~1.EXE"

# Load MessageBox for dialogs
Add-Type -AssemblyName PresentationFramework

function Show-Dialog($filePath, $message, $title, $buttons = "OK") {
    $fullMessage = "File: $filePath`n`n$message"
    return [System.Windows.MessageBox]::Show($fullMessage, $title, $buttons)
}

# Get current SVN username
$svnUser = svn info --show-item=username 2>$null

# ---------------------------------------------------------------------------
# PROCESS EACH FILE
# ---------------------------------------------------------------------------
foreach ($FilePath in $FilePaths) {

    # STEP 1. Verify file exists
    if (-not (Test-Path $FilePath)) {
        Show-Dialog $FilePath "File not found." "Error" "OK"
        continue
    }

    # STEP 2. Check if file is under SVN
    $svnInfo = svn info --non-interactive -- "$FilePath" 2>$null

    if ($LASTEXITCODE -ne 0) {
        # Not an SVN versioned file → just open normally
        Start-Process -FilePath $swLauncher -ArgumentList "`"$FilePath`""
        continue
    }

    # STEP 3. Parse lock info
    $lockOwnerLine = $svnInfo | Select-String "Lock Owner:"
    $lockOwner = $null
    if ($lockOwnerLine) {
        $lockOwner = $lockOwnerLine.ToString().Split(":")[1].Trim()
    }

    # STEP 4. Decide what to do
    if ($lockOwner) {
        if ($lockOwner -eq $svnUser) {
            # You own the lock → open normally
            Start-Process -FilePath $swLauncher -ArgumentList "`"$FilePath`""
        } else {
            # Locked by someone else → ask read-only
            $result = Show-Dialog $FilePath "This file is locked by $lockOwner.`n`nOpen as read-only?" "SVN Lock" "YesNo"
            if ($result -eq "Yes") {
                Start-Process -FilePath $swLauncher -ArgumentList "`"$FilePath`""
            }
        }
    }
    else {
        # Not locked → ask if user wants to get a lock
        $result = Show-Dialog $FilePath "This file is not locked.`nWould you like to get a lock?" "SVN Lock" "YesNoCancel"
        
        if ($result -eq "Yes") {
            svn lock --force -- "$FilePath" | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Show-Dialog $FilePath "Lock acquired. Opening file..." "SVN Lock" "OK"
                Start-Process -FilePath $swLauncher -ArgumentList "`"$FilePath`""
            }
            else {
                Show-Dialog $FilePath "Failed to acquire lock." "SVN Lock" "OK"
            }
        }
        elseif ($result -eq "No") {
            # Open read-only
            Start-Process -FilePath $swLauncher -ArgumentList "`"$FilePath`""
        }
        # Cancel → do nothing
    }
}
