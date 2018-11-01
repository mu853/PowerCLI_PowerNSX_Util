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
                "ダッシュボード名" = $v.name;
                "ウィジェット名" = $w.name;
                "説明" = ( $w.info -Replace  "\</?[^\>]+\>", "" ) -Replace "\&nbsp;", "";
            }
        }
    } | Export-Csv -Encoding utf8 -Path ( "{0}\dashboards.csv" -F $outdir )

    $cp.alerts | %{
        $a = $_
        [PSCustomObject]@{
            "アラート名" = $a.name;
            "説明" = ( $a.info -Replace  "\</?[^\>]+\>", "" ) -Replace "\&nbsp;", "";
        }
    } | Export-Csv -Encoding utf8 -Path ( "{0}\alerts.csv" -F $outdir )
}
