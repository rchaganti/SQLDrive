using namespace Microsoft.PowerShell.SHiPS
Import-Module DbaTools -Force

[SHiPSProvider(UseCache = $true)]
class SQLRoot : SHiPSDirectory
{
    static [PSObject[]] $availableSQLInstances

    #Default contructor
    SQLRoot([string]$name) : base($name)
    {
    }

    [Object[]] GetChildItem()
    {
        $obj = @()

        if ([SQLRoot]::availableSQLInstances)
        {
            [SQLRoot]::availableSQLInstances | ForEach-Object {
                $obj += [SQLServer]::new($_.Keys, $_)
            }
        }
        else
        {
            $localInstances = Get-SQLInstance -ErrorAction SilentlyContinue
            if ($localInstances)
            {
                [SQLRoot]::availableSQLInstances += $localInstances
                $obj += [SQLServer]::new($localInstances.Keys, $localInstances)
            }
        }
        return $obj
    }
}

[SHiPSProvider(UseCache = $true)]
class SQLServer : SHiPSDirectory
{
    hidden [PSObject] $SqlInstanceObject

    #Default contructor
    SQLServer([string]$name,[PSObject]$SqlInstanceObject) : base($name)     
    {
        $this.SqlInstanceObject = $SqlInstanceObject
    }

    [Object[]] GetChildItem()
    {
        $instances = $($this.SqlInstanceObject.$($this.name).Instances)
        $credential = $($this.SqlInstanceObject.$($this.name).Credential)

        $obj = @()
        foreach ($instance in $instances)
        {
            $parameters = @{
                SqlInstance = "$($this.Name)\$($instance)"
            }

            if ($credential)
            {
                $parameters.Add('Credential',$credential)
            }
           
            $instanceobject = Connect-DbaInstance @parameters -ErrorAction Stop 
            if ($instanceobject)
            {
                $obj += [SQLInstance]::new($instance, $instanceobject, $credential)
            }
        }
        return $obj
    }
}

[SHiPSProvider(UseCache = $true)]
class SQLInstance : SHiPSDirectory
{
    hidden [Object] $InstanceObject
    hidden [PSCredential] $Credential

    [string] $DatabaseEngineType
    [string] $DatabaseEngineEdition
    [Version] $Version
    [String] $EngineEdition
    [Version] $ResourceVersion
    [Version] $BuildClrVersion
    [String] $ServiceAccount
    [String] $ProductLevel
    [String] $LoginMode

    #Default contructor
    SQLInstance([string]$name,[Object]$InstanceObject, [PSCredential]$Credential) : base($name)     
    {
        $this.InstanceObject = $InstanceObject
        $this.Credential = $Credential
        $this.LoginMode = $InstanceObject.LoginMode
        $this.ProductLevel = $InstanceObject.ProductLevel
        $this.ServiceAccount = $InstanceObject.ServiceAccount
        $this.BuildClrVersion = $InstanceObject.BuildClrVersion
        $this.ResourceVersion = $InstanceObject.ResourceVersion
        $this.EngineEdition = $InstanceObject.EngineEdition
        $this.Version = $InstanceObject.Version
        $this.DatabaseEngineEdition = $InstanceObject.DatabaseEngineEdition
        $this.DatabaseEngineType = $InstanceObject.DatabaseEngineType
    }

    [Object[]] GetChildItem()
    {
        $obj = @()
        $obj += [SQLDatabases]::new('Databases',$this.InstanceObject, $this.Credential)
        $obj += [SQLRoles]::new('Roles',$this.InstanceObject, $this.Credential)
        return $obj
    }
}

[SHiPSProvider(UseCache = $true)]
class SQLDatabases : SHiPSDirectory
{
    hidden [Object] $InstanceObject
    hidden [PSCredential] $Credential

    #Default contructor
    SQLDatabases([string]$name,[Object]$InstanceObject,[PSCredential]$Credential) : base($name)     
    {
        $this.InstanceObject = $InstanceObject
        $this.Credential = $Credential
    }

