<#
.SYNOPSIS
    XyOps PowerShell event plugin - Executes PowerShell commands within the xyOps environment.

.DESCRIPTION
    This script is an xyOps event plugin that executes PowerShell code blocks and reports progress,
    output, and file changes back to the XyOps system. It provides structured logging with
    optional timestamps and handles job execution with comprehensive error handling.
    
    The script reads job parameters from JSON input, executes the provided PowerShell command,
    and reports results in a standardized format that xyOps can process.

.PARAMETER None
    This script reads parameters from JSON input via Read-Host.

.NOTES
    Version:        1.1.0
    Author:         Nick Dollimount
    Contributor:    Tim Alderweireldt
    Copyright:      2026
    Purpose:        XyOps PowerShell event plugin

#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

# MARK: Write-XyOpsLog
function Write-xyOpsJobOutput {
    <#
    .SYNOPSIS
        Writes messages to the xyOps job output stream with optional timestamps.
    
    .DESCRIPTION
        Logs messages to the xyOps job output with configurable timestamp prefixes.
        Uses the PowerShell Information stream for output.
    
    .PARAMETER Message
        The message to log.
    
    .PARAMETER Level
        The log level (info, warning, error). Default is 'info'.
    
    .EXAMPLE
        Write-XyOpsLog "Job started successfully"
    
    .EXAMPLE
        Write-XyOpsLog "An error occurred" -Level error
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('info', 'warning', 'error')]
        [string]$Level = 'info'
    )

    $timestamp = if ($script:enableLogTime) {
        Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    } else {
        $null
    }

    $logMessage = if ($timestamp) {
        "[$timestamp] [$Level] $Message"
    } else {
        "[$Level] $Message"
    }

    Write-Information -MessageData $logMessage -InformationAction Continue
}

# MARK: Send-XyOpsOutput
function Send-XyOpsOutput {
    <#
    .SYNOPSIS
        Sends structured output back to the xyOps system.
    
    .DESCRIPTION
        Converts PowerShell objects to JSON format and writes them to the output stream
        for consumption by the xyOps system. Supports hashtables, PSCustomObjects, arrays,
        and primitive types. Automatically flushes output to prevent buffering.
    
    .PARAMETER InputObject
        The object to send to xyOps. Can be a hashtable, PSCustomObject, array, or primitive type.
    
    .EXAMPLE
        Send-XyOpsOutput @{ xy = 1; code = 0 }
    
    .EXAMPLE
        Send-XyOpsOutput ([pscustomobject]@{ xy = 1; progress = 50 })
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        Write-Output "`n"
        [Console]::Out.Flush()
        return
    }

    if ($InputObject -is [hashtable] -or 
        $InputObject -is [System.Management.Automation.PSCustomObject] -or 
        $InputObject -is [array]) {
        Write-Output "$($InputObject | ConvertTo-Json -Depth 100 -Compress)`n"
    } elseif ($InputObject -is [string] -or 
              $InputObject -is [int] -or 
              $InputObject -is [bool] -or 
              $InputObject -is [decimal]) {
        Write-Output "$InputObject`n"
    } else {
        Throw "Unsupported data type."
    }
    
    # Flush output immediately to prevent buffering issues
    [Console]::Out.Flush()
}

# MARK: Send-XyOpsProgress
function Send-XyOpsProgress {
    <#
    .SYNOPSIS
        Reports job progress percentage to XyOps.
    
    .DESCRIPTION
        Sends a progress update to the XyOps system with a percentage value between 0 and 100.
    
    .PARAMETER Percent
        The progress percentage (0-100).
    
    .EXAMPLE
        Send-XyOpsProgress 25
    
    .EXAMPLE
        Send-XyOpsProgress 75.5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [decimal]$Percent
    )

    Send-XyOpsOutput ([pscustomobject]@{
        xy       = 1
        progress = $Percent
    })
}

# MARK: Send-XyOpsFile
function Send-XyOpsFile {
    <#
    .SYNOPSIS
        Reports file changes to the xyOps system.
    
    .DESCRIPTION
        Notifies xyOps about files that have been created, modified, or should be tracked
        during job execution.
    
    .PARAMETER Filename
        The path to the file to report.
    
    .EXAMPLE
        Send-XyOpsFile "/path/to/output.txt"
    
    .EXAMPLE
        Send-XyOpsFile "C:\temp\report.log"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Filename
    )

    $output = [pscustomobject]@{
        xy    = 1
        files = @(
            @{
                path   = $Filename
                delete = $false
            }
        )
    }

    Send-XyOpsOutput $output
}

