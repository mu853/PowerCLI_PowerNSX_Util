function Convert-RawAndColumn(){
<#
    .SYNOPSIS
        Convert raw and column of any object.
    .EXAMPLE
        $vm01 = [PSCustomObject]@{ Name = "vm01"; Memory = 10; CPU = 4 }
        PS C:\>$vm02 = [PSCustomObject]@{ Name = "vm02"; Memory = 20; CPU = 6 }
        
        PS C:\>@($vm01, $vm02)

        Name Memory CPU
        ---- ------ ---
        vm01     10   4
        vm02     20   6


        PS C:\>@($vm01, $vm02) | Convert-RawAndColumn

        Key       4    6
        ---       -    -
        Memory   10   20
        Name   vm01 vm02
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateScript({ $_ | gm -MemberType NoteProperty })]
        [object]$InputObject,
        
        [string]$HeaderKey = "Name"
    )
    
    begin {
        $data = @()
        $keys = @()
        $init = $false

        function init($obj){
            Set-Variable -Name keys -Value ($obj | Get-Member -MemberType NoteProperty).Name -Scope 1
            if($HeaderKey -notcontains $keys){
                Set-Variable -Name HeaderKey -Value $keys[0] -Scope 1
            }
            Set-Variable -Name init -Value $true -Scope 1
        }
    }
    
    process {
        if(!$init){ init($InputObject) }
        $data += $InputObject
    }
    
    end {
        $keys | %{
            $key = $_
            if($key -ne $HeaderKey){
                $obj = [PSCustomObject]@{ Key = $key }
                $data | %{
                    $obj | Add-Member -MemberType NoteProperty -Name $_.$HeaderKey -Value $_.$key -Force
                }
                $obj
            }
        }
    }
}

