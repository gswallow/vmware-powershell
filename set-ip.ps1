# Load enough VB to be able to create dialog boxes.
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null

# Get the active network interface object
$iface = Get-WmiObject win32_networkadapterconfiguration -filter "ipenabled = 'true'"

# Get the Computer's name
$sys = Get-WmiObject win32_computersystem

# Create friendlier variables from the WMI Object.
$origaddr = $iface.IPaddress[0]
$origmask = $iface.IPSubnet[0]
$origrtr = $iface.DefaultIPGateway[0]
$origdns1 = $iface.DNSServerSearchOrder[0]
$origdns2 = $iface.DNSServerSearchOrder[1]
$origdomain = $iface.DNSDomain
$orighostname = $sys.Name

function askUserForNetworkSettings { 
  $addr = [Microsoft.VisualBasic.Interaction]::InputBox("Please supply an IP address", "IP Address", "$origaddr")
  $mask = [Microsoft.VisualBasic.Interaction]::InputBox("Please supply a netmask", "Netmask", "$origmask")
  $rtr = [Microsoft.VisualBasic.Interaction]::InputBox("Please supply a default gateway", "Gateway", "$origrtr")
  $dns1 = [Microsoft.VisualBasic.Interaction]::InputBox("Please supply a primary DNS server", "DNS", "$origdns1")
  $dns2 = [Microsoft.VisualBasic.Interaction]::InputBox("Please supply a secondary DNS server", "DNS", "$origdns2")
  $shortname = [Microsoft.VisualBasic.Interaction]::InputBox("Please supply the short host name", "Hostname", "$orighostname")
  $domain = [Microsoft.VisualBasic.Interaction]::InputBox("Please supply the DNS domain name", "Domainname", "$origdomain")
  return $addr, $mask, $rtr, $dns1, $dns2, $shortname, $domain
}

if (!(  Test-Path c:\.addressed )) { 
  do { 
    ($addr, $mask, $rtr, $dns1, $dns2, $shortname, $domain) = askUserForNetworkSettings
    $sso = $dns1, $dns2
    $res = [Microsoft.VisualBasic.Interaction]::MsgBox("You chose to set the following:`n`n  Address: $addr`n  Netmask: $mask`n  Gateway: $rtr`n  DNS Servers: $dns1, $dns2`n  Hostname: $shortname`n  Domain Name: $domain", 4, "Confirm?")
    Write-Host $res
    if ($res -eq "Yes") {
      if ( ! $iface.EnableStatic($addr,$mask)) {
        continue
      }
      if ( ! $iface.SetGateways($rtr,1) ) { 
        continue
      }
      break
    }
  } while ($true)

  $res = 0
  $rv = $iface.SetDNSDomain($domain)
  $res = $res + $rv.ReturnValue
  $rv = $iface.SetDNSServerSearchOrder($sso)
  $res = $res + $rv.ReturnValue
  $rv = $sys.Rename($shortname)
  $res = $res + $rv.ReturnValue

  if ($res -eq 0) {
    # Success!  Touch c:\.addressed so this doesn't run again.
    New-Item c:\.addressed -Type File
    $hidden = [io.fileattributes]::hidden
    Set-ItemProperty -Path C:\.addressed -Name attributes -Value ((Get-ItemProperty -Path C:\.addressed).attributes -BXOR $hidden)
  } else {
    [Microsoft.VisualBasic.Interaction]::MsgBox("Something went wrong renaming your host ($res).  Please reboot.", 0, "Aww Shucks!")
  }
}  
