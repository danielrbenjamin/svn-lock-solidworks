After installing TortoiseSVN, run this command in the terminal to edit config file to enable autoprops and add svn:needs-lock=yes property to solidworks files:
```
invoke-WebRequest -Uri "https://raw.githubusercontent.com/danielrbenjamin/svn-lock-solidworks/refs/heads/main/setupsvnlocks.ps1" -OutFile "$env:TEMP\setupsvnlocks.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\setupsvnlocks.ps1"
```

Setup For Existing Files:
```
$types = @("*.sldprt","*.sldasm","*.slddrw")
foreach ($type in $types) {
    Get-ChildItem -Recurse -Filter $type | ForEach-Object {
        svn propset svn:needs-lock yes $_.FullName
    }
}
```

Undo Setup For Existing Files:
```
$types = @("*.sldprt","*.sldasm","*.slddrw")
foreach ($type in $types) {
    Get-ChildItem -Recurse -Filter $type | ForEach-Object {
        svn propdel svn:needs-lock $_.FullName
    }
}
```

SVN Locking Communication Script
```
$folder="$PWD\svn-lock-solidworks"; New-Item -ItemType Directory -Path $folder -Force | Out-Null; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/danielrbenjamin/svn-lock-solidworks/refs/heads/main/Open-SW-With-LockCheck.ps1" -OutFile "$folder\Open-SW-With-LockCheck.ps1"; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/danielrbenjamin/svn-lock-solidworks/refs/heads/main/Open-SW-With-LockCheck.bat" -OutFile "$folder\Open-SW-With-LockCheck.bat"; $lnk="$folder\Open-SW-With-LockCheck.lnk"; $ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut($lnk); $s.TargetPath="$folder\Open-SW-With-LockCheck.bat"; $s.WorkingDirectory=$folder; $s.WindowStyle=7; $s.Save()
```
