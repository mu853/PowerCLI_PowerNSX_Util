function Start-VMRC(){
<#
    .SYNOPSIS
        Start VMRC with VirtualMachine object.
        vmrc is alias of this function.
    .PARAMETER vm
        VirtualMachine Object or VM Name
    .PARAMETER username
        User name for connecting to VIServer
    .PARAMETER viserver
        VIServer of the target VM
    .PARAMETER createShortcut
        If this option is set, this function only creates shortcut to start vmrc.
    .EXAMPLE
        Get-VM ESG* | where PowerState -eq PoweredOn | vmrc
#>
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [object[]]$vm,

        [string]$username,
        [string]$viserver,
        [switch]$createShortcut
    )

    begin{
        $vmrc = "C:\Program Files (x86)\vmware\VMware Remote Console\vmrc.exe"
        if(!(Test-Path $vmrc -PathType Leaf)){
            throw "{0} not found." -F $vmrc
        }

        if((Test-Path variable:global:DefaultVIServer) -and $Global:DefaultVIServer.IsConnected){
            if(!$viserver){
                $viserver = $Global:DefaultVIServer.Name
            }
            if(!$username){
                $username = $Global:DefaultVIServer.User
            }
        }else{
            if($vm | ?{ $_ -isnot [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine] }){
                throw "Connect to vCenter Server first."
            }
        }
    }
  
    process {
        foreach($v in $vm){
            if($v -is [string]){
                $v = Get-VM $v
            }

            if($v){
                $uri = "vmrc://{0}@{1}/?moid={2}" -F $username, $viserver, $v.ExtensionData.MoRef.Value
                if($createShortcut){
                    $wsh = New-Object -ComObject WScript.Shell
                    $shortcut = $wsh.CreateShortcut((Convert-Path ".") + "\" + $v.Name + ".lnk")
                    $shortcut.TargetPath = $vmrc
                    $shortcut.Arguments = $uri
                    $shortcut.Save()
                }else{
                    & $vmrc $uri
                }
            }
        }
    }
}

Set-Alias -Name vmrc -Value Start-VMRC
