 <#
.Developer: Srinath Prathi
.SYNOPSIS
Performs restore of database on specified server when correct backup files or location is provided
.DESCRIPTION
Upon passing correct backup location\file function restores database specified in backuplocation or backup files
Backup location should be a UNC Path - \\hostname\backuplocation. Restoring databases can be done with replace or recovery
Please check detailed log in location c:\temp\Restore-MT_SQLDB_
.PARAMETER RestoreServername(mandatory)
Parameter to store single value restore servername - hostname\instancename
.PARAMETER Restoredatabase
Parameter to store array of source database name - 'databasename1','databasename2',...
.PARAMETER backuplocation(mandatory)
Parameter to store location of backup files. - uncpath -\\hostname\location_of_file
.PARAMETER Recovery(switch) 
Enable this switch to restore database with full recovery -Recovery. If not mentioned default value restore with norecovery will be triggered.
.PARAMETER Replace(switch)
Enable this switch to restore database with replace -Replace. If not mentioned default value restore with no replace will be triggered.
.Example
Restore-MT_SQLDB -Restoreservername hostname\instancename -restoredatabase 'db1' -backuplocation '\\servername\E$\backup\disk1\foldername\db1.bak'
Restores database on single server with name db1 with  backup file in mentioned in backuplocation parameter
.Example
Restore-MT_SQLDB-Restoreservername hostname\instancename -restoredatabase 'db1','db2' -backuplocation '\\servername\E$\Backup\Disk1\foldername\'
Restore all backup files from foldername into db1, db2 with default options with no replace and norecovery.
.Example
Restore-MT_SQLDB-Restoreservername hostname\instancename -restoredatabase 'db1','db2' -backuplocation '\\servername\E$\Backup\Disk1\foldername\' -replace -recovery
Restore all backup files from foldername into db1, db2 with default options with replace and recovery
.Example
$backupinfo = Backup-MT_SQLDB -backupserver hostname\instancename  -backupdatabase'db1','db2','db3'
Restore-MT_SQLDB -Restoreservername hostname\instancename -backuplocation $backupinfo.uncpath -replace -recovery
Uses return value of backup-MT_SQLDB command as input for restore. Restores all the databases that are in $backupinfo.uncpath with same name.
.Example
$backupinfo = Backup-MT_SQLDB -backupserver hostname\instancename  -backupdatabase'db1','db2','db3'
$backupinfo.uncpath | Restore-MT_SQLDB -Restoreservername hostname\instancename -Replace -Recovery
Restores all databases present in location $backupinfo.uncpath with same name.
.Example
Restoring same database with one backup file to multiple servers
$backuplocation="\\hostname\E$\backup\disk1\MSSQL11.Instancename\Foldername\filename.bak"
$srvs= 'hostname1\instancename1','hostname2\instnacename2'
$srvs.GetEnumerator().foreach{Restore-MT_SQLDB -Restoreservername $_ -backuplocation $backuplocation -recovery}
for with replace restore:
$srvs.GetEnumerator().foreach{Restore-MT_SQLDB -Restoreservername $_ -backuplocation $backuplocation -replace -recovery}
.Notes
If you want to restore multiple database with different recovery and replace options. Use seperate restore commands to match replace and recovery options.
example:
db1, db2 with replace and db3 with no recovery,
use:
Restore-MT_SQLDB -restoreservername hostname\instancename -restoredatabase 'db1', 'db2' -Replace -recovery
Restore-MT_SQLDB -restoreservername hostname\instancename -restoredatabase 'db3' -Replace 

No.of backup files should match no.of database names provided for function.
Example:
You cannot provide two backup files to function and mention three database names in syntax.

