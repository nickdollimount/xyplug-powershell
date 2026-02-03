<#
.SYNOPSIS
    xyOps PowerShell event plugin - Executes PowerShell commands within the xyOps environment.

.DESCRIPTION
    This script is a xyOps event plugin that executes PowerShell code blocks and reports progress,
    output, and file changes back to the xyOps system. It provides structured logging with
    optional timestamps and handles job execution with comprehensive error handling.
    
    The script reads job parameters from JSON input, executes the provided PowerShell command,
    and reports results in a standardized format that xyOps can process.

.PARAMETER None
    This script reads parameters from JSON input via Read-Host.

.NOTES
    Author:         Nick Dollimount
    Contributor:    Tim Alderweireldt
    Copyright:      2026
    Purpose:        xyOps PowerShell event plugin
    Features:       - Cross-platform compatibility
                    - Comprehensive helper functions for xyOps integration

#>

# MARK: Write-xyOpsJobOutput
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet('info', 'warning', 'error')][string]$Level = 'info'
    )

    if ($Script:enableLogTime -eq $true) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss:ffff"
        $logMessage = "[$($timestamp)] [$($Level)] $($Message)"
    }
    else {
        $logMessage = "[$($Level)] $($Message)"
    }

    Send-xyOpsOutput $logMessage
}

# MARK: Send-xyOpsOutput
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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object]$InputObject
    )

    try {
        Write-Information -MessageData (($InputObject -is [string]) ? $InputObject : ($InputObject | ConvertTo-Json -Depth 100 -Compress)) -InformationAction Continue -OutBuffer 0
    }
    catch {
        Throw "Unsupported data type."
    }
}

# MARK: Send-xyOpsProgress
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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][decimal]$Percent
    )

    Send-xyOpsOutput ([pscustomobject]@{
            xy       = 1
            progress = $Percent / 100
        })
}

# MARK: New-Filename
function New-Filename {
    <#
    .SYNOPSIS
        Generates a unique filename.
    
    .DESCRIPTION
        Generates a unique filename using a new Guid value to avoid reusing filenames.
    
    .PARAMETER Filetype
        The file type that should be used in the filename generation.

    .PARAMETER Prefix
        Optional string to add to the beginning of the filename. Spaces are automatically converted to underscores.
    
    .EXAMPLE
        New-Filename -Filetype csv
    
    .EXAMPLE
        New-Filename -Filetype log -Prefix "data update"
    
    .EXAMPLE
        New-Filename log
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]$Filetype,
        [Parameter(Mandatory = $false)]$Prefix
    )

    $prefix = $Prefix -replace " ", "_"
    $guid = (New-Guid).Guid

    $filename = "$((![string]::IsNullOrEmpty($prefix)) ? "$($prefix)_" : $null)$($guid).$($fileType)"
    return $filename
}

# MARK: Send-xyOpsFile
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
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$Filename
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

# MARK: Send-xyOpsPerf
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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][hashtable]$Metrics,        
        [Parameter(Mandatory = $false)][int]$Scale
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

# MARK: Send-xyOpsLabel
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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$Label
    )

    Send-xyOpsOutput ([pscustomobject]@{
            xy    = 1
            label = $Label
        })
}

# MARK: Send-xyOpsData
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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object]$Data
    )

    Send-xyOpsOutput ([pscustomobject]@{
            xy   = 1
            data = $Data
        })
}

# MARK: Send-xyOpsTable
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
        [Parameter(Mandatory = $true)][array]$Rows,
        [Parameter(Mandatory = $false)][string]$Title,
        [Parameter(Mandatory = $false)][array]$Header,
        [Parameter(Mandatory = $false)][string]$Caption
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

# MARK: Send-xyOpsHtml
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
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $false)][string]$Title,
        [Parameter(Mandatory = $false)][string]$Caption
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

# MARK: Send-xyOpsText
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
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $false)][string]$Title,
        [Parameter(Mandatory = $false)][string]$Caption
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

# MARK: Send-xyOpsMarkdown
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
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $false)][string]$Title,
        [Parameter(Mandatory = $false)][string]$Caption
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

