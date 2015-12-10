###############################################################################
#
# ScriptName: Lockstep - Windows Server - Dhcp Scope Statistic.ps1
# Auther: eshoemaker@lockstepgroup.com
# Last Updated: Q4 2015
# Monitors DHCP scope usage for Windows Server 2012r2.
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
# prtg_linuxuser ....................................................... UNUSED
# prtg_linuxpassword ................................................... UNUSED
#
# prtg_snmpcommunity ................................................... UNUSED
#
# prtg_version ......................................................... UNUSED
# prtg_url ............................................................. UNUSED
# prtg_primarychannel .................................................. UNUSED
#
###############################################################################

###############################################################################
#                                 REQUIREMENTS
#
# Set placeholders as environment variables must be set
# DhcpServer Powershell Module must be installed on Prtg Probe
# DHCP server must be running Windows Server 2012r2
#
###############################################################################

###############################################################################
#                                     TODO
#
#
###############################################################################

###############################################################################
# Script Parameters

[CmdletBinding()]   # this adds the ability to use -Verbose and -Debug
param (
    #[string]$Computername="Empty"
    [Parameter(Mandatory=$False,Position=0)] # Position means you don't have to declare the parameter name when you call it.  ie: script.s1 mydhcpserver, instead of script.ps1 -computername mydhcpserver
    [string]$Computername,                   # We don't really need to declare this as anything special, we'll just check for null
    
    [Parameter(Mandatory=$False)]
    [array]$ScopeId
)

###############################################################################
# Function for PRTG friendly errors on module failure

function Test-ModuleImport ([string]$Module) {
    Import-Module $Module -ErrorAction SilentlyContinue
    if (!($?)) { return $false } `
        else   { return $true }
}

###############################################################################
# PRTG Error function
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
# Check for DhcpServer Module

$Import = Test-ModuleImport DhcpServer

if (!($Import)) {
return @"
<prtg>
  <error>1</error>
  <text>DhcpServer module not loaded: ensure the module is visible for 32-bit PowerShell.</text>
</prtg>
"@
}

###############################################################################
# Set ComputerName to Device if nothing was specified
if (!($ComputerName)) {
    $Test = Get-Item env:prtg_host -ErrorAction silentlyContinue
    if (!($Test.Value)) {
        return Set-PrtgError "prtg_host not specified.  Verify it is configured and 'Set placeholders as environment values' is enabled."
    } else {
        $ComputerName = "$($env:prtg_host)"
    }
}

###############################################################################
# Start the script

#If ($Computername -ne "Empty"){
If ($Computername) {                                                              # just checking to see if it exists
    $AllResults="<prtg>"
    try { # this block is to test the dhcp server, and return a friendly error if something doesn't work
        $DhcpParams = @{} #this will create the parameter block for the dhcp calls, this allows us to add the scopeid only if it's specified.
        $DhcpParams.ComputerName = $ComputerName
        if ($ScopeId) {
            $DhcpParams.ScopeId = $ScopeId
        }
        $DHCPStatistics = Get-DhcpServerv4ScopeStatistics @DhcpParams
        $DHCPScopeInfo  = Get-DHcpServerv4Scope @DhcpParams
    } catch {
        return Set-PrtgError $_.Exception
    }
    Foreach ($Scope in $DHCPStatistics){
        $ThisScopeID     = $Scope.ScopeID.IPAddressToString
        $ScopeName       = ($DHCPScopeInfo | ? { $_.ScopeID -eq $ThisScopeID} ).Name
        $PercentageInUse = "{0:N0}" -f $Scope.PercentageInUse
        $AddressesFree   = $Scope.Free
        $tempobj = "
            <result>
            <channel>$ScopeName (Percentage Used)</channel>
            <value>$PercentageInUse</value>
            <Unit>Percent</Unit>
            <LimitMaxError>95</LimitMaxError>
            <LimitMaxWarning>90</LimitMaxWarning>
            <LimitMinWarning></LimitMinWarning>
            <LimitMinError></LimitMinError>
            <LimitMode>1</LimitMode>
            </result>

            <result>
            <channel>$ScopeName (Free IP Addresses)</channel>
            <value>$AddressesFree</value>
            <CustomUnit>IP's</CustomUnit>
            <LimitMaxError></LimitMaxError>
            <LimitMaxWarning></LimitMaxWarning>
            <LimitMinWarning>15</LimitMinWarning>
            <LimitMinError>5</LimitMinError>
            <LimitMode>1</LimitMode>
            </result>
        "
        $AllResults += $tempobj
    }
    $AllResults += "
        <Text>DHCP Scope Statistics</Text>
        </prtg>
    "
    return $AllResults  # added return so the script stops
} else {                # returns a prtg readable error if there's no computername specified
    return Set-PrtgError "No ComputerName Specified."
}