####### FUNCTIONS #######


# Get services information
function Get-Windows-Services{
    
    param (
            [string]$ComputerName,
            [string]$ServiceName
          )
    try{

    # Get name of each service and its status
        if((Get-Service -Name $ServiceName -ComputerName $ComputerName).status -eq "Running"){

            $status = "Running"

        } else {

            $status = "Stopped"

        }

    } catch {

       # Write-LogError -LogPath "C:\inetpub\wwwroot\powershell\Logs\$dateLog.log" -Message “$ComputerName :- $_.Exception"
            $status = "Not Found"
        }
    return $computerName, $serviceName, $status
}

# Get CPU of each server
function Get-Windows-Cpu{

    param (
            [string]$ComputerName
          )
    try{

    # Get load percentage
    $load = (Get-WmiObject win32_processor -ComputerName $ComputerName).LoadPercentage

    

    } catch {
 
       # Write-LogError -LogPath "C:\inetpub\wwwroot\powershell\Logs\$dateLog.log" -Message “$ComputerName :- $_.Exception"
        $load = "ERROR"
    }
    return $computername, $load
}

Function Check-Website{

   param (
            [string]$SiteUrl,
            [string]$SiteKeyword
        )
     
    try{
        # Invoke instead as credential problems with sharepoint
        if($SiteUrl -like "http://arcadia*"){
            # Scans the website and searches for keyword
            $complete = (Invoke-WebRequest $SiteUrl -UseBasicParsing).content.Contains($SiteKeyword)
            $success = "OK"

        }else{
            # Creates object and uses current credentials then downloads the website to check for keyword  
            $webclient = New-Object System.Net.WebClient
            $webclient.UseDefaultCredentials = $true
            $webpage = $webclient.DownloadString($SiteUrl)

            # If keyword found set $success to OK
            if (($webpage).Contains($SiteKeyword)) { 
              
                $success = "OK"

            }else {

                $success = "Not Found"

              }
            }
        }
    catch {
           # Write-LogError -LogPath "C:\inetpub\wwwroot\powershell\Logs\$dateLog.log" -Message “$ComputerName :- $_.Exception"
            $success = "ERROR" 
    }
    return $success
}

Function Get-Windows-Uptime {

    Param (
            [string] $ComputerName
          )

        $os = Get-WmiObject win32_operatingsystem -ComputerName $ComputerName

        if ($os.LastBootUpTime) {
            
            $uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
            $limit = (Get-Date).AddDays(-7)
            if($uptime.Days -gt 7 ){
                return ("Uptime: " + $uptime.Days + "d " + $uptime.Hours + "h " + $uptime.Minutes + "m" ), $os.Description, "REBOOT"
            } else {
                return ("Uptime: " + $uptime.Days + "d " + $uptime.Hours + "h " + $uptime.Minutes + "m" ), $os.Description, "GOOD"
            
            }  

        } else {

            #Write-LogError -LogPath "C:\inetpub\wwwroot\powershell\Logs\$dateLog.log" -Message “$ComputerName :- $_.Exception"
            return "0"
         }
}

function Get-Windows-AV {

    Param (
            [String]$ComputerName
        )    
    try{
        $HKLM = [UInt32] "0x80000002"
        $registry = [WMIClass] "\\$ComputerName\root\default:StdRegProv"
        $valueName = "AVDatDate"
        $a = $registry.GetStringValue($HKLM,"SOFTWARE\WOW6432Node\McAfee\AVEngine", $valueName)
        $today = (Get-Date -Format 'yyyy/MM/dd')
        $av = [DateTime]$a.sValue
        $threshold = [DateTime]$today
        $avDate = $threshold.AddDays(-7)
        if($av -lt $avDate ){
            return "<span class='glyphicon glyphicon-remove-circle' style='color:red;' aria-hidden='true'></span>", "ERROR"
        
        } else{
            
            return "<span class='glyphicon glyphicon-ok-sign' style='color:green;' aria-hidden='true'></span>", "OK"

        }
    } catch {
        
        return "N"
        #Write-LogError -LogPath "C:\inetpub\wwwroot\powershell\Logs\$dateLog.log" -Message “$ComputerName :- $_.Exception"

    }


}


####### WINDOWS FUNCTIONS #######

####### UNIX FUNCTIONS #######


function Get-Unix-Process{

    param (
            [string]$ComputerName,
            [string]$Keyword
          )
   try{

       $ips = [System.Net.Dns]::GetHostAddresses("$ComputerName")

       if((invoke-snmpwalk -ipaddress $ips -oid 1.3.6.1.2.1.25.4.2.1.2 -community public).value.contains("$Keyword")){

        $status = "RUNNING"

       } else {

        $status = "STOPPED"

       }
   } catch {
   
        $status = "ERROR"

   }
    return $status
}

function Get-Unix-Uptime{

    param (
            [string]$ComputerName

          )
   try{

       $ips = [System.Net.Dns]::GetHostAddresses("$ComputerName")

       $unixUpTime = (Invoke-snmpget -ipaddress $ips -oid 1.3.6.1.2.1.25.1.1.0 -community public).value

   } catch {
   
       $unixUpTime = "ERROR"

   }
   return $unixUpTime
}

function Get-Unix-Cpu{

    param (
            [string]$ComputerName

          )
    try{

        $ips = [System.Net.Dns]::GetHostAddresses("$ComputerName")

        $unixCpu = 100 - (Invoke-snmpget -ipaddress $ips -oid 1.3.6.1.4.1.2021.11.11.0 -Community public).value 

    } catch {
    
        $unixCpu = "ERROR"
    
    }
    return $unixCpu
}

####### UNIX FUNCTIONS #######