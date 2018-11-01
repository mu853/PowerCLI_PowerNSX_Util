function Extract-AlertAndDashboard(){
    <#
    .SYNOPSIS
    Extract alert and dashboard list from vRLI contents pack file (.vlcp).

    .EXAMPLE
    Extract-AlertAndDashboard -path "C:\hoge\fuga\VMware - NSX-vSphere  v3.6.vlcp"
    #>
    
    param(
        $path,
        $outdir
    )
    
    $cp = gc $path | ConvertFrom-Json
    
    $cp.dashboardSections.views | %{
        $v = $_
        $v.rows.widgets | %{
            $w = $_
            [PSCustomObject]@{
                "�_�b�V���{�[�h��" = $v.name;
                "�E�B�W�F�b�g��" = $w.name;
                "����" = ( $w.info -Replace  "\</?[^\>]+\>", "" ) -Replace "\&nbsp;", "";
            }
        }
    } | Export-Csv -Encoding utf8 -Path ( "{0}\dashboards.csv" -F $outdir )

    $cp.alerts | %{
        $a = $_
        [PSCustomObject]@{
            "�A���[�g��" = $a.name;
            "����" = ( $a.info -Replace  "\</?[^\>]+\>", "" ) -Replace "\&nbsp;", "";
        }
    } | Export-Csv -Encoding utf8 -Path ( "{0}\alerts.csv" -F $outdir )
}
