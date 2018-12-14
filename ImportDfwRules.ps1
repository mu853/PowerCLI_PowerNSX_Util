PowerShellは都度コミットする、変更時は削除＆追加が必要　★削除に失敗する。。。
既存ルールを書き換えたい場合は、APIで書き換え対象個所全体を更新したほうが良い


function Add-Rule(){
    param(
        [Parameter (Mandatory=$true, ValueFromPipeline=$True)]
        $csv
    )
    
    process {
        # セクションを検索し、なかったら作成する
        $section = Get-NsxFirewallSection -Name $csv.Section | Select-Object -First 1
        if( -not $section ){
            $section = New-NsxFirewallSection -Name $csv.Section -sectionType layer3sections -position top
        }

        # ルールの条件
        $rule = @{
           Section = $section
           Name = $csv.Name
           Action = $csv.Action
           EnableLogging = $true
        }

        # ソースを指定（IPセットやセキュリティグループは事前に作成済みの前提）
        if( $csv.Source ){
            switch( $csv.SourceType ){
                "SecurityGroup" { $rule.Source = Get-NsxSecurityGroup -Name $csv.Source }
                "IPset"         { $rule.Source = Get-NsxIPset -Name $csv.Source }
                default         { $rule.Source = $csv.Source }
            }
        }

        # 宛先を指定（IPセットやセキュリティグループは事前に作成済みの前提）
        if( $csv.Destination ){
            switch( $csv.DestinationType ){
                "SecurityGroup" { $rule.Destination = Get-NsxSecurityGroup -Name $csv.Destination }
                "IPset"         { $rule.Destination = Get-NsxIPset -Name $csv.Destination }
                default         { $rule.Destination = $csv.Destination }
            }
        }

        # サービスを指定（独自サービスが必要な場合、事前に作成済みの前提）
        if( $csv.Service ){
            $rule.Service = Get-NsxService -LocalOnly -Name $csv.Service
        }
        
        
        # 適用先を指定（セキュリティグループは事前に作成済みの前提）
        if( $csv.AppliedTo ){
            $rule.AppliedTo = Get-NsxSecurityGroup -Name $csv.AppliedTo
        }

        New-NsxFirewallRule @rule
    }
}

function Add-SecurityGroup {
    param(
        [Parameter (Mandatory=$true)]
        $csv
    )
    
    $csv[0].SetOperator
    $criterias = @()
    foreach ( $c in $csv ) {
        if ( $c.Key ) {
            $criteria = New-NsxDynamicCriteriaSpec -Key $c.key -Condition $c.Condition -Value $c.Value
            $criterias += $criteria
        } else {
            $entity = $null
            switch ( $c.EntityType ) {
                "LogicalSwitch" { $entity = Get-NsxLogicalSwitch $c.EntityName }
                "IPset"         { $entity = Get-NsxIpSet $c.EntityName }
                "SecurityGroup" { $entity = Get-SecurityGroup $c.EntityName }
            }
            $criteria = New-NsxDynamicCriteriaSpec -Entity $entity
            $criterias += $criteria
        }
    }
    
    $sg = New-NsxSecurityGroup -Name $csv[0].Name
    $dynamicConfig = @{
        SetOperator = $csv[0].SetOperator
        CriteriaOperator = $csv[0].CriteriaOperator
        DynamicCriteriaSpec = $criterias
    }
    $sg | Add-NsxDynamicMemberSet @dynamicConfig
}

Import-Csv IPsets.csv | %{ New-NsxIpSet -Name $_.Name -IPAddress $_.IPAddress }
Import-Csv SG.csv | Group-Object -Property Name | %{ Add-SecurityGroup $_.Group }
Import-Csv Rules.csv | Add-Rule




