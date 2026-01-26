<p align="center"><img src="logo.png" height="128" alt="PowerShell Plugin"/></p>
<h1 align="center">PowerShell Plugin</h1>

PowerShell event plugin for the [xyOps Workflow Automation System](https://xyops.io).

---

## Requirements
- #### PowerShell 7.x
  For detailed instructions on installing PowerShell, please review the [Microsoft Learn Documentation](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell?view=powershell-7.5).

---

## Parameters

- `Code Block`
- `Enable Time in Output`
- `Output xyOps JSON Data`

## Usage

When creating an event, you will provide your PowerShell script code inside the **Code Block** parameter. There is also an optional parameter that is checked by default, **Enable Time in Output**, which as the name implies, enables a timestamp on each output line when using the **Log** helper function. Checking off the **Output xyOps JSON Data** parameter will output the job data in JSON format in the job output. This can be useful when creating your events to get a visual representation of the included data available to you. *Note that this parameter is locked to administrator accounts.* This JSON data is made available as a PowerShell object variable called **$xyops**. So outputting the JSON data will let you see the structure of that object variable.

## Helper Functions

This plugin includes the following helper functions:

### Core Functions
- `Write-xyOpsJobOutput` (formerly `Log`)
- `Send-XyOpsOutput` (formerly `ReportOutput`)
- `Send-XyOpsProgress` (formerly `ReportProgress`)
- `Send-XyOpsFile` (formerly `ReportFile`)

### New Functions (v1.1.0)
- `Send-XyOpsPerf` - Performance metrics
- `Send-XyOpsLabel` - Custom job labels
- `Send-XyOpsData` - Output data for next job
- `Send-XyOpsTable` - Display data tables
- `Send-XyOpsHtml` - Display HTML content
- `Send-XyOpsText` - Display plain text
- `Send-XyOpsMarkdown` - Display Markdown
- `Get-XyOpsInputFiles` - Get input file metadata
- `Get-XyOpsParam` - Get parameter values

### Syntax

> #### Write-xyOpsJobOutput (formerly Log)

        Write-xyOpsJobOutput [-Message] <string> [-Level {info | warning | error}]

The **Write-xyOpsJobOutput** helper function lets you report text back to the job output which will be displayed in the job details.

Examples:

1. Reporting text back to the job output.

        Write-xyOpsJobOutput "Sample output to be passed to xyOps job output."

2. Strings can be piped to the helper function.

        "Log this information to the job output, please. Thanks." | Write-xyOpsJobOutput -Level warning


> #### Send-XyOpsOutput (formerly ReportOutput)

        Send-XyOpsOutput [-InputObject] <object>

The **Send-XyOpsOutput** helper function provides a simple way to report back updates to the job output using a PowerShell object or a hashtable. The input is converted to the proper JSON format that xyOps requires. Keep in mind that xyOps expects a specific structure, depending on what you're reporting back. Please refer to the [xyOps documentation](https://github.com/pixlcore/xyops/blob/main/docs/plugins.md) for more information.

Examples:

1. Bypass the Send-XyOpsProgress function and report the progress data directly using the **Send-XyOpsOutput** function.

        Send-XyOpsOutput ([pscustomobject]@{
            xy       = 1
            progress = 0.75
        })

> #### Send-XyOpsProgress (formerly ReportProgress)

        Send-XyOpsProgress [-Percent] <decimal>

The **Send-XyOpsProgress** helper function provides a simple way to report back progress percent to the job output. This progress is displayed on the job details page while running.

Examples:

1. Report progress of 50%.

        Send-XyOpsProgress 50

2. Report progress of 25%.

        Send-XyOpsProgress 25

3. Using Send-XyOpsProgress how you might normally use PowerShell's built-in Write-Progress cmdlet.

        function repeatNames {
            param(
                $firstName,
                $lastName
            )

            $items = 1..5
            $current = 0
            foreach ($current in $items) {
                $current++
                Send-XyOpsProgress ($current / $items.Count * 100)
                Write-xyOpsJobOutput "Hello, $($firstName) $($lastName)! Welcome!"
                Start-Sleep -Seconds 1
            }
        }

        repeatNames -firstName Jon -lastName Doe

> #### Send-XyOpsFile (formerly ReportFile)

        Send-XyOpsFile [-Filename] <string>

The **Send-XyOpsFile** helper function allows you to upload a file to the job output. The file is then accessible in the UI to download. It can also be passed to the input of a proceeding event within a workflow to be further processed.

Examples:

1. Report a generated file back to the job output.

        $outfile = "people_$(New-Guid).csv"
        $peopleList | Export-Csv -Path $outfile
        Send-XyOpsFile $outfile

2. Generate output and report the file in one event, then consume the file in a second event using a workflow.

First Event Code (generate data and output file)

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

        Send-XyOpsFile $filename
 
Second Event Code (receiving input from previous event)

        $files = Get-XyOpsInputFiles
        $people = Import-Csv -Path $files[0].filename

        foreach ($person in $people) {
                Write-xyOpsJobOutput "$($person.Name), $($person.Age), is from $($person.Country)."
        }

---

## New Functions (v1.1.0)

> #### Send-XyOpsPerf

        Send-XyOpsPerf -Metrics <hashtable> [-Scale <int>]

Sends performance metrics to xyOps for visualization as a pie chart.

Examples:

        # Metrics in seconds
        Send-XyOpsPerf @{ database = 18.5; api_calls = 3.2; processing = 0.8 }
        
        # Metrics in milliseconds
        Send-XyOpsPerf @{ database = 1850; api_calls = 3200 } -Scale 1000

> #### Send-XyOpsLabel

        Send-XyOpsLabel [-Label] <string>

Sets a custom label for the job displayed in the UI.

Examples:

        Send-XyOpsLabel "Backup - Production DB"
        Send-XyOpsLabel "Deploy to $env:TARGET_ENV"

> #### Send-XyOpsData

        Send-XyOpsData -Data <object>

Outputs arbitrary data to be passed to the next job in a workflow.

Examples:

        Send-XyOpsData @{ status = "complete"; records_processed = 1234 }

> #### Send-XyOpsTable

        Send-XyOpsTable -Rows <array> [-Header <array>] [-Title <string>] [-Caption <string>]

Renders a data table in the Job Details page.

Examples:

        $rows = @(
            @("192.168.1.1", "Server1", "Online"),
            @("192.168.1.2", "Server2", "Offline")
        )
        Send-XyOpsTable -Rows $rows -Header @("IP", "Name", "Status") -Title "Server Status"

> #### Send-XyOpsHtml

        Send-XyOpsHtml -Content <string> [-Title <string>] [-Caption <string>]

Renders custom HTML in the Job Details page.

Examples:

        $html = "<h3>Summary</h3><ul><li>Total: <b>1000</b></li></ul>"
        Send-XyOpsHtml -Content $html -Title "Results"

> #### Send-XyOpsText

        Send-XyOpsText -Content <string> [-Title <string>] [-Caption <string>]

Renders plain text with preserved formatting.

Examples:

        $logContent = Get-Content "/var/log/app.log" -Raw
        Send-XyOpsText -Content $logContent -Title "Application Log"

> #### Send-XyOpsMarkdown

        Send-XyOpsMarkdown -Content <string> [-Title <string>] [-Caption <string>]

Renders Markdown content (converted to HTML).

Examples:

        $md = "## Results`n- **Success**: 98%`n- **Failed**: 2%"
        Send-XyOpsMarkdown -Content $md -Title "Summary"

> #### Get-XyOpsInputFiles

        Get-XyOpsInputFiles

Returns an array of input file metadata objects.

Examples:

        $files = Get-XyOpsInputFiles
        foreach ($file in $files) {
            Write-xyOpsJobOutput "Processing: $($file.filename) ($($file.size) bytes)"
            # File is already in current directory
            $content = Get-Content $file.filename
        }

> #### Get-XyOpsParam

        Get-XyOpsParam -Name <string> [-Default <object>]

Retrieves parameter values from xyOps or environment variables.

Examples:

        $timeout = Get-XyOpsParam -Name "timeout" -Default 30
        $apiKey = Get-XyOpsParam -Name "api_key"

---
## Data Collection

This plugin **DOES NOT** collect any data or user information.