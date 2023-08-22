#Script to be executed on local exchange servers management console.
#Adds a target domain for mailboxes that did not get one during the run of the hybrid configuration wizard, due to them having e-mail address policy processing disabled.


# Fetch all mailboxes
$mailboxes = Get-Mailbox -ResultSize Unlimited

# Define the target domain
$targetDomain = "xxxxxxx.mail.onmicrosoft.com"

#generate random suffix for target alias, so to avoid conflicts.
$random = (Get-Date).Ticks % 36 -as [char]
$random += (Get-Random -Minimum 10 -Maximum 36) -as [char]
$random += (Get-Random -Minimum 10 -Maximum 36) -as [char]
$random += (Get-Random -Minimum 10 -Maximum 36) -as [char]

# Loop through each mailbox and check/add the proxyAddress
foreach ($mailbox in $mailboxes) {
    $hasProxyAddress = $false

    # Check if the mailbox has a proxyAddress with the target domain
    foreach ($proxyAddress in $mailbox.EmailAddresses) {
        if ($proxyAddress.PrefixString -eq "smtp" -and $proxyAddress.AddressString -like "*@$targetDomain") {
            $hasProxyAddress = $true
            break
        }
    }

    # If missing, add the proxyAddress with the target domain
    if (-not $hasProxyAddress) {
        $alias = $mailbox.Alias
        $newProxyAddress = "smtp:$($alias)-$random@$targetDomain"
        $mailbox.EmailAddresses += $newProxyAddress
        Set-Mailbox -Identity $mailbox.Identity -EmailAddresses $mailbox.EmailAddresses
        Write-Host "Added proxyAddress $newProxyAddress to $($mailbox.DisplayName)"
    }
}
