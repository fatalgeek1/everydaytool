<#

.SYNOPSIS

.DESCRIPTION
EveryDay Powershell automation tool represents open source collaboration project with the goal to speed up the day-to-day administration tasks in Microsoft environments.
In the essence, it is just a bundle of functions that will be executed based on user input choice.


#>

Write-Host -ForegroundColor Green "WELCOME to EveryDay Tool, ease of administration is in front of you!"
Write-Host -ForegroundColor Green "You can pick one of the listed options below, backend functions will do the rest for you."
Start-Sleep 4
Write-Host -ForegroundColor Cyan "
ACTIVE DIRECTORY ADMINISTRATION
-------------------------------

1. Invoke replication against all of the domain controllers in the forest.
"
#############

Try {
    [int]$Number = (Read-Host -Prompt "Chose the task by entering the task number" -ErrorAction SilentlyContinue)
}
Catch {
    Write-Host "Input accepts only integers, please relaunch the script." -ForegroundColor Red
}
Switch ($Number) {
    1 {
        Import-Module ActiveDirectory
        # Check last replication time first
        $DomainControllers = (Get-ADDomainController -filter *).name
        $LastRepTime = (Get-ADReplicationUpToDatenessVectorTable -Target $DomainControllers[0]).LastReplicationSuccess[0]
        Write-Host "Last replication time was at - $LastRepTime" -ForegroundColor Cyan
        Write-Host "Invoking replication against $DomainControllers" -ForegroundColor Green
        foreach ($DC in $DomainControllers) {
            Invoke-Command -ComputerName $DC -ScriptBlock {
                cmd.exe /c repadmin /syncall /A /e /d
            } -InDisconnectedSession
        }
    }
    2 {
        
    }
    3 {

    }
    Default {
        Write-Host "Number that you entered is out of scope." -ForegroundColor Red
    }
}