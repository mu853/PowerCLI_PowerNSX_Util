Set-PSDebug -Strict
$ErrorActionPreference = "Stop"

function Export-ResourcePool () {
    param (
        [parameter(mandatory=$true)]
        [string]$path
    )
    
    if ( ! ( Test-Path -PathType Container $path ) ) {
        "Cannot find directory [{0}]" -F $path
        return
    }
    
    foreach ( $cl in ( Get-Cluster ) ) {
       $filePath = Join-Path $path ( "{0}.csv" -F $cl.Name )
       $rp = Get-ResourcePool -Location $cl
       $rp | %{ $_ | Add-Member -MemberType NoteProperty -Name Route -Value ( Get-RouteResourcePool $_ ) }
       $rp | Select Name, CpuExpandableReservation, CpuLimitMhz, CpuReservationMhz, CpuSharesLevel, MemExpandableReservation, MemLimitMB, MemReservationMB, MemSharesLevel, Route | Export-Csv -Path $filePath -Encoding utf8
    }
}

function Get-RouteResourcePool () {
    param (
        [parameter(mandatory=$true)]
        $rp
    )
    
    $stack = @()
    while( $rp.Parent -and ( $rp.Parent.GetType().Name -eq "ResourcePoolImpl") ){
        $stack += $rp.Name
        $rp = $rp.Parent
    }
    [array]::Reverse($stack)
    
    return $stack -Join ":"
}

function Get-LeafResourcePool() {
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
            $location = Get-ResourcePool -Location $location -Name $route_array[$i]
        } catch {
            return $location, $route_array[$i..($route_array.Length - 1)]
        }
    }
    return $location, ""
}

function Import-ResourcePool () {
    param (
        [parameter(mandatory=$true)]
        [string]$path
    )
    
    $clusterName = ( ( $path | Split-Path -Leaf ) -split "\.")[0]
    $root = Get-Cluster $clusterName | Get-ResourcePool -NoRecursion
    
    foreach ( $r in ( Import-Csv $path ) ) {
        if ( $r.Name -eq "Resources" ) {
            "Skip default resource pool [Resources]" | Write-Host
            continue
        }
        
        $location, $leaves = Get-LeafResourcePool $r.Route $root
        
        foreach( $leaf in ( $leaves -Split ":" ) ){
            if( $leaf -ne "" ) {
                $config = @{
                    Location = $location
                    Name = $r.Name
                    CpuExpandableReservation = [System.Convert]::ToBoolean( $r.CpuExpandableReservation )
                    CpuLimitMhz = $r.CpuLimitMhz
                    CpuReservationMhz = $r.CpuReservationMhz
                    CpuSharesLevel = $r.CpuSharesLevel
                    MemExpandableReservation = [System.Convert]::ToBoolean( $r.MemExpandableReservation )
                    MemLimitMB = $r.MemLimitMB
                    MemReservationMB = $r.MemReservationMB
                    MemSharesLevel = $r.MemSharesLevel
                }
                
                if ( $r.CpuSharesLevel -eq "Custom" ) {
                    $config["NumCpuShares"] = $r.NumCpuShares
                }
                if ( $r.MemSharesLevel -eq "Custom" ) {
                    $config["NumMemShares"] = $r.NumMemShares
                }
                
                try {
                    "Creating ResourcePool {0} @ {1} ..." -F $leaf, $location | Write-Host -ForegroundColor Cyan -NoNewLine
                    New-ResourcePool @config | Out-Null
                    "`t`tOK" | Write-Host -ForegroundColor Green
                } catch {
                    "`t`tNG" | Write-Host -ForegroundColor Red
                    $Error | Write-Host
                }
            }
        }
    }
}
