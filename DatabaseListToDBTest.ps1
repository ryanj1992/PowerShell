<# This function finds all instances on an SQL server #>
Function Get-SQLInstances {
 
    param (
        [string]$ComputerName = $env:COMPUTERNAME
    )
 
    try {
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName)
        $regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\Instance Names\\SQL" )
        $instances = $regkey.GetValueNames()
        $SQLversion = $regkey.GetValue("Version")
 
        if ($InstanceName) {
            if ($instances -contains $InstanceName) {
                return $true
            } else {
                return $false
            }
        } else {
            $instances
        }
    }
    catch {
        Write-Error $_.Exception.Message
        return $false
        Write-Error "ERROR: Could not retrieve SQL Instances $computername"
    }
}

<# This function finds all databases associated with each instance #>
Function Get-SQLDatabases {

	param (
		[string]$instancename = $env:INSTANCENAME
	)

	try{
 	    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
	     $s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instancename
         
         # Write out the server\instance name and SQL version
         #write-output ($instancename + " (SQL Version " + $s.versionstring + ") " + $cpu_info)
         #write-output("------------------------------")
	     
         # Database id > 4 eliminates system databases and IsAccessible tells whether the database is online/offline
         $dbs=$s.Databases  | Where-Object {$_.id -gt 4 -and $_.IsAccessible -eq $true}
         return $dbs.Name
	}
	catch {
        	Write-Error $_.Exception.Message
	        #return $false
            Write-Error "ERROR: Could Not Connect to SQL Instance $instanceName"
    }
}



$cpu_info = ""


$params = @{'server' = 'ABNWHHSV437'; 'Database' = 'MonitoringTest'}
$dblist = invoke-sqlcmd @params -query @" 
select * from [MonitoringTest].[dbo].[DatabaseList1]
"@


# 2 servers for testing
#$serverlist = @{Name="ABNWHHSV97"}, @{Name="ABNWHHSV427"}
#$serverlist = @{Name="ABNWHHSV437"}

#$serverlist = @{Name="abnwhhsv427"},  @{Name="abnwhhsv410"},  @{Name="abnwhhsv408"}, @{Name="abnwhhsv399"}, @{Name="abnwhhsv391"}, @{Name="abnwhhsv370"}, @{Name="abnwhhsv346"}, @{Name="abnwhhsv344"}, @{Name="abnwhhsv105"}

# Get All Servers from Active Directory
$serverlist = Get-ADComputer -Filter {ObjectClass -eq "Computer" -and OperatingSystem -like "*server*"} | Select Name
$serverlist = $serverlist | Sort-Object Name

$connError = @()
$databaseArray = @()

# Loop through all servers
foreach ($server IN $serverlist.name){
    
    if($server){

    write-output ("Checking " + $server + "...")

    # Check for SQL Service
    try {

        # Test the connection of the server to check its online
        if(Test-Connection -ComputerName $server -Count 1 -Quiet){

        # Finds all services like SQL server
        $service = Get-Service -Computername $server -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like "*SQL Server*"}
        
        # If it find a SQL server service then jump into this if statement
        if ($service){
        #write-output($service)

        try{
            # Get all the SQL Instances on this server  (see function above)
	        $instances = Get-SQLInstances -ComputerName $server
        }
        catch{}
	
    
        try{
            # Loop through all SQL instances
	        foreach ($instance in $instances){

                if ($instance){

                # Write out the names of all databases on this server\instance
		        $databases = Get-SQLDatabases -InstanceName ($server + "\" + $instance).Replace("\MSSQLSERVER","")

                if($databases){

                # For each database, insert these values into a custom object
                foreach ($db in $databases){
                     $dbDetails = [PSCustomObject] @{
                        Server          = $server.Trim()
                        Instance        = $instance.Trim()
                        DatabaseName    = $db.Trim()
                        }

                        Write-Host $dbDetails

                    # append the database details to an array which has been declared above
                    $databaseArray += $dbDetails
                    $serverfound = 0

                    # for each database stored in the database (not on the server)
                    foreach($database in $dblist){
                    
                        $dbname = $database.DatabaseName.Trim()

                        # if the database name is found in the database then increment $serverFound (so it doesn't add the database again)
                        if ($dbname -eq $dbDetails.DatabaseName.Trim()) {

                            $serverFound++
                            Write-Host $dbname "Found" -ForegroundColor green
                    
                        }
                    }

                    ######################### ADDING DATABASE TO SQL SERVER #############################

                    # if the database was not found then jump into this if statement
                    if ($serverFound -lt 1) {
                    
                        Write-Host "Adding Database" $dbDetails.DatabaseName -ForegroundColor yellow

                        # Data preparation for loading data into SQL table 
                        $InsertResults = @"
                                    INSERT INTO [MonitoringTest].[dbo].[DatabaseList1](Server, Instance, DatabaseName)
                                    VALUES ('$($dbDetails.Server)',
                                            '$($dbDetails.Instance)',
                                            '$($dbDetails.DatabaseName)')

"@
                        #call the invoke-sqlcmdlet to execute the query
                        Invoke-sqlcmd @params -Query $InsertResults
                    
                    }
                    

                    ######################### ADDING DATABASE TO SQL SERVER #############################

                }
                
                # $connError is used for testing purposes (holds all servers that this script cannot connect too)
                } else {
                    $connError += $server
                  } 


                #write-output ""
                }

                
	        }
        }
        catch{}
        }
    
    

    } else {"Could not connect to Server"}
    }
    catch{}
    }
}

######################### DELETING DATABASE FROM SQL SERVER #############################

# Loop through each database name in the database
foreach ($database in $dblist) {
    
    $j = 0
    $i = 0
    $serverName = $database.Server.Trim()
    $dbName = $database.DatabaseName.Trim()

    <# This is a nested loop - for each database in the database it will loop through this
       nested loop which loops through each database we've stored in the array above
       and checks to see if the DBNAME and SERVERNAME match with anything in the array
       if it does, don't delete. If not then place the database in the retiredDatabases table
       and delete from the main table (DatabaseList1) #>
    foreach ($db in $databaseArray){

        if ($databaseArray[$j].DatabaseName.Equals($dbName) -and $databaseArray[$j].Server.Equals($serverName)){

            $i++

        }

        $j++
    }

    if ($i -eq 0) {
                            
        Write-Host "$($dbName) has been retired $($database.Server)" -ForegroundColor RED
        # Data preparation for loading data into SQL table

        $insertDecommission = @"
        INSERT INTO [MonitoringTest].[dbo].[RetiredDatabases](Server, Instance, DatabaseName, CherwellBusinessService, Notes, RetiredDate)
        VALUES ('$($database.Server)',
                '$($database.Instance)',
                '$($database.DatabaseName)',
                '$($database.CherwellBusinessService)',
                '$($database.Notes)',
                '$(Get-Date)')

"@
        #call the invoke-sqlcmdlet to execute the query
        Invoke-sqlcmd @params -Query $insertDecommission

        $deleteResults = @"
                    DELETE FROM [MonitoringTest].[dbo].[DatabaseList1]
                    WHERE DatabaseName like '%$($dbName)%' AND Server like '%$($serverName)%'

"@
        #call the invoke-sqlcmdlet to execute the query
        Invoke-sqlcmd @params -Query $deleteResults

    }
}


######################### DELETING DATABASE FROM SQL SERVER #############################