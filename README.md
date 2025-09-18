After installing TortoiseSVN, run this command in the terminal to edit config file to enable autoprops and add svn:needs-lock=yes property to solidworks files:
```
invoke-WebRequest -Uri "https://raw.githubusercontent.com/danielrbenjamin/svn-lock-solidworks/refs/heads/main/setupsvnlocks.ps1" -OutFile "$env:TEMP\setupsvnlocks.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\setupsvnlocks.ps1"
```
