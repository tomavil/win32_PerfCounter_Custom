$perfCounterRevision = 10
$osVer = (Get-WmiObject Win32_OperatingSystem).Version

## Define new class name and date
$newClassName = 'Win32_PerfCounter_Custom'
$date = Get-Date -Format "yyyy'-'MM'-'dd HH':'mm':'ss'.'fff"
 
## Remove older revision or older than 24h 
If ((Get-WmiObject -class win32_perfcounter_custom -list) -ne $null) {
	If ((Get-WmiObject Win32_PerfCounter_Custom).perfCounterRevision -lt $perfCounterRevision) {
		Remove-WmiObject $newClassName -ErrorAction SilentlyContinue
	}
	$classInstances = Get-WmiObject -class win32_perfcounter_custom
	ForEach ($classInstance in $classInstances) {
		If ([datetime]$classInstance.scriptLastRan -lt (get-date).addhours(-24)) {
			$classInstance | Remove-WmiObject
		}
	}	
}

# Create new WMI class
$newClass = New-Object System.Management.ManagementClass ("root\cimv2", [String]::Empty, $null)
$newClass["__CLASS"] = $newClassName
  
## Create properties you want inventoried   !SCCM hardware inventory converts everything to nvarchar(255), String = less headache in SQL!
$newClass.Qualifiers.Add("static", $true)
$newClass.Properties.Add("perfCounterName", [System.Management.CimType]::String, $false)
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
$newClass.Properties.Add("disk0ID", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("disk0Free", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("disk1ID", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("disk1Free", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("disk2ID", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("disk2Free", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("disk3ID", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("disk3Free", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("systemStabilityIndex", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("scriptLastRan", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("perfCounterRevision", [System.Management.CimType]::String, $false)
$newClass.Properties["scriptLastRan"].Qualifiers.Add("Key", $true)
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

ForEach ($proc in $procs) {
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
$bootTime = $OS.ConvertToDateTime($OS.LastBootUpTime) 
$uptime = $OS.ConvertToDateTime($OS.LocalDateTime) - $boottime 

$disks=(Get-WMIObject -class Win32_LogicalDisk -filter Drivetype=3 | Sort-Object FreeSpace)
	
 Set-WmiInstance -Namespace root\cimv2 -class $NewClassName -argument @{
	PerfCounterName = "General Performance Metrics"
	cpuavg = [math]::Round($cpuload.Average,2).ToString((New-Object Globalization.CultureInfo ""))
	cpumin = [math]::Round($cpuload.Minimum,2).ToString((New-Object Globalization.CultureInfo ""))
	cpumax = [math]::Round($cpuload.Maximum,2).ToString((New-Object Globalization.CultureInfo ""))
	processTimeTotal = [math]::Round($processTimeTotal/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	kernelTimeTotal = [math]::Round($kerneltimeTotal/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	userTimeTotal = [math]::Round($usertimeTotal/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	uptimehours = [math]::Round($upTime.TotalSeconds/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	processTimePerc = [math]::Round($processTimeTotal/($upTime.TotalSeconds)*100,6).ToString((New-Object Globalization.CultureInfo ""))
	highestKernelProcName = ($highestKernelProcName)
	highestKernelTime = [math]::Round($highestKernelTime/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	highestUserProcName = ($highestUserProcName)
	highestUserTime = [math]::Round($highestUserTime/3600,2).ToString((New-Object Globalization.CultureInfo ""))
	highestWorkingSetProcName =  ($highestWorkingSetProcName)
	highestWorkingSet = [math]::Round($highestWorkingSet,0).ToString((New-Object Globalization.CultureInfo ""))
	disk0free = $disks[0] | Measure-Object -Property freespace -Sum | % {[Math]::Round(($_.sum / 1MB),0)}
	disk0ID = $disks[0].DeviceID
	disk1Free = $disks[1] | Measure-Object -Property freespace -Sum | % {[Math]::Round(($_.sum / 1MB),0)}
	disk1ID = $disks[1].DeviceID
	disk2Free = $disks[2] | Measure-Object -Property freespace -Sum | % {[Math]::Round(($_.sum / 1MB),0)}
	disk2ID = $disks[2].DeviceID
	disk3Free = $disks[3] | Measure-Object -Property freespace -Sum | % {[Math]::Round(($_.sum / 1MB),0)}
	disk3ID = $disks[3].DeviceID
	freePhysMemory = (Get-Counter -Counter "\Memory\Available MBytes").CounterSamples[0].CookedValue
	totalPhysMemory = (Get-WMIObject -class Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | % {[Math]::Round(($_.sum / 1MB),0)})
	SystemStabilityIndex = [math]::Round((Get-WMIObject -class Win32_ReliabilityStabilityMetrics | Select -first 1).SystemStabilityIndex,3).ToString((New-Object Globalization.CultureInfo ""))
    perfCounterRevision = $perfCounterRevision
	scriptLastRan = $date
} | Out-Null

If ($osVer -lt 6.2) { #Server older than 2012 - enable reliability analysis,trigger RAC manually for next run
   If ((Get-ItemProperty hklm:'\SOFTWARE\Microsoft\Reliability Analysis\WMI' -name 'WMIEnable').WMIEnable -ne 1) {
		Set-ItemProperty hklm:'\SOFTWARE\Microsoft\Reliability Analysis\WMI' -name 'WMIEnable' -value 1 
		$s = new-object -com("Schedule.Service") 
		$s.connect() 
		$x=$s.GetFolder('\Microsoft\Windows\RAC').gettask('ractask').definition 
		$x.triggers.item(2).enabled=$true 
		$s.GetFolder('\Microsoft\Windows\RAC').registertaskdefinition('ractask',$x,6,'LocalService',$null,5) | Out-Null
		$s.GetFolder('\Microsoft\Windows\RAC').gettask('ractask').run(0) | Out-Null
	}
}


Write-Output "Complete"
