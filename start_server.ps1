function Get-FirewallRule {
    <#
    .DESCRIPTION
        Get full information of the firewall rule and whether it is found and valid
        Optional Check to validate if the firewall rule's property matches with your Check hashtable before returning

    .PARAMETER DisplayName
        The display name of the firewall rule (Cannot be NULL or Empty)

    .PARAMETER Check
        The hashtable of key and value pairs of the firewall rule (Optional)

    .INPUTS
        String
        HashTable{key, value}

    .OUTPUTS
        Hashtable {
            rule: MSFT_NetFirewallRule (if found)
            found: Boolean
            valid: Boolean (if passed $Check, given $True by default if no $Check is passed in)
        }
    #>

    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $DisplayName = "SSH Port",
        [hashtable] $Check
    )

    # This only consist basic information
    $firewall_rule = Get-NetFirewallRule | Where {$_.DisplayName -eq $DisplayName}

    $return_value = @{
        rule = $firewall_rule
        found = if ($firewall_rule) {$True} else {$False}
        invalid = $False
    }

    if (-not $return_value.found) {
        return $return_value
    }
    
    if ($Check) {
        $firewall_port_info = $firewall_rule | Get-NetFirewallPortFilter

        $properties = @{}

        foreach ($property in $firewall_rule.PSObject.Properties) {
            if ($properties.ContainsKey($property.Name)){
                continue
            }
            $properties.Add($property.Name, $property.Value)
        }

        foreach ($property in $firewall_port_info.PSObject.Properties) {
            if ($properties.ContainsKey($property.Name)){
                continue
            }
            $properties.Add($property.Name, $property.Value)
        }

        foreach ($key in $Check.keys) {
            $expected_property_value = $Check[$key]
            if ($properties[$key] -ne $expected_property_value) {
                $error = "Property '$key' in firewall does not have the value of '$expected_property_value' "
                $return_value.invalid = $error
                return $return_value
            }
        }
    }
    
    return $return_value
}

function Cleanup {
    param (
        [ValidateNotNullOrEmpty()]
        [string]$Service = "sshd",
        [Parameter(Mandatory)]
        [string]$Firewall_Name
    )

    $Service_Info = Get-Service $Service

    if ($Service_Info.Status -eq "Running") {
        Stop-Service $Service
        write-output "Stopping $Service"
    }

    $firewall_rule_info = Get-FirewallRule -DisplayName $firewall_rule_name

    if ($firewall_rule_info.found -and $firewall_rule_info.rule.Enabled -eq "True") {
        Set-NetFirewallRule -InputObject $firewall_rule_info.rule -Enabled False
        write-output "Disabled Firewall '$firewall_rule_name'"
    }
}

$ErrorActionPreference = 'Stop'

$firewall_rule_name = "SSH Port" # The only user configurable variable

trap {
    Cleanup sshd -Firewall_Name $firewall_rule_name
}

$is_available = Get-Service sshd
# Check the OpenSSH Server is installed
if ($is_available.length -eq 0) {
    write-host "sshd is not installed. please install in Settings > System > Optional features"
    exit
} 

$is_running = $is_available | Select -property Status

# Check the OpenSSH Server is already running
if ($is_running.Status -eq "Running" ) {
    write-host "sshd is already running. exiting now"
    exit
}

${is_disabled} = $is_available | Select -property starttype

if ($is_disabled.starttype -eq "Disabled") {
    write-host "sshd startup type is disabled. Please set it to 'Automatic' or 'Manual'."
    write-host "You may run the following command to set it 'Manual'."
    write-host "Set-Service sshd -StartupType Manual"
    exit
}

# Start terminating sshd after any interuption of the script execution
write-host Starting sshd

Start-Service sshd

$is_running = Get-Service sshd | Select -property Status

if ($is_running.Status -ne "Running") {
    write-host "Something went wrong when starting sshd service. Please check the script. Exit now"
    exit
}

# Automatically assumes the sshd_config file is located in the ssh folder in Program Data.
$config_path = "$env:ProgramData\ssh\sshd_config"
$config_lines = Get-Content -path $config_path

if (-not $config_lines) {
    write-host "Cannot find port number in sshd_config. Might not be able to find sshd_config in $config_path"
    throw 1
}

$port = @($config_lines) -like "Port *"
$port_num = $port.Substring(5)

$firewall_property = @{
    DisplayName = $firewall_rule_name
    LocalPort = $port_num
    Protocol = "TCP"
    Direction = "Inbound"
    EdgeTraversalPolicy = "Block"
}

$firewall_rule_info = Get-FirewallRule -DisplayName $firewall_rule_name -Check $firewall_property

if ($firewall_rule_info.found) {
    if ($firewall_rule_info.invalid) { # Rule with $firewall_rule_name is found but property do not match. Need to use another $firewall_rule_name
        write-output "Found existing firewall rule with display name '$firewall_rule_name' that does not match required properties."
        write-output $firewall_rule_info.invalid
        write-output "Please choose another firewall name used in variable 'firewall_rule_name'"
        throw 1
    }
    else { 
        Set-NetFirewallRule -InputObject $firewall_rule_info.rule -Enabled True
    }
}
else { # No rule found. We need to create based on our required property.
    New-NetFirewallRule @firewall_property
    $actual_display_name = $firewall_property.DisplayName # In case, you changed the variable above.
    write-output "Created new rule named '$actual_display_name'"
}

Write-output "Server started at Port '$port_num'"
Read-Host -Prompt "Press Enter to stop the Server"

Cleanup sshd -Firewall_Name $firewall_rule_name