<#

.SYNOPSIS

.DESCRIPTION
EveryDay Powershell automation tool represents an open source collaboration project with the goal to speed up the day-to-day administration tasks in Microsoft environments.
In the essence, it is just a bundle of functions that will be executed based on user input choice.


#>
Clear-host
Write-Host -ForegroundColor Green "WELCOME to EveryDay Tool, ease of administration is in front of you!"
Write-Host -ForegroundColor Green "You can pick one of the listed options below, backend functions will do the rest for you."
Write-Host -ForegroundColor Cyan "
ACTIVE DIRECTORY ADMINISTRATION
-------------------------------

1. Invoke replication against all of the domain controllers in the forest.
2. Invoke DNS replication.
3. Check group membership.
4. Find inactive computers.
5. List sites and site subnets.
6. Clone user group membership from one to another user.
7. Get computer site.
8. Test secure LDAP.
"
#############

Try {
    [int]$Number = (Read-Host -Prompt "Chose the task by entering the task number" -ErrorAction Stop)
}
Catch {
    Write-Host "Input accepts only integers, please relaunch the script." -ForegroundColor Red
    Break
}
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
        Write-Host "$WriteOut  " -ForegroundColor Magenta -NoNewline
        Read-Host

    }
}
Function Find-EmptyString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [AllowEmptyString()]
        [string]$VariableName
    )
    process {
        $Stringtest = [string]::IsNullOrEmpty($VariableName)
        if ($true -eq $Stringtest) {
            Write-Host "You did not insert any input." -ForegroundColor Red
            Break
        }
    }
}

