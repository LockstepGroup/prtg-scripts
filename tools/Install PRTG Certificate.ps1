###############################################################################
###############################################################################
#
# convert pfx to PRTG's necessary formats for SSL support.
# jsanders@lockstepgroup.com
# 3/27/2016 (happy easter)
#
# if you run this on a PRTG server, and PRTG is installed to the C: drive
# then it should just drop the output files in the current directory.
#
# if prtg is installed on a different drive, you might need to update the path
# to openssl below.
#
# if i ever get around to adding error checking to this, i'll make that auto-
# magic
#
# future things to add:
# accept input file rather than requiring it come from the store
# be more flexible with store inputs
# just LOTS more error checking
#
###############################################################################
###############################################################################


[CmdletBinding()]
param (
	[parameter(Mandatory=$true)]
	[string]$TargetCertificateName,
	[string]$OutputCertificate = "prtg.crt",
	[string]$OutputCACertificate = "root.pem",
	[string]$OutputClientKey = "prtg.key"
)



###############################################################################
# function definitions

function MakeRandomString ($length = 10) { ([char[]](97..122) | sort {Get-Random})[0..$length] -join '' }

###############################################################################
# might want some error checking on this

$InterimPFXFile = "myexport.pfx"

if ((Get-WmiObject -Class Win32_Processor -Property AddressWidth | Select-Object -ExpandProperty AddressWidth -First 1) -eq 64) {
	$PRTGInstallRoot = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Paessler\PRTG Network Monitor").exepath
} else {
	$PRTGInstallRoot = (Get-ItemProperty "HKLM:\SOFTWARE\Paessler\PRTG Network Monitor").exepath
}

$PathToOpenSSL = Join-Path $PRTGInstallRoot "openssl.exe"

if (!(Test-Path $PathToOpenSSL)) {
	Write-Error ("Unable to locate OpenSSL at path " + $PathToOpenSSL)
	exit
}

$TemporaryKeyFile = "temp_" + (MakeRandomString) + ".dat"

###############################################################################
# get the certificate from the store, and export it

$ExportPasswordPlaintext = MakeRandomString

$ExportPassword = ConvertTo-SecureString -String $ExportPasswordPlaintext -Force –AsPlainText

$TargetCertificate = Get-ChildItem Cert:\LocalMachine\my | 
	Where-Object { $_.DnsNameList -contains $TargetCertificateName }

if (!$TargetCertificate) {
	Write-Error ("Unable to locate certificate matching DNS name " + $TargetCertificateName)
	exit
}
	
Write-Host "Performing operations against certificate:"
Write-Host (" - Subject: " + $TargetCertificate.Subject)
Write-Host (" - Issuer: " + $TargetCertificate.Issuer)
Write-Host (" - Validity: " + $TargetCertificate.NotBefore + " - " + $TargetCertificate.NotAfter)
Write-Host (" - Has key? " + $TargetCertificate.HasPrivateKey)

if (!$TargetCertificate.HasPrivateKey) {
	write-error "NO PRIVATE KEY FOUND!"
	exit
}

$ExportedCertificate = Export-PfxCertificate –Cert $TargetCertificate –FilePath $InterimPFXFile -Password $ExportPassword

###############################################################################
# use openssl to convert the exported pfx to the right format for PRTG
# might want some error checking on this

Write-Host (" - Writing client certificate (" + $OutputCertificate + ") ...")
& $PathToOpenSSL @("pkcs12", "-in", $InterimPFXFile, "-out", $OutputCertificate, "-clcerts", "-nodes", "-nokeys", "-passin", ("pass:" + $ExportPasswordPlainText)) 2>&1 | Out-Null

Write-Host (" - Writing root certificate (" + $OutputCACertificate + ") ...")
& $PathToOpenSSL @("pkcs12", "-in", $InterimPFXFile, "-out", $OutputCACertificate, "-cacerts", "-nodes", "-nokeys", "-passin", ("pass:" + $ExportPasswordPlainText)) 2>&1 | Out-Null

Write-Host " - Getting encrypted private key..."
& $PathToOpenSSL @("pkcs12", "-in", $InterimPFXFile, "-out", $TemporaryKeyFile, "-nocerts", "-nodes", "-passin", ("pass:" + $ExportPasswordPlainText)) 2>&1 | Out-Null

Write-Host (" - Writing decrypted private key (" + $OutputClientKey + ") ...")
& $PathToOpenSSL @("rsa", "-in", $TemporaryKeyFile, "-out", $OutputClientKey) 2>&1 | Out-Null

###############################################################################
# cleanup temp files

Remove-Item $InterimPFXFile
Remove-Item $TemporaryKeyFile

###############################################################################
# cert/key verification

$a = & $PathToOpenSSL @("x509", "-noout", "-modulus", "-in", $OutputCertificate) 2> $null
$b = & $PathToOpenSSL @("rsa", "-noout", "-modulus", "-in", $OutputClientKey) 2> $null

if ($a -eq $b) { "Certificate and key match. Congrats!" }