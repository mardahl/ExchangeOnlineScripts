#Script by mum@apento.com to change DMARC policy on existing valid records.
Start-Transcript .\lastrunLog.txt -Force
$output = ".\output$(get-date -format ddMMyyy).txt"
Write-Host "DMARC RECORDS:" | Out-File -FilePath $output

$RUA = "xxx@rua.domain.com" #must be the rUA adress that is currently in use, since we match validity based on this.

#set the policy you want to have - none,quarantine,reject
$policy = "reject"

#one domain per line.
$domains = @"
domain.com
domain.dk
domain.co.uk
"@ -split "`r`n"

#fix possible duplicates and sort domains
$domains = $domains  | sort | Get-Unique


foreach ($dom in $domains){
    Write-Host ""
    $dompad = $(($dom + ".").PadRight(32))
    try {
        $dmarc = Resolve-DnsName "_dmarc.$dom" -Type TXT -ErrorAction SilentlyContinue
        if (!$dmarc.Strings){
            throw "no value"
        } elseif (($dmarc.Strings).ToLower() -notlike "v=dmarc1*"){
            throw "invalid value"
        } else {
            if ($dmarc.Strings -notlike "*$RUA*"){
                Write-Host "_dmarc.$dom currently has no valid existing company DMARC policy (skipping):" -ForegroundColor Red
                Write-Host "Value       : $($dmarc.Strings)"  -ForegroundColor DarkGray
                continue
            }
            else {
                #Generating new DMARC value string
                $newValueArray = $dmarc.Strings -split ";"
                #find policy indexe
                $policyIndex = ""
                foreach ($item in $newValueArray){
                    $index = $newValueArray.IndexOf($item)
                    if ($item -ilike "* p=*"){
                        $policyIndex = $index
                    }
                }
                
                #add new policy

                $newValueArray[$policyIndex] = " p=$policy"
                $newValue = $newValueArray -join ";"
            }

        }
        Write-Host "$dom currently has the following DMARC policy:" -ForegroundColor Cyan
        Write-Host "Old Value   : $($dmarc.Strings)" -ForegroundColor DarkGray
        Write-Host "$dom needs to be updated - Please add:" -ForegroundColor Yellow
        $msg = "_dmarc.$dompad`t     IN      TXT      `"$newValue`""
        Write-Host $msg
        $msg | Out-File -FilePath $output -Append
    } catch {
        write-error $_
        continue
    }

}
Stop-Transcript
Get-Content $output | Out-GridView