# MARK: Send-XyOpsPerf
function Send-XyOpsPerf {
    <#
    .SYNOPSIS
        Reports performance metrics to xyOps.
    
    .DESCRIPTION
        Sends performance timing data to xyOps for display as a pie chart on the Job Details page.
        Metrics represent time spent in different categories.
    
    .PARAMETER Metrics
        Hashtable of performance metrics where keys are category names and values are time in seconds.
    
    .PARAMETER Scale
        Optional scale factor if metrics are not in seconds (e.g., 1000 for milliseconds).
    
    .EXAMPLE
        Send-XyOpsPerf @{ db = 18.51; http = 3.22; gzip = 0.84 }
    
    .EXAMPLE
        Send-XyOpsPerf @{ db = 1851; http = 3220; gzip = 840 } -Scale 1000
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Metrics,
        
        [Parameter(Mandatory = $false)]
        [int]$Scale
    )

    $output = [pscustomobject]@{
        xy   = 1
        perf = $Metrics
    }
    
    if ($Scale) {
        $output.perf['scale'] = $Scale
    }

    Send-XyOpsOutput $output
}

# MARK: Send-XyOpsLabel
function Send-XyOpsLabel {
    <#
    .SYNOPSIS
        Sets a custom label for the job.
    
    .DESCRIPTION
        Adds a custom label to the job which will be displayed alongside the Job ID
        in the xyOps UI. Useful for differentiating jobs with different parameters.
    
    .PARAMETER Label
        The label text to display.
    
    .EXAMPLE
        Send-XyOpsLabel "Reindex Database"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Label
    )

    Send-XyOpsOutput ([pscustomobject]@{
        xy    = 1
        label = $Label
    })
}

# MARK: Send-XyOpsData
function Send-XyOpsData {
    <#
    .SYNOPSIS
        Sends arbitrary output data to be passed to the next job.
    
    .DESCRIPTION
        Outputs data that will be automatically passed to the next job in a workflow
        or via a run event action. Data can be any PowerShell object.
    
    .PARAMETER Data
        The data object to pass to the next job.
    
    .EXAMPLE
        Send-XyOpsData @{ hostname = "server01"; status = "ok" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Data
    )

    Send-XyOpsOutput ([pscustomobject]@{
        xy   = 1
        data = $Data
    })
}

# MARK: Send-XyOpsTable
function Send-XyOpsTable {
    <#
    .SYNOPSIS
        Sends tabular data for display in the xyOps UI.
    
    .DESCRIPTION
        Renders a data table on the Job Details page in xyOps.
    
    .PARAMETER Rows
        Array of rows, where each row is an array of column values.
    
    .PARAMETER Title
        Optional title displayed above the table.
    
    .PARAMETER Header
        Optional array of header column names.
    
    .PARAMETER Caption
        Optional caption displayed under the table.
    
    .EXAMPLE
        Send-XyOpsTable -Rows @(@("192.168.1.1", "Server1", 100), @("192.168.1.2", "Server2", 200)) -Header @("IP", "Name", "Count")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Rows,
        
        [Parameter(Mandatory = $false)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [array]$Header,
        
        [Parameter(Mandatory = $false)]
        [string]$Caption
    )

    $table = @{
        rows = $Rows
    }
    
    if ($Title) { $table['title'] = $Title }
    if ($Header) { $table['header'] = $Header }
    if ($Caption) { $table['caption'] = $Caption }

    Send-XyOpsOutput ([pscustomobject]@{
        xy    = 1
        table = $table
    })
}

# MARK: Send-XyOpsHtml
function Send-XyOpsHtml {
    <#
    .SYNOPSIS
        Sends custom HTML content for display in xyOps.
    
    .DESCRIPTION
        Renders custom HTML on the Job Details page. Only basic HTML elements are allowed.
    
    .PARAMETER Content
        The HTML content to display.
    
    .PARAMETER Title
        Optional title displayed above the content.
    
    .PARAMETER Caption
        Optional caption displayed under the content.
    
    .EXAMPLE
        Send-XyOpsHtml -Content "<h3>Results</h3><p>Job completed <b>successfully</b></p>" -Title "Summary"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        
        [Parameter(Mandatory = $false)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [string]$Caption
    )

    $html = @{
        content = $Content
    }
    
    if ($Title) { $html['title'] = $Title }
    if ($Caption) { $html['caption'] = $Caption }

    Send-XyOpsOutput ([pscustomobject]@{
        xy   = 1
        html = $html
    })
}

