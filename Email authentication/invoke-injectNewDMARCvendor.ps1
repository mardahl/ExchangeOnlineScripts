#Script by github.com/mardahl to inject new DMARC vendor into existing records, to avoid disrupting existing work with DMARC.
#NB: the script wont generate DMARC DNS values for domains without a DMARC policy.

Start-Transcript .\lastrunLog$(get-date -format ddMMyyy).txt -Force
$output = ".\output$(get-date -format ddMMyyy).txt"

#region declarations

#enter your desired new RUF and RUA (can be the same)
$newRUA = "dmarc-rua@domain.com"
$newRUF = "dmarc-ruf@domain.com"

#enter desired policy level (none, quarantine, reject)
$policy = "none"


#list of domains to process, (only one per line)
$domains = @"
example.com
test.com
microsoft.com
"@ -split "`r`n"

#filtering for duplicates just in case.
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
            if ($dmarc.Strings -like "*$newRUA*"){
                Write-Host "_dmarc.$dom already has the new RUA (skipping):" -ForegroundColor Red
                Write-Host "Value       : $($dmarc.Strings)"  -ForegroundColor DarkGray
                continue
            }
            else {
                #Generating new DMARC values array
                $newValueArray = $dmarc.Strings -split ";"
                #find policy indexe
                $policyIndex = ""
                foreach ($item in $newValueArray){
                    $index = $newValueArray.IndexOf($item)
                    if ($item -ilike " p=*"){
                        $policyIndex = $index
                    }
                }
                
                #add new policy

                $newValueArray[$policyIndex] = " p=$policy;"
                $newValue = $newValueArray -join ";"
            }

        }
        Write-Host "$dom currently has the following DMARC policy:" -ForegroundColor Cyan
        Write-Host "Old Value   : $($dmarc.Strings)" -ForegroundColor DarkGray
        Write-Host "$dom DNS needs to be updated - Please replace current record with:" -ForegroundColor Yellow
        $msg = "_dmarc.$dompad`t     IN      TXT      `"$newValue`""
        Write-Host $msg
        $msg | Out-File -FilePath $output -Append
    } catch {
        write-error $_
        continue
    }
    
}
notepad.exe $output
Stop-Transcript
