###############################################################################
###############################################################################
#
# VMware VM Space Utilization Sensor
# December 2016, jsanders@lockstepgroup.com
#
###############################################################################
###############################################################################
# script parameters

Param (
	[Parameter(Position=0)]
	[string]$VMwareClusterName,
	[Parameter(Position=1)]
	[string]$VMwareVMNameFilter,
	[Parameter(Position=2)]
	[int]$TotalPaidSizeInGB
)

###############################################################################
###############################################################################
# output handling functions from prtgshell
# https://github.com/brianaddicks/prtgshell

function Set-PrtgResult {
    Param (
    [Parameter(mandatory=$True,Position=0)]
    [string]$Channel,
    
    [Parameter(mandatory=$True,Position=1)]
    $Value,
    
    [Parameter(mandatory=$True,Position=2)]
    [string]$Unit,

    [Parameter(mandatory=$False)]
    [alias('mw')]
    [string]$MaxWarn,

    [Parameter(mandatory=$False)]
    [alias('minw')]
    [string]$MinWarn,
    
    [Parameter(mandatory=$False)]
    [alias('me')]
    [string]$MaxError,
    
    [Parameter(mandatory=$False)]
    [alias('wm')]
    [string]$WarnMsg,
    
    [Parameter(mandatory=$False)]
    [alias('em')]
    [string]$ErrorMsg,
    
    [Parameter(mandatory=$False)]
    [alias('mo')]
    [string]$Mode,
    
    [Parameter(mandatory=$False)]
    [alias('sc')]
    [switch]$ShowChart,
    
    [Parameter(mandatory=$False)]
    [alias('ss')]
    [ValidateSet("One","Kilo","Mega","Giga","Tera","Byte","KiloByte","MegaByte","GigaByte","TeraByte","Bit","KiloBit","MegaBit","GigaBit","TeraBit")]
    [string]$SpeedSize,

	[Parameter(mandatory=$False)]
    [ValidateSet("One","Kilo","Mega","Giga","Tera","Byte","KiloByte","MegaByte","GigaByte","TeraByte","Bit","KiloBit","MegaBit","GigaBit","TeraBit")]
    [string]$VolumeSize,
    
    [Parameter(mandatory=$False)]
    [alias('dm')]
    [ValidateSet("Auto","All")]
    [string]$DecimalMode,
    
    [Parameter(mandatory=$False)]
    [alias('w')]
    [switch]$Warning,
    
    [Parameter(mandatory=$False)]
    [string]$ValueLookup
    )
    
    $StandardUnits = @("BytesBandwidth","BytesMemory","BytesDisk","Temperature","Percent","TimeResponse","TimeSeconds","Custom","Count","CPU","BytesFile","SpeedDisk","SpeedNet","TimeHours")
    $LimitMode = $false
    
    $Result  = "  <result>`n"
    $Result += "    <channel>$Channel</channel>`n"
    $Result += "    <value>$Value</value>`n"
    
    if ($StandardUnits -contains $Unit) {
        $Result += "    <unit>$Unit</unit>`n"
    } elseif ($Unit) {
        $Result += "    <unit>custom</unit>`n"
        $Result += "    <customunit>$Unit</customunit>`n"
    }
    
	if (!($Value -is [int])) { $Result += "    <float>1</float>`n" }
    if ($Mode)        { $Result += "    <mode>$Mode</mode>`n" }
    if ($MaxWarn)     { $Result += "    <limitmaxwarning>$MaxWarn</limitmaxwarning>`n"; $LimitMode = $true }
    if ($MaxError)    { $Result += "    <limitminwarning>$MinWarn</limitminwarning>`n"; $LimitMode = $true }
    if ($MaxError)    { $Result += "    <limitmaxerror>$MaxError</limitmaxerror>`n"; $LimitMode = $true }
    if ($WarnMsg)     { $Result += "    <limitwarningmsg>$WarnMsg</limitwarningmsg>`n"; $LimitMode = $true }
    if ($ErrorMsg)    { $Result += "    <limiterrormsg>$ErrorMsg</limiterrormsg>`n"; $LimitMode = $true }
    if ($LimitMode)   { $Result += "    <limitmode>1</limitmode>`n" }
    if ($SpeedSize)   { $Result += "    <speedsize>$SpeedSize</speedsize>`n" }
    if ($VolumeSize)  { $Result += "    <volumesize>$VolumeSize</volumesize>`n" }
    if ($DecimalMode) { $Result += "    <decimalmode>$DecimalMode</decimalmode>`n" }
    if ($Warning)     { $Result += "    <warning>1</warning>`n" }
    if ($ValueLookup) { $Result += "    <ValueLookup>$ValueLookup</ValueLookup>`n" }
    
    if (!($ShowChart)) { $Result += "    <showchart>0</showchart>`n" }
    
    $Result += "  </result>`n"
    
    return $Result
}