# MARK: Send-XyOpsText
function Send-XyOpsText {
    <#
    .SYNOPSIS
        Sends plain text content for display in xyOps.
    
    .DESCRIPTION
        Renders plain text on the Job Details page with formatting preserved.
    
    .PARAMETER Content
        The plain text content to display.
    
    .PARAMETER Title
        Optional title displayed above the content.
    
    .PARAMETER Caption
        Optional caption displayed under the content.
    
    .EXAMPLE
        Send-XyOpsText -Content "Log file contents..." -Title "Log Output"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        
        [Parameter(Mandatory = $false)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [string]$Caption
    )

    $text = @{
        content = $Content
    }
    
    if ($Title) { $text['title'] = $Title }
    if ($Caption) { $text['caption'] = $Caption }

    Send-XyOpsOutput ([pscustomobject]@{
        xy   = 1
        text = $text
    })
}

# MARK: Send-XyOpsMarkdown
function Send-XyOpsMarkdown {
    <#
    .SYNOPSIS
        Sends Markdown content for display in xyOps.
    
    .DESCRIPTION
        Renders Markdown on the Job Details page (converted to HTML).
    
    .PARAMETER Content
        The Markdown content to display.
    
    .PARAMETER Title
        Optional title displayed above the content.
    
    .PARAMETER Caption
        Optional caption displayed under the content.
    
    .EXAMPLE
        Send-XyOpsMarkdown -Content "## Results`n- Item 1`n- Item 2" -Title "Summary"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        
        [Parameter(Mandatory = $false)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [string]$Caption
    )

    $markdown = @{
        content = $Content
    }
    
    if ($Title) { $markdown['title'] = $Title }
    if ($Caption) { $markdown['caption'] = $Caption }

    Send-XyOpsOutput ([pscustomobject]@{
        xy       = 1
        markdown = $markdown
    })
}

# MARK: Get-XyOpsInputFiles
function Get-XyOpsInputFiles {
    <#
    .SYNOPSIS
        Gets the list of input files passed to the job.
    
    .DESCRIPTION
        Returns an array of input file metadata objects from the xyOps job input.
        Files are already downloaded to the current working directory.
    
    .EXAMPLE
        $files = Get-XyOpsInputFiles
        foreach ($file in $files) {
            Write-Host "Processing: $($file.filename)"
        }
    #>
    [CmdletBinding()]
    param()

    if ($script:xyOps.input.files) {
        return $script:xyOps.input.files
    }
    return @()
}

# MARK: Get-XyOpsParam
function Get-XyOpsParam {
    <#
    .SYNOPSIS
        Gets a parameter value from xyOps or environment variable.
    
    .DESCRIPTION
        Retrieves a parameter value, checking both the params object and environment variables.
        Environment variables are checked first as xyOps passes params as env vars.
    
    .PARAMETER Name
        The parameter name to retrieve.
    
    .PARAMETER Default
        Optional default value if parameter is not found.
    
    .EXAMPLE
        $timeout = Get-XyOpsParam -Name "timeout" -Default 30
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $false)]
        [object]$Default = $null
    )

    # Check environment variable first (xyOps passes params as env vars)
    $envValue = [Environment]::GetEnvironmentVariable($Name)
    if ($null -ne $envValue) {
        return $envValue
    }
    
    # Check params object
    if ($script:xyOps.params.$Name) {
        return $script:xyOps.params.$Name
    }
    
    return $Default
}

# MARK: Main Execution
try {
    # Read job parameters from JSON input
    $script:xyOps = ConvertFrom-Json -Depth 100 (Read-Host)
    $command = [scriptblock]::create($script:xyOps.params.command)
    $script:enableLogTime = $script:xyOps.params.logtime

    # Set current directory to the working directory of the job
    Set-Location $script:xyOps.cwd

    # Output xyOps configuration if requested
    if ($script:xyOps.params.outputxyops) {
        Write-Information -MessageData "$(($script:xyOps | ConvertTo-Json -Depth 100))`n" -InformationAction Continue
    }

    Write-xyOpsJobOutput 'Job Started'

    # Execute the provided PowerShell script code
    & $command

    # Report success
    Send-XyOpsOutput ([pscustomobject]@{
        xy   = 1
        code = 0
    })
}
catch {
    # Write out error details
    Write-xyOpsJobOutput "Error:" -Level error
    Write-xyOpsJobOutput $_ -Level error
    Write-xyOpsJobOutput "Exception:" -Level error
    Write-xyOpsJobOutput $_.Exception -Level error

    # Report failure
    Send-XyOpsOutput ([pscustomobject]@{
        xy          = 1
        code        = 999
        description = "Job failed!"
    })
}
finally {
    Write-xyOpsJobOutput 'Job Finished'
}
