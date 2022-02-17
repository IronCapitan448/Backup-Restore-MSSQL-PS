<#
.Developer Srinath Prathi
.Synopsis
Adds database to Availability group either primary or secondary or both.
.Description
Upon passing servername and database name function adds database by checking if database is present in
Primary and Secondary. Function programmatically finds Primary and secondary nodes. Checks if database mentioned is 
on primary\secondary. If Database is not present on both primary and seconday then function asks for source database for
backup and restore.
.Parameter servername(Mandatory)
Hostname\InstanceName where Availability group is present.
.Parameter database(Mandatory)
Name of database which you want into Availablity group.
.Example
Add-MT_AG_DB -servername hostname\instancename -database databasename
Adding single database on single server.
.Example
$dbs=('db1','db2','db3')
$dbs.GetEnumerator().foreach{Add-MT_AG_DB -servername hostname\instancename -database $_}
Adding all databases in the array list $dbs on server hostname\instancename
#>
function add-MT_AG_DB {

    param (
        [Parameter(Mandatory)][string]$servername,
        [Parameter(Mandatory)][string]$database
    )
    try {
    
        $ErrorActionPreference = "Stop"
        Write-Warning "========DBA TOOLS MODULE REQUIRED FOR THIS SCRIPT========"
        import-module dbatools
        $PSDefaultParameterValues = @{ '*-Dba*:EnableException' = $true }
        $user = $env:UserName
        $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
        $InfoLog = "c:\temp\ADD-MT_AG_DB_" + $LogFileSuffix + ".log"
        $LogFileSuffix = (Get-Date).tostring("yyyyMMdd_hhmmss") 
        $InfoLog = "c:\temp\ADD-MT_AG_DB_" + $LogFileSuffix + ".log"
        . C:\Users\sprathi\PS_Scripting\BackupTool_PS\Write-log.ps1
        Write-Log -message "$(Get-date)::::CurrentUser:$user" -logfile $InfoLog 
        Write-Log -message "$(Get-date)::::Adding databsae to AG Initiated::::" -logfile $InfoLog
        Write-Log -message "$(Get-date)::::Server Name:$servername::::" -LogFile $InfoLog
        Write-Log -message "$(Get-date)::::Database Name:$database::::" -LogFile $InfoLog
        import-module sqlserver
        . C:\Users\sprathi\PS_Scripting\BackupTool_PS\Backup-MT_SQLDB.ps1
        . C:\Users\sprathi\PS_Scripting\BackupTool_PS\Restore-MT_SQLDB.ps1
        $path = "SQLSERVER:\SQL\$servername\AvailabilityGroups\"
        $AG = Get-ChildItem $path
        $AGName = $AG.Name
        $primaryserver= $AG.PrimaryReplicaServerName
        $AG = Get-ChildItem "SQLSERVER:\SQL\$primaryserver\AvailabilityGroups\"
        $Roles = $AG.AvailabilityReplicas
        $secondaryserver = $Roles.name | Where-Object { $_ -ne $primaryserver }
        $message=$Roles | Out-String
        Write-host $message -ForegroundColor DarkMagenta
        Write-Log -Message "$(Get-date)::::AG Information::::" -LogFile $InfoLog
        Write-log -Message $message -LogFile $InfoLog
        $primarypath = "SQLSERVER:\SQL\$primaryserver\AvailabilityGroups\$AGName"
        $secondarypath = "SQLSERVER:\SQL\$secondaryserver\AvailabilityGroups\$AGName"
        $addprimary = { Add-SqlAvailabilityDatabase -Path $primarypath -Database $database }
        $addsecondary = { Add-SqlAvailabilityDatabase -Path $secondarypath -Database $database}
        $primaryHost = $primaryserver.split('\').item(0)
        $secondaryHost =$secondaryserver.split('\').item(0)
        $primInsta= Get-ChildItem "SQLSERVER:\SQL\$primaryHost"
        $secInsta=Get-ChildItem "SQLSERVER:\SQL\$secondaryHost"
        $primBkpDir= $primInsta.backupdirectory
        $secBkpDir= $secInsta.backupdirectory
        $AGprimBkpDir = -join($primBkpDir,"\Add_MT_AG_DB_",(Get-Date).tostring("yyyyMMdd_hhmmss"),'\')
        $AGsecBkpDir = -join($secBkpDir,"\Add_MT_AG_DB_",(Get-Date).tostring("yyyyMMdd_hhmmss"),'\')
        Write-Log -Message "$(Get-date)::::Location of backups::::" -LogFile $InfoLog
        Write-log -Message "$AGprimBkpDir`n$AGsecBkpDir" -LogFile $InfoLog
        $PrimDBS = get-sqldatabase -serverinstance $primaryserver
        $PrimNOAGDBS = $PrimDBS | Select-Object Name, status, AvailabilityGroupName | Where-Object { $_.name -eq $database }
        $SecDBS = get-sqldatabase -ServerInstance $secondaryserver
        $SecNOAGDBS = $SecDBS | Select-Object Name, status, AvailabilityGroupName | Where-Object { $_.name -eq $database }
        Write-Log -Message "$(Get-date)::::Database $Database AG information::::" -LogFile $InfoLog
        $message=$PrimNOAGDBS | Out-String
        Write-Log -Message $message -LogFile $InfoLog
        $message=$SecNOAGDBS | Out-String
        Write-Log -Message $message -LogFile $InfoLog
        if (!($PrimNOAGDBS.Name) ) {
            if (!!($SecNOAGDBS.Name)) {
                Write-Host "====Database doesnot exists on Primary:$primaryserver but exists on Secondary:$secondaryserver.`nRestoring Database from Secondary:$secondaryserver to $primaryserver====" -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::Database doesnot exists on Primary:$primaryserver but exists on Secondary:$secondaryserver.`nRestoring Database from Secondary:$secondaryserver to $primaryserver" -LogFile $InfoLog
                $backupinfo =Backup-MT_SQLDB -backupserver $secondaryserver -backupdatabase $database -Type FULL -backuplocation $AGprimBkpDir
                $backupinfo | out-string | Write-Host -ForegroundColor DarkMagenta
                $message = $backupinfo | out-string
                Write-Log -Message $message -LogFile $InfoLog
                $Restorepath=$backupinfo.uncpath.replace($backupinfo.backupfile,"") 
                $Restoreinfo =Restore-MT_SQLDB -RestoreServerName $primaryserver -Restoredatabase $database -backuplocation $Restorepath -Recovery
                $message = $restoreinfo | out-string
                Write-Host $message -ForegroundColor DarkMagenta 
                Write-Log -Message $message -LogFile $InfoLog  
                Write-Host "====Adding Database $database on Primary:$primaryserver in AG:$AGNAME=====" -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::Adding Database $database on Primary:$primaryserver in AG:$AGNAME"-LogFile $InfoLog
                &$addprimary
                Write-Log -Message "$(Get-date)::::Making Database:$database ready for on Secondary:$secondaryserver" -LogFile $InfoLog
                $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type FULL -backuplocation $AGprimBkpDir
                $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type log -backuplocation $AGprimBkpDir
                $message=$backupinfo | out-string
                Write-Host $message  -ForegroundColor DarkMagenta
                $Restorepath=$backupinfo.uncpath.replace($backupinfo.backupfile,"")
                $Restoreinfo =Restore-MT_SQLDB -RestoreServerName $secondaryserver -Restoredatabase $database -backuplocation $Restorepath -Replace
                $message=$restoreinfo | out-string
                Write-Host $message -ForegroundColor DarkMagenta
                Write-Host "====Adding Database $database on Secondary:$secondary in AG:$AGNAME=====" -ForegroundColor DarkMagenta
                &$addsecondary
                $message= $AG.AvailabilityDatabases | Out-String 
                Write-Host $message -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::`n$message" -LogFile $InfoLog
            }
            elseif (!($SecNOAGDBS.Name)) {
                Write-Host "====Database doesnot exists on Primary Server: $primaryserver and $secondaryserver====" -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::Database doesnot exists on Primary Server: $primaryserver and $secondaryserver" -LogFile $InfoLog
                Write-Log -Message "$(Get-date)::::Taking Input from user for Source Server for Backup to restore on Primary" -LogFile $InfoLog
                Write-Host "====`nDo you want to restore database from another server?`nIf Yes Please enter Servername or else Please Press Enter:"
                $backupserver=Read-Host "ServerName:"
                $backupdatabase=Read-Host "DatabaseName:"
                Write-Log -Message "$(Get-date)::::SourceServer:$backupserver,Database:$backupdatabase" -LogFile $InfoLog
                if (!($backupserver)) {
                Write-Host "====Cannot Add database into AG as database doesnot exists on Primary: $primaryserver or on Secondary:$secondaryserver====" -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::Cannot Add database into AG as database doesnot exists on Primary: $primaryserver or on Secondary:$secondaryserver and no source server was entered." -LogFile $InfoLog
                Write-Log -Message "$(Get-date)::::Please Restore database on atleast one of the AG Node:::::" -LogFile $InfoLog
                Write-Log -Message "$(Get-date)::::Exiting script!!!::::" -LogFile $InfoLog
                Break
                }   
                else{
                Write-Host "====Performing Backup and restore from $backupserver,$backupdatabase on $primaryserver====" -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::Performing Backup and restore from $backupserver,$backupdatabase on $primaryserver" -LogFile $InfoLog
                $backupinfo = Backup-MT_SQLDB -backupserver $backupserver -backupdatabase $backupdatabase 
                $message=$backupinfo | out-string 
                Write-Host $messge -ForegroundColor DarkMagenta 
                Write-Log -Message $message -LogFile $InfoLog
                $restoreinfo = Restore-MT_SQLDB -RestoreServerName $primaryserver -Restoredatabase $database -backuplocation $backupinfo.uncpath -Recovery
                $message=$restoreinfo | out-string 
                Write-Host $message -ForegroundColor DarkMagenta
                Write-Log -Message $message -LogFile $InfoLog
                Write-Host "====Adding Database $database on Primary:$primaryserver in AG:$AGNAME=====" -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::Adding Database $database on Primary:$primaryserver in AG:$AGNAME" -LogFile $InfoLog
                &$addprimary
                Write-Log -Message "$(Get-date)::::Performing backup of Primary on to secondary" -LogFile $InfoLog
                $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type FULL -backuplocation $AGprimBkpDir
                $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type log -backuplocation $AGprimBkpDir
                $message=$backupinfo | out-string 
                Write-Host $message -ForegroundColor DarkMagenta
                Write-log -Message $message -LogFile $InfoLog
                $Restorepath=$backupinfo.uncpath.replace($backupinfo.backupfile,"")
                $Restoreinfo =Restore-MT_SQLDB -RestoreServerName $secondaryserver -Restoredatabase $database -backuplocation $Restorepath -Replace
                $message=$restoreinfo | out-string
                Write-Host $message -ForegroundColor DarkMagenta
                Write-log -Message $message -LogFile $InfoLog
                Write-Host "====Adding Database $database on Secondary:$secondaryserver in AG:$AGNAME=====" -ForegroundColor DarkMagenta
                Write-log -Message "$(Get-date)::::Adding Database $database on Secondary:$secondaryserver in AG:$AGNAME" -LogFile $InfoLog
                &$addsecondary
                $message=$AG.AvailabilityDatabases | Out-String 
                Write-Host $message -ForegroundColor DarkMagenta
                Write-Log -Message $message -LogFile $InfoLog
                }

            } 
        }    
        elseif (!($PrimNOAGDBS.AvailabilityGroupName)) {
            Write-Host "====Database exists on Primary: $primaryserver but not part of AG: AGNAME====" -ForegroundColor DarkMagenta
            Write-Log -Message "$(Get-date)::::Database exists on Primary: $primaryserver but not part of AG: AGNAME" -LogFile $InfoLog
            Write-Host "====Adding Database $database on Primary:$primaryserver in AG:$AGNAME=====" -ForegroundColor DarkMagenta
            Write-Log -Message "$(Get-date)::::Adding Database $database on Primary:$primaryserver in AG:$AGNAME" -LogFile $InfoLog
            &$addprimary
            if (!($SecNOAGDBS.Name)) {
                Write-Host "====Database doesnot exists on Secondary: $secondaryserver, Restoring from Primary:$primaryserver" -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::Database doesnot exists on Secondary: $secondaryserver, Restoring from Primary:$primaryserver" -LogFile $InfoLog
                Write-Log -Message "$(Get-date)::::Making Database:$database ready for on Secondary:$secondaryserver" -LogFile $InfoLog
                $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type FULL -backuplocation $AGprimBkpDir
                $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type log -backuplocation $AGprimBkpDir
                $message=$backupinfo | outstring 
                Write-Host $message -ForegroundColor DarkMagenta  
                Write-log -Message $message -LogFile $InfoLog
                $Restorepath=$backupinfo.uncpath.replace($backupinfo.backupfile,"")
                $Restoreinfo =Restore-MT_SQLDB -RestoreServerName $secondaryserver -Restoredatabase $database -backuplocation $Restorepath -Replace
                $message=$restoreinfo |out-string 
                Write-Host $message -ForegroundColor DarkMagenta   
                Write-log -Message $message -LogFile $InfoLog
                Write-Host "====Adding Database $database on Secondary:$secondaryserver in AG:$AGNAME=====" -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::Adding Database $database on Secondary:$secondaryserver in AG:$AGNAME" -LogFile $InfoLog
                &$addsecondary
                $message=$AG.AvailabilityDatabases | Out-String 
                Write-Host $message -ForegroundColor DarkMagenta
                Write-log -Message $message -LogFile $InfoLog
            }
            elseif (!($SecNoAGDBS.AvailabilityGroupName)) {
                Write-host "====Database exists on Secondary but not part of AG. Attempting to add database into AG Group $AGNAME====" -ForegroundColor DarkMagenta
                Write-Log -Message "$(Get-date)::::Database exists on Secondary but not part of AG. Attempting to add database into AG Group $AGNAME" -LogFile $InfoLog
                if ($SecNOAGDBS.Status -ne "Restoring") {
                    Write-Host "====Database is not in restoring state on secondry $secondaryserver====" -ForegroundColor DarkMagenta
                    Write-Log -Message "$(Get-date)::::Database is not in restoring state on secondry $secondaryserver" -LogFile $InfoLog
                    Write-Host "====Restoring Primary database Full and Log on secondary====" -ForegroundColor DarkMagenta
                    Write-Log -Message "$(Get-date)::::Restoring Primary database Full and Log on secondary====" -LogFile $InfoLog
                    $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type FULL -backuplocation $AGprimBkpDir
                    $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type log -backuplocation $AGprimBkpDir
                    $message=$backupinfo | out-string 
                    Write-host $message -ForegroundColor DarkMagenta 
                    Write-log -Message $message -LogFile $InfoLog
                    $Restorepath=$backupinfo.uncpath.replace($backupinfo.backupfile,"")
                    $Restoreinfo =Restore-MT_SQLDB -RestoreServerName $secondaryserver -Restoredatabase $database -backuplocation $Restorepath  -Replace
                    $message=$restoreinfo | out-string 
                    Write-Host $message -ForegroundColor DarkMagenta
                    Write-log -Message $message -LogFile $InfoLog
                    Write-Host "====Adding Database $database on Secondary:$Secondaryserver in AG:$AGNAME=====" -ForegroundColor DarkMagenta
                    Write-log -Message "$(Get-date)::::Adding Database $database on Secondary:$Secondaryserver in AG:$AGNAME" -LogFile $InfoLog
                    &$addsecondary
                    $message=$AG.AvailabilityDatabases | Out-String 
                    Write-Host $message -ForegroundColor DarkMagenta
                    Write-log -Message $message -LogFile $InfoLog
                    
                }
            }
        }
           else {
                Write-Host "====Database exists on Primary and Already Part of AG. Adding database $database to Secondary====" -ForegroundColor DarkMagenta
                Write-log -Message "$(Get-date)::::Database exists on Primary and Already Part of AG. Adding database $database to Secondary" -LogFile $InfoLog
                if (!($SecNOAGDBS.Name)) {
                Write-Host "====Database doesnot exists on Secondary: $secondaryserver, Restoring from Primary:$primaryserver" -ForegroundColor DarkMagenta
                Write-log -Message "$(Get-date)::::Database doesnot exists on Secondary: $secondaryserver, Restoring from Primary:$primaryserver" -LogFile $InfoLog
                $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type FULL -backuplocation $AGprimBkpDir
                $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type log -backuplocation $AGprimBkpDir
                $message=$backupinfo | out-string  
                Write-Host $message -ForegroundColor DarkMagenta
                Write-log -Message $message -LogFile $InfoLog
                $Restorepath=$backupinfo.uncpath.replace($backupinfo.backupfile,"")
                $Restoreinfo =Restore-MT_SQLDB -RestoreServerName $secondaryserver -Restoredatabase $database -backuplocation $Restorepath -Replace
                $message=$restoreinfo | out-string  
                Write-Host $message -ForegroundColor DarkMagenta
                Write-log -Message $message -LogFile $InfoLog
                Write-host "====Attempting to add Database $database on Secondary: $secondaryserver===="
                Write-log -Message "$(Get-date)::::Attempting to add Database $database on Secondary: $secondaryserver" -LogFile $InfoLog
                &$addsecondary
                $message=$AG.AvailabilityDatabases | Out-String  
                Write-Host $message -ForegroundColor DarkMagenta
                Write-log -Message $message -LogFile $InfoLog
                }
                elseif (!($SecNoAGDBS.AvailabilityGroupName)) {
                Write-host "====Database exists on Secondary but not part of AG. Attempting to add database into AG Group $AGNAME====" -ForegroundColor DarkMagenta
                Write-log -Message "$(Get-date)::::Database exists on Secondary but not part of AG. Attempting to add database into AG Group $AGNAME" -LogFile $InfoLog
                if ($SecNOAGDBS.Status -ne "Restoring") {
                    write-host "====Database is not in restoring state on secondry $secondaryserver====" -ForegroundColor DarkMagenta
                    Write-log -Message "$(Get-date)::::Database is not in restoring state on secondry $secondaryserver" -LogFile $InfoLog
                    Write-Host "====Restoring Primary database Full and Log on secondary====" -ForegroundColor DarkMagenta
                    Write-log -Message "$(Get-date)::::Restoring Primary database Full and Log on secondary" -LogFile $InfoLog
                    $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type FULL -backuplocation $AGprimBkpDir
                    $backupinfo =Backup-MT_SQLDB -backupserver $primaryserver -backupdatabase $database -Type log -backuplocation $AGprimBkpDir
                    $message=$backupinfo | out-string  
                    Write-Host $message -ForegroundColor DarkMagenta
                    Write-log -Message $message -LogFile $InfoLog
                    $Restorepath=$backupinfo.uncpath.replace($backupinfo.backupfile,"")
                    $Restoreinfo =Restore-MT_SQLDB -RestoreServerName $secondaryserver -Restoredatabase $database -backuplocation $Restorepath  -Replace
                    $restoreinfo | out-string  
                    Write-Host $message  -ForegroundColor DarkMagenta
                    Write-log -Message $message -LogFile $InfoLog
                    &$addsecondary
                    $message=$AG.AvailabilityDatabases | Out-String 
                    Write-Host $message -ForegroundColor DarkMagenta
                    Write-log -Message $message -LogFile $InfoLog
                }
                else {
                    Write-Host "====Adding Database $database on Secondary:$secondryserver in AG:$AGNAME=====" -ForegroundColor DarkMagenta
                    Write-log -Message "$(Get-date)::::Adding Database $database on Secondary:$secondryserver in AG:$AGNAME" -LogFile $InfoLog
                    &$addsecondary
                    $message=$AG.AvailabilityDatabases | Out-String 
                    Write-Host $message -ForegroundColor DarkMagenta
                    Write-log -Message $message -LogFile $InfoLog
                }
            }
        }        
        return $AG.AvailabilityDatabases
    }
        catch {
        Write-Host $_.Exception.Message -BackgroundColor DarkRed
            }
        finally {
        $Error.Clear()
        }

}