Switch ($Number) {
    1 {
        Find-Module "ActiveDirectory"
        # Check last replication time first
        $DomainControllers = (Get-ADDomainController -filter *).name
        $LastRepTime = (Get-ADReplicationUpToDatenessVectorTable -Target $DomainControllers[0]).LastReplicationSuccess[0]
        Write-Host "Last replication time was at - $LastRepTime" -ForegroundColor Cyan
        Write-Host "Invoking replication against $DomainControllers" -ForegroundColor Green
        foreach ($DC in $DomainControllers) {
            Invoke-Command -ComputerName $DC -ScriptBlock {
                cmd.exe /c repadmin /syncall /A /e /d
            } -InDisconnectedSession | Out-Null
        }
    }
    2 {
        Find-Module ActiveDirectory
        $DClist = new-object System.Collections.Arraylist
        $SiteList = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().sites.name
        foreach ($Site in $SiteList) {
            [array]$DC = (Get-ADDomainController -Filter {Site -eq "$Site"}).name | Select-Object -First 1
            $DClist += $DC
        }
        $ZoneList = (Get-DnsServerZone -ComputerName $DClist[0] | Where-Object {$_.IsDsIntegrated -eq $true -and $_.IsReverseLookupZone -eq $false -and $_.ZoneName -notmatch "TrustAnchors" -and $_.ZoneName -notmatch "_msdcs.$($env:USERDNSDOMAIN)"}).ZoneName
        Write-Host "Invoking replication against $DClist for zones $ZoneList" -ForegroundColor Cyan
        foreach ($DC in $DClist) {
            foreach ($Zone in $ZoneList) {
                Invoke-Command -ComputerName $DC -ScriptBlock {
                    dnscmd /ZoneRefresh $Zone
                    Sync-DnsServerZone -Name $Zone 
                } -InDisconnectedSession | Out-Null
            }
        }
    }
    3 {
        Find-Module ActiveDirectory
        $GroupName = (Get-UserInput -WriteOut "Enter the group name:")
        Find-EmptyString -VariableName $GroupName
        try {
            Get-ADGroup -Identity "$GroupName" -ErrorAction Stop | out-null
        }
        catch {
            Write-Host "Cannot find an object with identity $($GroupName) under $env:USERDNSDOMAIN" -ForegroundColor Red
            Break
        }
        [array]$Members = (Get-ADGroupMember -Identity "$($GroupName)").Name
        Write-Output ""
        Write-Host "Members of the group - $GroupName are:" -ForegroundColor Cyan
        foreach ($Member in $Members) {
            Write-Host "$Member" -ForegroundColor Green
        }
    }
    4 {
        Find-Module ActiveDirectory
        Write-Host "Script is going to check for all of the computer objects that did not update their password for +90 days." -ForegroundColor Cyan
        $PwdAge = 90
        $PwdDate = (get-date).AddDays(-$PwdAge).ToFileTime()
        $ComputerList = (Get-ADComputer -filter {Enabled -eq $true} -Properties * | Where-Object {$_.PwdLastSet -le $PwdDate}).Name
        $Isitempty = [string]::IsNullOrEmpty("$ComputerList")
        if ($true -eq $Isitempty) {
            Write-Host "There are no inactive computers in your Active Directory!" -ForegroundColor Green
        }
        else {
            Write-Host "List of the computers that did not update their password for +90 days is:" -ForegroundColor Green
            foreach ($Computer in $ComputerList) {
                Write-Host "$Computer" -ForegroundColor Green
            }
        }

    }
    5 {
        Find-Module ActiveDirectory
        $sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().sites
        $sitesandsubnets = New-Object System.Collections.ArrayList
        Write-Host "List of found AD sites is:" -ForegroundColor Cyan
        Write-Output ""
        foreach ($site in $sites) {
            Write-Host "$($site.name)" -ForegroundColor Green
        }
        start-sleep 2
        Write-Output ""
        Write-Host "List of found subnets per site:" -ForegroundColor Cyan
        foreach ($site in $sites) {
            $temp = New-Object PSCustomObject -Property @{
                'Site' = $($site.name)
                'Subnet' = $($site.subnets);
            }
            $sitesandsubnets += $temp
        }
        $sitesandsubnets
    }
    6 {
        Find-Module ActiveDirectory
        $SourceUser = (Get-UserInput -WriteOut "Insert the name of the source user:")
        Find-EmptyString -VariableName $SourceUser
        try {
            $Getuser = Get-ADUser -Identity $SourceUser -ErrorAction Stop
        }
        catch {
            Write-Host "Cannot find and object with identity $($SourceUser) under $env:USERDNSDOMAIN" -ForegroundColor Red
            Break
        }
        $DestinationUser = (Get-UserInput -WriteOut "Insert the name of the destination user:")
        Find-EmptyString -VariableName $DestinationUser
        try {
            $Getuser = Get-ADUser -Identity $DestinationUser -ErrorAction Stop
        }
        catch {
            Write-Host "Cannot find and object with identity $($SourceUser) under $env:USERDNSDOMAIN" -ForegroundColor Red
            Break
        }
        Write-Output ""
        Write-Host "Successfully found both user objects under $env:USERDNSDOMAIN" -ForegroundColor Green
        $GroupMembership = (Get-ADPrincipalGroupMembership -Identity $SourceUser).Name
        Write-Host "Cloning group membership from $($SourceUser) to $($DestinationUser)" -ForegroundColor Cyan
        Write-Host "Group list:" -ForegroundColor Green
        foreach ($Group in $GroupMembership) {
            Write-Host $Group -ForegroundColor Green
        }
        Write-Output ""
        foreach ($Group in $GroupMembership) {
            try {
                Write-Host "Adding $($DestinationUser) to group $($Group)" -ForegroundColor Cyan
                Add-ADGroupMember -Identity "$Group" -Members "$DestinationUser" -ErrorAction 
            }
            catch {
                Write-Host "User was already a member of $($Group) group." -ForegroundColor Yellow
            }
        }
    }
    7 {
        $RemoteComputer = (Get-UserInput -WriteOut "Enter the name of the computer:")
        Find-EmptyString -VariableName $RemoteComputer
        Try {
            Write-Host "Trying to get AD site of $($RemoteComputer)" -ForegroundColor Cyan
            $SiteName = invoke-command -ComputerName $RemoteComputer -ScriptBlock {
                (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine" -Name "Site-Name").'site-name'
            } -ErrorAction Stop
        }
        Catch {
            Write-Host "Cannot connect to computer - $($RemoteComputer)." -ForegroundColor Red
            Break
        }
        $FoundSite = New-Object PSCustomObject -Property @{
            'ComputerName' = $RemoteComputer;
            'SiteName' = $SiteName;
        }
        $FoundSite
    }
    8 {
        $DomainController = (Get-UserInput -WriteOut "Type the name of the Domain Controller, or type all to test them all:")
        Find-EmptyString -VariableName $DomainController
        if ($DomainController -eq "All") {
            Write-Host "Search for all Domain Controllers in $env:USERDNSDOMAIN" -ForegroundColor Cyan
            $DomainControllers = (Get-ADDomainController -Filter *).Name
            foreach ($DC in $DomainControllers) {
                $LDAPS = [ADSI]"LDAP://$($DC):636"
                Try {
                    $Connection = [adsi]$LDAPS
                }
                Catch {
                }
                if ($Connection.Path) {
                    Write-Host "LDAPS properly configured on $DC." -ForegroundColor Green
                }
                else {
                    Write-Host "Cannot establish LDAPS to $DC." -ForegroundColor Red
                }
            }
        }
        else {
            $LDAPS = [ADSI]"LDAP://$($DomainController):636"
            Try {
                $Connection = [adsi]$LDAPS
            }
            Catch {
            }
            if ($Connection.Path) {
                Write-Host "LDAPS properly configured on $DomainController." -ForegroundColor Green
            }
            else {
                Write-Host "Cannot establish LDAPS to $DomainController." -ForegroundColor Red
            }
        }
    }
    Default {
        Write-Host "Number that you entered is out of scope or input is empty." -ForegroundColor Red
    }
}