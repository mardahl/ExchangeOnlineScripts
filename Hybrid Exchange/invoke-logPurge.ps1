<#
.SYNOPSIS
  Quick script to cleanup excess logging on an Exchange server purely used for Hybrid Exchange Management.
  
.DESCRIPTION
  This script can be run on a daily scheduled task as SYSTEM, and will cleanup the log files that Exchange 2013+ creates during normal operations.
  If you care about debugging, you should not be so quick to purge all these logs.
  
.OUTPUTS
  Creates an transcript of the last run in F:\scripts\lastcleanupoutput.txt - change this in the begining of the script code.
.NOTES
  Credits: Original script found here: https://www.alitajran.com/cleanup-logs-exchange-2013-2016-2019/
  Author: Michael Mardahl
  Twitter: @michael_mardahl
  Blog: www.msendpointmgr.com
  
.DISCLAIMER
  Use of this script is entirely up to your discression, the author takes no responsability for anything it does - test and evaluate on your own.
#>
#Requires -RunAsAdministrator

# Set the age in days that log are retained. Anything older will be deleted.
$days = 2

# Log file paths
$IISLogPath = "C:\inetpub\logs\LogFiles\"
$ExchangeLogPath = "f:\Exchange Server\V15\Logging\"
$ETLLogPath = "f:\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\ETLTraces\"
$ETLLogPath2 = "f:\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\Logs\"
$logOutputFile = "f:\scripts\lastcleanupoutput.txt"

# Start transcript log output
Start-Transcript $logOutputFile -Force

#region functions

Function CleanLogfiles($TargetFolder) {
    #Function that cleans out Exchange related log files in the TargetFolder and all subfolders
    Write-Host "INFO: Processing $TargetFolder"

    if (Test-Path $TargetFolder) {
        $Now = Get-Date
        $LastWrite = $Now.AddDays(-$days)
        $Files = Get-ChildItem $TargetFolder -Recurse | Where-Object { $_.Name -like "*.log" -or $_.Name -like "*.blg" -or $_.Name -like "*.etl" } | Where-Object { $_.lastWriteTime -le "$lastwrite" } | Select-Object FullName  
        foreach ($File in $Files) {
            $FullFileName = $File.FullName  
            Write-Host "INFO: Deleting file $FullFileName" 
            Remove-Item $FullFileName -ErrorAction SilentlyContinue | out-null
        }
    }
    Else {
        Write-Host "ERROR: The folder $TargetFolder doesn't exist! Check the folder path!"
    }
}

#endregion functions

#region execute

CleanLogfiles($IISLogPath)
CleanLogfiles($ExchangeLogPath)
CleanLogfiles($ETLLogPath)
CleanLogfiles($ETLLogPath2)

Stop-Transcript

#endregion execute
