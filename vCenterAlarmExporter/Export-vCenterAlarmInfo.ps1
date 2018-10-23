function GetEvents(){
    $events = @{}
    
    ( Get-View EventManager ).Description.EventInfo | %{
        if( $_.Key -in @( "EventEx", "ExtendedEvent" ) ){
            $_.Key, $_.FullFormat = $_.FullFormat -Split "\|"
        }
        $events[ $_.Key ] = $_
    }
    return $events
}

function GetPerfDescription( $CountId ){
    $counter = ( Get-View ( Get-View ServiceInstance ).Content.PerfManager ).QueryPerfCounter( $CountId )
    "{0} {1} {2}" -F $counter.GroupInfo.Key, $counter.NameInfo.Key, $counter.UnitInfo.Key
}

function GetTrigger(){
    param( $alarm, $events )
    
    $triggers = $alarm.ExtensionData.Info.Expression
    
    # vCenter�̃o�[�W�����ɂ���ĊK�w���Ⴄ�΍�B�ŉ��w�܂œW�J����
    while( $triggers[0].GetType().Name -in @( "AndAlarmExpression", "OrAlarmExpression" ) ){
        $triggers = $triggers[0].Expression
    }
    
    $triggers | %{
        if( $_.EventTypeId ){
            $desc = $events[$_.EventTypeId].Description
            
            if( $desc -eq $null ){
                $eventTypeId = ( $_.EventTypeId -split "\." )[-1]
                $desc = $events[$eventTypeId].Description
            }
            
            if( $desc -eq $null ){
                $desc = $_.EventTypeId
            }
            
            # EventType���Ԏ؂肵�ĕۑ�
            $_.EventType = $desc
        }
    }
    
    return , $triggers
}

function GetActions( $alarm ){
    $actions = @()
    
    foreach( $ac in $alarm.ExtensionData.Info.Action.Action ){
        $actions += [PSCustomObject]@{
            "�A�N�V����" = $ac.Action -replace "VMware.Vim.", "";
            "�\��"       = if( $ac.Action.ToList ){ $ac.Action.ToList }elseif( $ac.Action.Script ){ $ac.Action.Script };
            "�΁ˉ�"     = ( $ac.TransitionSpecs | ?{ ( $_.StartState -eq "green" )  -and ( $_.FinalState -eq "yellow" ) } ) -ne $null;
            "���ː�"     = ( $ac.TransitionSpecs | ?{ ( $_.StartState -eq "yellow" ) -and ( $_.FinalState -eq "red" )    } ) -ne $null;
            "�ԁˉ�"     = ( $ac.TransitionSpecs | ?{ ( $_.StartState -eq "red" )    -and ( $_.FinalState -eq "yellow" ) } ) -ne $null;
            "���˗�"     = ( $ac.TransitionSpecs | ?{ ( $_.StartState -eq "yellow" ) -and ( $_.FinalState -eq "green" )  } ) -ne $null;
            "�J��Ԃ�"   = "{0}��" -F ( $alarm.ExtensionData.Info.ActionFrequency / 60 )
        }
    }
    
    return , $actions
}

function GetTriggerCondition( $alarm ){
    $typeName = $alarm.ExtensionData.Info.Expression.GetType().Name
    
    if( $typeName -notin @( "AndAlarmExpression", "OrAlarmExpression" ) ){
        return ""
    }
    return $typeName -replace "AlarmExpression", ""
}

function GetAlarmTarget( $trigger ){
    if( $trigger -eq $null){
        return ""
    }
    
    $type = "vCenter Server"
    if( $trigger.ObjectType -or $trigger.Type ){
        $type = $trigger.ObjectType + $trigger.Type
    }
    return $type
}

function GetAlarmType( $trigger ){
    if( $trigger.EventTypeId ){
        return "�C�x���g"
    }
    return "�����܂��͏��"
}

