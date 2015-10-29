Function Invoke-PivotFinder {
<#
.SYNOPSIS
This script performs enumeration on a list of potential pivot hosts to identify if any of the hosts are able to connect by way of ping 
to any of the target hosts, in addition the script optionally check for a number of other indicators on the pivot host to identify
 connectivity such as RDP Saved Connection profiles, Putty saved sessions, Cygwin SSH known hosts, and in the future possibly others.

.DESCRIPTION
Invoke-PivotFinder performs WMI queries on the remote hosts to determine if they candidates for being a pivot to one or more targets.
Targets and pivots can be defined in the 'pivots' and 'targets' parameters, respectively. The function will automatically detect if
the provided addresses are in a file (newline seprated), CIDR format, range of IP addresses, or comma seprated individual IP addresses.

The Invoke-PivotFinder script will verify that the current session has local admin privileges on the remote pivot hosts before beginning 
enumeration on any one host. Connectivity is determined by remotely invoking ping commands on the pivot hosts and observing the status.

.PARAMETER Pivots
String: list of targets either - a filename, a CIDR, an IP address range, or invidiual addresses comma separated

.PARAMETER Targets
String: list of targets either - a filename, a CIDR, an IP address range, or invidiual addresses comma separated

.PARAMETER CheckPutty
Switch: If enabled, Invoke-PivotFinder will access the remote registry of the pivot host to identify any saved connection profiles matching the targets

.PARAMETER CheckCygwin
Switch: If enabled, Invoke-PivotFinder will access the remote file system of the pivot host and identify any and all users withost h SSH known hosts
that match the targets

.PARAMETER CheckRDP
Switch: If enabled, Invoke-PivotFinder will access the remote registry to identify saved connection profiles and identify if any are targets.

.PARAMETER Timeout
Integer: Timeout value is set for all pings remotely invoked on pivot hosts to remote targets.

.EXAMPLE

Attempt to remotely ping every host in .\SCADA_hosts from the (potential) pivot hosts: 10.1.3.37,10.1.4.37,10.42.45.2
Invoke-PivotFinder -Pivots 10.1.3.37,10.1.4.37,10.42.45.2 -Targets .\SCADA_hosts

.EXAMPLE

Attempt to remotely ping every host in .\SCADA_hosts and check them each for RDP profiles, Cygwin SSH, and Putty profiles from the hosts on network: 10.13.37.0/24
Invoke-PivotFinder -Pivots 10.13.37.0/24 -Targets .\SCADA_hosts -CheckPutty -CheckRDP -CheckCygwin 


.NOTES

.LINK
CIDR2IP:
https://github.com/darkoperator/Posh-SecMod/blob/master/Discovery/Discovery.psm1

#>
	param(
        [Parameter (Mandatory=$true)][String]$Targets,
        [Parameter (Mandatory=$true)][String]$Pivots,
        [Parameter (Mandatory=$false)][Switch]$CheckPutty,
        [Parameter (Mandatory=$false)][Switch]$CheckCygwin,
        [Parameter (Mandatory=$false)][Switch]$CheckRDP,
        [Parameter (Mandatory=$false)][Integer]$Timeout
    )
    
    # Mercilessly stolen from 
    #https://github.com/darkoperator/Posh-SecMod/blob/master/Discovery/Discovery.psm1
    begin {
	   function New-IPv4Range
        {
                <#
                .Synopsis
                    Generates a list of IPv4 IP Addresses given a Start and End IP.
                .DESCRIPTION
                    Generates a list of IPv4 IP Addresses given a Start and End IP.
                #>
                param(
                    [Parameter(Mandatory=$true,
                               ValueFromPipelineByPropertyName=$true,
                               Position=0)]
                               $StartIP,
                               
                    [Parameter(Mandatory=$true,
                               ValueFromPipelineByPropertyName=$true,
                               Position=2)]
                               $EndIP          
                )
                
                # created by Dr. Tobias Weltner, MVP PowerShell
                $ip1 = ([System.Net.IPAddress]$StartIP).GetAddressBytes()
                [Array]::Reverse($ip1)
                $ip1 = ([System.Net.IPAddress]($ip1 -join '.')).Address
    
                    $ip2 = ([System.Net.IPAddress]$EndIP).GetAddressBytes()
                    [Array]::Reverse($ip2)
                    $ip2 = ([System.Net.IPAddress]($ip2 -join '.')).Address
    
                    for ($x=$ip1; $x -le $ip2; $x++) {
                        $ip = ([System.Net.IPAddress]$x).GetAddressBytes()
                        [Array]::Reverse($ip)
                        $ip -join '.'
                    }
            }


            function New-IPv4RangeFromCIDR 
            {
                <#
                .Synopsis
                    Generates a list of IPv4 IP Addresses given a CIDR.
                .DESCRIPTION
                    Generates a list of IPv4 IP Addresses given a CIDR.
                #>
                param(
                    [Parameter(Mandatory=$true,
                               ValueFromPipelineByPropertyName=$true,
                               Position=0)]
                               $Network
                )
                # Extract the portions of the CIDR that will be needed
                $StrNetworkAddress = ($Network.split("/"))[0]
                [int]$NetworkLength = ($Network.split("/"))[1]
                $NetworkIP = ([System.Net.IPAddress]$StrNetworkAddress).GetAddressBytes()
                $IPLength = 32-$NetworkLength
                [Array]::Reverse($NetworkIP)
                $NumberOfIPs = ([System.Math]::Pow(2, $IPLength)) -1
                $NetworkIP = ([System.Net.IPAddress]($NetworkIP -join ".")).Address
                $StartIP = $NetworkIP +1
                $EndIP = $NetworkIP + $NumberOfIPs
                # We make sure they are of type Double before conversion
                If ($EndIP -isnot [double])
                {
                    $EndIP = $EndIP -as [double]
                }
                If ($StartIP -isnot [double])
                {
                    $StartIP = $StartIP -as [double]
                }
                # We turn the start IP and end IP in to strings so they can be used.
                $StartIP = ([System.Net.IPAddress]$StartIP).IPAddressToString
                $EndIP = ([System.Net.IPAddress]$EndIP).IPAddressToString
                New-IPv4Range $StartIP $EndIP
            }
        Function IP-Regex {
            param($ip)
            if($ip -match '[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]') {
                return $true
            }
            else {
                return $false
            }
        }
        # Function to evaluate whether the addresses given are either a file (newline separated list), a range, or a comma separated list of final_addresses
        Function Get-EvalAddress {
            param ([Parameter(Mandatory=$true)[string] $addresses)
            
            # Check to see if $targets is a newline separated file we can read from
            if($target_file = Is-File $targets) {
                $temp_addresses = Get-Content $addresses
                foreach($address in $temp_addresses) {
                    if(IP-Regex $target) {
                        $final_addresses = $final_targets + $target
                    }
                    else {
                        Write-Host "$target is not a valid IP address"
                    }
                }  
            }   
            # Manage if CIDR is detected from $targets (kind of a crappy check)
            else if ($addresses -match "*/*") 
            {
                $final_addresses = New-IPv4RangeFromCIDR -Network $CIDR
            }
            # Manage if range is detected from $tagets (kind of a crappy check)
            else if ($addresses -match "-") {
                $rangeips = $Range.Split("-")
                $final_addresses = New-IPv4Range -StartIP $rangeips[0] -EndIP $rangeips[1]
            }
            # Otherwise lets just split by commas and be over with it
            else {
                $final_addresses = $targets -split ","
            }
            return $final_address
        }
        
        if(-not $Timeout) {
            $Timeout = 5   # is this MS or S?
        }

        $final_targets = Get-EvalAddress -addresses $targets
        $final_pivots = Get-EvalAddress -addresses $pivots
        
    } # end of beginning
    
    # foreach target attempt to login with WMI to ensure we can (avoid multiple login failures!)
    process {
        $results = @{}
        foreach ($pivot in $final_pivots) {
            $results.Add($pivot, @())
        }
        # Helper functions
        #Invoke-RemotePing -host -timeout returns result 0 if success
        # todo: check for exceptions that might be useful to know, for now just record sucess
        Invoke-RemotePing {
            param([string]$remotehost,[string]$target, [integer]$timeout)
            $ping = (Get-WmiObject -Query "select * from Win32_Pingstatus where Address='$target' and timeout = $timeout" -ComputerName $remotehost|select Statuscode)
            return $ping
        }
        Invoke-RDPProfileCheck {
            param([string]$remotehost,[string]$target, [switch]$allusers)
            # unable to determine if there is an easy way to work with PSDrive for registry, if so most of the code
            # is already written for this check in Get-Computerdetails.ps1
        }
        Invoke-PuttyCheck {
            param([string]$remotehost,[string]$target, [switch]$allusers)
            #This should be more or less the same, remote registry access without the remote registry service is needed or should be researched
            # The check is located in meterpreter scripts/enum_putty.rb for reference

        }
        Invoke-CygwinCheck {
            param([string]$remotehost,[string]$target, [switch]$allusers)
            # CygWin likely installs a registry key for its base 
            # Optionally pull SSH keys identified on the machine if a pivot is identified
        }
        # The pivot checking loop
        foreach ($pivot in $final_pivots) {
            # Check to see if we can even login to the pivot through WMI (requires LA or equiv)
            # if so we go in order depending on options: ping, rdp profiles, putty saved sessions, and finally cygwin .ssh known_hosts
            # Note: there may be a better/more reliable LA check, but this covers most use cases if they can access WMI remotely
            if((Invoke-RemotePing -remotehost $pivot -target 127.0.0.1 -timeout 10) -eq 0) {
                # The pingloop
                foreach ($target in $final_targets) {
                    if((Invoke-RemotePing -remotehost $pivot -target $target -timeout $timeout) -eq 0) {
                        Write-Host "Ping pivot detected: $pivot -> $target"
                        $results[$pivot] = $results[$pivot] + $target
                    }
                }
                # The RDP Connection profile loop
                foreach ($target in $final_targets) {
                    Invoke-RDPProfileCheck -remotehost $pivot -target $target
                }
                # Putty saved session
                foreach ($target in $final_targets) {
                    Invoke-PuttyCheck -remotehost $pivot -target $target
                }
                # Cygwin .ssh known_hosts
                foreach ($target in $final_targets) {
                    Invoke-CygwinCheck -remotehost $pivot -target $target
                }
            }
            else {
                Write-Host "[-] Cannot login to pivot host: $pivot"
            }
        }
    } #end process
    end {
        # find a pretty way to present this
        $results | Format-Table -Auto    
    }
}