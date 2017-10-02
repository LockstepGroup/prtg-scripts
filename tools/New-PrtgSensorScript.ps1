#Requires
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$True,Position=0)]
    [string]$ScriptName,

    [Parameter(Mandatory=$True,Position=1)]
    [string]$OutputDirectory,

    [Parameter(Mandatory=$True,Position=2)]
    [string]$AuthorEmail,

    [Parameter(Mandatory=$True,Position=3)]
    [string]$Description
)

# We'll use these to pull down the most recent version of Set-PrtgError and New-PrtgResult from github
$PrtgShellRepo    = 'LockstepGroup/prtgshell2'
$RawContentUrl    = 'https://raw.githubusercontent.com/' + $PrtgShellRepo
$SetPrtgErrorUrl  = $RawContentUrl + '/master/src/cmdlets/Set-PrtgError.ps1'
$NewPrtgResultUrl = $RawContentUrl + '/master/src/cmdlets/New-PrtgResult.ps1'

# Formulate Date
$Month = Get-Date -Format MM
$Year  = Get-Date -Format yyyy

# Bootstrap variables
$FullOutput = ""

# Output Path
try {
    $OutputDirectory = Resolve-Path $OutputDirectory
} catch {
    Throw "OutputDirectory not valid"
}
$OutputPath = Join-Path -Path $OutputDirectory -ChildPath "$ScriptName`.ps1"


$Header = @"
###############################################################################
#
# ScriptName: $ScriptName
# Auther: $AuthorEmail
# Last Updated: $Month $Year
# $Description
#
###############################################################################
"@

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


$FullOutput += $Header

$FullOutput | Out-File -FilePath $OutputPath