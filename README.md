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
- `Process Module Files`

## Usage

When creating an event, you will provide your PowerShell script code inside the **Code Block** parameter. There is also an optional parameter that is checked by default, **Enable Time in Output**, which as the name implies, enables a timestamp on each output line when using the **Log** helper function. Checking off the **Output xyOps JSON Data** parameter will write the job data in JSON format in the job output at the beginning of the job. This can be useful when creating your events to get a visual representation of the included data available to you. *Note that this parameter is locked to administrator accounts.* This JSON data is made available as a PowerShell object variable called **$xyops**. So outputting the JSON data will let you see the structure of that object variable. Checking off **Process Module Files** will import all .psm1 files attached to the job input. These files can be manually uploaded each time or added to a bucket to be referenced by a **Fetch Bucket** action.

## Helper Functions

This plugin includes the following helper functions:
- `Log`
- `GenerateFilename`
- `ReportOutput`
- `ReportProgress`
- `ReportFile`
- `ReportError`

### Syntax

> #### Log

        Log [-Text] <string> [-Level {Information | Warning | Error}]

The **Log** helper function let's you report text back to the job output which will be displayed in the job details.

Examples:

1. Reporting text back to the job output.

        Log "Sample output to be passed to xyOps job output."

2. Strings can be piped to the **Log** helper function.

        "Log this information to the job output, please. Thanks." | Log -Level Warning

> #### GenerateFilename

        GenerateFilename -fileType <string> [-prefix <string>]

The **GenerateFilename** helper function generates a filename that includes a GUID as well as an optional prefix.

Examples:

1. Generate a new output filename. You'll see that generated filename is listed twice. This is because it both logs the filename to the job output as well as returns it. This is by design to have it both logged in the output and be assignable to a variable for later use. Spaces in the -prefix parameter are replaced with underscores.

        GenerateFilename -fileType csv

        > [INFO] Output file: 151915eb-c5d1-4a9d-8c52-c9734c3fbf1f.csv
        > 151915eb-c5d1-4a9d-8c52-c9734c3fbf1f.csv

2. Generate a filename with a prefix and use it in a command.

        $outfile = GenerateFilename -fileType csv -prefix "people names"
        
        > [INFO] Output file: people_names_bfd73a3c-50cc-47aa-b858-4cf17474c9fa.csv

        $peopleList | Export-Csv -Path $outfile

> #### ReportOutput

        ReportOutput [-inputObject] <object>

The **ReportOutput** helper function provides a simple way to report back updates to the job output using a PowerShell object or a hashtable. The input is converted to the proper JSON format that xyOps requires. Keep in mind that xyOps expects a specific structure, depending on what you're reporting back. Please refer to the [xyOps documentation](https://docs.xyops.io/) for more information.

Examples:

1. Bypass the ReportProgress function and report the progress data directly using the **ReportOutput** function.

        ReportOutput ([pscustomobject]@{
            xy       = 1
            progress = 0.75
        })

> #### ReportProgress

        ReportProgress [-percent] <decimal>

The **ReportProgress** helper function provides a simple way to report back progress percent to the job output. This progress is displayed on the job details page while running.

Examples:

1. Report progress of 50%.

        ReportProgress -percent 0.5

2. Report progress of 25%.

        ReportProgress 0.25

3. Using ReportProgress how you might normally use PowerShell's built-in Write-Progress cmdlet.

        function repeatNames {
            param(
                $firstName,
                $lastName
            )

            $items = 1..5
            $current = 0
            foreach ($current in $items) {
                $current++
                ReportProgress -percent ($current / $items.Count)
                Log "Hello, $($firstName) $($lastName)! Welcome!"
                Start-Sleep -Seconds 1
            }
        }

        repeatNames -firstName Jon -lastName Doe

> #### ReportFile

        ReportFile [-filename] <string>

The **ReportFile** helper function allows you to upload a file to the job output. The file is then accessible in the UI to download. It can also be passed to the input of a proceeding event within a workflow to be further processed.

Examples:

1. Report a generated file back to the job output.

        $outfile = GenerateFilename -fileType csv -prefix people
        
        > [INFO] Output file: people_bfd73a3c-50cc-47aa-b858-4cf17474c9fa.csv

        $peopleList | Export-Csv -Path $outfile
        ReportFile -filename $outfile

2. Generate output and report the file in one event, then consume the file in a second event using a workflow.

First Event Code (generate data and output file)

        $filename = GenerateFilename -fileType csv -prefix 'people'

        $items = [System.Collections.Generic.List[object]]::new(@(
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
        ))

        $items | Export-Csv -Path $filename -NoTypeInformation

        ReportFile $filename
 
Second Event Code (receiving input from previous event)

        $people = Import-Csv -Path ($xyops.input.files[0].filename)

        foreach ($person in $people) {
                Log "$($person.Name), $($person.Age), is from $($person.Country)."
        }

> #### ReportError

        ReportError [-jobError] <string> [-errorCode <int>] [-exit <switch>]

The **ReportError** helper function reports back error details to the job output in a consistent format. You can provide a custom error code when reporting or leave it blank to use the default error code **999**.

Examples:

1. Report a generic error back to the job output.

        try {
                Invoke-RestMethod -Uri https://idontexist.comerror
        }
        catch {
                ReportError -jobError "Something went wrong!"
        }

2. Report the same error using positional parameters.

        try {
                Invoke-RestMethod -Uri https://idontexist.comerror
        }
        catch {
                ReportError "Something went wrong!"
        }

3. Report a generic error back to the job output using a custom error code.

        try {
                Invoke-RestMethod -Uri https://idontexist.comerror
        }
        catch {
                ReportError -jobError "Something went wrong!" -errorCode 56
        }

4. Report the same error using positional parameters.

        try {
                Invoke-RestMethod -Uri https://idontexist.comerror
        }
        catch {
                ReportError "Something went wrong!" 56
        }

---
## Data Collection

This plugin **DOES NOT** collect any data or user information.