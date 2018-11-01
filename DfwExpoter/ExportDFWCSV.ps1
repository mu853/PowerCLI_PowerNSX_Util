function GetSources {
    param (
        $sources
    )
    
    $temp = foreach( $src in $sources ){
        $value = $src.value
        
        if( $src.type -eq "VirtualMachine" ){
            $vm = Get-VM -Id ("VirtualMachine-{0}" -F $src.value)
            $value = "{0} [{1}]" -F $vm.Name, $src.type
        }
        
        if( $src.type -eq "SecurityGroup" ){
            $sg = Get-NsxSecurityGroup -objectId securitygroup-20
            $value = "{0} [{1}]" -F $sg.name, $src.type
        }
        
        if( -not $src.isValid ){
            $value = "x {0}" -F $value
        }
        
        $value
    }
    
    $temp -join "`n"
}

function GetDestinations {
    param (
        $destinations
    )
    
    return GetSource -sources $destinations
}

function GetServices {
    param (
        $services
    )
    
    $temp = foreach( $srv in $services ){
        $value = $srv.name
        
        if( -not $srv.isValid ){
            $value = "x {0}" -F $value
        }
        
        $value
    }
    
    $temp -join "`n"
}

function GetAppliedTo {
    param (
        $appliedToList
    )
    
    $temp = foreach( $at in $appliedToList ){
        $value = $at.name
        
        if( -not $at.isValid ){
            $value = "x {0}" -F $value
        }
        
        if( $at.type -ne "DISTRIBUTED_FIREWALL" ){
            $value = "{0} [{1}]" -F $at.name, $at.type
        }
        
        $value
    }
    
    $temp -join "`n"
}

function Export-DFWRulesCSV {
    param (
        $path
    )
    
    Get-NsxFirewallRule | %{
        $r = $_

        [PSCustomObject]@{
            disabled = $r.disabled
            name = $r.name
            id = $r.id
            src = ( GetSources -sources $r.sources.source )
            dst = ( GetDestinations -destinations $r.destinations.destination )
            service = ( GetServices -services $r.services.service )
            action = $r.action
            direction = $r.direction
            packetType = $r.packetType
            appliedTo = ( GetAppliedTo -appliedToList $r.appliedToList.appliedTo )
            logged = $r.logged
        }
    } | Export-Csv -Encoding UTF8 -NoTypeInformation -Path $path
}
