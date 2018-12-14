#crashrecovery for wow server
$config_path = "BubbleHearthConfig.json";

##################################################
# You do not need to modify anything below here.##
##################################################
# Created 12/13/18 by Brady Russell bradyrussell.com

#####################################################
$global:progressPreference = 'silentlyContinue';
$ws = (new-object -comobject wscript.shell);
function YesNoPrompt(){
    Param($Text, $Title);
    return $ws.popup($Text, 0,$Title,4) -eq 6;
}

function AbortRetryIgnorePrompt(){
    Param($Text, $Title);
    switch($ws.popup($Text, 0,$Title,2)){
        4 { return 'retry'}
        5 { return 'ignore'}
        default { return 'abort'}
    }
}

function VerboseLogText(){
    Param($LogFileSuffix=$BH_CurrentConfig.LogFileSuffix, $Text, $isVerboseEnabled=$BH_CurrentConfig.VerboseLogging, $NoNewLine = 0);
    if($isVerboseEnabled) {
        LogText -LogFileSuffix $LogFileSuffix -Text $Text -NoNewLine $NoNewLine;
    }
}

function LogText(){
    Param($LogFileSuffix = $BH_CurrentConfig.LogFileSuffix, $Text, $NoNewLine = 0);
    if($NoNewLine) {
        Add-Content ((Get-Date -Format "s").Split('T').Get(0)+$LogFileSuffix) ("["+(Get-Date -DisplayHint DateTime).toString() + "] "+$Text) -NoNewline;
    } else {
        Add-Content ((Get-Date -Format "s").Split('T').Get(0)+$LogFileSuffix) ("["+(Get-Date -DisplayHint DateTime).toString() + "] "+$Text);
    }
}

function CustomSleep(){
    Param([float]$Seconds = 1, [float]$Resolution = 20.0, [bool]$Enabled=1);
    if($Enabled){
        $ProgressPreference = "Continue";
        for($i = 0; $i -lt $Resolution; $i++){
            Sleep -Milliseconds (($Seconds * 1000.0) / $Resolution);
            Write-Progress -Activity "Idle" -Status "Awaiting next check interval" -PercentComplete ($i*(100.0/$Resolution)) -SecondsRemaining ((($Seconds * 1000.0) - $i*(($Seconds * 1000.0) / $Resolution))/1000.0);
        }
        Write-Progress -Activity "Idle" -Completed 
        $ProgressPreference = "SilentlyContinue";
    } else {
        Sleep -Seconds $Seconds;
    }
}

function print($Text = "", $Color = "white", $NoNewLine = 0){
    if($NoNewLine) {
        Write-Host $Text -ForegroundColor $Color -NoNewline;
        VerboseLogText -Text $Text -NoNewLine 1;
    } else {
        Write-Host $Text -ForegroundColor $Color;
        VerboseLogText -Text $Text;
    }
}
#####################################################

$DEFAULT_CONFIG = [PSCustomObject]@{
    "Name"="BubbleHearth Default CFG";
    "Version"="1.1.2a";
    "VerboseLogging"=1;

    "DisplayWaitingProgressBar"=1

    "SecondsBetweenChecks"=10;
    "ShouldRunRecoveryScripts"=1;

    "ShouldUseRCON"=0;
    
    "PathToChecksFile"="BubbleHearthChecks.json";
    "LogFileSuffix"="_BHLog.txt";

    "RCON_Credentials"=[PSCustomObject]@{
            "IP"="127.0.0.1";
            "Port"=1420;
            "Username"="rcon_user";
            "Password"="rcon_pass";
        };
    };

           
$DEFAULT_CHECKS = @(
    [PSCustomObject]@{"CheckName"="System Memory"; "PercentSystemMemoryUsageLimit"= 100;"RecoverySettings"=[PSCustomObject]@{"Script"="BubbleHearth_Redemption.ps1";"ProcessName"="ram";"BinaryPath"="";};},
    [PSCustomObject]@{"CheckName"="Database Server"; "IP"="127.0.0.1"; "Port" = 3310; "RecoverySettings"=[PSCustomObject]@{"Script"="BubbleHearth_Redemption.ps1";"ProcessName"="dbserver";"BinaryPath"="";};},
    [PSCustomObject]@{"CheckName"="World Server"; "IP"="127.0.0.1"; "Port" = 8085;  "RecoverySettings"=[PSCustomObject]@{"Script"="BubbleHearth_Redemption.ps1";"ProcessName"="worldserver";"BinaryPath"="";};},
    [PSCustomObject]@{"CheckName"="Auth Server"; "IP"="127.0.0.1"; "Port" = 3724;  "RecoverySettings"=[PSCustomObject]@{"Script"="BubbleHearth_Redemption.ps1";"ProcessName"="authserver";"BinaryPath"="";};}
);

