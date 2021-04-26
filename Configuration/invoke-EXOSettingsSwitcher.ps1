<#
.SYNOPSIS
    An on/off switch for Exchange Online Organization Configuration settings

.DESCRIPTION
    This script will iterate through a list of useful Exchange Online Settings, and allow the admin to turn them on or off while showing the current setting.
    Can be used as a base script for switching other simmilar settings in Microsoft 365 Powershell modules.

.INPUTS
    None

.NOTES
    Version       : 1.0a
    Author        : Michael Mardahl
    Twitter       : @michael_mardahl
    Blogging on   : www.msendpointmgr.com
    Creation Date : 26 April 2021
    Updated Date  : -
    Purpose/Change: Initial development
    License       : MIT (Leave author credits)

.EXAMPLE
    Execute script
    .\invoke-EXOSettingsSwitcher.ps1
    (Needs to be executed interactively by a user with the Exchange Administrator role)
#>
#Requires -Modules ExchangeOnlineManagement

#region declarations

#You can add more setting here if you like, all settings can be gathered using the "Get-OrganizationConfig" cmdlet with ExchangeOnline
$settings = @("SendFromAliasEnabled","OAuth2ClientProfileEnabled","AllowPlusAddressInRecipients","FocusedInboxOn")

#endregion declarations
#region execute

connect-exchangeonline -ShowBanner:$false
$welcomeArt = @"
   ____         __                      ____       ___                
  / __/_ ______/ /  ___ ____  ___ ____ / __ \___  / (_)__  ___        
 / _/ \ \ / __/ _ \/ _ ``/ _ \/ _ ``/ -_) /_/ / _ \/ / / _ \/ -_)       
/___//_\_\\__/_//_/\_,_/_//_/\_, /\__/\____/_//_/_/_/_//_/\__/        
  / __/__ / /_/ /_(_)__  ___/___/   / __/    __(_) /_____/ /  ___ ____
 _\ \/ -_) __/ __/ / _ \/ _ ``(_-<  _\ \| |/|/ / / __/ __/ _ \/ -_) __/
/___/\__/\__/\__/_/_//_/\_, /___/ /___/|__,__/_/\__/\__/_//_/\__/_/   
                       /___/            
"@
Write-Host $welcomeArt -ForegroundColor Yellow

foreach($option in $settings) {
    #Read each setting individually and allow user to choose what to do
    try {
        [bool]$currentSetting = Get-OrganizationConfig -ErrorAction Stop| Select $option -ExpandProperty $option
    } catch {
        $currentSetting = $false
    }
    Write-Host " "
    Write-Host "$option"
    #Add some readable text output
    $settingText = if ($currentSetting) {"Enabled"} Else {"Disabled"}
    Write-Host "`t ^^^^^^^^^^^^ `t is currently $settingText" 
    Write-Host " "
    Do {
        $choise = (Read-Host "Do you want to flip the switch for option: $option [y/n]?")
        if (($choise -ne "y") -and ($choise -ne "n")){
            Write-Host "Please enter (y)es or (n)o." -ForegroundColor Yellow
        }
    } While(($choise -ne "y") -and ($choise -ne "n"))
    Write-Host " "
    if($choise -eq "y") {
        #Flip the setting from true to false and vice versa
        $newSetting = if ($currentSetting) {$false} Else {$true}
        Write-Verbose "Configuring $option as $([string]$newSetting)" -Verbose
        #Define the parameter set for the option and setting
        $parameters = @{
            $option = $newSetting
        }
        Set-OrganizationConfig @parameters
        $validateSetting = Get-OrganizationConfig | Select $option -ExpandProperty $option
        Write-Verbose "The new setting of $option is: $validateSetting" -Verbose
    }

    Write-Host " "
}
#endregion execute
Disconnect-ExchangeOnline