    [Object[]] GetChildItem()
    {
        $obj = @()
        foreach ($database in $this.instanceObject.Databases)
        {
            $obj += [SQLDatabase]::new($database.name, $this.InstanceObject, $database, $this.Credential)
        }
        return $obj
    }
}

[SHiPSProvider(UseCache = $true)]
class SQLDatabase : SHiPSDirectory
{
    hidden [Object] $InstanceObject
    hidden [Object] $DatabaseObject
    hidden [PSCredential] $Credential
    [int] $ActiveConnections
    [Bool] $AutoClose
    [Bool] $AutoShrink
    [String] $Collation
    [int] $Version
    [String] $UserName
    [double] $SpaceAvailable
    [double] $Size

    #Default contructor
    SQLDatabase([string]$name,[Object]$InstanceObject,[Object] $DatabaseObject, [PSCredential]$Credential) : base($name)     
    {
        $this.InstanceObject = $InstanceObject
        $this.Credential = $Credential
        $this.ActiveConnections = $DatabaseObject.ActiveConnections
        $this.AutoClose = $DatabaseObject.AutoClose
        $this.AutoShrink = $DatabaseObject.AutoShrink
        $this.Collation = $DatabaseObject.Collation
        $this.Version = $DatabaseObject.Version
        $this.UserName = $DatabaseObject.UserName
        $this.SpaceAvailable = $DatabaseObject.SpaceAvailable
        $this.Size = $DatabaseObject.Size
    }

    [Object[]] GetChildItem()
    {
        $obj = @()
        return $obj
    }
}

[SHiPSProvider(UseCache = $true)]
class SQLRoles : SHiPSDirectory
{
    hidden [Object] $InstanceObject
    hidden [PSCredential] $Credential

    #Default contructor
    SQLRoles([string]$name,[Object]$InstanceObject,[PSCredential]$Credential) : base($name)     
    {
        $this.InstanceObject = $InstanceObject
        $this.Credential = $Credential
    }

    [Object[]] GetChildItem()
    {
        $obj = @()
        foreach ($role in $this.InstanceObject.Roles)
        {
            $obj += [SQLRole]::New($role.Name, $role)
        }
        return $obj
    }
}

[SHiPSProvider(UseCache = $true)]
class SQLRole : SHiPSLeaf
{
    hidden [Object] $RoleObject
    [datetime] $DateCreated
    [datetime] $DateModified
    [int] $ID
    [Boolean] $IsFixedRole
    [String] $Owner
    [String] $State

    #Default contructor
    SQLRole([string]$name, [Object]$RoleObject) : base($name)     
    {
        $this.RoleObject = $RoleObject
        $this.DateCreated = $RoleObject.DateCreated
        $this.DateModified = $RoleObject.DateModified
        $this.ID = $RoleObject.ID
        $this.IsFixedRole = $RoleObject.IsFixedRole
        $this.Owner = $RoleObject.Owner
        $this.State = $RoleObject.State
    }
}

function Get-SQLInstance
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [String]
        $ComputerName,

        [Parameter()]
        [psCredential]
        $Credential
    )

    $parameters = @{}
    if ($ComputerName)
    {
        $parameters.add('ComputerName',$ComputerName)
    }

    if ($Credential)
    {
        $parameters.Add('Credential', $Credential)
    }

    if ($parameters.Keys)
    {
        $instances = Get-DbaSqlService @parameters

    }
    else
    {
        $instances = Get-DbaSqlService
    }

    $serverName = $instances.ComputerName | Select-Object -Unique
    $availableInstances = ($instances.InstanceName).Where({$_ -ne ''}) | Select-Object -Unique

    return @{
        $serverName = @{
            Instances = $availableInstances
            Credential = $Credential
        }
    }
}

function Connect-SQLServer
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [String]
        $ComputerName,

        [Parameter()]
        [psCredential]
        $Credential
    )

    $sqlServer = Get-SqlInstance -ComputerName $ComputerName -Credential $Credential
    [SQLRoot]::availableSQLInstances += $sqlServer
}
