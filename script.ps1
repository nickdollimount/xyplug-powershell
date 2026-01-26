<#
.SYNOPSIS
    xyOps PowerShell event plugin - Executes PowerShell commands within the xyOps environment.

.DESCRIPTION
    This script is an xyOps event plugin that executes PowerShell code blocks and reports progress,
    output, and file changes back to the xyOps system. It provides structured logging with
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
    Purpose:        xyOps PowerShell event plugin
    Features:       - PowerShell 5 and Core support
                    - Cross-platform compatibility
                    - Comprehensive helper functions for xyOps integration

#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

# Initialize script-level variables
$script:enableLogTime = $false
$script:xyOps = $null

# ============================================================================
# Logging Functions
# ============================================================================

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
        Write-xyOpsJobOutput "Job started successfully"
    
    .EXAMPLE
        Write-xyOpsJobOutput "An error occurred" -Level error
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('info', 'warning', 'error')]
        [string]$Level = 'info'
    )

    $timestamp = if ($script:enableLogTime -eq $true) {
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

# ============================================================================
# Core Output Functions
# ============================================================================

function Send-xyOpsOutput {
    <#
    .SYNOPSIS
        Sends structured JSON output back to the xyOps system. This is low-level output to xyOps.
    
    .DESCRIPTION
        Converts PowerShell objects to JSON format and writes them to the output stream
        for consumption by the xyOps system. Supports hashtables, PSCustomObjects, arrays,
        and primitive types. Automatically flushes output to prevent buffering.
    
    .PARAMETER InputObject
        The object to send to xyOps. Can be a hashtable, PSCustomObject, array, or primitive type.
    
    .EXAMPLE
        Send-xyOpsOutput @{ xy = 1; code = 0 }
    
    .EXAMPLE
        Send-xyOpsOutput ([pscustomobject]@{ xy = 1; progress = 50 })
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

function Send-xyOpsProgress {
    <#
    .SYNOPSIS
        Reports job progress percentage to xyOps.
    
    .DESCRIPTION
        Sends a progress update to the xyOps system with a percentage value between 0 and 100.
    
    .PARAMETER Percent
        The progress percentage (0-100).
    
    .EXAMPLE
        Send-xyOpsProgress 25
    
    .EXAMPLE
        Send-xyOpsProgress 75.5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [decimal]$Percent
    )

    Send-xyOpsOutput ([pscustomobject]@{
        xy       = 1
        progress = $Percent / 100
    })
}

# ============================================================================
# File and Data Management Functions
# ============================================================================

function Send-xyOpsFile {
    <#
    .SYNOPSIS
        Reports file changes to the xyOps system so that xyOps can upload the file and use it.
    
    .DESCRIPTION
        Notifies xyOps about files that have been created, modified, or should be tracked
        during job execution.
    
    .PARAMETER Filename
        The path to the file to report.
    
    .EXAMPLE
        Send-xyOpsFile "/path/to/output.txt"
    
    .EXAMPLE
        Send-xyOpsFile "C:\temp\report.log"
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

    Send-xyOpsOutput $output
}

function Send-xyOpsPerf {
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
        Send-xyOpsPerf @{ db = 18.51; http = 3.22; gzip = 0.84 }
    
    .EXAMPLE
        Send-xyOpsPerf @{ db = 1851; http = 3220; gzip = 840 } -Scale 1000
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

    Send-xyOpsOutput $output
}

function Send-xyOpsLabel {
    <#
    .SYNOPSIS
        Sets a custom label for the job.
    
    .DESCRIPTION
        Adds a custom label to the job which will be displayed alongside the Job ID
        in the xyOps UI. Useful for differentiating jobs with different parameters.
    
    .PARAMETER Label
        The label text to display.
    
    .EXAMPLE
        Send-xyOpsLabel "Reindex Database"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Label
    )

    Send-xyOpsOutput ([pscustomobject]@{
        xy    = 1
        label = $Label
    })
}

function Send-xyOpsData {
    <#
    .SYNOPSIS
        Sends arbitrary output data to be passed to the next job.
    
    .DESCRIPTION
        Outputs data that will be automatically passed to the next job in a workflow
        or via a run event action. Data can be any PowerShell object.
    
    .PARAMETER Data
        The data object to pass to the next job.
    
    .EXAMPLE
        Send-xyOpsData @{ hostname = "server01"; status = "ok" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Data
    )

    Send-xyOpsOutput ([pscustomobject]@{
        xy   = 1
        data = $Data
    })
}

