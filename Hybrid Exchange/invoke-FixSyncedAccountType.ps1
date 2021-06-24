# Quick and dirty FIX for azure ad connect synced accounts that dont show up as remote mailbox after you have fully migrated all mailboxes to exchange online and just have the local exchange server for management.
#This will for example, change a user account type from mail user to remote recipient, so that you can use the targetAddress atributte. which is required if you are relaying emails through your on-prem exchange.
#The script might need to be run twice, as it will try and make sure that the Exchange GUID is aligned between on-prem and EXO.
#This script requires exchange online powershell management module and local active directory powershell modules.
#NB: you might need to review the target address after applying, as teh normal tagert address should be alias@tenantdomain.mail.onmicrosoft.com

#Author: Michael Mardahl (github.com/mardahl)
#License: MIT

connect-exchangeonline

$UserList = get-mailbox userToFix@domain.com #(can also be a query for multiple users)

foreach ($user in $UserList) {
$upn, $tempusr = $null 
    $upn = $user.UserPrincipalName
    $tempusr = get-aduser -filter "UserPrincipalName -eq '$upn'" -Properties * #| Select Name,MSExchMailboxGuid,Username,Identity
    write-Verbose $tempusr.Name -Verbose
    write-Verbose $upn -Verbose
    if($tempusr.MSExchMailboxGuid){
        $guid = [GUID]$tempusr.MSExchMailboxGuid
        if ( $guid -eq $user.ExchangeGuid ) {

            Write-Host "EXO GUID MATCH! $guid" -ForegroundColor Green
            Write-Host "------ existing proxyAddresses"
            $tempusr.ProxyAddresses
            Write-Host "------ added proxyAddresses"
            #pause

            #Add PrimarySMTP which is required
            $SMTP = "SMTP:" + $user.PrimarySmtpAddress 
            if(-not ($tempusr.ProxyAddresses -contains "$SMTP")){
                Write-Host "Adding $SMTP" -ForegroundColor Yellow
                $tempusr | Set-ADUser -add @{ProxyAddresses="$SMTP"}
            }

            #Add legacyDN which is required
            $X500 = "X500:" + $user.legacyExchangeDN 
            if(-not ($tempusr.ProxyAddresses -contains "$X500")){
                Write-Host "Adding $X500" -ForegroundColor Yellow
                $tempusr | Set-ADUser -add @{ProxyAddresses="$X500"}
            }

            #Set mailNickname
            $alias = $user.Alias 
            if(-not ($tempusr.mailNickname)){
                Write-Host "Adding mailNickname $alias" -ForegroundColor Yellow
                pause
                $tempusr | Set-ADUser -replace @{mailNickname="$alias"}
            }

            #Set recipientDisplaytype
            
            if(-not ($tempusr.msExchRecipientDisplayType -contains "-2147483642")){
                Write-Host "Adding msExchRecipientDisplayType" -ForegroundColor Yellow
                pause
                $tempusr | Set-ADUser -replace @{msExchRecipientDisplayType="-2147483642"}
            }

            #Set msExchRecipientTypeDetails
            
            if(-not ($tempusr.msExchRecipientTypeDetails -contains "2147483648")){
                Write-Host "Adding msExchRecipientTypeDetails" -ForegroundColor Yellow
                pause
                $tempusr | Set-ADUser -replace @{msExchRecipientTypeDetails="2147483648"}
            }
            
            #Set recipientRemotetype
            
            if(-not ($tempusr.msExchRemoteRecipientType -contains "4")){          
                Write-Host "Adding msExchRemoteRecipientType" -ForegroundColor Yellow
                pause
                $tempusr | Set-ADUser -replace @{msExchRemoteRecipientType="4"}
            }

            #Set targetAddress
            $target = "SMTP:" + $user.PrimarySMTPAddress 
            if(-not ($tempusr.targetAddress)){          
                Write-Host "Adding targetAddress $target" -ForegroundColor Yellow
                pause
                $tempusr | Set-ADUser -replace @{targetAddress="$target"}
            }

        } else {
            Write-Host "FAIL MATCH!" -ForegroundColor red
            
            Write-Host $guid
            Write-Host $user.ExchangeGuid

             $Params = @{msExchMailboxGUID = [GUID]$user.ExchangeGuid;}

            $tempusr | Set-ADUser -replace $Params

        }
    } else {
        Write-Host "no guid" -ForegroundColor Yellow

         $Params = @{msExchMailboxGUID = [GUID]$user.ExchangeGuid;}
         $tempusr | Set-ADUser -replace $Params
            #pause
    }

}