# MARK: Get-xyOpsInputFiles
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
    $files = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $Script:xyOps.input.files) {
        $files.Add($file)
    }
    
    return $files
}

# MARK: Get-xyOpsBucketFile
function Get-xyOpsBucketFile {
    <#
    .SYNOPSIS
        Gets file from the specified bucket.
    
    .DESCRIPTION
        Uses the get_bucket API to retrieve a file from a specified bucket.
    
    .EXAMPLE
        Get-xyOpsBucketFile -BucketId 'bml2ut4ys4pt7raf' -Filename 'customers.csv'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][string]$BucketId,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)][string]$Filename,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 2)][string]$OutFilename
    )

    if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
        throw "No secrets have been assigned to this plugin or event. Bucket access is currently unavailable."
    }

    $bucketApiKey = $Script:xyOps.secrets."$($Script:xyOps.params.bucketapikeyvariable)"
    $apiUri = "$($Script:xyOps.base_url)/api/app/get_bucket/v1?id=$($BucketId)"

    $requestSplat = @{
        Uri     = $apiUri
        Method  = 'GET'
        Headers = @{
            'X-API-KEY' = $bucketApiKey
        }
    }

    try {
        $bucketData = (Invoke-RestMethod @requestSplat)
    }
    catch {
        throw "There was a problem retrieving the specified bucket details."
        $_
    }

    if ([string]::IsNullOrEmpty($bucketData.files)) {
        Write-xyOpsJobOutput "There are no files in specified bucket."
        return
    }

    $filePath = $bucketData.files.Where({ $_.filename -eq $Filename }).path

    if ([string]::IsNullOrEmpty($filePath)) {
        Write-xyOpsJobOutput "The requested file does not exist in the specified bucket."
        return
    }

    $apiUri = "$($Script:xyOps.base_url)/$($filePath)"

    $requestSplat = @{
        Uri     = $apiUri
        Method  = 'GET'
        Headers = @{
            'X-API-KEY' = $bucketApiKey
        }
    }

    try {
        Invoke-RestMethod @requestSplat -OutFile "./$(($OutFilename) ? $OutFilename : $Filename)"
    }
    catch {
        throw "There was a problem downloading the requested file."
        $_
    }
}

# MARK: Add-xyOpsBucketFile
function Add-xyOpsBucketFile {
    <#
    .SYNOPSIS
        Adds file to the specified bucket.
    
    .DESCRIPTION
        Uses the upload_bucket_files API to add a file to a specified bucket.
    
    .EXAMPLE
        $newFile = New-FileName -FileType csv
        $customers | Export-Csv -FilePath $newFile
        Add-xyOpsBucketFile -BucketId 'bml2ut4ys4pt7raf' -Filename $newFile
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][string]$BucketId,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)][string]$Filename
    )

    if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
        throw "No secrets have been assigned to this plugin or event. Bucket access is currently unavailable."
    }

    $bucketApiKey = $Script:xyOps.secrets."$($Script:xyOps.params.bucketapikeyvariable)"
    $apiUri = "$($Script:xyOps.base_url)/api/app/upload_bucket_files/v1?id=$($BucketId)"


    $requestSplat = @{
        Uri     = $apiUri
        Method  = 'POST'
        Headers = @{
            'X-API-KEY' = $bucketApiKey
        }
        Form    = @{
            file = (Get-Item -Path $Filename)
        }
    }

    try {
        Invoke-RestMethod @requestSplat
        Write-xyOpsJobOutput "File [$($Filename)] uploaded to Bucket [$($BucketId)]."
    }
    catch {
        throw "There was a problem uploading the requested file."
        $_
    }
}

