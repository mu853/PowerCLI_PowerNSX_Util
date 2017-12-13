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
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$vm,

        [switch]$createShortcut
    )

    begin{
        if($createShortcut){
            $vmrc = "C:\Program Files (x86)\vmware\VMware Remote Console\vmrc.exe"
            if(!(Test-Path $vmrc -PathType Leaf)){
                throw "{0} not found." -F $vmrc
            }
        }
    }
  
    process {
        foreach($v in $vm){
            if($v -is [string]){
                $v = Get-VM $v
            }

            if($v){
                if($createShortcut){
                    $viserver = $Global:DefaultVIServer.Name
                    $username = $Global:DefaultVIServer.User
                    $uri = "vmrc://{0}@{1}/?moid={2}" -F $username, $viserver, $v.ExtensionData.MoRef.Value

                    $wsh = New-Object -ComObject WScript.Shell
                    $shortcut = $wsh.CreateShortcut((Convert-Path ".") + "\" + $v.Name + ".lnk")
                    $shortcut.TargetPath = $vmrc
                    $shortcut.Arguments = $uri
                    $shortcut.Save()
                }else{
                    Open-VMConsoleWindow $vm
                }
            }
        }
    }
}

Set-Alias -Name vmrc -Value Start-VMRC
