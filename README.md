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
