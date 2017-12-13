function Get-SnapshotTree(){
<#
    .SYNOPSIS
        Build a text tree of the snapshots of the given VM.
        The "*" mark represents the current snapshot
    .PARAMETER vm
        VirtualMachine Object
    .EXAMPLE
        Get-VM vm01 | Get-SnapshotTree
        [vm01]
        Test_00 (VirtualMachineSnapshot-snapshot-1846)
          „¯Test_01 (VirtualMachineSnapshot-snapshot-1847)
            „°Test_03 (VirtualMachineSnapshot-snapshot-1849)
            „«„¯Test_04 (VirtualMachineSnapshot-snapshot-1850)
            „¯Test_00 (VirtualMachineSnapshot-snapshot-1854)
              „¯Test_01 * (VirtualMachineSnapshot-snapshot-1855)
                „¯Test_02 (VirtualMachineSnapshot-snapshot-1856)
#>
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$vm
    )
    
    process{
        foreach($v in $vm){
            Get-Snapshot -VM $v | %{
                $ss = $_
                while($ss.Parent){
                    $ss = $ss.parent
                }
                $ss
            } | Get-Unique | Get-SnapshotSubTree -leftPad "  "
        }
    }
}

function Get-SnapshotSubTree(){
<#
    .SYNOPSIS
        This function is for private use only.
#>
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        $ss,
        [string]$leftPad = "",
        [switch]$isChild
    )
    
    if($ss -and (! $isChild)){
        "[{0}]" -F $ss.VM.Name
        "{0} ({1})" -F ($ss.Name + @(if($ss.IsCurrent){ " *" })), $ss.Id
    }
    
    $len = $ss.Children.length
    for($i = 0; $i -lt $len; $i++){
        $child = $ss.Children[$i]
        $snapshotName = "{0} ({1})" -F ($child.Name + @(if($child.IsCurrent){ " *" })), $child.Id
        if($i + 1 -lt $len){
            $leftPad + "„°" + $snapshotName
            Get-SnapshotSubTree -ss $child -leftPad ($leftPad + "„«") -isChild
        }else{
            $leftPad + "„¯" + $snapshotName
            Get-SnapshotSubTree -ss $child -leftPad ($leftPad + "  ") -isChild
        }
    }
}
