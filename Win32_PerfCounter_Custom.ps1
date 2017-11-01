[cultureinfo]::CurrentCulture = [cultureinfo]::InvariantCulture ##Is this needed?
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
$newClass.Properties.Add("ScriptLastRan", [System.Management.CimType]::String, $false)
$newClass.Properties["PerfCounterName"].Qualifiers.Add("Key", $true)
$newClass.Put() | Out-Null
 
$cpuload=(get-counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 3 |
    select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average -Minimum -Maximum)

$procs = Get-Process 
$processTime = 0 ; $processTimeTotal = 0
$userTime = 0 ; $userTimeTotal = 0
$kernelTime = 0 ; $kernelTimeTotal = 0
$workingSet = 0 ; $highestWorkingSet = 0 ; $highestWorkingSetProcName = ""
$highestKernelTime = 0 ; $highestKernelProcName = ""
$highestUserTime = 0 ; $highestUserProcName = ""

foreach ($proc in $procs) {
$processTime= $proc.TotalProcessorTime.Hours
$kernelTime=$proc.PrivilegedProcessorTime.TotalHours
$userTime=$proc.UserProcessorTime.TotalHours
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
cpuavg = "{0:N2}" -f ($cpuload.Average)
cpumin = "{0:N2}" -f ($cpuload.Minimum)
cpumax = "{0:N2}" -f ($cpuload.Maximum )		
processTimeTotal = "{0:N2}" -f ($processTimeTotal)
kernelTimeTotal = "{0:N2}" -f ($kerneltimeTotal)
userTimeTotal = "{0:N2}" -f ($usertimeTotal)
uptimehours = "{0:N2}" -f ($UpTime.TotalHours)
processTimePerc = "{0:N6}" -f ($processTimeTotal/($UpTime.TotalHours)*100) 
#processTimePerc = ($processTimeTotal/([float]$UpTime.TotalHours))
highestKernelProcName = ($highestKernelProcName)
highestKernelTime = "{0:N2}" -f ($highestKernelTime)
highestUserProcName = ($highestUserProcName)
highestUserTime = "{0:N2}" -f ($highestUserTime)
highestWorkingSetProcName =  ($highestWorkingSetProcName)
highestWorkingSet = ($highestWorkingSet)
freeDiskC = (Get-WMIObject -class Win32_logicaldisk | where {$_.DeviceID -eq 'C:'} | Measure-Object -Property freespace -Sum | % {[Math]::Round(($_.sum / 1MB),0)})
freePhysMemory = (Get-Counter -Counter "\Memory\Available MBytes").CounterSamples[0].CookedValue
totalPhysMemory = (Get-WMIObject -class Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | % {[Math]::Round(($_.sum / 1MB),2)})

ScriptLastRan = $Date
} | Out-Null

Write-Output "Complete"
