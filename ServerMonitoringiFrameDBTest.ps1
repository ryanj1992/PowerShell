<# This script uses all the same functions as the other scripts for Priority 1 and 2.
These scripts are just split up for parallel processing to make monitoring faster.
Everything is the same, however some loops will be different and links towards the bottom.
These will be highlighted in the comments. #>

# Sets the css into a variable
$cssFile = Get-Content "$Using:ScriptRoot\css\style.css"      

# Create head tags which contains title, refresh page, CSS and bootstrap CSS
$head =  @"
    <head>
        <title>Server Report</title>
        <meta http-equiv="refresh" content="100">
        <link rel='stylesheet' href='https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css'>
            <style>
                $cssFile 
            </style>
    </head>
"@
    # Create tables and headers for each report
    $html = @"
    <table class = "table table-hover table-striped table-bordered webTable">
        <th style = "text-align: center; width: 70%; ">Application</th>
        <th style = "text-align: center; width: 30%; ">Status</th>
"@

    $errorReport = @"
    <table class = "table table-hover table-striped table-bordered webTable">
        <th style = "text-align: center; width: 70%; ">Application</th>
        <th style = "text-align: center; width: 30%; ">Status</th>
"@

    $warningReport = @"
    <table class = "table table-hover table-striped table-bordered webTable">
        <th style = "text-align: center; width: 70%; ">Application</th>
        <th style = "text-align: center; width: 30%; ">Status</th>
"@

# TLS Security bypass
[Net.ServicePointManager]::SecurityProtocol = 
[Net.SecurityProtocolType]::Tls12 -bor `
    [Net.SecurityProtocolType]::Tls11 -bor `
    [Net.SecurityProtocolType]::Tls

#$ScriptDir = Split-Path $MyInvocation.MyCommand.Path

# This imports the functions
Import-Module -Name $Using:ScriptRoot\Functions\functions.psm1 -DisableNameChecking

