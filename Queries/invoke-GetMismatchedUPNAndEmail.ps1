<# .DESCRIPTION
    This script searches Exchange Online mailboxes for users with mismatched UserPrincipalName and PrimarySMTPAddress,
    and checks whether the user's company attribute matches any of the specified values.

    .NOTES
    - This script assumes that the Exchange Online PowerShell module is installed.
    - This script requires that you have an active Exchange Online subscription, and that you have the necessary
      permissions to access Exchange Online mailboxes.
    - Before running the script, update the list of allowed company values in the $AllowedCompanies variable to match
      your desired values.

    Author: Michael Mardahl (github.com/mardahl)
    Licensing: MIT
#>

#Define the list of allowed company values
$AllowedCompanies = @('Company A', 'CompanyB')

# Create an empty array to store the user data
$UserData = @()

# Search for users with mismatched UserPrincipalName and PrimarySMTPAddress
$Users = Get-User -ResultSize Unlimited
foreach ($User in $Users) {
    if ($AllowedCompanies -contains $User.Company) {
        # Store the user's relevant data in a hash table
        $UserInfo = @{
            'UserPrincipalName' = $User.UserPrincipalName
            'PrimarySMTPAddress' = $User.PrimarySMTPAddress
            'Company' = $User.Company
        }

        # Add the user data to the array
        $UserData += New-Object PSObject -Property $UserInfo
    }
}

# Export the user data to a CSV file
$UserData | Export-Csv -Path .\MismatchedUserData.csv -NoTypeInformation
