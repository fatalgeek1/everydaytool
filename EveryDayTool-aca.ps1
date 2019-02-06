<#

.SYNOPSIS

.DESCRIPTION
EveryDay Powershell automation tool represents open source collaboration project with the goal to speed up the day-to-day administration tasks in Microsoft environments.
In the essence, it is just a bundle of functions that will be executed based on user input choice.


#>
Clear-host
Write-Host -ForegroundColor Green "WELCOME to EveryDay Tool, ease of administration is in front of you!"
Write-Host -ForegroundColor Green "You can pick one of the listed options below, backend functions will do the rest for you."
Start-Sleep 4
Write-Host -ForegroundColor Cyan "
ACTIVE DIRECTORY ADMINISTRATION
-------------------------------

1. Copy AD user right from one AD user to other AD user
"
#############################################


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

Switch ($Number) 
{
    1 {
        Find-Module ActiveDirectory
        $ADUserFirst = (read-host -Prompt "Enter the username from which you want to copy the AD rights")
        $Stringtest = [string]::IsNullOrEmpty("$ADUserFirst")
        $ADUserSecond = (read-host -Prompt "Enter the username to which you want to copy the AD rights")
        $Stringtest = [string]::IsNullOrEmpty("$ADUserSecond")
        if ($true -eq $Stringtest) {
            Write-Host "You did not enter any input." -ForegroundColor Red
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
    }

    Default {
        Write-Host "Number that you entered is out of scope or input is empty." -ForegroundColor Red
            }