# MARK: Remove-xyOpsBucketFile
function Remove-xyOpsBucketFile {
    <#
    .SYNOPSIS
        Deletes file from the specified bucket.
    
    .DESCRIPTION
        Uses the delete_bucket_file API to delete a file from a specified bucket.
    
    .EXAMPLE
        Remove-xyOpsBucketFile -BucketId 'bml2ut4ys4pt7raf' -Filename 'customers.csv'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][string]$BucketId,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)][string]$Filename
    )
    
    if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
        throw "No secrets have been assigned to this plugin or event. Bucket access is currently unavailable."
    }

    $bucketApiKey = $Script:xyOps.secrets."$($Script:xyOps.params.bucketapikeyvariable)"
    $apiUri = "$($Script:xyOps.base_url)/api/app/delete_bucket_file/v1"


    $requestSplat = @{
        Uri     = $apiUri
        Method  = 'POST'
        Headers = @{
            'X-API-KEY' = $bucketApiKey
        }
        Body    = @{
            id       = $BucketId
            filename = $Filename
        }
    }

    try {
        $null = Invoke-RestMethod @requestSplat
        Write-xyOpsJobOutput "File [$($Filename)] was deleted from Bucket [$($BucketId)]."
    }
    catch {
        throw ($_.ErrorDetails.Message | ConvertFrom-Json)
    }
}

# MARK: Get-xyOpsBucketData
function Get-xyOpsBucketData {
    <#
    .SYNOPSIS
        Gets data from the specified bucket.
    
    .DESCRIPTION
        Uses the get_bucket API to retrieve JSON data from the specified bucket.
    
    .EXAMPLE
        $bucketData = Get-xyOpsBucketData -BucketId 'bml2ut4ys4pt7raf'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][string]$BucketId
    )

    if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
        throw "No secrets have been assigned to this plugin or event. Bucket access is currently unavailable."
    }

    $bucketApiKey = $Script:xyOps.secrets."$($Script:xyOps.params.bucketapikeyvariable)"
    $apiUri = "$($Script:xyOps.base_url)/api/app/get_bucket/v1?id=$($BucketId)"

    $requestSplat = @{
        Uri     = $apiUri
        Method  = 'GET'
        Headers = @{
            'X-API-KEY' = $bucketApiKey
        }
    }

    try {
        $bucketData = (Invoke-RestMethod @requestSplat).data
    }
    catch {
        $_
    }

    return $bucketData
}

# MARK: Set-xyOpsBucketData
function Set-xyOpsBucketData {
    <#
    .SYNOPSIS
        Sets data in the cache bucket.
    
    .DESCRIPTION
        Uses the write_bucket API to write a JSON converted object to a specified bucket data.
    
    .EXAMPLE
        Set-xyOpsBucketData -BucketId 'bml2ut4ys4pt7raf' -Key 'Countries' -InputObject @('Canada','United States','United Kingdom')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][string]$BucketId,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)][string]$Key,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 2)][object]$InputObject
    )

    if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
        throw "No secrets have been assigned to this plugin or event. Bucket access is currently unavailable."
    }

    $bucketApiKey = $Script:xyOps.secrets."$($Script:xyOps.params.bucketapikeyvariable)"
    $apiUri = "$($Script:xyOps.base_url)/api/app/write_bucket_data/v1?id=$($BucketId)"

    $requestSplat = @{
        Uri         = $apiUri
        Method      = 'POST'
        Headers     = @{
            'X-API-KEY' = $bucketApiKey
        }
        ContentType = 'application/json'
        Body        = @{
            data = [PSCustomObject]@{
                "$($Key)" = $InputObject
            }
        } | ConvertTo-Json -Depth 100
    }

    try {
        $null = Invoke-RestMethod @requestSplat
        Write-xyOpsJobOutput "Bucket [$($BucketId)] data updated."
    }
    catch {
        throw "There was an issue updating bucket [$($BucketId)] data."
        $_
    }
}

# MARK: Get-xyOpsCache
function Get-xyOpsCache {
    <#
    .SYNOPSIS
        Gets data from the cache bucket.
    
    .DESCRIPTION
        Uses the get_bucket API to retrieve JSON data from a bucket configured for cache.
    
    .EXAMPLE
        $Countries = Get-xyOpsCache -Key Countries
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$Key
    )
    if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
        throw "No secrets have been assigned to this plugin or event. Cache is currently unavailable."
    }

    $cacheBucketId = $Script:xyOps.secrets."$($Script:xyOps.params.cachebucketidvariable)"

    try {
        $bucketData = Get-xyOpsBucketData -BucketId $cacheBucketId
        $cacheData = $bucketData."$($Key)"
    }
    catch {
        $_
    }

    return $cacheData
}

