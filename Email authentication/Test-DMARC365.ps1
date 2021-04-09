<#
.SYNOPSIS
    Check domains for DMARC readiness with Exchange Online

.DESCRIPTION
    This script will verify the presence of the required records for using DMARC with a domain in Exchange Online.
    It's a very simple check to let you know if anything was missed on one or more domains.
    The output is sent to a GridView where it is easy to copy to a spreadsheet for further work.

.INPUTS
    None

.NOTES
    Version       : 1.4b
    Author        : Michael Mardahl
    Twitter       : @michael_mardahl
    Blogging on   : iphase.dk & www.msendpointmgr.com
    Creation Date : 02 December 2020
    Purpose/Change: Added record output
    License       : MIT (Leave author credits)

.EXAMPLE
    Execute script after modification.
    .\Test-DMARC365.ps1
    (Needs to be executed interactively)

.NOTES
    You ned to edit the here string list of domains in the "declarations" region of the script.
    If you are not familiar with here strings, please notice and keep the formatting.
    For more advanced cases, you can modify to use a CSV file.

#>

#region declarations

$domainList = @"
microsoft.com
msendpointmgr.com
apento.com
iphase.dk
"@

#endregion declarations

#region functions

#Custom function to generate object with domain specific data about DKIM, DMARC, SPF and MX
function getDomainInfo {
    [cmdletbinding()]
    param (

        [Parameter(Mandatory = $true)]
        [String]$FQDN

    )
    #Hide errors
    $prevErrPref = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"

    #Set values to not found
    $resultMX = "N/A";$resultDMARC = "N/A"; $resultDKIM = "N/A"; $resultSPF = "N/A"
    $resultMXRecord = "N/A";$resultDMARCRecord = "N/A"; $resultDKIMRecord = "N/A"; $resultSPFRecord = "N/A"

    #Testing MX, SPF, DMARC and DKIM

    #MX
    if(Resolve-DnsName $FQDN -Type MX | select NameExchange -First 1 -ExpandProperty NameExchange){

        $resultMX = "Present"
        $resultMXRecord = Resolve-DnsName $FQDN -Type MX | select NameExchange -First 1 -ExpandProperty NameExchange

    }

    #SPF
    if(Resolve-DnsName $FQDN -Type TXT | Where-Object Strings -ILike "v=spf1*"){

        $resultSPF ="Present"
        $resultSPFRecordArr = Resolve-DnsName $FQDN -Type TXT | Where-Object Strings -ILike "v=spf1*" | select Strings -ExpandProperty Strings
        $resultSPFRecord = $resultSPFRecordArr -join ""

    }

    #DMARC
    if(Resolve-DnsName "_dmarc.$FQDN" -Type TXT | Where-Object Strings -ILike "v=DMARC1*"){

        $resultDMARC = "Present"
        $resultDMARCRecord = Resolve-DnsName "_dmarc.$FQDN" -Type TXT | Where-Object Strings -ILike "v=DMARC1*" | select Strings -ExpandProperty Strings

    }

    #DKIM
    $DKIM1 = Resolve-DnsName "selector1._domainkey.$FQDN" -Type CNAME
    $DKIM2 = Resolve-DnsName "selector2._domainkey.$FQDN" -Type CNAME
    if(($DKIM1.NameHost -ilike "selector1.*") -or ($DKIM2.NameHost -ilike "selector2.*")){

        $resultDKIM = "Present"
        $resultDKIMRecord = "$($DKIM1 | select NameHost -ExpandProperty NameHost -ErrorAction SilentlyContinue) | $($DKIM2 | select NameHost -ExpandProperty NameHost -ErrorAction SilentlyContinue)"

    }

    $statusObject = [PSCustomObject]@{

        DomainName          = $FQDN
        DMARC               = $resultDMARC
        DMARCRecord         = $resultDMARCRecord
        MX                  = $resultMX
        MXRecord            = $resultMXRecord
        SPF                 = $resultSPF
        SPFRecord           = $resultSPFRecord
        DKIM                = $resultDKIM
        DKIMRecord          = $resultDKIMRecord

    }

    #Reset error messages and return object
    $ErrorActionPreference = $prevErrPref
    Return $statusObject
}

#endregion functions

#region execute

Write-Host "[INFO] Processing domains for DMARC status..."

#Array with all the domains data
[System.Collections.ArrayList]$statusArray = @()

#Iterate throguh the domains with the custom function
$domainArray = $domainList -split "`r`n"
foreach($dom in $domainArray){

    $trimDom = $dom.Trim()
    $statusArray.Add((getDomainInfo -FQDN $trimDom)) | Out-Null

}

Write-Host "[INFO] Launching GridView."
#Output to gridview (can be copied directly to spreadsheet
$statusArray | Out-GridView -Title "DMARC test result" -OutputMode Multiple

Write-Host "[INFO] Finished."

#endregion execute
