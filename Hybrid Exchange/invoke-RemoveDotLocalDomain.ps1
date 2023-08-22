#Script to remove illegal .local domain from Exchange on-prem accounts before hybrid migration can take place.
#This script must be run in the local exchange servers management console. It will do a backup of the original data first, but this file can be quite large, so you can comment out that like if you like.

#read all mailboxes (if you have more than a few hundred, this might take some time, and you might consider doing some more advanced scripting).
$mailboxes = get-mailbox -Resultsize Unlimited

#do backup
$mailboxes | Export-Clixml .\Desktop\mailboxdata.xml

foreach ($mailbox in $mailboxes) {
write-host "Evaluating : $($mailbox.DisplayName)"
    $emailaddresses = $mailbox.emailaddresses;
    $badaddress = ""

    for ($i=0; $i -lt $emailaddresses.count; $i++) {
        #removing .local domain if found
        if ($emailaddresses[$i].smtpaddress -like "*.local") {
            $badaddress = $emailaddresses[$i];
            write-host "found $badaddress - removing" -foregroundcolor yellow
            $emailaddresses = $emailaddresses - $badaddress;
            $mailbox | set-mailbox -emailaddresses $emailaddresses;
        }
        if ($badaddress)  {
            continue
        }
    }
}
