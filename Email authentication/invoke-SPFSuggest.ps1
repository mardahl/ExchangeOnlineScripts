#quick Script by github.com/mardahl to inject to suggest SPF records for domains that are missing them.
Start-Transcript .\lastrunLog.txt -Force
$output = ".\output$(get-date -format ddMMyyy).txt"


#one domain per line.
$domains = @"
domain.com
domain.dk
domain.co.uk
"@ -split "`r`n"

foreach ($dom in $domains){
    Write-Host ""
    $dompad = $(($dom + ".").PadRight(32))
    
        #if no SPF suggest softfail SPF
        $spf = ""
        $spf = Resolve-DnsName "$dom" -Type TXT -ErrorAction SilentlyContinue | Where-Object Strings -ILike "*spf1*"
        if (!$spf.Strings){   
            $msg = "$dompad`t    IN      TXT      `"v=spf1 ~all`""
            Write-Host $msg
            $msg | Out-File -FilePath $output -Append
            continue
        } 

        Write-Verbose "Existing SPF found for $dom" -Verbose
        Write-Verbose "$($spf.Strings)" -Verbose

        #if no MX suggest fail SPF
        $mx = ""
        $mx = Resolve-DnsName "$dom" -Type MX -ErrorAction SilentlyContinue
        if (!$mx.Name){   
            Write-Verbose "No MX record found though! Suggesting no-sending SPF." -Verbose

            $msg = "###$dompad`t    IN      TXT      `"v=spf1 -all`""
            Write-Host $msg
            $msg | Out-File -FilePath $output -Append
     
        } 

}
Stop-Transcript
