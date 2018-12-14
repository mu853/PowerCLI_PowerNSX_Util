PowerShell�͓s�x�R�~�b�g����A�ύX���͍폜���ǉ����K�v�@���폜�Ɏ��s����B�B�B
�������[�����������������ꍇ�́AAPI�ŏ��������Ώی��S�̂��X�V�����ق����ǂ�


function Add-Rule(){
    param(
        [Parameter (Mandatory=$true, ValueFromPipeline=$True)]
        $csv
    )
    
    process {
        # �Z�N�V�������������A�Ȃ�������쐬����
        $section = Get-NsxFirewallSection -Name $csv.Section | Select-Object -First 1
        if( -not $section ){
            $section = New-NsxFirewallSection -Name $csv.Section -sectionType layer3sections -position top
        }

        # ���[���̏���
        $rule = @{
           Section = $section
           Name = $csv.Name
           Action = $csv.Action
           EnableLogging = $true
        }

        # �\�[�X���w��iIP�Z�b�g��Z�L�����e�B�O���[�v�͎��O�ɍ쐬�ς݂̑O��j
        if( $csv.Source ){
            switch( $csv.SourceType ){
                "SecurityGroup" { $rule.Source = Get-NsxSecurityGroup -Name $csv.Source }
                "IPset"         { $rule.Source = Get-NsxIPset -Name $csv.Source }
                default         { $rule.Source = $csv.Source }
            }
        }

        # ������w��iIP�Z�b�g��Z�L�����e�B�O���[�v�͎��O�ɍ쐬�ς݂̑O��j
        if( $csv.Destination ){
            switch( $csv.DestinationType ){
                "SecurityGroup" { $rule.Destination = Get-NsxSecurityGroup -Name $csv.Destination }
                "IPset"         { $rule.Destination = Get-NsxIPset -Name $csv.Destination }
                default         { $rule.Destination = $csv.Destination }
            }
        }

        # �T�[�r�X���w��i�Ǝ��T�[�r�X���K�v�ȏꍇ�A���O�ɍ쐬�ς݂̑O��j
        if( $csv.Service ){
            $rule.Service = Get-NsxService -LocalOnly -Name $csv.Service
        }
        
        
        # �K�p����w��i�Z�L�����e�B�O���[�v�͎��O�ɍ쐬�ς݂̑O��j
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