# MARK: Set-xyOpsCache
function Set-xyOpsCache {
    <#
    .SYNOPSIS
        Sets data in the cache bucket.
    
    .DESCRIPTION
        Uses the write_bucket API to write a JSON converted object to a bucket data configured for cache.
    
    .EXAMPLE
        Set-xyOpsCache -Key Countries -InputObject @('Canada','United States','United Kingdom')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][string]$Key,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)][object]$InputObject
    )

    if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
        throw "No secrets have been assigned to this plugin or event. Cache is currently unavailable."
    }

    $cacheApiKey = $Script:xyOps.secrets."$($Script:xyOps.params.bucketapikeyvariable)"
    $cacheBucketId = $Script:xyOps.secrets."$($Script:xyOps.params.cachebucketidvariable)"
    $apiUri = "$($Script:xyOps.base_url)/api/app/write_bucket_data/v1?id=$($cacheBucketId)"

    $requestSplat = @{
        Uri         = $apiUri
        Method      = 'POST'
        Headers     = @{
            'X-API-KEY' = $cacheApiKey
        }
        ContentType = 'application/json'
        Body        = @{
            data = [PSCustomObject]@{
                "$($Key)" = $InputObject
            }
        } | ConvertTo-Json -Depth 100
    }

    try {
        $null = Invoke-RestMethod @requestSplat
        Write-xyOpsJobOutput "Cache [$($Key)] updated."
    }
    catch {
        throw "There was an issue updating cache [$($Key)]."
        $_
    }
}

# MARK: Get-xyOpsParam
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
        [string]$Name
    )

    # If no name specified, display all parameters
    if ([string]::IsNullOrEmpty($Name)) {
        $paramList = [System.Collections.Generic.List[object]]::new()
        
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
        if ($Script:xyOps.params) {
            $Script:xyOps.params.PSObject.Properties | ForEach-Object {
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
    if ($Script:xyOps.params.$Name) {
        return $Script:xyOps.params.$Name
    }
    
    return $null
}

# MARK: Begin

# Read job parameters from JSON input
[PSCustomObject]$Script:xyOps = ConvertFrom-Json -Depth 100 (Read-Host)

try {
    $command = [scriptblock]::create($Script:xyOps.params.command)
}
catch {
    throw "The code block provided is invalid. Please use a proper code editor to verify your script."
}

$Script:enableLogTime = $Script:xyOps.params.logtime

if ($Script:xyOps.input -and ($Script:xyOps.params.passdata -eq $true)) {
    if ($Script:xyOps.input.data) {
        Send-xyOpsData $Script:xyOps.input.data
    } else {
        Send-xyOpsData $Script:xyOps.input
    }
}

# Set current directory to the working directory of the job
Set-Location $Script:xyOps.cwd

# Output xyOps Json data
if ($Script:xyOps.params.outputxyops) {
    $formattedJson = $Script:xyOps | ConvertTo-Json -Depth 100
    $markdownContent = "``````json`n$($formattedJson)`n``````"
    Send-xyOpsMarkdown -Content $markdownContent -Title "Job Data - Json"
}

# Output PowerShell Version
Write-xyOpsJobOutput "PowerShell Version: $($PSVersionTable.PSVersion)"

# Import any .psm1 module files provided from a bucket fetch action.
if ($Script:xyOps.params.processmodules) {
    $moduleFiles = Get-xyOpsInputFiles | Where-Object { $_.filename -like "*.psm1" }
    foreach ($moduleFile in $moduleFiles) {
        try {
            Write-xyOpsJobOutput "Loading module file: $($moduleFile.filename)" -Level info
            Import-Module "./$($moduleFile.filename)"
        }
        catch {
            Write-xyOpsJobOutput $_ -Level error
        }
    }
}

Write-xyOpsJobOutput 'Job Started'

try {

    & $command

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