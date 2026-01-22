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

When creating an event, you will provide your PowerShell script code inside the **Code Block** parameter. There is also an optional parameter that is checked by default, **Enable Time in Output**, which as the name implies, enables a timestamp on each output line when using the **out** helper function. Checking off the **Output xyOps JSON Data** parameter will output the job data in JSON format in the job output. This can be useful when creating your events to get a visual representation of the included data available to you. *Note that this parameter is locked to administrator accounts.* This JSON data is also available as a PowerShell object variable called **$xyops**. So outputting the JSON data will let you see the structure of that object variable.

## Helper Functions

This plugin includes the following helper functions:
- `out`
- `reportProgress`

### Syntax

> #### out

The **out** helper function let's you report text back to the job output which will be displayed in the job details.

Examples:

1. Reporting text back to the job output.

        out "Sample output to be passed to xyOps job output."

2. Strings can be piped to the **out** helper function.

        "Log this information to the job output, please. Thanks." | out

> #### reportProgress

The **reportProgress** helper function provides a simple way to report back progress percent to the job output. This progress is displayed on the job details page while running.

Examples:

1. Report progress of 50%.

        reportProgress -percent 0.5

2. Report progress of 25%.

        reportProgress 0.25

3. Using reportProgress how you might normally use PowerShell's built-in Write-Progress cmdlet.

        function repeatNames {
            param(
                $firstName,
                $lastName
            )

            $items = 1..5
            $current = 0
            foreach ($current in $items) {
                $current++
                reportProgress -percent ($current / $items.Count)
                out "Hello, $($firstName) $($lastName)! Welcome!"
                Start-Sleep -Seconds 1
            }
        }

        repeatNames -firstName Jon -lastName Doe

---
## Data Collection

This plugin **DOES NOT** collect any data or user information.