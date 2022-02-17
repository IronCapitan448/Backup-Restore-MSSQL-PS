<#
.Developer
Srinath Prathi
.SYNOPSIS
Performs Native backup of specified database on specified server.
.DESCRIPTION
Upon passing backupservername and database name, Function will perform backup of that database on specified server.
Single or multiple databases can be passed for backup. If no value is specified then backup of all databases will be taken.
Detailed Log file will be saved in location c:\temp\Backup-MT_SQLDB_*.
.SYNTAX
Backup-MT_SQLDB -backupserver hostname\instancename -backupdatabase 'dbname1','dbname2' -Type 'FULL' -backuplocation '\\hostname\E$\backup\disk1\foldername
.PARAMETER backupserver
hostname\instancename - source servername for backup.
.PARAMETER backupdatabase
database name for backup on source server.
.PARAMETER Type
To specify type of backup. Type can be 'FULL', 'Log','Differential','Diff'
.PARAMETER backuplocation
Location for backup files(unc path only). If not specified default location will be used. If doesnot exits backup location will be created.

.Example
Backup-MT_SQLDB -backupserver hostname\instancename  -backupdatabase'db1','db2','db3'
Performs backup of databases db1,db2 and db3 on backup server hostname\instance
.Example
Backup-MT_SQLDB -backupserver hostname\instancename -backupdatabase 'db1','db2','db3' -Type log
Performs log backup of databases db1,db2 and db3
.Example
$backuplocation = "\\hostname\E$\backup\disk1\MSSQL11.Instancename\Foldername"
$dbs= ('db1','db2','db3')
Backup-MT_SQLDB -backupserver hostname\instancename -backupdatabase $dbs -Type Full -backuplocation $backuplocation
performs full backup of all databases in array $dbs to $backuplocation
.Example
$backuptable=@{}
$backuptable.  ****TRY THIS******
$srvs= 'hostname1\instancename1','hostname2\instnacename2'
$srvs.GetEnumerator().foreach{Backup-MT_SQLDB -backupserver $_ }
backups all databases mentioned in array list $srvrs
.Example
$srvs= 'hostname1\instancename1','hostname2\instnacename2'
$srvs.GetEnumerator().foreach{Backup-MT_SQLDB -backupserver $_ -backupdatabase 'sa'}
backups sa database on all servers in the array list $srvs


#>

function Backup-MT_SQLDB {
    param ([Parameter(Mandatory)][string]$backupserver, 
        [array]$backupdatabase, [string]$Type = 'FULL', [string]$backuplocation
    )
    $ErrorActionPreference = "Stop"
    Write-Warning "========DBA TOOLS MODULE REQUIRED FOR THIS SCRIPT========"
    import-module dbatools
    $PSDefaultParameterValues = @{ '*-Dba*:EnableException' = $true }
    $user = $env:UserName
    $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
    $InfoLog = "c:\temp\Backup-MT_SQLDB_" + $LogFileSuffix + ".log"
    $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
    $InfoLog = "c:\temp\Backup-MT_SQLDB_" + $LogFileSuffix + ".log"
    .\Write-log.ps1
    Write-Log -message "$(Get-date)::::CurrentUser:$user" -logfile $InfoLog
    
    try {
        if (!($backupdatabase.count)) {
            Write-Host "====No Value entered for Backup, by default all databases will be backed up====" -ForegroundColor DarkBlue
            if (!($backuplocation)) {
                $Bkps = Backup-DbaDatabase -SqlInstance $backupserver -Type $Type -CompressBackup -IgnoreFileChecks -ErrorAction Stop  
            }
            else {
                $Bkps = Backup-DbaDatabase -SqlInstance $backupserver -Type $Type -Path $backuplocation -CompressBackup -IgnoreFileChecks -ErrorAction Stop
            }
            
            Write-log -message "$(Get-date)::::No Value entered for Backup, by default all databases will be backed up" -logfile $InfoLog
            Write-Host "========Backup Information========" -ForegroundColor DarkMagenta
        }
        else {
            Write-log -message "$(Get-date)::::Databases that are selected for backup are $Backupdatabase" -logfile $InfoLog
            Write-host "========Taking Backups of $backupdatabase, Please Wait=======" -ForegroundColor DarkMagenta
            if (!($backuplocation)) {
                $Bkps = Backup-DbaDatabase -SqlInstance $backupserver -Database $backupdatabase -Type $Type -CompressBackup -IgnoreFileChecks -ErrorAction Stop    
            }
            else {
                $Bkps = Backup-DbaDatabase -SqlInstance $backupserver -Database $backupdatabase -Type $Type -Path $backuplocation -CompressBackup -BuildPath -ErrorAction Stop
            }
        }
        $backupinfo = $Bkps
        Write-Log -message "$(Get-date)::::Backup information::::" -logfile $InfoLog
        Write-Host "====Backup information====" -ForegroundColor DarkMagenta
        $message = $backupinfo | Format-Table -AutoSize | out-string
        Write-log -Message $message -LogFile $InfoLog
        $backuppath = $backupinfo.backuppath
        $uncpath = $backuppath
        if ($uncpath.count -gt 1) {
            $servername = $backupinfo.computername[0]
            for ($i = 0; $i -lt $backuppath.count; $i++) {
                $uncpath.item($i) = -join ('\\', $servername, '\', $backuppath[$i])
            }
            $uncpath = $uncpath.replace(':', '$')
            for ($i = 0; $i -lt $backupinfo.count; $i++) {
                $backupinfo.item($i) | add-member -NotePropertyName uncpath -NotePropertyValue $uncpath[$i]
            }
        }
        else {
            $servername = $backupinfo.computername
            $uncpath = -join ('\\', $servername, '\', $backuppath)
            $uncpath = $uncpath.replace(':', '$')
            $backupinfo | add-member -NotePropertyName uncpath -NotePropertyValue $uncpath
        }
        $message =$backupinfo | Select-Object SqlInstance,DatabaseName,BackupPath,uncpath,Script,Type,TotalSize,BackupFile,Backupfilescount,Duration | format-list |Out-String
        Write-host $message -ForegroundColor DarkMagenta
        write-log -Message $message -LogFile $InfoLog
        return $backupinfo
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