function PrintLine( $n, $a, $at, $atype, $tc, $t, $c, $ac ){
    [PSCustomObject]@{
        "No."          = $n;
        "�A���[����"   = if( $a ){ $a.Name };
        "����"         = if( $a ){ $a.Description };
        "�Ď��Ώ�"     = if( $at){ $at };
        "�Ď����e"     = if( $atype){ $atype };
        "�L����"       = if( $a ){ $a.Enabled };
        "�g���K�[����" = $tc;
        "�g���K�["     = if( $t.EventType ){ $t.EventType }elseif( $t.Metric ){ GetPerfDescription -CountId $t.Metric.CounterId }else{ $t.StatePath };
        "���Z�q"       = $t.Operator;
        "�x������"     = if( $t.StatePath ){ $t.Yellow }elseif( $t.Metric ){ "{0}%/{1}��" -F ( $t.Yellow / 100 ), ( $t.YellowInterval / 60 ) };
        "�d�����"     = if( $t.StatePath ){ $t.Red    }elseif( $t.Metric ){ "{0}%/{1}��" -F ( $t.Red    / 100 ), ( $t.RedInterval    / 60 ) };
        "�C�x���g"     = if( $t ){ $t.EventType };
        "�X�e�[�^�X"   = $t.Status;
        "����"         = if( $t ){ $t.Comparisons.Count };
        "����:����"    = $c.AttributeName;
        "����:���Z�q"  = $c.Operator;
        "����:�l"      = $c.Value;
        "�A�N�V����"   = $ac.'�A�N�V����';
        "�\��"         = $ac.'�\��';
        "�΁ˉ�"       = $ac.'�΁ˉ�';
        "���ː�"       = $ac.'���ː�';
        "�ԁˉ�"       = $ac.'�ԁˉ�';
        "���˗�"       = $ac.'���˗�';
        "�J��Ԃ�"     = $ac.'�J��Ԃ�';
    }
}

function Export-vCenterAlarm(){

    <#
    .SYNOPSIS
    vCenter�A���[����CSV�`���ŃG�N�X�|�[�g���܂�

    .EXAMPLE
    Connect-VIServer vcenter.lab.local -User administrator@vsphere.local -Password P@ssw0rd
    Export-vCenterAlarm -Path C:\vc_alarm.csv
    #>

    param (
        [Parameter( Mandatory = $True )]
        [string]$path,
        [Parameter( Mandatory = $False )]
        [ValidateSet( "ja", "en" )]
        [string]$lang = "ja",
        [Parameter( Mandatory = $False )]
        [switch]$simple
    )
    
    ( Get-View ( Get-View ServiceInstance ).Content.SessionManager ).SetLocale( $lang )
    
    $events = GetEvents

    $no = 1
    Get-AlarmDefinition | %{
        $alarm = $_
        
        $t_condition = GetTriggerCondition $alarm
        $triggers    = GetTrigger -alarm $alarm -events $events
        $actions     = GetActions $alarm
        
        ####
        # ��܂��ɉ��L�̂悤�Ȍ`���ŏo�͂���
        # �g���K�[�ƃg���K�[�����͐e�q�֌W�����邪�A�A�N�V�����Ƃ͓Ɨ����Ă���̂�
        # ��`�����������ɏ]���čs��ǉ����Ă����K�v������
        # 
        # no   alarm     trigger     trigger comparison     action
        # ---  --------  ----------  ---------------------  ---------
        #  1   alarm 1   trigger 1   trigger comparison 1   action 1
        #                            trigger comparison 2
        #                trigger 2
        #  2   alarm 2   trigger 1                          action 1
        #                                                   action 2
        ####
        
        $it = 0; $itc = 0; $ia = 0
        while( ( $ia -lt $actions.Count ) -or ( $it -lt $triggers.Count ) ){
            $trigger = $null; $action = $null; $t_comp = $null; $alarmTarget = $null; $alarmType = $null;
            
            ## Trigger
            if( $it -lt $triggers.Count ){
                $trigger = $triggers[$it]
                $alarmTarget = GetAlarmTarget -trigger $trigger
                $alarmType = GetAlarmType -trigger $trigger
            }
            
            ## Trigger Comparison
            if( $trigger.Comparisons -is [array] ){
                $t_comp = $trigger.Comparisons[ $itc ]
            }
            
            ## Action
            if( $ia -lt $actions.Count ){
                $action = $actions[ $ia ]
            }
            
            if( ( $ia -eq 0 ) -or ( $PsBoundParameters.ContainsKey('simple') )){
                # 1�s�ڂ͑S���o��
                PrintLine     $no   $alarm $alarmTarget $alarmType $t_condition $trigger $t_comp $action
            }else{
                # 2�s�ڈȍ~�̓A���[�g���ʂ̒l�͏o�͂��Ȃ�
                if( $itc -eq 0 ){
                    PrintLine "" $null  $null        $null      $null        $trigger $t_comp $action
                }else{
                    # �g���K�[������2�s�ڈȍ~������ꍇ�A�g���K�[���ʂ̒l�͏o�͂��Ȃ�
                    PrintLine "" $null  $null        $null      $null        $null    $t_comp $action
                }
            }
            
            if( $trigger.Comparisons -is [array] ){
                $itc++
                
                if( $itc -ge $trigger.Comparisons.Count ){    # Last One
                    $it++
                    $itc = 0
                }
            }else{
                $it++
            }
            $ia++
        }
        $no++
    } | Export-Csv -Encoding UTF8 -NoTypeInformation -Path $path
}