# ============================================================================
# UI Display Functions
# ============================================================================

function Send-xyOpsTable {
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
        Send-xyOpsTable -Rows @(@("192.168.1.1", "Server1", 100), @("192.168.1.2", "Server2", 200)) -Header @("IP", "Name", "Count")
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

    Send-xyOpsOutput ([pscustomobject]@{
        xy    = 1
        table = $table
    })
}

function Send-xyOpsHtml {
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
        Send-xyOpsHtml -Content "<h3>Results</h3><p>Job completed <b>successfully</b></p>" -Title "Summary"
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

    Send-xyOpsOutput ([pscustomobject]@{
        xy   = 1
        html = $html
    })
}

function Send-xyOpsText {
    <#
    .SYNOPSIS
        Sends plain text content to display in xyOps in a separate textbox.
    
    .DESCRIPTION
        Renders plain text on the Job Details page with formatting preserved.
    
    .PARAMETER Content
        The plain text content to display.
    
    .PARAMETER Title
        Optional title displayed above the content.
    
    .PARAMETER Caption
        Optional caption displayed under the content.
    
    .EXAMPLE
        Send-xyOpsText -Content "Log file contents..." -Title "Log Output"
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

    Send-xyOpsOutput ([pscustomobject]@{
        xy   = 1
        text = $text
    })
}

function Send-xyOpsMarkdown {
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
        Send-xyOpsMarkdown -Content "## Results`n- Item 1`n- Item 2" -Title "Summary"
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

    Send-xyOpsOutput ([pscustomobject]@{
        xy       = 1
        markdown = $markdown
    })
}

# ============================================================================
# Input and Parameter Functions
# ============================================================================

