Set-PSDebug -Strict

function Get-VmReservation(){
<#
    .SYNOPSIS
        This function gets virtual machine resouces (cpu/memory/disk) and its reservation value.
    .PARAMETER vm
        VirtualMachine Object
    .EXAMPLE
        Get-VmReservation -vm VirtualMachines
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$vm
    )

    process{
        foreach($v in $vm){
            [PSCustomObject]@{
                "Name" = $v.Name
                "Size" = "-"
                "Cpu" = $v.NumCpu
                "Cpu(reserv)" = $v.ExtensionData.ResourceConfig.CpuAllocation.Reservation
                "Memory" = Get-SizeString($v.MemoryMB)
                "Memory(reserv)" = Get-SizeString($v.ExtensionData.ResourceConfig.MemoryAllocation.Reservation)
                "Disk" = (Get-SizeString( ($v.ExtensionData.Config.Hardware.Device | ?{ $_.GetType().Name -eq "VirtualDisk" }).CapacityInKB | %{ $_ / 1024} ))  -join ", "
            }
        }
    }
}

function Get-SizeString(){
<#
    .SYNOPSIS
        This function convert megabyte value to human readable string.
    .PARAMETER sizeInMB
        megabyte value
    .EXAMPLE
        Get-SizeString 100
        100 MB
    .EXAMPLE
        Get-SizeString 1024
        1 GB
    .EXAMPLE
        Get-SizeString 1000
        0.98 GB
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [int[]]$sizeInMB
    )
    
    process{
        foreach($s in $sizeInMB){
            if($s -lt 1000){
                "{0} MB" -F $s
            }else{
                $sizeInGB = $s / 1024
                if($sizeInGB -is [int]){
                    "{0} GB" -F $sizeInGB
                }else{
                    "{0:0.00} GB" -F $sizeInGB
                }
            }
        }
    }
}

function Get-NsxManager(){
<#
    .SYNOPSIS
        Get NSX Manager virtual machine object with NSX connection information.
#>
    Get-VM | ?{ $_.Guest.IPAddress | ?{ $_ -eq $Global:DefaultNSXConnection.Server } }
}

function Get-NsxComponetResourceReservation(){
<#
    .SYNOPSIS
        This function gets provisioned resouces of NSX Components (Manager/Controller/Edge).
        It requires PowerCLI and PowerNSX modules.
        Before use, connect to NSX server like Connect-NsxtServer -Server NsxManager 
    .EXAMPLE
        Get-NsxComponetResourceReservation | ft -AutoSize
         
        Name                                 Size    Cpu Cpu(reserv) Memory Memory(reserv) Disk
        ----                                 ----    --- ----------- ------ -------------- ----
        ESG-01-0                             compact   1        1000 512 MB 512 MB         584 MB, 512 MB
        NSX_Controller_xxxxxxxxxxxxxxxxxxxxx -         4           0 4 GB   2 GB           20 GB
        nsxmanager                           -         4           0 16 GB  0 MB           60 GB
#>
    if(!(Test-Path variable:global:DefaultNSXConnection)){
        throw "Connect to NSX Manager first."
    }
    
    $result = @()
    $result += Get-NsxEdge | %{
        $edge = $_
        Get-VM -Name @($edge.appliances.appliance)[0].vmName | %{
            $obj = Get-VmReservation $_
            $obj.Size = $edge.appliances.applianceSize
            $obj
        }
    }
    $result += @(Get-NsxController) | %{
        $c = $_
        Get-VM -Name $c.virtualMachineInfo.name | %{
            Get-VmReservation $_
        }
    }
    $result += Get-VmReservation (Get-NsxManager)
    
    $result
}
