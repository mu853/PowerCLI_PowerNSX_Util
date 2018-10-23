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
    
    # vCenterのバージョンによって階層が違う対策。最下層まで展開する
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
            
            # EventTypeを間借りして保存
            $_.EventType = $desc
        }
    }
    
    return , $triggers
}

function GetActions( $alarm ){
    $actions = @()
    
    foreach( $ac in $alarm.ExtensionData.Info.Action.Action ){
        $actions += [PSCustomObject]@{
            "アクション" = $ac.Action -replace "VMware.Vim.", "";
            "構成"       = if( $ac.Action.ToList ){ $ac.Action.ToList }elseif( $ac.Action.Script ){ $ac.Action.Script };
            "緑⇒黄"     = ( $ac.TransitionSpecs | ?{ ( $_.StartState -eq "green" )  -and ( $_.FinalState -eq "yellow" ) } ) -ne $null;
            "黄⇒赤"     = ( $ac.TransitionSpecs | ?{ ( $_.StartState -eq "yellow" ) -and ( $_.FinalState -eq "red" )    } ) -ne $null;
            "赤⇒黄"     = ( $ac.TransitionSpecs | ?{ ( $_.StartState -eq "red" )    -and ( $_.FinalState -eq "yellow" ) } ) -ne $null;
            "黄⇒緑"     = ( $ac.TransitionSpecs | ?{ ( $_.StartState -eq "yellow" ) -and ( $_.FinalState -eq "green" )  } ) -ne $null;
            "繰り返し"   = "{0}分" -F ( $alarm.ExtensionData.Info.ActionFrequency / 60 )
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
        return "イベント"
    }
    return "条件または状態"
}

function PrintLine( $n, $a, $at, $atype, $tc, $t, $c, $ac ){
    [PSCustomObject]@{
        "No."          = $n;
        "アラーム名"   = if( $a ){ $a.Name };
        "説明"         = if( $a ){ $a.Description };
        "監視対象"     = if( $at){ $at };
        "監視内容"     = if( $atype){ $atype };
        "有効化"       = if( $a ){ $a.Enabled };
        "トリガー条件" = $tc;
        "トリガー"     = if( $t.EventType ){ $t.EventType }elseif( $t.Metric ){ GetPerfDescription -CountId $t.Metric.CounterId }else{ $t.StatePath };
        "演算子"       = $t.Operator;
        "警告条件"     = if( $t.StatePath ){ $t.Yellow }elseif( $t.Metric ){ "{0}%/{1}分" -F ( $t.Yellow / 100 ), ( $t.YellowInterval / 60 ) };
        "重大条件"     = if( $t.StatePath ){ $t.Red    }elseif( $t.Metric ){ "{0}%/{1}分" -F ( $t.Red    / 100 ), ( $t.RedInterval    / 60 ) };
        "イベント"     = if( $t ){ $t.EventType };
        "ステータス"   = $t.Status;
        "条件"         = if( $t ){ $t.Comparisons.Count };
        "条件:引数"    = $c.AttributeName;
        "条件:演算子"  = $c.Operator;
        "条件:値"      = $c.Value;
        "アクション"   = $ac.'アクション';
        "構成"         = $ac.'構成';
        "緑⇒黄"       = $ac.'緑⇒黄';
        "黄⇒赤"       = $ac.'黄⇒赤';
        "赤⇒黄"       = $ac.'赤⇒黄';
        "黄⇒緑"       = $ac.'黄⇒緑';
        "繰り返し"     = $ac.'繰り返し';
    }
}

function Export-vCenterAlarm(){

    <#
    .SYNOPSIS
    vCenterアラームをCSV形式でエクスポートします

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
        # 大まかに下記のような形式で出力する
        # トリガーとトリガー条件は親子関係があるが、アクションとは独立しているので
        # 定義数が多い方に従って行を追加していく必要がある
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
                # 1行目は全部出力
                PrintLine     $no   $alarm $alarmTarget $alarmType $t_condition $trigger $t_comp $action
            }else{
                # 2行目以降はアラート共通の値は出力しない
                if( $itc -eq 0 ){
                    PrintLine "" $null  $null        $null      $null        $trigger $t_comp $action
                }else{
                    # トリガー条件の2行目以降がある場合、トリガー共通の値は出力しない
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

