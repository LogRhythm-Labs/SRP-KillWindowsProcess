# Copyright 2016 LogRhythm Inc.   
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.  You may obtain a copy of the License at;
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

# Set up a trap to properly exit on terminating exceptions
trap [Exception] {
	write-error $("TRAPPED: " + $_)
	exit 1
	}

$TargetHost = $args[0]

# Determine if process name or PID was passed and set up proper variables
# If PID is from Win 2008, it will be in hex, so convert to decimal before passing along

if($args[1] -match '^0x\w+$') {
$HexProcess = $args[1]
$TargetProcess = [Convert]::ToInt32($HexProcess,16)
$filter = "ProcessID"
$operator = "="
$wildcared = ""
}

elseif($args[1] -match '^\d+$') {
$TargetProcess = $args[1]
$filter = "ProcessID"
$operator = "="
$wildcared = ""
}

else {
$filter = "Name"
$operator = "LIKE"
$TargetProcess = $args[1]
$wildcard = "%"
}


# Get local hostname and IP to determine whether action will be local or remote
$localHost = [System.Net.Dns]::GetHostName()
$localIP = [System.Net.Dns]::GetHostAddresses("$localHost")

# If local, or no credentials passed, build appropriate WMI object
# if it is remote and no cred were passed, commands will be run under current credentials
if($localHost -like $TargetHost -OR $localIP -like $TargetHost -OR -not $args[2]) {
$process = Get-WMIObject -Class Win32_Process -Filter "$filter $operator '$TargetProcess$wildcard'" -ComputerName "$TargetHost" | % {$_.Terminate() }
				}

# If remote and alternative credentials passed, build modified WMI object with credentials
else {
$username = $args[2]
$password = $args[3]
$securePassword = new-Object System.Security.SecureString
$password.ToCharArray() | % { $securePassword.AppendChar($_) }
$credential = New-Object -typename System.Management.Automation.PSCredential -argumentlist "$username",$securePassword
$process = Get-WMIObject -Class Win32_Process -Filter "$filter $operator '$TargetProcess$wildcard'" -ComputerName "$TargetHost" -Credential $credential | % {$_.Terminate() }
}


# Handle any non-terminating exceptions
if(-not $?)	{
		Write-Error "Unable to get WMI Object"
		exit 1
		}

Write-Host "Process $TargetProcess on $TargetHost killed"
