<#

.SYNOPSIS

.DESCRIPTION
EveryDay Powershell automation tool represents an open source collaboration project with the goal to speed up the day-to-day administration tasks in Microsoft environments.
In the essence, it is just a bundle of functions that will be executed based on user input choice.


#>
Clear-host
Write-Host -ForegroundColor Green "WELCOME to EveryDay Tool, ease of administration is in front of you!"
Write-Host -ForegroundColor Green "You can pick one of the listed options below, backend functions will do the rest for you."
Start-Sleep 4
Write-Host -ForegroundColor Cyan "
ACTIVE DIRECTORY ADMINISTRATION
-------------------------------

1. Invoke replication against all of the domain controllers in the forest.
2. Invoke DNS replication.
3. Check group membership.
4. Find inactive computers.
5. List sites and site subnets.
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
        $GroupName = (read-host -Prompt "Enter the group name")
        $Stringtest = [string]::IsNullOrEmpty("$GroupName")
        if ($true -eq $Stringtest) {
            Write-Host "You did not enter any input." -ForegroundColor Red
            Break
        }
        try {
            Get-ADGroup -Identity "$GroupName" -ErrorAction Stop | out-null
        }
        catch {
            Write-Host "Cannot find an object with identity $($GroupName) under $env:USERDNSDOMAIN" -ForegroundColor Red
            Break
        }
        [array]$Members = (Get-ADGroupMember -Identity "$($GroupName)").Name
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
    Default {
        Write-Host "Number that you entered is out of scope or input is empty." -ForegroundColor Red
    }
}