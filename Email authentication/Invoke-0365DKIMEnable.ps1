<#
.SYNOPSIS
    Enables DKIM for all domains in Office 365 Exchange Online

.DESCRIPTION
    This script will get all domains in Exchange Online and enable DKIM and rotate the key to 2048bit.

.INPUTS
    None

.NOTES
    Version       : 1.2
    Author        : Michael Mardahl
    Twitter       : @michael_mardahl
    Blogging on   : www.msendpointmgr.com
    Creation Date : 02 December 2020
    Updated Date  : 04 February 2021
    Purpose/Change: Moved from GIST
    License       : MIT (Leave author credits)

.EXAMPLE
    Execute script
    .\Invoke-O365DKIMEnable.ps1
    (Needs to be executed interactively)

#>


#region execute

try{
    Connect-ExchangeOnline -ErrorAction Stop
} catch {
    Throw "Failed to logon to Exchange Online, make sure you have installed the Exchange Online Management v2 module"
}

$dkim = Get-DkimSigningConfig

foreach($obj in $dkim){
    Write-Host "Enabling 2048-bit DKIM for $($obj.Domain)" -ForegroundColor Green
    Write-Verbose "Enable - DKIM" -Verbose
    Set-DkimSigningConfig -Identity $($obj.Domain) -Enabled $true
    if($obj.Enabled){
        Write-Verbose "Rotating key to 2048-bit" -Verbose
        Rotate-DkimSigningConfig -KeySize 2048 -Identity $($obj.Domain)
    }
    Write-Output " "
    pause
}

#endregion execute
