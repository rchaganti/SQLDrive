# SQLDrive
This is an experimental version of SQL Server as PowerShell Drive using the SHiPS module.

## Usage
```
Import-Module SHiPS -Force
Import-Module .\SQLDrive.psd1 -Force

New-PSDrive -Name SQL -PSProvider SHiPS -Root SQLDrive#SQLRoot
```
## Current State Demo


