<# .DESCRIPTION
    This script searches Azure AD for users with mismatched UserPrincipalName and Mail,
    and outputs the results as a CSV file for further investigation.

    .NOTES
    - This script assumes that the Azure AD PowerShell module is installed and you are connected with enough permissions.

    Author: Michael Mardahl (github.com/mardahl)
    Licensing: MIT
#>

 # Create an empty array to store the user data
$UserData = @()

# Populate all users in a sorted array
$Users = Get-AzureADUser -All $true
$Users = $Users | Sort-Object DisplayName | Get-Unique -AsString

# Search for users with mismatched UserPrincipalName and Mail
foreach ($User in $Users) {
    $User.DisplayName
        if ($User.UserPrincipalName -ne $User.Mail) {
            # Store the user's relevant data in a hash table
            $UserInfo = @{
                'DisplayName' = $User.DisplayName
                'UserPrincipalName' = $User.UserPrincipalName
                'Mail' = $User.Mail
                'Company' = $User.CompanyName
                'DirSyncEnabled' = $User.DirSyncEnabled
            }
        }
        # Add the user data to the array
        $UserData += New-Object PSObject -Property $UserInfo
}

# Export the user data to a CSV file
$UserData | Export-Csv -Path .\MismatchedUserDataXXX.csv -NoTypeInformation -Force 
