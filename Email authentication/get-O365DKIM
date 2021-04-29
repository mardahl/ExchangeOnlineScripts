# By Michael Mardahl 
# github.com/mardahl

#requires -RunAsAdministrator
Set-ExecutionPolicy Bypass -Confirm:$false -Force
Install-Module ExchangeOnlineManagement
Import-Module ExchangeOnlineManagement

try{
    Connect-ExchangeOnline -ErrorAction Stop
} catch {
    Throw "Failed to logon to Exchange Online"
}

$dkim = Get-DkimSigningConfig | Where-Object Identity -NotLike "*onmicrosoft*"

foreach($obj in $dkim){
    Write-Host "DNS records for $($obj.Domain)" -ForegroundColor Green
    Write-Output "   TYPE = CNAME"
    Write-Output "   TTL = 900"
    Write-Output "      HOSTNAME = selector1._domainkey.$($obj.Domain)"
    Write-Output "      VALUE = $($obj.Selector1CNAME)."
    Write-Output "   TYPE = CNAME"
    Write-Output "   TTL = 900"
    Write-Output "      HOSTNAME = selector2._domainkey.$($obj.Domain)"
    Write-Output "      VALUE = $($obj.Selector2CNAME)."
    Write-Output "         "
}
