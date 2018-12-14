#BubbleHearth Redeption - ressurects crashed servers as best it can

function GetProcessIfRunning(){
    Params($ProcessName);
    return Get-Process $ProcessName -ErrorAction SilentlyContinue; # null on fail
}

function EnsureProcessReallyDied(){
    Params($ProcessName);
    $proc = GetProcessIfRunning $ProcessName;
    if($proc){
        if($proc.Responding){
            $srv_up = Test-NetConnection -ComputerName $check.IP -Port $check.Port -InformationLevel "Quiet";
        }
    }
    return 0; # dead
}


#is the process running?
#if so is it .responding? & network?
#if not ask it to close main window
#after 5s,5s,30s:db,as,ws force kill
#relaunch from $BH_CurrentBinary


#server takes ~30s to start, prob longer if not clean exit

if($args.Count -lt 1) {
    Write-Host "You must pass a file path as the first parameter. This file is what will be ressurected." -ForegroundColor Red; 
    pause; exit;
}


$args[0]
pause;

($args[0].BinaryPath);
pause