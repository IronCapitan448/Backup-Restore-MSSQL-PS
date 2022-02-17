<#
Developer: Srinath Prathi
.Syntax
Backup-MT_DDBoost_DB -servername hostname\instanename -database databasename
.SYNOPSIS
Performs backup of specified database on specified server from DDBoost.
.DESCRIPTION
Upon being passed single server and single database name command will perform backup of database
by collecting information from ddboost info table of servername and saves information in log file
on C:\Temp location with name Backup-MT_DDBoost_YYYYMMDD_HHMMSS.log.
Server Names provided should be a full path i.e., hostname\instancename.
If No Name for database is provided by default all databases will be backed up.
.Parameter Servername
Hostname\Instancename - ServerName for backup  
.Parameter database
Database name for backup. If value is NULL all databases in instance are backedup.
.Example
Backup-MT_DDBOOST_DB -servername servername\instancename -database database1
Performs backup on servername\instancename  for database database1
.Example
Backup-MT_DDBOOST_DB -servername servername\instancename
Performs backup of all databases on server servername\instancename
.Example
$DB=('database1','database2','database3')
$DB.GetEnumerator().foreach{Backup-MT_DDBOOST_DB -servername servername\instancename -database $_}
Performs backup of all the databases in array $DB on same server -servername\instancename
.Notes
If No Name for database is provided by default all databases will be backed up.
#>
function Backup-MT_DDBOOST_DB {
    param([Parameter(Mandatory)][string]$servername, [string]$database)
    try {
        #creating file to store dynamic ddboost cmd command.
    $ErrorActionPreference = "Stop"
    $user = $env:UserName
    $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
    $InfoLog = "c:\temp\Backup-MT_DDBoost_" + $LogFileSuffix + ".log"
    $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
    $InfoLog = "c:\temp\Backup-MT_DDBoost_" + $LogFileSuffix + ".log"
    .\Write-log.ps1
    Write-Log -message "$(Get-date)::::CurrentUser:$user" -logfile $InfoLog
    Write-Log -message "$(Get-date)::::DDBoost Backup Script Initiated" -logfile $InfoLog
    Write-Log -message "$(Get-date)::::Backup server:$servername,Database:$database" -logfile $InfoLog
    $logfile = "c:\Temp\" + "ddboost_bkp_query" + (get-date).tostring("yyyyMMdd_hhmmss") + ".bat"
    $query = "select * from sa..mt_ddboost_info"
    #query to get required information from server needed for backup of ddboost server
    Write-host "====Fetching DD_BOOST Details from Instance====" -ForegroundColor DarkMagenta
    Write-Log -message "$(Get-date)::::Fetching DD_BOOST Details from Instance::::::::::" -logfile $InfoLog
    $Res = invoke-SqlCmd -ServerInstance $servername -Database sa -Query $query
    Write-host "====DD Boost info of server $servername===="  -ForegroundColor DarkMagenta
    Write-Log -message "$(Get-date)::::DD Boost info of server $servername" -logfile $InfoLog
    $message=$res | Out-String
    Write-host $message -ForegroundColor DarkMagenta
    Write-log -Message $message -LogFile $InfoLog
    $dd_host = $Res.dd_host
    $dd_user = $Res.dd_user
    $dd_path = $Res.dd_path
    #dividing ddboost info table into variables
    $instName = $servername.split('\')
    $HostSrv = $instname[0]
    $instName = $instName[1]
    #seperating Hostname and Instance
    $DDBkpsrv = -join ("MSSQL$", $instName, ":", $database)
    #making string for ddboost command line
    $ddbBkpQuery = "ddbmsqlsv.exe -c " + $HostSrv + ".micron.com" + " -l full -a " + '"NSR_DFA_SI=TRUE"' + " -a " + '"NSR_DFA_SI_USE_DD=TRUE"' + " -a " + "`"NSR_DFA_SI_DD_HOST=$dd_host`"" +
    " -a " + "`"NSR_DFA_SI_DD_USER=$dd_user`"" + " -a " + "`"NSR_DFA_SI_DEVICE_PATH=$dd_path`"" + " " + "`"$DDBkpsrv`""
    #assigining ddboost command to variable
    Write-host "====DDBOOST COMMAND LINE AS FOLLOWS====" -ForegroundColor DarkMagenta
    Write-Log -message "$(Get-date)::::DDBOOST COMMAND LINE AS FOLLOWS" -logfile $InfoLog
    $message=$ddbBkpQuery | out-string
    Write-host $message -ForegroundColor DarkMagenta
    Write-Log -Message $message -LogFile $InfoLog
    Add-Content -Path $logfile -value $ddbBkpQuery
    Write-Log -Message "$(Get-date)::::Bat file for execution: $logfile" -LogFile $InfoLog
    #writing command to bat file
    #creating session to execute batch on remote server.
    Write-host ":::::::Copying bat file to remote server:::::::" -ForegroundColor DarkMagenta
    Write-Log -message "$(Get-date)::::Copying bat file to remote server:$servername" -logfile $InfoLog
    $Session = New-PSSession -ComputerName "$HostSrv" 
    Copy-Item "$logfile" -Destination "C:\Temp\ddboost_bkp_query.bat" -ToSession $Session
    Write-Host ":::::::::::Initiating Backup of Database $Database:::::::::" -ForegroundColor DarkMagenta
    Write-Log -message "$(Get-date)::::Initiating Backup of Database $Database" -logfile $InfoLog
    $Bkp = Invoke-Command -ScriptBlock { C:\Temp\ddboost_bkp_query.bat } -Session $Session
    $message= $Bkp | Out-String
    Write-Log -Message $message -LogFile $InfoLog
    Write-Host $message -ForegroundColor DarkMagenta
    return $Bkp
    }
    catch [System.Exception] {
        Write-Host $_.Exception.Message -BackgroundColor DarkRed
        Throw "PLEASE VERIFY SERVERNAME" 
        
    }
    catch {
        Write-Host $_.Exception.Message -BackgroundColor DarkRed
        
        
    }
    finally {
        $Error.Clear()
    }
    
}