cd "C:\Monitoring\Service Monitor\Powershell Testing\"
$ScriptRoot = "C:\Monitoring\Service Monitor\Powershell Testing\"
$job1 = Start-Job -FilePath 'C:\Monitoring\Service Monitor\Powershell Testing\ServerMonitoringiFrameDBTest.ps1'
$job2 = Start-Job -FilePath 'C:\Monitoring\Service Monitor\Powershell Testing\ServerMonitoringiFrameP1Test.ps1'
$job3 = Start-Job -FilePath 'C:\Monitoring\Service Monitor\Powershell Testing\ServerMonitoringiFrameP2Test.ps1'
$job4 = Start-Job -FilePath 'C:\Monitoring\Service Monitor\Powershell Testing\ServerMonitoringiFrameInfraTest.ps1'

$runningJobs = Get-Job -State Running 
    while($runningJobs.Count -gt 0){
    Start-Sleep -Seconds 1
    $runningJobs = Get-Job -State Running
}