#>
function Restore-MT_SQLDB {
    param (
        
        [Parameter(Mandatory)][string]$RestoreServerName,
        [array]$Restoredatabase,
        [Parameter(Mandatory, ValueFromPipeline)][array]$backuplocation,
        [switch]$Recovery, [switch]$Replace
    )
    $ErrorActionPreference = "Stop"
    Write-Warning "========DBA TOOLS MODULE REQUIRED FOR THIS SCRIPT========"
    import-module dbatools
    $PSDefaultParameterValues = @{ '*-Dba*:EnableException' = $true }
    $user = $env:UserName
    $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
    $InfoLog = "c:\temp\Restore-MT_SQLDB_" + $LogFileSuffix + ".log"
    $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
    $InfoLog = "c:\temp\Restore-MT_SQLDB_" + $LogFileSuffix + ".log"
    .\Write-log.ps1
    Write-Log -message "$(Get-date)::::CurrentUser:$user" -logfile $InfoLog 
    Write-Log -message "$(Get-date)::::Restore database initiated::::" -logfile $InfoLog
    Write-Log -message "$(Get-date)::::Destination Server:$RestoreServerName::::" -LogFile $InfoLog
    Write-Log -message "$(Get-date)::::Destination Server:$RestoreServerName::::" -LogFile $InfoLog
    try {
        if ($Restoredatabase.count -ne $backuplocation.count) 
        {
        Write-Warning -Message "===Backup files count doesnot match with Restore Databases Count==="
        Write-Log -Message "$(Get-date)::::No.of backup files passed or not equal to restore databases. Exiting Script" -LogFile $InfoLog
        Throw "PLEASE CHECK BACKUP FILES. CANNOT MATCH No.of BACKUP FILES WITH DATABASE NAMES"
        }
        else {  
        Write-Log -Message "$(Get-date)::::Selected databases for Restore:$Restoredatabase" -LogFile $InfoLog
        for ($i = 0; $i -lt $Restoredatabase.Count; $i++) 
        {
            $files=@{}
            Get-DbaDbFile -SqlInstance $RestoreServerName -Database $Restoredatabase.item($i) | Select-Object LogicalName, PhysicalName | ForEach-Object {$files[$_.LogicalName] = $_.PhysicalName}
            if ($Replace.Ispresent -and $Recovery.IsPresent) {
                $db = $Restoredatabase.item($i)
             Write-host "====Restoring database $db on $RestoreServerName with Recovery and Replace====" -ForegroundColor DarkMagenta
             Write-log -Message "$(Get-date)::::Restoring database $db on $RestoreServerName with Replace and Recovery" -LogFile $InfoLog
             $Restoreinfo = Restore-DbaDatabase -SqlInstance $RestoreServerName -Database $Restoredatabase.Item($i) -filemapping $files -withreplace -Path $backuplocation.item($i)
             $message=$restoreinfo | out-string
             Write-Log -Message "$(Get-date)::::RESTORE INFORMATION::::`n$message" -LogFile $InfoLog
             Write-Host "========Restore Information========" -ForegroundColor DarkMagenta
             Write-Host $message -ForegroundColor DarkMagenta
            }
            elseif ($Replace.Ispresent -eq $false) {
                if ($Recovery.IsPresent) {
                    $db=$Restoredatabase.item($i)
                Write-Host "====Restoring Database $db on $RestoreServerName with Recovery No Replace====" -ForegroundColor DarkMagenta
                Write-log -Message "$(Get-date)::::Restoring Database $db on $RestoreServerName with Recovery No Replace" -LogFile $InfoLog
                $Restoreinfo = Restore-DbaDatabase -SqlInstance $RestoreServerName -Database $Restoredatabase.item($i) -Path $backuplocation.item($i)  -ReplaceDbNameInFile 
                $message=$restoreinfo | out-string
                Write-Log -Message "$(Get-date)::::RESTORE INFORMATION::::`n$message" -LogFile $InfoLog
                Write-Host "========Restore Information========" -ForegroundColor DarkMagenta
                Write-Host $message -ForegroundColor DarkMagenta
                }
                else {
                    $db=$Restoredatabase.item($i)
                    Write-Host "====Restoring Database $db on $RestoreServerName with No Recovery No Replace====" -ForegroundColor DarkMagenta
                    Write-log -Message "$(Get-date)::::Restoring Database $db on $RestoreServerName with No Recovery No Replace" -LogFile $InfoLog
                    $Restoreinfo = Restore-DbaDatabase -SqlInstance $RestoreServerName -Database $Restoredatabase.item($i) -Path $backuplocation.item($i)  -ReplaceDbNameInFile -NoRecovery 
                    $message=$restoreinfo | out-string
                    Write-Log -Message "$(Get-date)::::RESTORE INFORMATION::::`n$message" -LogFile $InfoLog
                    Write-Host "========Restore Information========" -ForegroundColor DarkMagenta
                    Write-Host $message -ForegroundColor DarkMagenta
                }
            }
            else {
                $db=$Restoredatabase.item($i)
                Write-Host "====Restoring Database $db on $RestoreServerName with No Recovery Replace====" -ForegroundColor DarkMagenta
                Write-log -Message "$(Get-date)::::Restoring Database $db on $RestoreServerName with No Recovery Replace" -LogFile $InfoLog
                $restoreinfo = Restore-DbaDatabase -SqlInstance $RestoreServerName -Database $Restoredatabase.item($i) -Path $backuplocation.item($i) -filemapping $files -ReplaceDbNameInFile -withreplace -NoRecovery
                $message=$restoreinfo | out-string
                Write-Log -Message "$(Get-date)::::RESTORE INFORMATION::::`n$message" -LogFile $InfoLog
                Write-Host "========Restore Information========"
                Write-Host $message -ForegroundColor DarkMagenta
                
            }
            
        }
        if ($restoreinfo.owner -ne "sa") {
            Write-Log -Message "$(Get-Date)::::Setting database owner to sa::::" -LogFile $InfoLog
            Write-host "====Setting Database owner to sa====" -ForegroundColor DarkMagenta
            $saowner=Set-DbaDbOwner -SqlInstance $RestoreServerName -Database $Restoredatabase 
            $message=$saowner | out-string
            Write-log -message $message -LogFile $InfoLog
            Write-Host $message -ForegroundColor DarkMagenta
        }
    }
       
        return $Restoreinfo

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