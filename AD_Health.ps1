$DomainCheck = Get-CimInstance -ClassName Win32_OperatingSystem
New-Item -Path 'C:\TeamLogicIT' -ItemType Directory
if ($DomainCheck.ProductType -ne "2") { write-output "Invalid" | Out-File C:\TeamLogicIT\AD_Health.txt ; exit 0 }

$DiagInfo = dcdiag
$DCDiagResult = $Diaginfo | select-string -pattern '\. (.*) \b(passed|failed)\b test (.*)' | foreach {
	$obj = @{
		TestName   = $_.Matches.Groups[3].Value
		TestResult = $_.Matches.Groups[2].Value
		Entity     = $_.Matches.Groups[1].Value
	}
	[pscustomobject]$obj
}
 
$DCDiagStatus = foreach ($FailedResult in $DCDiagResult | Where-Object { $_.Testresult -ne "passed" -and $_.Testname -ne "DFSREvent" -and $_.Testname -ne "FRSEvent" -and $_.Testname -ne "SystemLog"}) {
	"DC diag test failed on entity $($FailedResult.entity) - $($FailedResult.testname)"
}
if(!$DCDiagStatus){ $DCDiagStatus = "Healthy" }
 
$AlertTime = (get-date).AddHours(-6)
$FailedArr = @()
$RepStatus = Get-ADReplicationPartnerMetadata -Target * -Partition * | Select-Object Server, Partition, Partner, ConsecutiveReplicationFailures, LastReplicationSuccess, LastRepicationResult
foreach ($Report in $RepStatus) {
	$Partner = $Report.partner -split "CN="
	if ($report.LastReplicationSuccess -lt $AlertTime) {
		$FailedArr += "$($Report.Server) Failed to replicate with partner $($Partner[2]) for 6 hours. please investigate"
	}
}
if (!$FailedArr) { $FailedArr = "Healthy" } 
 
$DCDiagStatus | Out-File C:\TeamLogicIT\AD_Diag.txt
$FailedArr | Out-File C:\TeamLogicIT\AD_Replication.txt

	