##################################################### 
# try to load config
cls
if(Test-Path variable:BH_CurrentConfig) {Remove-Variable BH_CurrentConfig};
if([System.IO.File]::Exists($config_path)){ # cfg exists
    do{
        print ("Begin loading configurations... ( •_•)");
        try{
            $BH_CurrentConfig = (Get-Content -Path $config_path) | ConvertFrom-Json;
            print ("Loaded configuration: "+ $BH_CurrentConfig.Name) "green";
        } catch {
            print ("Failed to parse configuration at {0}!" -f $config_path) "red";

            switch(AbortRetryIgnorePrompt -Text "The configuration file could not be parsed. Ignore to use the defaults." -Title ("Failed to parse configuration!")){
                "retry" { break;};
                "ignore" { $BH_CurrentConfig = $DEFAULT_CONFIG; print( ("Ignoring invalid config file, using defaults."), "yellow"); };
                default { print ("No valid configuration, terminating.")  "red"; exit; };
            }

        }
    } while (-not(Test-Path variable:BH_CurrentConfig)); # for as long as there is no config loaded
} else { # no cfg write defaults
    $DEFAULT_CONFIG | ConvertTo-Json | Out-File -FilePath ($config_path);
    $BH_CurrentConfig = $DEFAULT_CONFIG;
    print ("No configuration file found at {0}, so a default one was created." -f $config_path)  "yellow";

}

#attempt to use the parsed config    #Push-Location -Path $BH_CurrentConfig.PathToWorkingDirectory;
try{
    if([System.IO.File]::Exists($BH_CurrentConfig.PathToChecksFile)){ # cfg exists
        try {
            $BH_CurrentChecks = (Get-Content -Path $BH_CurrentConfig.PathToChecksFile) | ConvertFrom-Json;
            print ("Loaded "+$BH_CurrentChecks.Count+" checks from file.")  "green" -NoNewLine 1; print "      ( •_•)>⌐■-■" "white";
        } catch {
            print ("Fatal: Error trying to load checks from file.")  "red"; pause; exit;
        }
    } else {
        $DEFAULT_CHECKS | ConvertTo-Json | Out-File -FilePath ($BH_CurrentConfig.PathToChecksFile);
        $BH_CurrentChecks = $DEFAULT_CHECKS;
        print ("No checks file found at "+$BH_CurrentConfig.PathToChecksFile+", so a default one was created.")  "yellow";
    }
} catch {
     print ("Fatal: Failed to apply imported configuration.") "red"; pause; exit;
}

print ("Finished loading configurations. (⌐■_■)") "white";

#####################################################
#cd C:\Users\Administrator\Desktop\SingleCore_AC_1.2; Stop-Process -name authserver -Force; start C:\Users\Administrator\Desktop\SingleCore_AC_1.2\Server\Bin64\authserver.exe

#####################################################
exit
#begin main loop

$os = Get-Ciminstance Win32_OperatingSystem;
[System.Collections.ArrayList]$NeedsRecoveredList = @();
while(1){
    $time = (Get-Date -DisplayHint DateTime).toString();

    echo ("[{0}] | Starting tests... "-f$time);

    foreach($check in $BH_CurrentChecks) { # for each server test its connection
        if([bool]($check.PSobject.Properties.name -match "PercentSystemMemoryUsageLimit")){ # is this a ram check?
            $ram_used_pct = (100.0-[math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,2));
            $ramclr = If ($ram_used_pct -le ($check.PercentSystemMemoryUsageLimit / 1.5)) {"green"} ElseIf ($ram_used_pct -le $check.PercentSystemMemoryUsageLimit) {"yellow"} Else {"red"}
            Write-Host ("        Total system memory usage: "+$ram_used_pct+"%.") -ForegroundColor $ramclr
            VerboseLogText -Text ("Total system memory usage: "+$ram_used_pct+"%.");
            if($ram_used_pct -gt $check.PercentSystemMemoryUsageLimit) {
                $a = $NeedsRecoveredList.Add($check.RecoverySettings);
                LogText -Text ("Check "+$check.CheckName + " failed! Current memory usage "+$ram_used_pct+"%!")  ;#log it
            }
        } elseif([bool]($check.PSobject.Properties.name -match "IP")) {
            $srv_up = Test-NetConnection -ComputerName $check.IP -Port $check.Port -InformationLevel "Quiet";

            If ($srv_up) {$result =" alive! :)"; $clr = "green"} Else {$result =" not responding... D:"; $clr = "red"}
            Write-Host ("        "+$check.CheckName + " is "+ $result) -ForegroundColor $clr

            if(-not($srv_up)){ # server down?
                $a = $NeedsRecoveredList.Add($check.RecoverySettings);
                LogText -Text ("Check {0} failed!" -f $check.CheckName)  ;#log it
            }
        } else {
            print ("Unknown check format: {0}" -f $check.ToString());
        }
    }

    If (-not($NeedsRecoveredList.Count.Equals(0))) {$emote=" F :("; $clr = "red"} Else {$emote="(⌐■_■)"; $clr = "green"}

    Write-Host ("        "+$NeedsRecoveredList.Count+" / "+$BH_CurrentChecks.Count+" tests failed.") -ForegroundColor $clr #-NoNewline;
    #Write-Host $emote -ForegroundColor Cyan;

    foreach($recoverySetting in $NeedsRecoveredList) {
        if($BH_CurrentConfig.ShouldRunRecoveryScripts){
            #launch our recovery script
            Start-Process powershell.exe -ArgumentList ("-file {0}" -f $recoverySetting.Script),("{0}" -f ($recoverySetting));
            LogText -Text ("Launched Recovery Script: "+$recoverySetting.ProcessName)  ;#log it
        } else {
            VerboseLogText -Text ("If enabled, would have started Recovery Script: "+$recoverySetting.Parameter)  ;#log it
        }
    }
    $NeedsRecoveredList.Clear();

    echo ("[{0}] | All tests completed." -f $time);

    CustomSleep -Seconds $BH_CurrentConfig.SecondsBetweenChecks -Resolution 50 -Enabled $BH_CurrentConfig.DisplayWaitingProgressBar;
}