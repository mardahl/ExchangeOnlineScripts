<#
    .DESCRIPTION
        An example runbook which connects to Exchange Online using the Managed Identity

    .NOTES
        AUTHOR: Michael Mardahl
        LASTEDIT: Nov 7, 2021
    
    .NOTES
        On line 52 there is a filter on the command names (cmdlets) that get imported for use.
        You must adjust this to include the cmdlets you need.
        Please keep to a minimum as Automation has limited memory.

    .NOTES
        This script requires quite excessive permission to Exchange Online in order to work with a Managed Identity.
        Assignment of these permissions is done through Azure Cloud shell using the following script.
        Remember: Set the correct ObjectID of the $MSIObjectID variable before running the script.
        NB: I used Global Reader role, but you might need Exhcange Admin role depending on your needs you can change it.
        
        #Begin script
        Connect-AzureAD
        $MSIObjectID = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        $EXOServicePrincipal = Get-AzureADServicePrincipal -Filter "displayName eq 'Office 365 Exchange Online'"
        $Approle=$EXOServicePrincipal.AppRoles.Where({$_.Value -eq 'Exchange.ManageAsApp'})
        New-AzureADServiceAppRoleAssignment -ObjectId $MSIObjectID -Id $Approle[0].Id -PrincipalId $MSIObjectID -ResourceId $EXOServicePrincipal.ObjectId
        $AADRole = Get-AzureADDirectoryRole | where DisplayName -eq 'Exchange Administrator'
        Add-AzureADDirectoryRoleMember -ObjectId $AADRole.ObjectId -RefObjectId $MSIObjectID
        #End script
#>

#region declarations
$Script:tenantDomain = "xxxxxxxxxxx.onmicrosoft.com" #please endter the defualt domain of the tenant the managed identity belongs to.
#endregion declarations

#region functions
function makeMSIOAuthCred () {
    $accessToken = Get-AzAccessToken -ResourceUrl "https://outlook.office365.com/"
    $authorization = "Bearer {0}" -f $accessToken.Token
    $Password = ConvertTo-SecureString -AsPlainText $authorization -Force
    $tenantID = (Get-AzTenant).Id
    $MSIcred = New-Object System.Management.Automation.PSCredential -ArgumentList ("OAuthUser@$tenantID",$Password)
    return $MSICred
}

function connectEXOAsMSI ($OAuthCredential) {
    #Function to connect to Exchange Online using OAuth credentials from the MSI
    $psSessions = Get-PSSession | Select-Object -Property State, Name
    If (((@($psSessions) -like '@{State=Opened; Name=RunSpace*').Count -gt 0) -ne $true) {
        Write-Verbose "Creating new EXOPSSession..." -Verbose
        try {
            $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/PowerShell-LiveId?BasicAuthToOAuthConversion=true&email=SystemMailbox%7bbb558c35-97f1-4cb9-8ff7-d53741dc928c%7d%40$tenantDomain" -Credential $OAuthCredential -Authentication Basic -AllowRedirection
            $null = Import-PSSession $Session -DisableNameChecking -CommandName "*mailbox*", "*unified*" -AllowClobber
            Write-Verbose "New EXOPSSession established!" -Verbose
        } catch {
            Write-Error $_
        }
    } else {
        Write-Verbose "Found existing EXOPSSession! Skipping connection." -Verbose
    }
}
#endregion functions

#region execute
$null = Connect-AzAccount -Identity
connectEXOAsMSI -OAuthCredential (makeMSIOAuthCred)

#Do some exchange scripting here!

Get-PSSession | Remove-PSSession
#endregion execute
