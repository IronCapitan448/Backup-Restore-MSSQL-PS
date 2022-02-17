<#
.SYNOPSIS
Function to restore a backup of database from one server to another server using DDBoost.
.Syntax
Restore-MT_DDBoost_DB -backupserver BOWSQLTEST2019A\BOMSSTEST2019A -backupDB Hamster1 -RestoreServer BOWSQLTEST2019B\BOMSSTEST2019B -RestoreDB Hamster1_Test1 -timestamp "12/08/2021 10:00:00 AM"
.DESCRIPTION
Upon passing backupserver and backupDB, Script collects data about data domain server from backupserver.
Prepares Dynamic CMD Command for restoration of Restore DB on RestoreServer. TimeStamp parameter makes it possible to restore database to particular
time frame given log backups are present on server. File Mapping is automatically done if restore database exists on Restoreserver.
Detailed log is stored in location C:\Temp\Restore-MT_DDBOOST_YYYYMMDD_HHMMSS.log.
.Parameter BackupServer(Mandatory)
Hostname\Instancename - to collect information about ddboost data domain where source database is present for restoration
.Parameter backupDB(Mandatory)
Single value of database name in string for backup file retrieval from DDBoost.
.Parameter RestoreServer(Mandatory)
Hostname\Instancename - Destination server name where database should be restored.
.Parameter RestoreDB(Mandatory) 
Database name in string for restore. Can be same or different from source database name.
.Parameter timestamp
Timestamp in format "MM/DD/YYYY HH:MM:SS AM\PM" (quotes mandatory). If log backups are present for given timestamp. Command automatically picks all backups until that timestamp for restore.
If no backups are present for given timestamp. Script throws an error.
.Example
Restore-MT_DDBoost_DB -backupserver hostname1\instancename1 -backupDB databasename1 -RestoreServer hostname2\instancename2 -RestoreDB databasename2 -timestamp "MM/DD/YYYY HH:MM:SS AM\PM"
#>
function Restore-MT_DDBoost_DB 
{
    param (
        [Parameter(Mandatory)][string]$backupserver, [Parameter(Mandatory)][string]$backupDB,
        [Parameter(Mandatory)][string]$RestoreServer, [Parameter(Mandatory)][string]$RestoreDB, [string]$timestamp

    )
    try {
        $ErrorActionPreference = "Stop"
    $user = $env:UserName
    $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
    $InfoLog = "c:\temp\Restore-MT_DDBOOST_" + $LogFileSuffix + ".log"
    $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
    $InfoLog = "c:\temp\Restore-MT_DDBOOST_" + $LogFileSuffix + ".log"
    .\Write-log.ps1
    Write-Log -message "$(Get-date)::::CurrentUser:$user" -logfile $InfoLog
    Write-Log -message "$(Get-date)::::DDBoost Backup Script Initiated" -logfile $InfoLog
    Write-Log -message "$(Get-date)::::Backup server:$backupserver,Database:$backupDB" -logfile $InfoLog
    #creating file to store dynamic ddboost cmd command.
    $RstrFile = "c:\Temp\" + "ddboost_rstr_query" + (get-date).tostring("yyyyMMdd_hhmmss") + ".bat"
    $query = "select * from sa..mt_ddboost_info"
    #query to get required information from server needed for backup of ddboost server
    Write-host "====Fetching DD_BOOST Details from Instance====" -ForegroundColor DarkMagenta
    Write-Log -message "$(Get-date)::::Fetching DD_BOOST Details from Instance::::::::::" -logfile $InfoLog
    $Res = invoke-SqlCmd -ServerInstance $backupserver -Database sa -Query $query
    Write-host "====DD Boost info of server $servername====="  -ForegroundColor DarkMagenta
    Write-Log -message "$(Get-date)::::DD Boost info of server $backupserver" -logfile $InfoLog
    $message = $Res | Out-String
    Write-host $message -ForegroundColor DarkMagenta
    Write-Log -message "$(Get-date)::::`n$message" -logfile $InfoLog
    $dd_host = $Res.dd_host
    $dd_user = $Res.dd_user
    $dd_path = $Res.dd_path
    $dd_lockbox = $Res.dd_lockbox
    #dividing ddboost info table into variables
    $bkpinstName = $backupserver.split('\')
    $bkpHostSrv = $bkpinstname[0]
    $bkpinstName = $bkpinstName[1]
    $rstrinstName = $RestoreServer.split('\')
    $rstrHostSrv = $rstrinstName[0]
    $rstrinstName = $rstrinstName[1]
    #seperating Hostname and Instance
    $DDBkpsrv = -join ("MSSQL$", $bkpinstName, ":", $backupDB)
    $DDBkpsrv_db = -join (' -$ ', '"MSSQL$', $bkpinstName, ":", '"')
    $RSTRSrv = -join ("MSSQL$", $rstrinstName, ":", $RestoreDB)
    #Getting Database file location###
    $dbfiles =@{}
    Get-DbaDbFile -SqlInstance $RestoreServerName -Database $Restoredatabase | Select-Object LogicalName, PhysicalName | ForEach-Object {$dbfiles[$_.LogicalName] = $_.PhysicalName}
    #making string for ddboost command line
        if (!($dbfiles)) 
    {
        $rstrddbquery = "ddbmsqlrc.exe -a " + "NSR_DFA_SI_DD_HOST=$dd_host" + " -a " + "NSR_DFA_SI_DD_USER=$dd_user" + " -a " + "NSR_DFA_SI_DEVICE_PATH=$dd_path" + " -a " + "`"NSR_DFA_SI_DD_LOCKBOX_PATH=$dd_lockbox`"" + " -c " + "$bkpHostSrv" + ".micron.com" + " -a " + "`"SKIP_CLIENT_RESOLUTION=TRUE`"" + " -f -t " + "`"$timestamp`"" + " -S " + "normal" + "$DDBkpsrv_db" + " -d " + "$RSTRSrv" + " " + "$DDBkpsrv"
    }
    else 
    {
        $files2=@{}
        foreach ($_ in $dbfiles.keys) {
            $files2.$_ = -join ("'", $_, "'", '=', "'", $dbfiles.$_, "'")
        }
        $a = $files2.values.foreach('ToString')
        $files = ""
        foreach ($_ in $a) {
            $files += -join ($_, ",")
        }
        $files = $files.TrimEnd(',')
        $rstrddbquery = "ddbmsqlrc.exe -a " + "NSR_DFA_SI_DD_HOST=$dd_host" + " -a " + "NSR_DFA_SI_DD_USER=$dd_user" + " -a " + "NSR_DFA_SI_DEVICE_PATH=$dd_path" + " -a " + "`"NSR_DFA_SI_DD_LOCKBOX_PATH=$dd_lockbox`"" + " -c " + "$bkpHostSrv" + ".micron.com" + " -a " + "`"SKIP_CLIENT_RESOLUTION=TRUE`"" + " -C "+"$files" + " -f -t " + "`"$timestamp`"" + " -S " + "normal" + "$DDBkpsrv_db" + " -d " + "$RSTRSrv" + " " + "$DDBkpsrv" 
    }
    Write-host "====DDBOOST COMMAND LINE AS FOLLOWS=====" -ForegroundColor DarkMagenta
    $message = $rstrddbquery
    Write-Host $message -ForegroundColor DarkMagenta
    Write-Log -Message "$(Get-date)::::`n$message" -LogFile $InfoLog
    Add-Content -Path $RstrFile -value $rstrddbquery
    #writing command to bat file
    #creating session to execute batch on remote server.
    Write-host "====Copying bat file to remote server====" -ForegroundColor DarkMagenta
    Write-Log -Message "$(Get-Date)::::Copying bat file to remote server" -LogFile $InfoLog
    $Session = New-PSSession -ComputerName $rstrHostSrv 
    Copy-Item "$RstrFile" -Destination "C:\Temp\ddboost_rstr_query.bat" -ToSession $Session
    Write-Host "====Initiating Restore of Database $RestoreDB====" -ForegroundColor DarkMagenta
    Write-Log -Message "$(Get-Date)::::Initiating Restore of Database $RestoreDB" -LogFile $InfoLog
    $Rstr = Invoke-Command -ScriptBlock { C:\Temp\ddboost_rstr_query.bat } -Session $Session
    $message=$Rstr
    Write-Host "===Restore Information`n$message" -ForegroundColor DarkMagenta
    Write-Log -Message "$(get-date)::::RestoreInformation::::`n$message" -LogFile $InfoLog
    Add-Content -Path $RstrFile -value ":::::::Restore information:::::::"
    Add-Content -Path $RstrFile -value $Rstr
    Return $Rstr
        
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