# Counts if application has at least 1 error/warning to display error/warning report correctly
$globalErrorCount = 0
$globalWarningCount = 0
  
    ## Priority
    write-host($_)

    # This loops through each XML file in the databases folder
    Get-ChildItem $Using:ScriptRoot\XML\Databases -Filter *.xml -Recurse | % {
    
        ## System name
        write-host($_)
        
        # Sets variables for errors and warnings on each application
        $errorStatus = 0
        $warningStatus = 0

        # Set variable for the content in XML file
        $content = [xml](Get-Content $_.FullName)

        # Access the content in the XML file with these variables
        $appName = $content.application.name
        $webName = $content.application.websites.website.url
        $unix = $content.application.unix.server.name
        $windows = $content.application.windows.server.name

        # Variable to append all html as the script goes along
        $appHTML = @()

        # Get time to measure speed of script in seconds
        $appStartTime = (Get-Date)

        # Variables for tooltips (if you hover over errors and warnings
        # on main page it will display a short description of whats wrong)
        $warningToolTip = ""
        $errorToolTip = ""

        # Start appending to appHTML (this will be added to $html at the end to include <head> etc)
        $appHTML += @"
        <body style = "background-color: darkgrey;">
            <h1 style = "text-align: center; margin-top: 120px;">$appName Report</h1>
            <div class = "container">
"@

        ############ WEBSITES #############
        <# Here the script checks if any websites are found in the XML. If so then jump into
        the if statement, if not then skip compeletly #>

        # Check if application has a website to check
        if ($webname) {
        
            # append table html for check
            $appHTML += @"
                <h4><b>Websites</b></h4>
                <div class = "row aligned-row">
                <div class = "col-md-6 box">
                <table style = 'margin-top: 20px;' class = 'table table-hover table-striped table-bordered'>
                <th style = 'text-align: center;'>Service</th>
                <th style = 'text-align: center;'>Status</th>

"@

            #Loop through each website within the XML file
            foreach ($website in $content.application.websites.website) {

                # Accessing and setting the url & name
                $url = $website.Url
                $name = $website.Name
   
                # Run function with URL and keyword as paramaters (check the functions script to see what it does)
                $urlCheck = (Check-Website -SiteURL $url -SiteKeyword $website.keyword)

                # Measure time taken to execute function
                $urlCheckTime = Measure-Command {$urlCheck}

                # Measure in miliseconds
                $urlMilliseconds = $urlCheckTime.Milliseconds

                # If statement to check what the function returns
                if ($urlCheck -eq "OK") {

                    # Append to $appHTML array above / creates a table row with the data calculated 
                    $appHTML +=   
                    "<tr>
                        <td style = 'text-align: center; width: 70%;'><a href='$url'>$name</a></td>
                        <td style = 'text-align: center; width: 30%; color: white;' class='green'>$urlCheck ($urlMilliseconds ms)</td>
                    </tr>"
                }
                else {
                    # Increment $errorStatus if website not "OK" and append to errorToolTip
                    $errorStatus++
                    $errorToolTip += "$name website down `n"

                    # Color red if error
                    $appHTML +=      
                    "<tr>
                        <td style = 'text-align: center; width: 70%;'><a href='$url'>$name</a></td>
                        <td style = 'text-align: center; width: 30%; color: white;' class='red'>$urlCheck</td>
                    </tr>"
                }
            }
            # Close table and divs
            $appHTML += "  </table>
                         </div>
                        </div>"
        }

        ############ END OF WEBSITES #############

        ############ UNIX SERVERS #############
        # This part checks if the XML has any UNIX servers it needs to check, if so then
        # the script will jump into the if statement, if not then it will skip.

        if ($unix) {

            # Append a header and row to $appHTML
            $appHTML += @"
            <h4><b>UNIX Servers</b></h4>
            <div class = "row aligned-row">

"@
            # Loop through each UNIX server in the XML file
            foreach ($unixServer in $content.application.unix.server) {

                $unixServerName = $unixServer.Name

                # Run functions against the UNIX servers (look in functions script to see what is does)
                $unixUpTime = Get-Unix-Uptime -ComputerName $unixServerName
                $unixCPU = Get-Unix-Cpu -ComputerName $unixServerName

                # Append HTML to hold data gathered (Name, Uptime)
                $appHTML += @"

                <div class = "col-md-6 box">
                    <h3 style = 'text-align: center;'>$unixServerName</h3>
                    <h5 style = 'text-align: center;'>Uptime: $unixUpTime</h5>
                    <table class = 'table table-hover table-striped table-bordered'>
                            <th style = 'text-align: center;'>CPU</th>
                            <th style = 'text-align: center;'>Load</th>

"@
                # Set CPU counter
                $unixCountCPU = 0

                # Loop through each UNIX cpu
                foreach ($processor in $unixCPU) {
                    $unixCountCPU++

                    # Check if the load of the CPU is > 95 if so make it a warning (orange)
                    if ($processor -gt 95) {
                        $warningStatus++
                        $warningToolTip += "$unixServerName has high CPU `n"

                        # Append server name and CPU information to current HTML
                        $appHTML += "
                        <tr>
                            <td style = 'width: 70%;'>CPU $unixCountCPU</td>
                            <td class = 'red' style = 'width: 30%; text-align: center; color: white;'>$processor%</td>
                        </tr>"
                    }

                    # if CPU < 95 then display green
                    else {
                        $appHTML += "
                        <tr>
                            <td style = 'width: 70%;'>CPU $unixCountCPU</td>
                            <td class = 'green' style = 'width: 30%; text-align: center; color: white;'>$processor%</td>
                        </tr>"
                    }   
                }

                # Append another HTML table for the UNIX processes
                $appHTML += @"
                        </table>
                            <table class = 'table table-hover table-striped table-bordered'>
                                <th style = 'text-align: center;'>Process</th>
                                <th style = 'text-align: center;'>Status</th>

"@
                # loop through each process in the XML file
                foreach ($unixProcess in $unixServer.processes.process) {

                    $unixProcessName = $unixProcess.Name

                    # Run function to check process is running (can be found in functions folder)
                    $unixProcessCheck = Get-Unix-Process -ComputerName $unixServerName -Keyword $unixProcessName

                    if ($unixProcessCheck -eq "Running") {

                        # Append to $appHTML make it green if equal to "Running" 
                        $appHTML +=      
                        "<tr>
                                <td style = 'width: 70%;'>$unixProcessName</td>
                                <td style = 'text-align: center; width: 30%; color: white;' class='green'>$unixProcessCheck</td>
                            </tr>"
                    }
                    else {

                        # If not running then increment error status, add to tooltip and take the HTML red
                        $errorStatus++
                        $errorToolTip += "$unixServerName process missing `n"
                        $appHTML +=      
                        "<tr>
                                <td style = 'width: 70%;'>$unixProcessName</td>
                                <td style = 'text-align: center; width: 30%; color: white;' class='red'>$unixProcessCheck</td>
                            </tr>"
                    }
                }

                # Close table tags
                $appHTML += "</table>
                                </div>"
            }

            # Close last div for UNIX servers
            $appHTML += "</div>"

        }

        ############ END OF UNIX SERVERS #############


        ############ WINDOWS SERVERS #############
        # This part checks if the XML has any windows servers it needs to check, if so then
        # the script will jump into the if statement, if not then it will skip.

        if ($windows) {
            $appHTML += "<h4><b>WINDOWS Servers</b></h4>
                     <div class = 'row aligned-row'>"

            # Variable to count the amount of servers on each row. If odd then create a new row
            $serverCount = 0

            # Loop through each computer within the XML file
            foreach ($computer in $content.application.windows.server) {
            
                # Count servers for layout
                $serverCount++
                # Set the server name and set to all capitals
                $serverName = $computer.name.ToUpper()

                # Call av function
                $av = Get-Windows-AV -ComputerName $serverName
                $aVirus = $av[0]
                # Checks if system needs AV updated
                if ($av[1] -eq "ERROR" ) {
                    $warningStatus++
                    $warningToolTip += "$serverName AV needs updated `n"
                }

                # Run Uptime & Description function
                $object = Get-Windows-Uptime -ComputerName $serverName

                $reboot = $object[2]
                $windowsDescription = $object[1]
                $windowsUpTime = $object[0]

                # Checks if system needs rebooted
                if ($reboot -eq "REBOOT") {
                    $windowsReboot = "text-align: center; color: orange;"
                }
                else {
                    $windowsReboot = "text-align: center;"
                }

                # had some problems with div alignment, therefore needed
                # this equation to make sure the HTML was straight
                if ($serverCount % 2 -eq 1 -and $serverCount -ne 1) {

                    $appHTML += "</div>
                                 <div class = 'row aligned-row'>"
        
                }

                # if $aVirus didn't go into the catch then it will return HTML for a red cross
                # or a green tick (look in the function script to see what happens)
                if ($aVirus -ne "N") {
                    $appHTML += @"
                    <div class = 'col-md-6 box'>
                        <h3 style = 'text-align: center;'>$serverName (AV $aVirus)</h3>
"@
                }
                else {

                    $appHTML += @"
                    <div class = 'col-md-6 box'>
                        <h3 style = 'text-align: center;'>$serverName</h3>
                       
"@               
                }
                
                # Add this HTML to insert the windows description and Uptime
                # Also sets up the next table for CPU and its load
                $appHTML += @"                 
                             <h4 style = 'text-align: center;'>$windowsDescription</h4>
                             <h5 style = '$windowsReboot'>$windowsUpTime</h5>
                             <table class = 'table table-hover table-striped table-bordered'>
                             <th style = 'text-align: center;'>CPU</th>
                             <th style = 'text-align: center;'>Load</th>
"@
                
                # Run CPU function (check the functions script to see how this works)
                $cpu = Get-Windows-Cpu -ComputerName $serverName

                # Set CPU counter
                $countCPU = 0

                # Loop through each CPU (some computers have more than 1)
                foreach ($processor in $cpu) {

                    # Increment the counter foreach CPU
                    $countCPU++

                    # If processor is > 95 then make it a warning and add to tooltip
                    if ($processor -gt 95) {
                        $warningStatus++
                        $warningToolTip += "$serverName has high CPU `n"

                        # Append server name and CPU information to current HTML
                        $appHTML += "
                        <tr>
                            <td style = 'width: 70%;'>CPU ($countCPU)</td>
                            <td class = 'red' style = 'width: 30%; text-align: center; color: white;'>$processor%</td>
                        </tr>"
                    }

                    # Append this HTML if not a warning (success green)
                    else {
                        $appHTML += "
                        <tr>
                            <td style = 'width: 70%;'>CPU ($countCPU)</td>
                            <td class = 'green' style = 'width: 30%; text-align: center; color: white;'>$processor%</td>
                        </tr>"
                    }   
                }

                # Append this HTML to make a table for disk space
                $appHTML += "</table>"

                $appHTML += @"
                <table class = 'table table-hover table-striped table-bordered'>
                <th style = 'text-align: center;'>Memory</th>
                <th style = 'text-align: center;'>Load</th>
"@
                
                # Run Memory function (check the functions script to see how this works)
                $memory = Get-Windows-Memory -ComputerName $serverName

                
                    # If memory is > 95 then make it a warning and add to tooltip
                    if ($memory -gt 95) {
                        $warningStatus++
                        $warningToolTip += "$serverName has high Memory `n"

                        # Append server name and memory information to current HTML
                        $appHTML += "
                        <tr>
                            <td style = 'width: 70%;'>Memory</td>
                            <td class = 'red' style = 'width: 30%; text-align: center; color: white;'>$memory%</td>
                        </tr>"
                    }

                    # Append this HTML if not a warning (success green)
                    else {
                        $appHTML += "
                        <tr>
                            <td style = 'width: 70%;'>Memory</td>
                            <td class = 'green' style = 'width: 30%; text-align: center; color: white;'>$memory%</td>
                        </tr>"
                    }   
                

                # Append this HTML to make a table for disk space
                $appHTML += "
        
                </table>





                <h4 style = 'text-align: center;'><b>Disk Usage</b></h4>
                <table class = 'table table-hover table-striped table-bordered'>"

                # Run DiskSpace cmdlet
                $colDisks = Get-WmiObject Win32_LogicalDisk -computername $serverName -Filter "DriveType = 3"

                # XML thresholds for disk space
                $xmlDiskName = $computer.disks.disk.name
                $xmlThresholdRed = $computer.disks.disk.error
                $xmlThresholdOrange = $computer.disks.disk.warn

                # Loop through colDisks array (each drive on the computer)
                foreach ($disk in $colDisks) {

                    if ($disk.Size -gt 0) {
                        # Formula for getting the percentage full
                        $diskPercent = 100 - [Math]::round((($disk.FreeSpace / $disk.Size) * 100))
                    }
                    else {
                        $diskPercent = 0
                    }

                    # Formula for getting GB, much better than viewing it in bytes
                    $diskUsage = [math]::round(($disk.Size - $disk.FreeSpace) / 1Gb)
                    $diskSize = [math]::round($disk.Size / 1Gb)
                    $diskDrive = $disk.DeviceID

                    # If XML has threshold
                    if ($xmlThresholdRed) {

                        # if diskpercent is greater than the threshold and diskdrive is the same as that in the XML make it an error
                        if ($diskPercent -gt $xmlThresholdRed -and $diskDrive -eq $xmlDiskName) {

                            # Increment $errorStatus, add to tooltip and change the color of the progress bar to RED
                            $errorStatus++
                            $errorToolTip += "$serverName $diskDrive $diskPercent% full `n"
                            $progressColor = "progress-bar progress-bar-danger"

                        }
                        
                        # elseif percent is > orange threshhold and < red threshold then make it a warning
                        elseif ($diskPercent -gt $xmlThresholdOrange -and $diskPercent -lt $xmlThresholdRed -and $diskDrive -eq $xmlDiskName) {

                            $warningStatus++
                            $warningToolTip += "$serverName $diskDrive $diskPercent% full `n"
                            $progressColor = "progress-bar progress-bar-warning"

                        }
                        
                        # else make the progress bar a success and show no errors/warnings
                        else {
                
                            $progressColor = "progress-bar progress-bar-success"

                        }
                    
                        # If not run through thresholds as normal                           
                    }
                    else {

                        # If statement measuring whether disk space is low/medium/high and setting a different colour to notify user
                        if ($diskPercent -lt 80 -or $diskPercent -eq 80) {
                
                            $progressColor = "progress-bar progress-bar-success"

                        }
                        elseif ($diskPercent -gt 80 -and $diskPercent -lt 90) {

                            $warningStatus++
                            $warningToolTip += "$serverName $diskDrive $diskPercent% full `n"
                            $progressColor = "progress-bar progress-bar-warning"

                        }
                        else {
                
                            $errorStatus++
                            $errorToolTip += "$serverName $diskDrive $diskPercent% full `n"
                            $progressColor = "progress-bar progress-bar-danger"

                        }
                    }
        
                    # Append disk information into a table into the current HTML
                    $appHTML +=      
                    "
                    <tr>
                        <td style = 'width: 10%;'>$diskDrive</td>
                        <td style = 'width: 90%;'>
                            <div class='progress'>
                                <div class='$progressColor' role='progressbar'
                                aria-valuenow='40' aria-valuemin='0' aria-valuemax='100' style='width:$diskPercent%'>
                                <b>$diskUsage GB / $diskSize GB</b> ($diskPercent%)
                                </div>
                            </div>
                        </td>
                    </tr>"
                }

                # Close table outside of loop and make a new table for services
                $appHTML += "</table>
                                <table class = 'table table-hover table-striped table-bordered'>
                                <th style = 'text-align: center;'>Service</th>
                                <th style = 'text-align: center;'>Status</th>"

                # Loop through each service in the XML file
                foreach ($service in $computer.services.service) {
            
                    # Set service name and run the Get-Services function (look in functions script to see what it does)
                    $serviceName = $service.name
                    $serviceInfo = Get-Windows-Services -ComputerName $serverName -ServiceName $serviceName

                    # If statement whether the function returned Stopped or Running to change background colour to red/green
                    if ($serviceInfo -eq "Stopped") {

                        $errorStatus++
                        $errorToolTip += "$serverName has service stopped `n"
                        $appHTML +=
                        "<tr>
                                <td style = 'width: 70%;'>$serviceName</td>
                                <td style = 'text-align: center; width: 30%; color: white;' class='red'>STOPPED</td>
                             </tr>"
                    }
                    else {

                        $appHTML +=
                        "<tr>
                                <td style = 'width: 70%;'>$serviceName</td>
                                <td style = 'text-align: center; width: 30%; color: white;' class='green'>RUNNING</td>
                            </tr>"
                    }
     
                }

                # Close table and div outside of loop
                $appHTML += "</table>
                        </div>"

            }
        }


        ############ END OF WINDOWS SERVERS #############

        $appHTML += "</div>
                   </div>"

        $appEndTime = (Get-Date)

        $appTotalTime = $(($appEndTime - $appStartTime).totalseconds).ToString("#")
        
        # <head> HTML for app pages
        $headApp = @"
    <!DOCTYPE html>
        <head>
            <title>Server Report</title>
            <link rel='stylesheet' href='https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css'>
            <style>
                $cssFile 
            </style>
        </head>
        <nav class="navbar navbar-default navbar-fixed-top" style = "background-color: white;">
            <div class="container-fluid">
                <div class="navbar-header" style = "min-height: 65px;">
                    <a class="navbar-brand" style = "margin-top: -25px; margin-left: -30px;" href="#"> <img src = "http://www.aeff.co.uk/wp-content/themes/aeff/images/logo_council.png" style = "width:250px;"></a>
                </div>
               
                <a class="btn btn-success btn-lg" href="/monitoringtest/monitoring" role="button">Back</a>
                <div style = "float: right;">
                    <div><p><b>$appName report was run on $appStartTime</b></p></div>
                    <div><p><b>Elapsed time: $appTotalTime Seconds</b></p></div>
                </div>
            </div>
        </nav>
    <body>
       
            
"@
        # Output the file to this location
        $outPutFile2 = "C:\inetpub\wwwroot\powershelltest\webpages\$appName.html"

        # append appHTML onto headApp
        $headApp + $appHTML | Out-File $outPutFile2 -Force
    
        # if any errors on a particular app then add to global count (for main page)
        if ($errorStatus -gt 0) {

            $globalErrorCount += $errorStatus
            $html += "<tr>
                        <td style = 'text-align: center;'><a href='/powershelltest/webpages/$appName.html' target='_parent'>$appName</a></td>
                        <td style = 'text-align: center;' class = 'red'><a href='/powershelltest/webpages/$appName.html' target='_parent' style='color: white;' data-toggle='tooltip' title='$errorToolTip'>$errorStatus Error(s)</a> </td>
                      </tr>"

            $errorReport += "<tr>
                        <td style = 'text-align: center;'><a href='/powershelltest/webpages/$appName.html' target='_parent'>$appName</a></td>
                        <td style = 'text-align: center;' class = 'red'><a href='/powershelltest/webpages/$appName.html' target='_parent' style='color: white;' data-toggle='tooltip' title='$errorToolTip'>$errorStatus Error(s)</a> </td>
                      </tr>
                      "
        } 
        else {
            $html += "<tr>
                        <td style = 'text-align: center;'><a href='/powershelltest/webpages/$appName.html' target='_parent'>$appName</a></td>
                        <td style = 'text-align: center;' class = 'green'><a href='/powershelltest/webpages/$appName.html' target='_parent' style='color: white;'>Running</a> </td>
                    </tr>"
        }
        
        # if any warnings on a particular app then add to global count (for main page)
        if ($warningStatus -gt 0) {

            $globalWarningCount += $warningStatus
            $warningReport += "<tr>
                        <td style = 'text-align: center;'><a href='/powershelltest/webpages/$appName.html' target='_parent'>$appName</a></td>
                        <td style = 'text-align: center;' class = 'orange'><a href='/powershelltest/webpages/$appName.html' target='_parent' style='color: white;' data-toggle='tooltip' title='$warningToolTip'>$warningStatus Warning(s)</a> </td> 
                      </tr>
                      "
        } 

    }

    # Close $html tags
    $html += "</table>
                </div>"
    # Close errorReport tags
    $errorReport += "</table>
                        </div>"
    # Close warningReport tags
    $warningReport += "</table>
                        </div>"

# 3 buttons at top of each priority (errors, warnings, success)
$dbButtonTop = @"
<h3 style ="text-align: center;">Databases</h3>
<div style = "text-align: center;">
    <a class="btn btn-success btn-sm" href="/powershelltest/RunningPanels/DBIframe.html" role="button">Running</a>
    <a class="btn btn-danger btn-sm" href="/powershelltest/ErrorPanels/DBErrorIframe.html" role="button">Errors ($globalErrorCount)</a>
    <a class="btn btn-warning btn-sm" href="/powershelltest/WarningPanels/DBWarningIframe.html" role="button">Warnings ($globalWarningCount)</a>
</div><br>
"@

# Output iFrames (warnings, errors, success)
$head + $dbButtonTop + $html | Out-File "C:\inetpub\wwwroot\powershelltest\RunningPanels\DBIframe.html"
$head + $dbButtonTop + $warningReport | Out-File "C:\inetpub\wwwroot\powershelltest\WarningPanels\DBWarningIframe.html"
$head + $dbButtonTop + $errorReport | Out-File "C:\inetpub\wwwroot\powershelltest\ErrorPanels\DBErrorIframe.html"

# End of script