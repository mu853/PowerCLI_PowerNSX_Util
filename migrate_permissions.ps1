Set-PSDebug -Strict
$ErrorActionPreference = "Stop"

function global:Export-Role(){
    param (
        [parameter(mandatory=$true)]
        [string]$path
    )
    
    Get-VIRole | %{
        [PSCustomObject]@{
            Name = $_.Name
            Id   = $_.Id
            IsSystem = $_.IsSystem
            Label = $_.ExtensionData.Info.Label
            Description = $_.Description
            PrivilegeList = $_.PrivilegeList -Join ","
        }
    } | Export-Csv -Encoding UTF8 -Path $path
}

function global:Import-Role (){
    param (
        [parameter(mandatory=$true)]
        [string]$inputCsv
    )

    $currentRole = Get-VIRole

    $roleList = Import-Csv $inputCsv
    $totalCount = $roleList.Length
    $index = 1
    
    foreach ( $role in $roleList ) {
        "{0:0000}/{1:0000}: " -F $index++, $totalCount | Write-Host -NoNewLine
        
        if ( $currentRole | ?{ $_.Name -eq $role.Name } ) {
            "Role aleady set - [Name: {0}]" -F $role.Name | Out-Host
            continue
        }
        
        "Adding role - [Name: {0}]" -F $role.Name | Write-Host -ForegroundColor Cyan -NoNewLine
        try {
            New-VIRole -Name $role.Name -Privilege ( $role.PrivilegeList -Split "," | %{ Get-VIPrivilege -id $_ } ) -Confirm:$false | Out-Null
            "`t`tOK" | Write-Host -ForegroundColor Green
        } catch {
            "`t`tNG" | Write-Host -ForegroundColor Red
            $_.Exception | Write-Host
        }
    }
}

function Get-EntityRoute () {
    param (
        $e
    )
    if( ! $e ){ return "" }
    
    $stack = @()
    $type = $e.GetType().Name
    while( $e.Parent -and ( $e.Parent.GetType().Name -eq $type ) ){
        $stack += $e.Name
        $e = $e.Parent
    }
    [array]::Reverse($stack)
    return $stack -Join ":"
}

function Get-RootEntity () {
    param (
        $e
    )
    if( ! $e ){ return "" }
    
    $type = $e.GetType().Name
    while( $e.Parent -and ( $e.Parent.GetType().Name -eq $type ) ){
        $e = $e.Parent
    }
    return $e.Parent
}

function Get-LeafEntity() {
    param (
        [parameter(mandatory=$true)]
        $route,
        [parameter(mandatory=$true)]
        $root,
        [parameter(mandatory=$true)]
        [ValidateSet("Folder", "ResourcePool")]
        $type
    )
    
    $route_array = $route -Split ":"
    $location = $root
    for( $i = 0; $i -lt $route_array.Length; $i++ ){
        try{
            if( $type -eq "Folder" ){
                $location = Get-Folder -Location $location -Name $route_array[$i]
            }else{
                $location = Get-ResourcePool -Location $location -Name $route_array[$i]
            }
        } catch {
            return $location, $route_array[$i..($route_array.Length - 1)]
        }
    }
    return $location, ""
}

function global:Export-Permission(){
    param (
        [parameter(mandatory=$true)]
        [string]$path
    )
    
    Get-VIPermission | %{
        $entityType = $_.ExtensionData.Entity.Type
        if( $entityType -eq "Folder" ){
            $entityType = "{0}_Folder" -F $_.Entity.Type
        }
        
        [PSCustomObject]@{
            EntityType = $entityType
            EntityId = $_.EntityId
            Entity = $_.Entity
            EntityRoute = ( Get-EntityRoute $_.Entity )
            Root = ( Get-RootEntity $_.Entity )
            RoleId = $_.ExtensionData.RoleId
            Role = $_.Role
            Principal = $_.Principal
            Propagate = $_.Propagate
            IsGroup = $_.IsGroup
        }
    } | Export-Csv -Encoding UTF8 -Path $path
}

