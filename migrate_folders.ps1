Set-PSDebug -Strict
$ErrorActionPreference = "Stop"

function Export-Folders () {
    param (
        [parameter(mandatory=$true)]
        [string]$path
    )
    
    Get-Folder | %{
        $f = $_
        if( $f.Parent -and ( $f.Parent.GetType().Name -eq "FolderImpl" ) ){
            $route = Get-RouteFolder $f
            [PSCustomObject]@{
                Name = $f.Name
                Route = $route
                Type = $f.Type
            }
        }
    } | Export-Csv -Path $path -Encoding utf8
}

function Get-RouteFolder () {
    param (
        [parameter(mandatory=$true)]
        $folder
    )
    
    $stack = @()
    while( $folder.Parent -and ( $folder.Parent.GetType().Name -eq "FolderImpl") ){
        $stack += $folder.Name
        $folder = $folder.Parent
    }
    [array]::Reverse($stack)
    
    return $stack -Join ":"
}

function Get-LeafFolder() {
    param (
        [parameter(mandatory=$true)]
        $route,
        [parameter(mandatory=$true)]
        $root
    )
    
    $route_array = $route -Split ":"
    $location = $root
    for( $i = 0; $i -lt $route_array.Length; $i++ ){
        try{
            $location = Get-Folder -Location $location -Name $route_array[$i]
        } catch {
            return $location, $route_array[$i..($route_array.Length - 1)]
        }
    }
    return $location, ""
}

function Import-Folder () {
    param (
        [parameter(mandatory=$true)]
        [string]$path
    )
    
    $roots = Get-Folder | ?{ ( ! $_.Parent ) -or ( $_.Parent -and ( $_.Parent.GetType().Name -eq "DatacenterImpl" ) ) }
    $root_vm = $roots | where type -eq VM
    $root_nw = $roots | where type -eq Network
    $root_hc = $roots | where type -eq HostAndCluster
    $root_ds = $roots | where type -eq Datastore
    $root_dc = $roots | where type -eq Datacenter
    
    foreach ( $f in ( Import-Csv $path ) ) {
        $location, $name = $null, $null
        switch( $f.Type ){
            "VM" {
                $location, $leaves = Get-LeafFolder $f.Route $root_vm
            }
            "Network" {
                $location, $leaves = Get-LeafFolder $f.Route $root_nw
            }
            "HostAndCluster" {
                $location, $leaves = Get-LeafFolder $f.Route $root_hc
            }
            "Datastore" {
                $location, $leaves = Get-LeafFolder $f.Route $root_ds
            }
            "Datacenter" {
                $location, $leaves = Get-LeafFolder $f.Route $root_dc
            }
        }
        
        foreach( $leaf in ( $leaves -Split ":" ) ){
            if( $leaf -ne "" ) {
                try {
                    "Creating Folder {0} @ {1} ..." -F $leaf, $location | Write-Host -ForegroundColor Cyan -NoNewLine
                    New-Folder -Location $location -Name $leaf | Out-Null
                    "`t`tOK" | Write-Host -ForegroundColor Green
                } catch {
                    "`t`tNG" | Write-Host -ForegroundColor Red
                    $Error | Write-Host
                }
            }
        }
    }
}
