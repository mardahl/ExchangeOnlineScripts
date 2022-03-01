<#
.SYNOPSIS
    Scans list of domains for DMARC, SFP and Office 365 DKIM records.
.DESCRIPTION
    This script will give you a CSV and nice HTML output for easy overview of multiple domains DMARC, SPF and Office 365 DKIM status.
    It will aid you in gaining a nice overview for getting to the goal of DMARC reject policy on all your domains.
.INPUTS
    None
    Just have a txt file called domains.txt in the same directory as the script, with one domain per line in the file.
.NOTES
    Version       : 1.3
    Author        : Michael Mardahl
    Twitter       : @michael_mardahl
    Blogging on   : www.msendpointmgr.com
    Creation Date : 19 February 2022
    Updated Date  : 01 March 2022
    Purpose/Change: Added progress output instead of text. added info output to log instead of screen.
    License       : MIT (Leave author credits)
.EXAMPLE
    Execute script
    .\Invoke-DMARCReport.ps1
    (Needs to be executed interactively)
#>

#region declarations

#Output to CSV location
$resultOutput = ".\DMARCScanResults-$(get-date -format ddMMyyy)" # Do NOT define file extention as several will be used by the script!

#get list of domains to process from this file
$domainFile = Get-Content .\domains.txt  #multiple domains one per line

#DNS server (should not be local DNS to avoid split brain DNS errors)
$DNSServer = "1.1.1.1" #CloudFlare DNS One One One One is default

#Progressbar enabled. Set as "SilentlyContinue" to disable
$ProgressPreference = "Continue"

#endregion declarations

#region execute

#log execution to file
Start-Transcript ".\Invoke-DMARCReport_ExecutionLog-$(get-date -format ddMMyyy).txt" -Force

#fix possible duplicates and sort domains
$domains = $domainFile  | sort | Get-Unique

#Array for holding results
$results = @()

#progress bar counter
$i = 0

#process domains
foreach ($domain in $domains){
    #trim whitespace
    $dom = $domain.Trim()
    #main progress
    Write-Progress -Id 1 -Activity "Scanning DNS records" -Status "$([math]::Round($i/$domains.count*100))% Complete:" -PercentComplete $([math]::Round($i/$domains.count*100))
    #sub progress
    Write-Progress -Id 2 -Activity "$dom" -Status "0% Complete:" -CurrentOperation "DMARC" -PercentComplete 0 -ParentId 1

    $dompad = $(($dom + ".").PadRight(36))
    
  
        $dmarc = Resolve-DnsName "_dmarc.$dom" -Server $DNSServer -Type TXT -ErrorAction SilentlyContinue
        if (!$dmarc.Strings){   
            Write-Information "_dmarc.$dompad is missing DMARC!"
            $DMARCRecordValue = 'N/A' 
            $DMARCRecordPolicy = 'N/A'
        } else {
            Write-Information "_dmarc.$dompad $($dmarc.Strings)"
            $DMARCRecordValue = [string]$dmarc.Strings 
            if($DMARCRecordValue -ilike '*p=none;*'){
                $DMARCRecordPolicy = "none"
            } elseif($DMARCRecordValue -ilike '*p=quarantine;*'){
                $DMARCRecordPolicy = "quarantine"
            } elseif($DMARCRecordValue -ilike '*p=reject;*'){
                $DMARCRecordPolicy = "reject"
            } else {
                $DMARCRecordPolicy = "Error"
            }
        }
    
    Write-Progress -Id 2 -Activity "$dom" -Status "25% Complete:" -CurrentOperation "SPF" -PercentComplete 25 -ParentId 1

        $spf = Resolve-DnsName $dom -Server $DNSServer -Type txt -ErrorAction SilentlyContinue | where strings -Like "v=spf1*"
        if (!$spf.Strings){   
            Write-Information "$dompad is missing SPF!"
            $SPFRecordValue = 'N/A'
            $SPFRecordPolicy = 'N/A'
        } else {
            Write-Information "$dompad $($spf.Strings)"
            $SPFRecordValue = [string]$spf.Strings
            if($SPFRecordValue -ilike "*`-all"){
                $SPFRecordPolicy = "Fail"
            } elseif($SPFRecordValue -ilike "*`~all"){
                $SPFRecordPolicy = "SoftFail"
            } elseif($SPFRecordValue -ilike "*`?all"){
                $SPFRecordPolicy = "Neutral"
            } elseif($SPFRecordValue -ilike "*`+all"){
                $SPFRecordPolicy = "Pass"
            } else {
                $SPFRecordPolicy = "Error"
            }
        }

    Write-Progress -Id 2 -Activity "$dom" -Status "50% Complete:" -CurrentOperation "DKIM o365" -PercentComplete 50 -ParentId 1

        $o365DKIM = Resolve-DnsName "selector1._domainkey.$dom" -Server $DNSServer -Type CNAME -ErrorAction SilentlyContinue
        if (-not ($o365DKIM.NameHost -like "*.onmicrosoft.com")){   
            Write-Information "$dompad does not have an Office 365 DKIM selector defined."
            $DKIMRecordExists = $false
        } else {
            Write-Information "selector1._domainkey.$dompad $($o365DKIM.NameHost)"
            $DKIMRecordExists = $true
        }

    Write-Progress -Id 2 -Activity "$dom" -Status "75% Complete:" -CurrentOperation "Finalizing" -PercentComplete 75 -ParentId 1

        #add results to array as custom object
        $results += [PSCustomObject]@{
            'Domain' = $dom
            'DMARCRecordExists' = $(if($DMARCRecordValue -eq 'N/A'){$false} else {$true})
            'DMARCRecordValue' = [string]$DMARCRecordValue
            'DMARCRecordPolicy' = [string]$DMARCRecordPolicy
            'O365DKIMExists' = $DKIMRecordExists
            'SPFRecordExists' = $(if($SPFRecordValue -eq 'N/A'){$false} else {$true})
            'SPFRecordValue' = [string]$SPFRecordValue
            'SPFRecordPolicy' = [string]$SPFRecordPolicy
           
        }

    #Attempt to avoid rate limiting for DNS - decrease "divisible by" number to adjust.
    if(($i -ne 0) -and ($i%100) -eq 0){
        Write-Progress -Id 2 -Activity "$dom" -Status "100% Complete:" -CurrentOperation "Done! - Pausing for 10 seconds to avoid rate limiting." -PercentComplete 100 -ParentId 1
        Start-Sleep -Seconds 10
    } else {
        Write-Progress -Id 2 -Activity "$dom" -Status "100% Complete:" -CurrentOperation "Done!" -PercentComplete 100 -ParentId 1
    }
    

    #main progress increase
    $i++

}
Write-Information "Finished processing domains"
Clear-Host
Write-Information "Generating output CSV"

