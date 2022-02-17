<#
.Synopsis
Function to write log of events into a text file
.DESCRIPTION
Write log of any events\information by passing message paramter and logfile for file location.
.PARAMETER MESSAGE
simple message holder varaible of string type.
.PARAMETER Logfile
logfile location holder.
.Syntax
$LogFile ="C:\temp\BackupRestore_Log.txt"
Write-log -Message "Hi" -LogFile $LogFile
.Notes
If you are trying to use this function make sure this function powershell file is same location of your actual script location.

#>



function Write-Log 
{
param([string]$Message, [string]$LogFile)
Add-Content  $LogFile -value $Message
}




