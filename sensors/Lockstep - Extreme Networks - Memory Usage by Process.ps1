###############################################################################
#
# ScriptName: Lockstep - Extreme Networks - Memory Usage by Process
# Auther: brian.addicks@lockstepgroup.com
# Last Updated: 10 2017
# Pulls memory usage by process from an Exos switch
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
# prtg_linuxuser .................................................. $SwitchUser
# prtg_linuxpassword .............................................. $SwitchPass
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

# Check for an load required modules

$RequiredModules = @('Posh-SSH') 

foreach ($module in $RequiredModules) {
    try {
        Import-Module $module -ErrorAction Stop | Out-Null
    } catch {
        return Set-PrtgError "Could not load required module: $module"
    }
}

########################################
# Sensor start

# Used for error tracking
$CurrentStep = $null

try {
    ########################################
    # Get the info from the switch

    # Create credential object
    $DevicePass = $env:prtg_linuxpassword | ConvertTo-SecureString -AsPlainText -Force
    $DeviceCred = New-Object System.Management.Automation.PSCredential($env:prtg_linuxuser,$DevicePass)

    # Connect to switch
    $CurrentStep = 'Create SSH Session: ' + $env:prtg_host
    $SshSession = New-SshSession -ComputerName $env:prtg_host -Credential $DeviceCred -AcceptKey -Force -ErrorAction Stop

    # Run Command
    $CurrentStep = 'Run SSH Command' + ($SshSession.SessionId)
    $Command = 'show memory'
    $CommandResults = Invoke-SSHCommand -SessionId $SshSession.SessionId -Command $Command

    # Disconnect SSH Session
    $CurrentStep = 'Remove SSH Session'
    Remove-SSHSession -SessionId $SshSession.SessionId | Out-Null

    ########################################
    # Process results
    $Rx = [regex]'\ (?<process>[a-z0-9]+?)\ +(?<usage>\d+)'
    $Matches = $Rx.Matches($CommandResults.Output)

    $Channels = ""
    foreach ($match in $Matches) {
        $Channels += Set-PrtgResult `
                         -Channel $match.Groups['process'].Value `
                         -Value $match.Groups['usage'].Value `
                         -Unit "Kbytes" `
                         -ShowChart
    }

    $XmlOutput  = "<prtg>`n"
    $XmlOutput += $Channels
    $XMLOutput += "</prtg>"
    return $XmlOutput
} catch {
    return Set-PrtgError ('Error: ' + $CurrentStep + ': ' + $Error[0].Exception.Message)
}