#Progress for finalization
Write-Progress -Id 3 -Activity "Generating output." -Status "0% Complete:" -PercentComplete 0

$results | Export-Csv -NoTypeInformation -Path "$resultOutput.csv" -Force

#Progress for finalization
Write-Progress -Id 3 -Activity "Generating output." -Status "50% Complete:" -PercentComplete 50

Write-Information "Generating output HTML"
#Generate some nice HTML
$js=@"
<script src="https://tofsjonas.github.io/sortable/sortable.js"></script>
"@
$Header = @"
<link href="https://tofsjonas.github.io/sortable/sortable.css" rel="stylesheet" />
<style>td { border-bottom: 1px solid #333333; }
</style>
"@
$htmlParams = @{
  Title = "DMARC status report $(get-date -format ddMMMyyy)"
  Head = "$Header"
  Body = "<H1>DMARC status report</H1>"
  PreContent = "<p>$(get-date -format ddMMMyyy) - $($results.count) domains queried via DNS server $DNSServer</p>"
  PostContent = "$js"
}
#fix the output so we can sort the table
$HTML = $results | ConvertTo-Html @htmlParams 
$HTML = $HTML -replace '<TABLE>','<table class="sortable">'
$HTML = $HTML -replace '<colgroup>.*</colgroup>','<thead>'
$HTML = $HTML -replace '</th></tr>',"</th></tr></thead><tbody>"
$HTML = $HTML -replace '</table>','</tbody></table>'
$HTML = $HTML -replace '<td>True</td>','<td style="background-color:#ccffcc;">True</td>'
$HTML = $HTML -replace '<td>False</td>','<td style="background-color:#cc3300;">False</td>'
$HTML = $HTML -replace '<td>none</td>','<td style="background-color:#cc3300;">none</td>'
$HTML = $HTML -replace '<td>quarantine</td>','<td style="background-color:#ffd11a;">quarantine</td>'
$HTML = $HTML -replace '<td>reject</td>','<td style="background-color:#ccffcc;">reject</td>'
$HTML = $HTML -replace '<td>Error</td>','<td style="background-color:#ff0000;">Error</td>'
$HTML = $HTML -replace '<td>Fail</td>','<td style="background-color:#ccffcc;">Fail</td>'
$HTML = $HTML -replace '<td>SoftFail</td>','<td style="background-color:#ffd11a;">SoftFail</td>'
$HTML = $HTML -replace '<td>Neutral</td>','<td style="background-color:#cc3300;">Neutral</td>'
$HTML = $HTML -replace '<td>Pass</td>','<td style="background-color:#ff0000;">Pass</td>'
$HTML | Out-File "$resultOutput.html" -Force

#Progress for finalization
Write-Progress -Id 3 -Activity "Generating output." -Status "100% Complete:" -PercentComplete 100

Stop-Transcript
#endregion execute 
