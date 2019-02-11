<#

.SYNOPSIS

.DESCRIPTION
EveryDay Powershell automation tool represents open source collaboration project with the goal to speed up the day-to-day administration tasks in Microsoft environments.
In the essence, it is just a bundle of functions that will be executed based on user input choice.


#>
Clear-host
Write-Host -ForegroundColor Green "WELCOME to EveryDay Tool, ease of administration is in front of you!"
Write-Host -ForegroundColor Green "You can pick one of the listed options below, backend functions will do the rest for you."
# Start-Sleep 4
Write-Host -ForegroundColor Cyan "

ACTIVE DIRECTORY ADMINISTRATION
-------------------------------

1. Copy AD user right from one AD user to other AD user

DHCP
-------------------------------
2. Search All DHCP Servers for a particular MAC Address lease
3. Search All DHCP Servers for a particular Hostname lease

MAIL
-------------------------------
4. Search for newly created e-mails in the last 5, 10, 30 or more days...
"
#############################################


Try {
    [int]$Number = (Read-Host -Prompt "Chose the task by entering the task number" -ErrorAction Stop)
}
Catch {
    Write-Host "Input accepts only integers, please relaunch the script." -ForegroundColor Red
    Break
}

############################# Functions #######################################################

Function Find-Module {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName
    )
    Process {
        Try {
            import-module -Name $ModuleName -ErrorAction Stop
        }
        Catch {
            $localname = (hostname)
            Write-Host "Required module - $($ModuleName) is not installed on $($localname)" -ForegroundColor Red
            Break
        }
    }
}

Function Get-UserInput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$WriteOut
    )
    process {
        Write-Host "$WriteOut  " -ForegroundColor Green -NoNewline
        Read-Host
    }
}

######################### Switch Part ########################################################################

Switch ($Number) 
{

################ 1. Copy AD user right from one AD user to other AD user ################################################

    1 {
        Find-Module ActiveDirectory
        $ADUserFirst = (read-host -Prompt "Enter the username from which you want to copy the AD rights")
        $Stringtest = [string]::IsNullOrEmpty("$ADUserFirst")
        $ADUserSecond = (read-host -Prompt "Enter the username to which you want to copy the AD rights")
        $Stringtest = [string]::IsNullOrEmpty("$ADUserSecond")
        if ($true -eq $Stringtest) {
            Write-Host "You did not enter any input." -ForegroundColor Yellow
            Break
        }
        try {
            Get-ADPrincipalGroupMembership -Identity $ADUserFirst -ErrorAction Stop | out-null
        }
        catch {
            Write-Host "Cannot find an object with identity $($ADUserFirst) under $env:USERDNSDOMAIN" -ForegroundColor Red
            Break
        }

        $grouplist = (Get-ADPrincipalGroupMembership -Identity $ADUserFirst).name
                   foreach ($group in $grouplist) {
                                                    Add-ADGroupMember -Identity "$group" -Members "$ADUserSecond"
                                                  }
       
        }

################ 2. Search All DHCP Servers for a particular MAC Address lease ############################################
     
     2 {

    $MACAddress = (read-host -Prompt "Enter the MAC address in the following format: XX-XX-XX-XX-XX-XX ")
    $Stringtest = [string]::IsNullOrEmpty("$MACAddress")
     if ($true -eq $Stringtest) {
            Write-Host "You did not enter any input." -ForegroundColor Yellow
            Break
        }

    $IDDomain = Get-ADDomainController | Select Partitions

    Get-ADObject -SearchBase $IDDomain.Partitions[3] -Filter 'ObjectClass -eq "dhcpclass"' | Select-Object Name | 
                             ForEach-Object {
                                             Get-DhcpServerv4Scope -ComputerName $_.Name | Get-DhcpServerv4Lease -ComputerName $_.Name | Where-Object -property clientid -eq "$MACAddress"
                                            }
      }

################ 3. Search All DHCP Servers for a Hostname lease ################################################
   
    3 {

    $HostName = (read-host -Prompt "Enter the Hostname (It can be just a part of the name) for which you want to find the leased IP address")
    $Stringtest = [string]::IsNullOrEmpty("$HostName")
     if ($true -eq $Stringtest) {
            Write-Host "You did not enter any input." -ForegroundColor Yellow
            Break
        }

    $IDDomain = Get-ADDomainController | Select Partitions

    Get-ADObject -SearchBase $IDDomain.Partitions[3] -Filter 'ObjectClass -eq "dhcpclass"' | Select-Object Name | 
                             ForEach-Object {
                                             Get-DhcpServerv4Scope -ComputerName $_.Name | Get-DhcpServerv4Lease -ComputerName $_.Name | Where-Object -property Hostname -like "*$HostName*"
                                            }
      }

################# 4. Search for newly created e-mails in the last 5, 10, 30 or more days... #####################################
    
    4 {

$AddDays = (Get-UserInput -WriteOut "How many days in the past do you want to search? Enter the number of days")
$When = ((Get-Date).AddDays(-$AddDays)).Date
$UserSearch = Get-ADUser -Filter {whenCreated -ge $When -and enabled -eq $true} -Properties * | Where-Object {$_.proxyaddresses -like "SMTP:*"} | select -expand proxyaddresses
$UserSearch | Select-String -Pattern "SMTP" -CaseSensitive
     }


################################# Default ###################################################

    Default {
        Write-Host "Number that you entered is out of scope or input is empty." -ForegroundColor Red
            }

}