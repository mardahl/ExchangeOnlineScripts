 #Script by github.com/mardahl to inject new DMARC vendor into existing records, to avoid disrupting existing work with DMARC.
#NB: the script will generate DMARC DNS values for domains without a DMARC policy and set it as none, the same goes for invalid records.

Start-Transcript .\lastrunLog$(get-date -format ddMMyyy).txt -Force
$output = ".\output$(get-date -format ddMMyyy).txt"

#region declarations

#enter your desired new RUA mail
$newRUA = "xxxxx@ag.eu.dmarcian.com"

#options to remove other elements of the policy
$removeRUF = $true #most systems don't send RUF, so best get rid of it because of PII.
$removeFO = $true #usually only used if you know exactly what you are doing.


#list of domains to process, (only one per line)
$domains = @"
iphase.dk
apento.com
microsoft.com
google.com
github.com
"@ -split "`r`n"

#filtering for duplicates just in case.
$domains = $domains  | sort | Get-Unique

foreach ($dom in $domains){
    Write-Host ""
    $dompad = $(($dom + ".").PadRight(32))
    try {
        $dmarc = Resolve-DnsName "_dmarc.$dom" -Type TXT -ErrorAction SilentlyContinue
        if (!$dmarc.Strings){
            throw "no value in $dom"
        } elseif (($dmarc.Strings).ToLower() -notlike "v=dmarc1*"){
            throw "invalid value in $dom"
        } else {
            if ($dmarc.Strings -like "*$newRUA*"){
                Write-Host "_dmarc.$dom already has the new RUA (skipping):" -ForegroundColor Red
                Write-Host "Value       : $($dmarc.Strings)"  -ForegroundColor DarkGray
                continue
            }
            else {
                #Generating new DMARC values array
                $newValueArray = $dmarc.Strings -split ";"
                #find RUA index
                $ruaIndex = ""
                foreach ($item in $newValueArray){
                    $index = $newValueArray.IndexOf($item)
                    if ($item -ilike " rua=*"){
                        $ruaIndex = $index
                    }
                }
                #find RUF index
                $rufIndex = ""
                foreach ($item in $newValueArray){
                    $index = $newValueArray.IndexOf($item)
                    if ($item -ilike " ruf=*"){
                        $rufIndex = $index
                    }
                }
                #find FO index
                $foIndex = ""
                foreach ($item in $newValueArray){
                    $index = $newValueArray.IndexOf($item)
                    if ($item -ilike " fo=*"){
                        $foIndex = $index
                    }
                }
                
                #add new policy

                #replace RUA
                $newValueArray[$ruaIndex] = " rua=mailto:$newRUA"
                #Remove RUF
                if($removeRUF){
                    $newValueArray = $newValueArray | Where-Object { $_ -ne $newValueArray[$rufIndex] }
                }
                #Remove FO
                if($removeFO){
                    $newValueArray = $newValueArray | Where-Object { $_ -ne $newValueArray[$foIndex] }
                }
                #Create new DNS record
                $newValue = $newValueArray -join ";"
            }

        }
        Write-Host "$dom currently has the following DMARC policy:" -ForegroundColor Cyan
        Write-Host "Current Value   : $($dmarc.Strings)" -ForegroundColor DarkGray
        Write-Host "$dom DNS needs to be updated - Please replace current record with:" -ForegroundColor Yellow
        $msg = "$dom,TXT,_dmarc,$newValue;,Change value"
        Write-Host $msg
        $msg | Out-File -FilePath $output -Append
    } catch {
        if($_ -like "*no value*"){
            Write-Host "$dom currently has NO DMARC policy:" -ForegroundColor Cyan
            $newValue = "v=DMARC1; p=none; rua=mailto:$newRUA;"
            $msg = "$dom,TXT,_dmarc,$newValue,Add"
            Write-Host $msg
            $msg | Out-File -FilePath $output -Append
        } elseif($_ -like "*invalid*"){
            Write-Host "$dom currently has the following INVALID DMARC policy:" -ForegroundColor Cyan
            Write-Host "Current Value   : $($dmarc.Strings)" -ForegroundColor DarkGray
            Write-Host "$dom DNS needs to be fixed - Please replace current record with:" -ForegroundColor Yellow
            $newValue = "v=DMARC1; p=none; rua=mailto:$newRUA;"
            $msg = "$dom,TXT,_dmarc,$newValue,Change invalid record"
            Write-Host $msg
            $msg | Out-File -FilePath $output -Append
        } else {
        write-error $_
        }
        continue
    }
    
}
notepad.exe $output
Stop-Transcript 
