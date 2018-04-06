###############################################################################
#
# ScriptName: Lockstep - Citrix NetScaler - HA Status
# Auther: naddicks@lockstepgroup.com
# Last Updated: 04 2018
# Pulls current HA status, state, and transition time from Citrix NetScaler using Nitro API
#
###############################################################################

###############################################################################
#                              PLACEHOLDER USAGE
# prtg_sensorid ........................................................ UNUSED
# prtg_deviceid ........................................................ UNUSED
# prtg_groupid ......................................................... UNUSED
# prtg_probeid ......................................................... UNUSED
#
# prtg_host ..................................................... $ComputerName
# prtg_device .......................................................... UNUSED
# prtg_group ........................................................... UNUSED
# prtg_probe ........................................................... UNUSED
# prtg_name ............................................................ UNUSED
#
# prtg_windowsdomain ................................................... UNUSED
# prtg_windowsuser ..................................................... UNUSED
# prtg_windowspassword ................................................. UNUSED
#
# prtg_linuxuser ....................................................... $NSUser
# prtg_linuxpassword ................................................... $NSPass
#
# prtg_snmpcommunity ................................................... UNUSED
#
# prtg_version ......................................................... UNUSED
# prtg_url ............................................................. UNUSED
# prtg_primarychannel .................................................. UNUSED
#
###############################################################################

###############################################################################
# Script Parameters

param (
)

###############################################################################
# prtgshell2 Functions pulled from github
# https://github.com/LockstepGroup/prtgshell2

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

###############################################################################
# Start of actual script

# Check for required environment variables passed from PRTG

$RequiredVariables = @('prtg_host',
                       'prtg_linuxuser',
                       'prtg_linuxpassword')

foreach ($var in $RequiredVariables) {
    try {
        $TestVar = Get-ChildItem -Path "Env:\$var" -ErrorAction Stop
    } catch {
        switch ($var) {
            'prtg_host' {
                return Set-PrtgError "Environment variable not found: $var.  Ensure 'Set placeholders as environment values' is enabled on the sensor."
            }
            default {
                $var = $var -replace 'prtg_',''
                return Set-PrtgError "Environment variable not found: $var.  Ensure '$var' is set and 'Set placeholders as environment values' is enabled on the sensor."
            }
        }
    }
}

########################################
# Sensor start

# Allow Invoke-RestMethod to work with self-signed cert
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Get NetScaler IP
$NSAddress = $env:prtg_host

# Set Credentials in variables
$NSPass = $env:prtg_linuxpassword | ConvertTo-SecureString -AsPlainText -Force
$NSCred = New-Object System.Management.Automation.PSCredential($env:prtg_linuxuser,$NSPass)

# Complete REST Query
$HAStatus = Invoke-RestMethod -Uri https://$NSAddress/nitro/v1/stat/hanode -Method Get -Credential $NSCred -ErrorAction Stop | Select-Object -ExpandProperty hanode

# Write results to PRTG
$Channels = ""

if ($HAStatus.hacurstate -eq "UP") {

    $ResultHAStatus = "1"
    $Channels += Set-PrtgResult `
                        -Channel "HA Current State" `
                        -Value $ResultHAStatus `
                        -Unit "Status" `
                        -ShowChart

} else {

    $ResultHAStatus = "2"
    $Channels += Set-PrtgResult `
                        -Channel "HA Current State" `
                        -Value $ResultHAStatus `
                        -Unit "Status" `
                        -ShowChart

}

if ($HAStatus.hacurmasterstate -eq "Primary") {

    $ResultHAMasterState = "1"
    $Channels += Set-PrtgResult `
                        -Channel "HA Master State" `
                        -Value $ResultHAMasterState `
                        -Unit "Status" `
                        -ShowChart

} elseif ($HAStatus.hacurmasterstate -eq "Secondary") {

    $ResultHAMasterState = "2"
    $Channels += Set-PrtgResult `
                        -Channel "HA Master State" `
                        -Value $ResultHAMasterState`
                        -Unit "Status" 1
                        -ShowChart

}

$XmlOutput  = "<prtg>`n"
$XmlOutput += $Channels
$XMLOutput += "</prtg>"
return $XmlOutput
