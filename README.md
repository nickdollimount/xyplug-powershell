<p align="center"><img src="logo.png" height="128" alt="PowerShell Plugin"/></p>
<h1 align="center">PowerShell Plugin</h1>

PowerShell event plugin for the [xyOps Workflow Automation System](https://xyops.io).

---

## Requirements
- **[PowerShell 7+](https://github.com/PowerShell/PowerShell)** (Cross-Platform)

For detailed instructions on installing PowerShell, please review the [Microsoft Learn Documentation](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell).

---

## Parameters

- **Code Block** - Your PowerShell script code
- **Enable Time in Output** [optional] - Adds timestamps to each log line (enabled by default)
- **Output xyOps JSON Data** [optional] - Displays job configuration as formatted JSON (admin only)
- **Process Module Files** [optional] - Import all .psm1 files attached to the job input. These files can be uploaded on a manual job run or added to a bucket to be referenced by a 'Fetch Bucket' action.

## Usage

When creating an event, you will provide your PowerShell script code inside the **Code Block** parameter. The job data is made available as a PowerShell object variable called **$xyOps**. Enabling **Output xyOps JSON Data** will display the structure of this object.

### Platform Support:
- **Windows/Linux/macOS**: PowerShell 7+

## Helper Functions

This plugin includes the following helper functions:

#### Logging & Core Output
- `Write-xyOpsJobOutput` - Write log messages with severity levels
- `Send-xyOpsOutput` - Low-level structured output to xyOps
- `Send-xyOpsProgress` - Report job progress percentage

#### File & Data Management
- `Send-xyOpsFile` - Upload files to job output
- `Send-xyOpsPerf` - Report performance metrics (pie chart)
- `Send-xyOpsLabel` - Set custom job label
- `Send-xyOpsData` - Pass data to next job in workflow

#### UI Display Functions
- `Send-xyOpsTable` - Display data tables
- `Send-xyOpsHtml` - Display HTML content
- `Send-xyOpsText` - Display plain text (preserved formatting)
- `Send-xyOpsMarkdown` - Display Markdown content

#### Input & Parameters
- `Get-xyOpsInputFiles` - Get input file metadata
- `Get-xyOpsParam` - Get parameter values (supports listing all params)

### Syntax

> #### Write-xyOpsJobOutput (formerly Log)

        Write-xyOpsJobOutput [-Message] <string> [-Level {info | warning | error}]

The **Write-xyOpsJobOutput** helper function lets you report text back to the job output which will be displayed in the job details.

Examples:

1. Reporting text back to the job output.

```powershell
Write-xyOpsJobOutput "Sample output to be passed to xyOps job output."
```

2. Strings can be piped to the helper function.

```powershell
"Log this information to the job output, please. Thanks." | Write-xyOpsJobOutput -Level warning
```


> #### Send-xyOpsOutput (formerly ReportOutput)

        Send-xyOpsOutput [-InputObject] <object>

The **Send-xyOpsOutput** helper function provides a simple way to report back updates to the job output using a PowerShell object or a hashtable. The input is converted to the proper JSON format that xyOps requires. Keep in mind that xyOps expects a specific structure, depending on what you're reporting back. Please refer to the [xyOps documentation](https://github.com/pixlcore/xyops/blob/main/docs/plugins.md) for more information.

Examples:

1. Bypass the Send-XyOpsProgress function and report the progress data directly using the **Send-XyOpsOutput** function.

```powershell
Send-xyOpsOutput ([pscustomobject]@{
        xy       = 1
        progress = 0.75
})
```

> #### Send-xyOpsProgress (formerly ReportProgress)

        Send-xyOpsProgress [-Percent] <decimal>

The **Send-xyOpsProgress** helper function provides a simple way to report back progress percent to the job output. This progress is displayed on the job details page while running.

Examples:

1. Report progress of 50%.

```powershell
Send-xyOpsProgress 50
```

2. Report progress of 25%.

```powershell
Send-xyOpsProgress 25
```

3. Using Send-xyOpsProgress how you might normally use PowerShell's built-in Write-Progress cmdlet.

```powershell
function repeatNames {
        param(
        $firstName,
        $lastName
        )

        $items = 1..5
        $current = 0
        foreach ($current in $items) {
        $current++
        Send-xyOpsProgress ($current / $items.Count * 100)
        Write-xyOpsJobOutput "Hello, $($firstName) $($lastName)! Welcome!"
        Start-Sleep -Seconds 1
        }
}

repeatNames -firstName Jon -lastName Doe
```

> #### Send-xyOpsFile (formerly ReportFile)

        Send-xyOpsFile [-Filename] <string>

The **Send-xyOpsFile** helper function allows you to upload a file to the job output. The file is then accessible in the UI to download. It can also be passed to the input of a proceeding event within a workflow to be further processed.

Examples:

1. Report a generated file back to the job output.

```powershell
$outfile = "people_$(New-Guid).csv"
$peopleList | Export-Csv -Path $outfile
Send-xyOpsFile $outfile
```

2. Generate output and report the file in one event, then consume the file in a second event using a workflow.

First Event Code (generate data and output file)

```powershell
$filename = "people_$(New-Guid).csv"

$items = @(
        [pscustomobject]@{
                Name = 'John Doe'
                Age = 40
                Country = 'Canada'
        }
        [pscustomobject]@{
                Name = 'Jane Doe'
                Age = 41
                Country = 'United Kingdom'
        }
        [pscustomobject]@{
                Name = 'Bob Smith'
                Age = 75
                Country = 'United States'
        }
        [pscustomobject]@{
                Name = 'Sally Smith'
                Age = 39
                Country = 'Canada'
        }
)

$items | Export-Csv -Path $filename -NoTypeInformation

Send-xyOpsFile $filename
```
 
Second Event Code (receiving input from previous event)

```powershell
$files = Get-xyOpsInputFiles
$people = Import-Csv -Path $files[0].filename

foreach ($person in $people) {
        Write-xyOpsJobOutput "$($person.Name), $($person.Age), is from $($person.Country)."
}
```

> #### Send-xyOpsPerf

        Send-xyOpsPerf -Metrics <hashtable> [-Scale <int>]

Sends performance metrics to xyOps for visualization as a pie chart.

Examples:

```powershell
# Metrics in seconds
Send-xyOpsPerf @{ database = 18.5; api_calls = 3.2; processing = 0.8 }

# Metrics in milliseconds
Send-xyOpsPerf @{ database = 1850; api_calls = 3200 } -Scale 1000
```

> #### Send-xyOpsLabel

        Send-xyOpsLabel [-Label] <string>

Sets a custom label for the job displayed in the UI.

Examples:

```powershell
Send-xyOpsLabel "Backup - Production DB"
Send-xyOpsLabel "Deploy to $env:TARGET_ENV"
```

> #### Send-xyOpsData

        Send-xyOpsData -Data <object>

Outputs arbitrary data to be passed to the next job in a workflow.

Examples:

```powershell
Send-xyOpsData @{ status = "complete"; records_processed = 1234 }
```

> #### Send-xyOpsTable

        Send-xyOpsTable -Rows <array> [-Header <array>] [-Title <string>] [-Caption <string>]

Renders a data table in the Job Details page.

Examples:

```powershell
$rows = @(
        @("192.168.1.1", "Server1", "Online"),
        @("192.168.1.2", "Server2", "Offline")
)
Send-xyOpsTable -Rows $rows -Header @("IP", "Name", "Status") -Title "Server Status"
```

> #### Send-xyOpsHtml

        Send-xyOpsHtml -Content <string> [-Title <string>] [-Caption <string>]

Renders custom HTML in the Job Details page.

Examples:

```powershell
$html = "<h3>Summary</h3><ul><li>Total: <b>1000</b></li></ul>"
Send-xyOpsHtml -Content $html -Title "Results"
```

> #### Send-xyOpsText

        Send-xyOpsText -Content <string> [-Title <string>] [-Caption <string>]

Renders plain text with preserved formatting.

Examples:

```powershell
$logContent = Get-Content "/var/log/app.log" -Raw
Send-xyOpsText -Content $logContent -Title "Application Log"
```

> #### Send-xyOpsMarkdown

        Send-xyOpsMarkdown -Content <string> [-Title <string>] [-Caption <string>]

Renders Markdown content (converted to HTML).

Examples:

```powershell
$md = "## Results`n- **Success**: 98%`n- **Failed**: 2%"
Send-xyOpsMarkdown -Content $md -Title "Summary"
```

> #### Get-xyOpsInputFiles

        Get-xyOpsInputFiles

Returns an array of input file metadata objects.

Examples:

```powershell
$files = Get-xyOpsInputFiles
foreach ($file in $files) {
        Write-xyOpsJobOutput "Processing: $($file.filename) ($($file.size) bytes)"
        # File is already in current directory
        $content = Get-Content $file.filename
}
```

> #### Get-xyOpsParam

        Get-xyOpsParam [-Name <string>] [-Default <object>]

Retrieves parameter values from xyOps or environment variables. When called without parameters, displays all available parameters in a formatted table.

Examples:

```powershell
# Get specific parameter with default value
$timeout = Get-xyOpsParam -Name "timeout" -Default 30
$apiKey = Get-xyOpsParam -Name "api_key"

# List all available parameters
Get-xyOpsParam
```

---
## Data Collection

This plugin **DOES NOT** collect any data or user information.

---
Author: Nick Dollimount

Contributors: Tim Alderweireldt