## Define new class name and date
$NewClassName = 'Win32_PerfCounter_Custom'
$Date = Get-Date -Format "yyyy'-'MM'-'dd HH':'mm':'ss'.'fff"
 
## Remove class if exists
Remove-WmiObject $NewClassName -ErrorAction SilentlyContinue
 
# Create new WMI class
$newClass = New-Object System.Management.ManagementClass ("root\cimv2", [String]::Empty, $null)
$newClass["__CLASS"] = $NewClassName
 
## Create properties you want inventoried   !SCCM hardware inventory converts everything to nvarchar(255), String = less headache in SQL!
$newClass.Qualifiers.Add("Static", $true)
$newClass.Properties.Add("PerfCounterName", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("cpuavg", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("cpumin", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("cpumax", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("processTimeTotal", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("kernelTimeTotal", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("userTimeTotal", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("uptimehours", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("processTimePerc", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("highestKernelProcName", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("highestKernelTime", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("highestUserProcName", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("highestUserTime", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("highestWorkingSetProcName", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("highestWorkingSet", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("freePhysMemory", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("totalPhysMemory", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("freeDiskC", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("SystemStabilityIndex", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("ScriptLastRan", [System.Management.CimType]::String, $false)
$newClass.Properties["PerfCounterName"].Qualifiers.Add("Key", $true)
$newClass.Put() | Out-Null
 
$cpuload=(get-counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 30 |
    select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average -Minimum -Maximum)

$procs = Get-Process 
$processTime = 0 ; $processTimeTotal = 0
$userTime = 0 ; $userTimeTotal = 0
$kernelTime = 0 ; $kernelTimeTotal = 0
$workingSet = 0 ; $highestWorkingSet = 0 ; $highestWorkingSetProcName = ""
$highestKernelTime = 0 ; $highestKernelProcName = ""
$highestUserTime = 0 ; $highestUserProcName = ""

foreach ($proc in $procs) {
	$processTime= $proc.TotalProcessorTime.TotalSeconds
	$kernelTime=$proc.PrivilegedProcessorTime.TotalSeconds
	$userTime=$proc.UserProcessorTime.TotalSeconds
	$workingSet=$proc.PeakWorkingSet/1MB
	if ($kernelTime -gt $highestKernelTime) {
	 $highestKernelTime = $kernelTime  
	 $highestKernelProcName=$proc.ProcessName 
	}
	if ($userTime -gt $highestUserTime) {
	 $highestUserTime = $userTime  
	 $highestUserProcName=$proc.ProcessName 
	}
	if ($userTime -gt $highestUserTime) {
	 $highestUserTime = $userTime  
	 $highestUserProcName=$proc.ProcessName 
	}
	if ($WorkingSet -gt $highestWorkingSet) {
	 $highestWorkingSet = $WorkingSet 
	 $highestWorkingSetProcName=$proc.ProcessName 
	}
	$processTimeTotal+=$processTime
	$kernelTimeTotal+=$kernelTime
	$userTimeTotal+=$userTime
}
$OS = Get-WmiObject win32_operatingsystem 
$BootTime = $OS.ConvertToDateTime($OS.LastBootUpTime) 
$Uptime = $OS.ConvertToDateTime($OS.LocalDateTime) - $boottime 
	
 Set-WmiInstance -Namespace root\cimv2 -class $NewClassName -argument @{
	PerfCounterName = "General Performance Metrics"
	cpuavg = [math]::Round($cpuload.Average,2).ToString((New-Object Globalization.CultureInfo ""))
	cpumin = [math]::Round($cpuload.Minimum,2).ToString((New-Object Globalization.CultureInfo ""))
	cpumax = [math]::Round($cpuload.Maximum,2).ToString((New-Object Globalization.CultureInfo ""))
	processTimeTotal = [math]::Round($processTimeTotal/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	kernelTimeTotal = [math]::Round($kerneltimeTotal/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	userTimeTotal = [math]::Round($usertimeTotal/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	uptimehours = [math]::Round($UpTime.TotalSeconds/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	processTimePerc = [math]::Round($processTimeTotal/($UpTime.TotalSeconds)*100,6).ToString((New-Object Globalization.CultureInfo ""))
	highestKernelProcName = ($highestKernelProcName)
	highestKernelTime = [math]::Round($highestKernelTime/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	highestUserProcName = ($highestUserProcName)
	highestUserTime = [math]::Round($highestUserTime/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	highestWorkingSetProcName =  ($highestWorkingSetProcName)
	highestWorkingSet = [math]::Round($highestWorkingSet,0).ToString((New-Object Globalization.CultureInfo ""))
	freeDiskC = (Get-WMIObject -class Win32_logicaldisk | where {$_.DeviceID -eq 'C:'} | Measure-Object -Property freespace -Sum | % {[Math]::Round(($_.sum / 1MB),0)})
	freePhysMemory = (Get-Counter -Counter "\Memory\Available MBytes").CounterSamples[0].CookedValue
	totalPhysMemory = (Get-WMIObject -class Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | % {[Math]::Round(($_.sum / 1MB),0)})
	SystemStabilityIndex = [math]::Round((Get-WMIObject -class Win32_ReliabilityStabilityMetrics | Select -first 1).SystemStabilityIndex,3).ToString((New-Object Globalization.CultureInfo ""))

	ScriptLastRan = $Date
} | Out-Null

If ($osVer -lt 6.2) { #Server older than 2012, trigger RAC manually for next run
	set-itemproperty hklm:'\SOFTWARE\Microsoft\Reliability Analysis\WMI' -name 'wmienable' -value 1 

	$s = new-object -com("Schedule.Service") 
	$s.connect() 
	$x=$s.GetFolder('\Microsoft\Windows\RAC').gettask('ractask').definition 
	$x.triggers.item(2).enabled=$true 
	$s.GetFolder('\Microsoft\Windows\RAC').registertaskdefinition('ractask',$x,6,'LocalService',$null,5) | Out-Null
	$s.GetFolder('\Microsoft\Windows\RAC').gettask('ractask').run(0) | Out-Null
}


Write-Output "Complete"