function Get-xyOpsInputFiles {
    <#
    .SYNOPSIS
        Gets the list of input files passed to the job.
    
    .DESCRIPTION
        Returns an array of input file metadata objects from the xyOps job input.
        Files are already downloaded to the current working directory.
    
    .EXAMPLE
        $files = Get-xyOpsInputFiles
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

function Get-xyOpsParam {
    <#
    .SYNOPSIS
        Gets a parameter value from xyOps or environment variable.
    
    .DESCRIPTION
        Retrieves a parameter value, checking both the params object and environment variables.
        Environment variables are checked first as xyOps passes params as env vars.
        When called without a Name parameter, displays all available parameters in a formatted table.
    
    .PARAMETER Name
        The parameter name to retrieve. If omitted, displays all available parameters.
    
    .PARAMETER Default
        Optional default value if parameter is not found.
    
    .EXAMPLE
        $timeout = Get-xyOpsParam -Name "timeout" -Default 30
    
    .EXAMPLE
        Get-xyOpsParam
        # Displays all available parameters from environment and xyOps
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,
        
        [Parameter(Mandatory = $false)]
        [object]$Default = $null
    )

    # If no name specified, display all parameters
    if ([string]::IsNullOrEmpty($Name)) {
        $paramList = [System.Collections.ArrayList]@()
        
        # Collect environment variables
        $envVars = [Environment]::GetEnvironmentVariables()
        foreach ($key in $envVars.Keys) {
            [void]$paramList.Add([PSCustomObject]@{
                Source = "Environment"
                Name   = $key
                Value  = $envVars[$key]
            })
        }
        
        # Collect xyOps params
        if ($script:xyOps.params) {
            $script:xyOps.params.PSObject.Properties | ForEach-Object {
                [void]$paramList.Add([PSCustomObject]@{
                    Source = "xyOps"
                    Name   = $_.Name
                    Value  = $_.Value
                })
            }
        }
        
        # Display as formatted table
        return $paramList | Format-Table -Property Source, Name, Value -AutoSize
    }

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

# ============================================================================
# Main Execution
# ============================================================================

try {
    # Read job parameters from JSON input
    $script:xyOps = ConvertFrom-Json -Depth 100 (Read-Host)
    $command = [scriptblock]::create($script:xyOps.params.command)
    $script:enableLogTime = $script:xyOps.params.logtime

    # Set current directory to the working directory of the job
    Set-Location $script:xyOps.cwd

    # Output xyOps configuration if requested
    if ($script:xyOps.params.outputxyops) {
        $formattedJson = $script:xyOps | ConvertTo-Json -Depth 100
        $codeBlockStart = '```json'
        $codeBlockEnd = '```'
        $markdownContent = "$codeBlockStart`n$formattedJson`n$codeBlockEnd"
        Send-xyOpsMarkdown -Content $markdownContent -Title "xyOps Job Configuration"
    }

    # Determine PowerShell version to use
    $usePowerShell5 = $script:xyOps.params.UsePowershell5 -eq $true
    
    if ($usePowerShell5) {
        # Validate Windows platform (PowerShell 5 is Windows-only)
        $runningOnWindows = if ($null -ne $IsWindows) { 
            $IsWindows 
        } else { 
            ($PSVersionTable.PSVersion.Major -le 5) -or ($env:OS -eq "Windows_NT") 
        }
        
        if (-not $runningOnWindows) {
            Write-xyOpsJobOutput "PowerShell 5 is only available on Windows. Current platform: $($PSVersionTable.Platform)" -Level error
            Send-xyOpsOutput ([pscustomobject]@{
                xy          = 1
                code        = 998
                description = "PowerShell 5 is not available on this platform (non-Windows)"
            })
            return
        }
        
        # Check if PowerShell 5 is available
        $powershellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        if (-not (Test-Path $powershellPath)) {
            Write-xyOpsJobOutput "PowerShell 5 executable not found at: $powershellPath" -Level error
            Send-xyOpsOutput ([pscustomobject]@{
                xy          = 1
                code        = 998
                description = "PowerShell 5 executable not found on this system"
            })
            return
        }
        
        Write-xyOpsJobOutput "PowerShell Version: 5.x (Windows PowerShell)"
    } else {
        Write-xyOpsJobOutput "PowerShell Version: $($PSVersionTable.PSVersion) (PowerShell Core)"
    }

    Write-xyOpsJobOutput 'Job Started'

    # ========================================================================
    # Execute User Command
    # ========================================================================
    
    if ($usePowerShell5) {
        # PowerShell 5 execution: Create wrapper script with xyOps functions
        $commandString = $script:xyOps.params.command
        
        # Extract all xyOps helper functions from the current script
        $scriptContent = Get-Content $PSCommandPath -Raw
        
        # Extract function definitions (from script initialization to main execution)
        $functionStart = $scriptContent.IndexOf('# Initialize script-level variables')
        $functionEnd = $scriptContent.IndexOf('# Main Execution')
        $functionsCode = $scriptContent.Substring($functionStart, $functionEnd - $functionStart)
        
        # Create wrapper script with functions and user command
        $wrapperScript = @"
# xyOps Helper Functions for PowerShell 5
$functionsCode

# User Command
$commandString
"@
        
        # Save wrapper script to temporary file
        $wrapperScriptPath = Join-Path $script:xyOps.cwd "ps5_wrapper_$PID.ps1"
        $wrapperScript | Out-File -FilePath $wrapperScriptPath -Encoding UTF8 -Force
        
        try {
            # Execute PowerShell 5 with the wrapper script using direct invocation
            Push-Location $script:xyOps.cwd
            
            $powershellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
            $stdoutPath = "$($script:xyOps.cwd)\ps5_stdout.tmp"
            $stderrPath = "$($script:xyOps.cwd)\ps5_stderr.tmp"
            
            # Use call operator with properly quoted arguments
            & $powershellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $wrapperScriptPath *> $stdoutPath 2> $stderrPath
            $exitCode = $LASTEXITCODE
            
            Pop-Location
            
            # Read and output the results
            if (Test-Path $stdoutPath) {
                $stdout = Get-Content $stdoutPath -Raw
                if ($stdout) {
                    Write-Information -MessageData $stdout -InformationAction Continue
                }
                Remove-Item $stdoutPath -Force -ErrorAction SilentlyContinue
            }
            
            if (Test-Path $stderrPath) {
                $stderr = Get-Content $stderrPath -Raw
                if ($stderr) {
                    Write-xyOpsJobOutput $stderr -Level error
                }
                Remove-Item $stderrPath -Force -ErrorAction SilentlyContinue
            }
            
            # Check exit code
            if ($exitCode -ne 0) {
                throw "PowerShell 5 execution failed with exit code: $exitCode"
            }
        } finally {
            # Clean up wrapper script
            if (Test-Path $wrapperScriptPath) {
                Remove-Item $wrapperScriptPath -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        # Execute normally in PowerShell Core
        & $command
    }

    # Report success
    Send-xyOpsOutput ([pscustomobject]@{
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
    Send-xyOpsOutput ([pscustomobject]@{
        xy          = 1
        code        = 999
        description = "Job failed!"
    })
}
finally {
    Write-xyOpsJobOutput 'Job Finished'
}
