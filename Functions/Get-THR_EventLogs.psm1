function Get-THR_EventLogs {
    <#
    .SYNOPSIS
        Gets all event logs on a given system since the specified time frame. Defaults to 2 hours.

    .DESCRIPTION
        Gets all event logs on a given system since the specified time frame. Defaults to 2 hours.

    .PARAMETER Computer
        Computer can be a single hostname, FQDN, or IP address.

    .PARAMETER StartTime
        Specify when to begin event log collection. Defaults to 2 hours ago based on target system time.
        
    .PARAMETER EndTime
        Specify when to end event log collection. Defaults to current time on target system time.

    .EXAMPLE
        Get-THR_EventLogs 
        Get-THR_EventLogs SomeHostName.domain.com
        Get-Content C:\hosts.csv | Get-THR_EventLogs
        Get-THR_EventLogs $env:computername
        Get-ADComputer -filter * | Select -ExpandProperty Name | Get-THR_EventLogs

    .NOTES
        Updated: 2018-07-26

        Contributing Authors:
            Anthony Phipps
            
        LEGAL: Copyright (C) 2018
        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.
    
        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <http://www.gnu.org/licenses/>.
        
    .LINK
       https://github.com/TonyPhipps/THRecon
       https://github.com/TonyPhipps/THRecon/wiki/EventLogs
    #>

    param(
    	[Parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        $Computer = $env:COMPUTERNAME,

        [Parameter()]
        [datetime] $StartTime,

        [Parameter()]
        [datetime] $EndTime
    )

	begin{

        $DateScanned = Get-Date -Format u
        Write-Information -InformationAction Continue -MessageData ("Started {0} at {1}" -f $MyInvocation.MyCommand.Name, $DateScanned)

        $stopwatch = New-Object System.Diagnostics.Stopwatch
        $stopwatch.Start()

        $total = 0

        class Event {
            [String] $Computer
            [DateTime] $DateScanned

            [String] $TimeCreated
            [String] $MachineName
            [String] $UserId
            [String] $ProcessId
            [String] $LogName
            [String] $Source
            [String] $LevelDisplayName
            [String] $EventId
            [String] $OpcodeDisplayName
            [String] $TaskDisplayName
            [String] $Message
            [String] $RecordId
            [String] $RelatedActivityId
            [String] $ThreadId
            [String] $Version
        }

        $Command = {
            if ($args){ 
                $StartTime = $args[0]
                $EndTime = $args[1]
            }
            
            if(!($StartTime)){
                $StartTime = (Get-Date) - (New-TimeSpan -Hours 2)
            }
            else{
                $StartTime = $StartTime
            }

            if(!($EndTime)){
                $EndTime = (Get-Date)
            }
            else{
                $EndTime = $EndTime
            }
           
            $Logs = Get-WinEvent -ListLog * | Where-Object { ($_.RecordCount -gt 0) }

            $EventLogs = Foreach ($Log in $Logs){

                Get-WinEvent -FilterHashTable @{ LogName=$Log.LogName; StartTime=$StartTime; EndTime=$EndTime } -ErrorAction SilentlyContinue
            }

            $EventLogs = $EventLogs | Select-Object TimeCreated, MachineName, UserId, ProcessId, LogName, ProviderName, LevelDisplayName, Id, OpcodeDisplayName, TaskDisplayName, Message, RecordId, RelatedActivityId, ThreadId, Version
            return $EventLogs
        }
	}

    process{

        $Computer = $Computer.Replace('"', '')  # get rid of quotes, if present

        Write-Verbose ("{0}: Querying remote system" -f $Computer)

        if ($Computer -eq $env:COMPUTERNAME){
            
            $ResultsArray = & $Command
        } 
        else {

            $ResultsArray = Invoke-Command -ArgumentList $StartTime, $EndTime -ComputerName $Computer -ErrorAction SilentlyContinue -ScriptBlock $Command
        }
            
        if ($ResultsArray) {
            
            $outputArray = Foreach ($ThisEvent in $ResultsArray) {

                $output = $null
                $output = [Event]::new()
                                    
                $output.Computer = $Computer
                $output.DateScanned = Get-Date -Format u

                $output.TimeCreated = $ThisEvent.TimeCreated
                $output.MachineName = $ThisEvent.MachineName
                $output.UserId = $ThisEvent.UserId
                $output.ProcessId = $ThisEvent.ProcessId
                $output.LogName = $ThisEvent.LogName
                $output.Source = $ThisEvent.ProviderName
                $output.LevelDisplayName = $ThisEvent.LevelDisplayName
                $output.EventId = $ThisEvent.Id
                $output.OpcodeDisplayName = $ThisEvent.OpcodeDisplayName
                $output.TaskDisplayName = $ThisEvent.TaskDisplayName
                $output.Message = $ThisEvent.Message
                $output.RecordId = $ThisEvent.RecordId
                $output.RelatedActivityId = $ThisEvent.RelatedActivityId
                $output.ThreadId = $ThisEvent.ThreadId
                $output.Version = $ThisEvent.Version
                
                $output
            }

            $total++
            return $outputArray
        }
        else {
                
            $output = $null
            $output = [Event]::new()

            $output.Computer = $Computer
            $output.DateScanned = Get-Date -Format u
            
            $total++
            return $output
        }
    }

    end{

        $elapsed = $stopwatch.Elapsed

        Write-Verbose ("Total Systems: {0} `t Total time elapsed: {1}" -f $total, $elapsed)
    }
}