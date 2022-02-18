#Script by github.com/mardahl to gather info about the state of DMARC on a list of domains
#MIT License

#region declarations

#Output to CSV location
$resultOutput = ".\DMARCResults-$(get-date -format ddMMyyy)" # Do NOT define file extention as several will be used by the script!

#get list of domains to process from this file
$domainFile = Get-Content .\bsdomains.txt  #multiple domains one per line

#DNS server (should not be local DNS to avoid split brain DNS errors)
$DNSServer = "1.1.1.1" #CloudFlare DNS One One One One is default

#endregion declarations

#region execute

#log execution to file
Start-Transcript ".\DMARCResultsExecutionLog-$(get-date -format ddMMyyy).txt" -Force

#fix possible duplicates and sort domains
$domains = $domainFile  | sort | Get-Unique

#Array for holding results
$results = @()

foreach ($domain in $domains){

    #trim whitespace
    $dom = $domain.Trim()
    Write-Host "******************************************************************"
    $dompad = $(($dom + ".").PadRight(36))
    
  
        $dmarc = Resolve-DnsName "_dmarc.$dom" -Server $DNSServer -Type txt -ErrorAction SilentlyContinue
        if (!$dmarc.Strings){   
            Write-Host "$dompad is missing DMARC!" -ForegroundColor Yellow
            $DMARCRecordValue, $DMARCRecordPolicy = 'N/A'
     
        } else {
            Write-Host "_dmarc.$dompad" $dmarc.Strings
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

        $spf = Resolve-DnsName $dom -Server $DNSServer -Type txt -ErrorAction SilentlyContinue | where strings -Like "v=spf1*"
        if (!$spf.Strings){   
            Write-Host "$dompad is missing SPF!" -ForegroundColor Yellow
            $SPFRecordValue, $SPFRecordPolicy = 'N/A'
     
        } else {
            Write-Host "$dompad" $spf.Strings
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

        $o365DKIM = Resolve-DnsName "selector1._domainkey.$dom" -Server $DNSServer -Type CNAME -ErrorAction SilentlyContinue
        if (-not ($o365DKIM.NameHost -like "*.onmicrosoft.com")){   
            Write-Host "$dompad is missing Office 365 DKIM!" -ForegroundColor Yellow
            $DKIMRecordExists = $false
     
        } else {
            Write-Host "selector1._domainkey.$dompad" $o365DKIM.NameHost
            $DKIMRecordExists = $true
        }

        #add results to hashtable as custom object
        $results += [PSCustomObject]@{
            'Domain' = $dom
            'DMARCRecordExists' = $(if($DMARCRecordValue -eq 'N/A'){$false} else {$true})
            'DMARCRecordValue' = [string]$DMARCRecordValue
            'DMARCRecordPolicy' = $DMARCRecordPolicy
            'O365DKIMExists' = $DKIMRecordExists
            'SPFRecordExists' = $(if($SPFRecordValue -eq 'N/A'){$false} else {$true})
            'SPFRecordValue' = $SPFRecordValue
            'SPFRecordPolicy' = $SPFRecordPolicy
           
        }

}

$results | Export-Csv -NoTypeInformation -Path "$resultOutput.csv" -Force

#Generate some nice HTML
$js=@"
<script src="https://tofsjonas.github.io/sortable/sortable.js"></script>
"@
$Header = @"
<link href="https://tofsjonas.github.io/sortable/sortable.css" rel="stylesheet" />
<style>td {border-bottom: 1px solid #333333;}</style>
"@
$htmlParams = @{
  Title = "DMARC status report $(get-date -format ddMMMyyy)"
  Head = "$Header"
  Body = "<H1>DMARC status report</H1>"
  PreContent = "<p>$(get-date -format ddMMMyyy)</p>"
  PostContent = "$js"
}
#fix the output so we can sort the table and have issues highlighted
$HTML = $results | ConvertTo-Html @htmlParams 
$HTML = $HTML -replace '<TABLE>','<table class="sortable">'
$HTML = $HTML -replace '<colgroup><col/><col/><col/><col/><col/><col/><col/><col/></colgroup>','<thead>'
$HTML = $HTML -replace '<th>SPFRecordPolicy</th></tr>','<th>SPFRecordPolicy</th></tr></thead><tbody>'
$HTML = $HTML -replace '</table>','</tbody></table>'
$HTML = $HTML -replace '<td>True</td>','<td style="background-color:#ccffcc;">True</td>'
$HTML = $HTML -replace '<td>False</td>','<td style="background-color:#cc3300;">False</td>'
$HTML = $HTML -replace '<td>none</td>','<td style="background-color:#cc3300;">none</td>'
$HTML = $HTML -replace '<td>quarantine</td>','<td style="background-color:#ffd11a;">quarantine</td>'
$HTML = $HTML -replace '<td>reject</td>','<td style="background-color:#ccffcc;">reject</td>'
$HTML = $HTML -replace '<td>Error</td>','<td style="background-color:#ff0000;">Error</td>'
$HTML | Out-File "$resultOutput.html" -Force


Stop-Transcript
#endregion execute