function Set-PrtgError {
	Param (
		[Parameter(Position=0)]
		[string]$PrtgErrorText
	)
	
	@"
<prtg>
  <error>1</error>
  <text>$PrtgErrorText</text>
</prtg>
"@

exit
}

###############################################################################
###############################################################################
# environment confirmation

$VMwareViServer = 	$env:prtg_host

if (!($VMwareViServer)) {
	Set-PrtgError 'Required parameter not specified (VMwareViServer): please set "Set placeholders as environment values" in sensor options'
}

if (!($env:prtg_windowsuser)) {
	Set-PrtgError 'Required parameter not specified (windowsuser): please set "Set placeholders as environment values" in sensor options and ensure Windows credentials are configured for device'
}

if (!($env:prtg_windowsdomain)) {
	Set-PrtgError 'Required parameter not specified (windowsdomain): please set "Set placeholders as environment values" in sensor options and ensure Windows credentials are configured for device'
}

if (!($env:prtg_windowspassword)) {
	Set-PrtgError 'Required parameter not specified (prtg_windowspassword): please set "Set placeholders as environment values" in sensor options and ensure Windows credentials are configured for device'
}

###############################################################################
###############################################################################
# creating credential object from prtg credentials supplied

$SecurePassword = ConvertTo-SecureString $env:prtg_windowspassword -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential (($env:prtg_windowsdomain + '\' + $env:prtg_windowsuser), $SecurePassword)

###############################################################################
###############################################################################
# validating snapin availability

$SnapInName = 'VMware.VimAutomation.Core'

try {
	Add-PSSnapin $SnapInName -ErrorAction Stop
} catch {
	$HostName = hostname
	Set-PrtgError "Unable to load require snapin $SnapInName. Please ensure required software is installed on probe $HostName."
	exit
}

###############################################################################
###############################################################################
# connection validation

$CertificateAction = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DefaultVIServerMode Multiple -Confirm:$false

try {
	$ViServer = Connect-VIServer $VMwareViServer -Credential $Cred -ErrorAction Stop
} catch {
	Set-PrtgError ("Unable to connect to VMware VI Server $VMwareViServer. Exception message: " + $Error[0].Exception.InnerException.Message.ToString())
	exit
}

###############################################################################
###############################################################################
# procedural code

$DatastoreMeasurements = Get-Cluster $VMwareClusterName | Get-VM $VMwareVMNameFilter | Select UsedSpaceGB,ProvisionedSpaceGB | Measure-Object -Sum UsedSpaceGB,ProvisionedSpaceGB | Select-Object Property,Sum,Count


$UsedSpace = $DatastoreMeasurements | Where-Object { $_.Property -eq 'UsedSpaceGB' } | Select-Object -ExpandProperty Sum
$ProvSpace = $DatastoreMeasurements | Where-Object { $_.Property -eq 'ProvisionedSpaceGB' } | Select-Object -ExpandProperty Sum


###############################################################################
###############################################################################
# output


$ReturnText = "OK: " + $DatastoreMeasurements[0].Count + " machines included"

$XMLOutput = "<prtg>`n"

$XMLOutput += Set-PrtgResult "Used Space" $UsedSpace "GBytes" -ShowChart
$XMLOutput += Set-PrtgResult "Provisioned Space" $ProvSpace "GBytes" -ShowChart


if ($TotalPaidSizeInGB) {
	$UsedPercentage = [int](($UsedSpace/$TotalPaidSizeInGB) * 100)
	$XMLOutput += Set-PrtgResult "Percent Used" $UsedPercentage "percent" -ShowChart
	
	$ProvPercentage = [int](($ProvSpace/$TotalPaidSizeInGB) * 100)
	$XMLOutput += Set-PrtgResult "Percent Provisioned" $ProvPercentage "percent" -ShowChart
}

$XMLOutput += Set-PrtgResult "Machines" $DatastoreMeasurements[0].Count "machines"

$XMLOutput += "  <text>$ReturnText</text>`n"
$XMLOutput += "</prtg>"

$XMLOutput