function global:Import-Permission (){
    param (
        [parameter(mandatory=$true)]
        [string]$inputCsv
    )

    $currentPermission = Get-VIPermission

    $permissionList = Import-Csv $inputCsv
    $totalCount = $permissionList.Length
    $index = 1

    foreach ( $permission in $permissionList ) {
        "{0:0000}/{1:0000}: " -F $index++, $totalCount | Write-Host -NoNewLine

        $samePermission = $currentPermission | ?{
            ( $_.Role -eq $permission.Role ) -and
            ( $_.Principal -eq $permission.Principal ) -and
            ( ( Get-EntityRoute $_.Entity ) -eq $permission.EntityRoute ) -and
            ( $_.Entity.Name -eq $permission.Entity ) -and
            ( $_.Propagate -eq $permission.Propagate )
        }
        if ( $samePermission ) {
            "Permission aleady set - [Role: {0}, Principal: {1}, Propagate: {2}]" `
                -F $permission.Role, $permission.Principal, $permission.Propagate | Out-Host
            continue
        }

        $entity = $null
        $arr = $null
        switch ( $permission.EntityType ) {
            "Datacenter" {
                $entity = Get-Datacenter -Name $permission.Entity
            }
            "ClusterComputeResource" {
                $entity = Get-Cluster -Name $permission.Entity
            }
            "HostSystem" {
                $entity = Get-VMHost -Name $permission.Entity
            }
            "VirtualMachine" {
                $entity = Get-VM -Name $permission.Entity
            }
            "StoragePod" {
                $entity = Get-DatastoreCluster -Name $permission.Entity
            }
            "Datastore" {
                $entity = Get-Datastore -Name $permission.Entity
            }
            "DistributedVirtualPortgroup" {
                $entity = Get-VDPortGroup -Name $permission.Entity
            }
            
            "Datacenter_Folder" {
                $root = Get-Folder | ?{ ( ! $_.Parent ) -or ( $_.Parent -and ( $_.Parent.GetType().Name -eq "DatacenterImpl" ) ) } | where type -eq Datacenter
                $entity, $arr = Get-LeafEntity -route $permission.EntityRoute -root $root -type "Folder"
            }
            
            "VM_Folder" {
                $root = Get-Folder | ?{ ( ! $_.Parent ) -or ( $_.Parent -and ( $_.Parent.GetType().Name -eq "DatacenterImpl" ) ) } | where type -eq VM
                $entity, $arr = Get-LeafEntity -route $permission.EntityRoute -root $root -type "Folder"
            }
            "HostAndCluster_Folder" {
                $root = Get-Folder | ?{ ( ! $_.Parent ) -or ( $_.Parent -and ( $_.Parent.GetType().Name -eq "DatacenterImpl" ) ) } | where type -eq HostAndCluster
                $entity, $arr = Get-LeafEntity -route $permission.EntityRoute -root $root -type "Folder"
            }
            "Datastore_Folder" {
                $root = Get-Folder | ?{ ( ! $_.Parent ) -or ( $_.Parent -and ( $_.Parent.GetType().Name -eq "DatacenterImpl" ) ) } | where type -eq Datastore
                $entity, $arr = Get-LeafEntity -route $permission.EntityRoute -root $root -type "Folder"
            }
            "Network_Folder" {
                $root = Get-Folder | ?{ ( ! $_.Parent ) -or ( $_.Parent -and ( $_.Parent.GetType().Name -eq "DatacenterImpl" ) ) } | where type -eq Network
                $entity, $arr = Get-LeafEntity -route $permission.EntityRoute -root $root -type "Folder"
            }
            
            "ResourcePool" {
                $root = $root_rp = Get-Cluster $permission.Root | Get-ResourcePool -NoRecursion
                $entity, $arr = Get-LeafEntity -route $permission.EntityRoute -root $root -type "ResourcePool"
            }
        }

        if ( ! $entity ) {
            "Entity is null, Entity Type: {0}" -F $permission.EntityType
            continue
        }

        "Adding permission - [Entity: {0}, Role: {1}, Principal: {2}, Propagate: {3}]" `
            -F $entity.ToString(), $permission.Role, $permission.Principal, $permission.Propagate | Write-Host -ForegroundColor Cyan -NoNewLine
        try {
            New-VIPermission -Entity $entity -Principal $permission.Principal -Role (Get-VIRole -Name $permission.Role) -Confirm:$false | Out-Null
            "`t`tOK" | Write-Host -ForegroundColor Green
        } catch {
            "`t`tNG" | Write-Host -ForegroundColor Red
            $_.Exception | Write-Host
        }
    }
}
