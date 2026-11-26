<p align="center"><img src="logo.png" height="128" alt="PowerShell Plugin"/></p>
<h1 align="center">PowerShell Plugin</h1>

PowerShell event plugin for the [xyOps Workflow Automation System](https://xyops.io).

---

## Requirements
- **[PowerShell 7+](https://github.com/PowerShell/PowerShell)** (Cross-Platform)

For detailed instructions on installing PowerShell, please review the [Microsoft Learn Documentation](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell).

### Platform Support:
- **Windows/Linux/macOS**: PowerShell 7+

---

## Parameters

- **Code Block** - Your PowerShell script code
- **Enable Time in Output** [optional] - Adds timestamps to each log line (enabled by default)
- **Output xyOps JSON Data** [optional] - Displays job configuration as formatted JSON (admin only)
- **Process Module Files** [optional] - Import all .psm1 files attached to the job input. These files can be uploaded on a manual job run or added to a bucket to be referenced by a 'Fetch Bucket' action.
- **Data Passthrough** [optional] - If checked, data output from one event will pass through automatically to its output. Note that if an event outputs the same data property as existing data that was passed in, it will overwrite what was passed into it.
- **Global Text Protection Mask** [optional] - The string value used for the global text protection mask value. When masking a protected string, it will be replaced by this value.
- **Bucket API Key Variable Name** [optional] - The variable name used for the API Key used for accessing buckets. (See **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)
- **Cache Bucket ID Variable Name** [optional] - The secret vault variable name used for the Bucket ID when configuring the cache bucket setup. (See **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)
- **Send Email API Key Variable Name** [optional] - The secret vault variable name used for the API Key for sending emails. (See **[Setting Up Email API Key](#setting-up-email-api-key)**)
- **Enable Debug** [optional] - If checked, the plugin will output much more detail from built-in helper functions to help with troubleshooting.
- **Run as User (uid)** [optional] - Enter the uid of the user you want the event to run as. This overrides the plugin default.
- **Run as Group (gid)** [optional] - Enter the gid of the group you want the event to run as. This overrides the plugin default.

## Usage

When creating an event, you will provide your PowerShell script code inside the **Code Block** parameter. The job data is made available as a PowerShell object variable called **$xyOps**. Enabling **Output xyOps JSON Data** will display the structure of this object and can be used when developing your scripts. It is not recommended to keep this on for production jobs.

## Setup

At the end of this document, there are some optional configuration steps that are required to use certain helper functions.
**[Setting Up Cache Bucket](#setting-up-cache-bucket)** | **[Setting Up Email API Key](#setting-up-email-api-key)**

---

## Helper Functions

This plugin includes the following helper functions:

#### Logging & Core Output
- [Write-xyOpsJobOutput](#write-xyopsjoboutput) - Write log messages with severity levels
- [Send-xyOpsStatus](#send-xyopsstatus) - Reports job status to xyOps
- [Send-xyOpsOutput](#send-xyopsoutput) - Low-level structured output to xyOps
- [Send-xyOpsProgress](#send-xyopsprogress) - Report job progress percentage
- [Set-xyOpsJobResult](#set-xyopsjobresult) - Set the final jobs status that is passed to xyOps
- [Write-xyOpsError](#write-xyopserror) - Write out expanded error details from a try/catch block
- [Protect-xyOpsSensitiveText](#protect-xyopssensitivetext) - Sanitize sensitive text block

#### File & Data Management
- [Send-xyOpsFile](#send-xyopsfile) - Upload files to job output
- [Send-xyOpsPerf](#send-xyopsperf) - Report performance metrics (pie chart)
- [Send-xyOpsLabel](#send-xyopslabel) - Set custom job label
- [Send-xyOpsData](#send-xyopsdata) - Pass data to next job in workflow
- [Send-xyOpsWorkflowData](#send-xyopsworkflowdata) - Pass data to the workflow workflow
- [Get-xyOpsInputFiles](#get-xyopsinputfiles) - Get input file metadata
- [Get-xyOpsBucketFile](#get-xyopsbucketfile) - Gets file from the specified bucket
- [Add-xyOpsBucketFile](#add-xyopsbucketfile) - Adds file to the specified bucket
- [Remove-xyOpsBucketFile](#remove-xyopsbucketfile) - Deletes file from the specified bucket
- [Get-xyOpsBucketData](#get-xyopsbucketdata) - Gets data from the specified bucket
- [Set-xyOpsBucketData](#set-xyopsbucketdata) - Sets data in the cache bucket
- [Clear-xyOpsBucket](#clear-xyopsbucket) - Clears data and/or files from the specified bucket
- [Get-xyOpsCache](#get-xyopscache) - Gets data from the cache bucket
- [Set-xyOpsCache](#set-xyopscache) - Sets data in the cache bucket
- [Clear-xyOpsCache](#Clear-xyopscache) - Clears data in the cache bucket
- [Get-xyOpsParam](#get-xyopsparam) - Get parameter values (supports listing all params)
- [Get-xyOpsTags](#get-xyopstags) - Gets available system tags.
- [Send-xyOpsTags](#send-xyopstags) - Pushes tags to the job output.
- [Send-xyOpsEmail](#send-xyopsemail) - Send an email using the built-in xyOps mechanism.
- [Push-xyOpsAction](#push-xyopsaction) - Adds actions to the job, workflow or alert.
- [New-Filename](#new-filename) - Generates a new filename that includes a GUID for uniqueness.

#### UI Display Functions
- [Send-xyOpsTable](#send-xyopstable) - Display data tables
- [Send-xyOpsHtml](#send-xyopshtml) - Display HTML content
- [Send-xyOpsText](#send-xyopstext) - Display plain text (preserved formatting)
- [Send-xyOpsMarkdown](#send-xyopsmarkdown) - Display Markdown content


## Syntax
---
> #### Write-xyOpsJobOutput

```
Write-xyOpsJobOutput [-Message] <string> [-Level {info | warning | error | critical | debug}] [-Halt] [-Color {black | red | green | yellow | blue | purple | cyan | white}] [-Style {regular | bold | underline | background | highIntensity | boldHighIntensity | highIntensityBackground}]
```

	.SYNOPSIS
		Writes messages to the xyOps job output stream with optional timestamps.
	
	.DESCRIPTION
		This function lets you report text back to the job output which will be displayed in the job details.
	
	.PARAMETER Message
		The message to log.
	
	.PARAMETER Level
		The log level (info, warning, error, critical). Default is 'info'.

	.PARAMETER Halt
		Setting this switch will halt the processing of the script completely and jump to the end. This will throw an error even if the level is set to info or warning.

	.PARAMETER Color
		This sets the color for the output text.

	.PARAMETER Style
		This sets the style of the output text. This cannot be used on its own and requires that the Color parameter be set as well. The default style when a color is set is 'regular'.

Examples:

```powershell
# Reporting text back to the job output.
Write-xyOpsJobOutput "Sample output to be passed to xyOps job output."

# Strings can be piped to the helper function.
"Log this information to the job output, please. Thanks." | Write-xyOpsJobOutput -Level warning

# The below examples uses all the possible color and style combinations for reference.

Write-xyOpsJobOutput "Black - Regular." -Color black
Write-xyOpsJobOutput "Black - Background." -Color black -Style Background
Write-xyOpsJobOutput "Black - Bold." -Color black -Style Bold
Write-xyOpsJobOutput "Black - BoldHighIntensity." -Color black -Style BoldHighIntensity
Write-xyOpsJobOutput "Black - HighIntensity." -Color black -Style HighIntensity
Write-xyOpsJobOutput "Black - HighIntensityBackground." -Color black -Style HighIntensityBackground
Write-xyOpsJobOutput "Black - RegUnderlineular." -Color black -Style Underline

Write-xyOpsJobOutput "Red - Regular." -Color Red
Write-xyOpsJobOutput "Red - Background." -Color Red -Style Background
Write-xyOpsJobOutput "Red - Bold." -Color Red -Style Bold
Write-xyOpsJobOutput "Red - BoldHighIntensity." -Color Red -Style BoldHighIntensity
Write-xyOpsJobOutput "Red - HighIntensity." -Color Red -Style HighIntensity
Write-xyOpsJobOutput "Red - HighIntensityBackground." -Color Red -Style HighIntensityBackground
Write-xyOpsJobOutput "Red - RegUnderlineular." -Color Red -Style Underline

Write-xyOpsJobOutput "Green - Regular." -Color Green
Write-xyOpsJobOutput "Green - Background." -Color Green -Style Background
Write-xyOpsJobOutput "Green - Bold." -Color Green -Style Bold
Write-xyOpsJobOutput "Green - BoldHighIntensity." -Color Green -Style BoldHighIntensity
Write-xyOpsJobOutput "Green - HighIntensity." -Color Green -Style HighIntensity
Write-xyOpsJobOutput "Green - HighIntensityBackground." -Color Green -Style HighIntensityBackground
Write-xyOpsJobOutput "Green - RegUnderlineular." -Color Green -Style Underline

Write-xyOpsJobOutput "Yellow - Regular." -Color Yellow
Write-xyOpsJobOutput "Yellow - Background." -Color Yellow -Style Background
Write-xyOpsJobOutput "Yellow - Bold." -Color Yellow -Style Bold
Write-xyOpsJobOutput "Yellow - BoldHighIntensity." -Color Yellow -Style BoldHighIntensity
Write-xyOpsJobOutput "Yellow - HighIntensity." -Color Yellow -Style HighIntensity
Write-xyOpsJobOutput "Yellow - HighIntensityBackground." -Color Yellow -Style HighIntensityBackground
Write-xyOpsJobOutput "Yellow - RegUnderlineular." -Color Yellow -Style Underline

Write-xyOpsJobOutput "Blue - Regular." -Color Blue
Write-xyOpsJobOutput "Blue - Background." -Color Blue -Style Background
Write-xyOpsJobOutput "Blue - Bold." -Color Blue -Style Bold
Write-xyOpsJobOutput "Blue - BoldHighIntensity." -Color Blue -Style BoldHighIntensity
Write-xyOpsJobOutput "Blue - HighIntensity." -Color Blue -Style HighIntensity
Write-xyOpsJobOutput "Blue - HighIntensityBackground." -Color Blue -Style HighIntensityBackground
Write-xyOpsJobOutput "Blue - RegUnderlineular." -Color Blue -Style Underline

Write-xyOpsJobOutput "Purple - Regular." -Color Purple
Write-xyOpsJobOutput "Purple - Background." -Color Purple -Style Background
Write-xyOpsJobOutput "Purple - Bold." -Color Purple -Style Bold
Write-xyOpsJobOutput "Purple - BoldHighIntensity." -Color Purple -Style BoldHighIntensity
Write-xyOpsJobOutput "Purple - HighIntensity." -Color Purple -Style HighIntensity
Write-xyOpsJobOutput "Purple - HighIntensityBackground." -Color Purple -Style HighIntensityBackground
Write-xyOpsJobOutput "Purple - RegUnderlineular." -Color Purple -Style Underline

Write-xyOpsJobOutput "Cyan - Regular." -Color Cyan
Write-xyOpsJobOutput "Cyan - Background." -Color Cyan -Style Background
Write-xyOpsJobOutput "Cyan - Bold." -Color Cyan -Style Bold
Write-xyOpsJobOutput "Cyan - BoldHighIntensity." -Color Cyan -Style BoldHighIntensity
Write-xyOpsJobOutput "Cyan - HighIntensity." -Color Cyan -Style HighIntensity
Write-xyOpsJobOutput "Cyan - HighIntensityBackground." -Color Cyan -Style HighIntensityBackground
Write-xyOpsJobOutput "Cyan - RegUnderlineular." -Color Cyan -Style Underline

Write-xyOpsJobOutput "White - Regular." -Color White
Write-xyOpsJobOutput "White - Background." -Color White -Style Background
Write-xyOpsJobOutput "White - Bold." -Color White -Style Bold
Write-xyOpsJobOutput "White - BoldHighIntensity." -Color White -Style BoldHighIntensity
Write-xyOpsJobOutput "White - HighIntensity." -Color White -Style HighIntensity
Write-xyOpsJobOutput "White - HighIntensityBackground." -Color White -Style HighIntensityBackground
Write-xyOpsJobOutput "White - RegUnderlineular." -Color White -Style Underline

```
[Logging & Core Output](#logging--core-output)

---
> #### Send-xyOpsOutput

```
Send-xyOpsOutput [-InputObject] <object>
```

	.SYNOPSIS
		Sends structured JSON output back to the xyOps system. This is low-level output to xyOps.
	
	.DESCRIPTION
		This function provides a simple way to report back updates to the job output using a PowerShell object or a hashtable. The input is converted to the proper JSON format that xyOps requires. Keep in mind that xyOps expects a specific structure, depending on what you're reporting back.
	
	.PARAMETER InputObject
		The object to send to xyOps. Can be a hashtable, PSCustomObject, array, or primitive type.

Please refer to the [xyOps documentation](https://github.com/pixlcore/xyops/blob/main/docs/plugins.md) for more information.

Examples:

```powershell
# Tell xyOps that the job has completed successfully.
Send-xyOpsOutput @{ xy = 1; code = 0 }

# Bypass the Send-XyOpsProgress function and report the progress data directly using the Send-XyOpsOutput function.
Send-xyOpsOutput ([pscustomobject]@{
	xy       = 1
	progress = 0.75
})
```
[Logging & Core Output](#logging--core-output)

---
> #### Send-xyOpsProgress

```
Send-xyOpsProgress [-Percent] <decimal> [-Status <string>]
```

	.SYNOPSIS
		Reports job progress percentage to xyOps.
	
	.DESCRIPTION
		Sends a progress update to the xyOps system with a percentage value between 0 and 100. Optionally, you can include a status with the progress update using the -Status parameter.
	
	.PARAMETER Percent
		The progress percentage (0-100).
	
	.PARAMETER Status
		The current status for the job.

Examples:

```powershell
# Report progress of 25%.
Send-xyOpsProgress -Percent 25

# Report progress with an optional status.
Send-xyOpsProgress -Percent 46 -Status "Processing $($itemNumber) of $($items.Count)..."

# Report progress with an optional status.
Send-xyOpsProgress 75.5 "Almost done!"

# Using Send-xyOpsProgress how you might normally use PowerShell's built-in Write-Progress cmdlet.

function repeatNames {
	param(
		$firstName,
		$lastName
	)

	$items = 1..5
	$current = 0
	foreach ($current in $items) {
		$current++
		Send-xyOpsProgress ($current / $items.Count * 100) "Working on $($current) of $($items.Count)"
		Write-xyOpsJobOutput "Hello, $($firstName) $($lastName)! Welcome!"
		Start-Sleep -Seconds 1
	}
}

repeatNames -firstName Jon -lastName Doe
```
[Logging & Core Output](#logging--core-output)

---
> #### Protect-xyOpsSensitiveText

```
Protect-xyOpsSensitiveText [-Text] <string> [-SensitiveName <array[string]>] [-Mask <string>]
```

	.SYNOPSIS
		Protects sensitive text values.
	
	.DESCRIPTION
		This function is used to sanitize strings of text that might contain sensitive data, such as Authorization headers. 
	
	.PARAMETER Text
		The full text to sanitize.
	
	.PARAMETER SensitiveName
		Specific list of property names to check.
	
	.PARAMETER Mask
		The string value to replace protected text with.
	
	.INPUTS
		System.String
		You can pipe a string (Text) to this function.
		Supports ValueFromPipeline.

Examples:

```powershell
# Santize error details using the default settings.
Write-xyOpsJobOutput ($sensitiveTextBlock | Protect-xyOpsSensitiveText)

# Santize error details but specifying the Authorization header name and using a custom mask.
Write-xyOpsJobOutput ($sensitiveTextBlock | Protect-xyOpsSensitiveText -SensitiveName 'Authorization' -Mask '<<REDACTED>>')

```
[Logging & Core Output](#logging--core-output)

---
> #### Write-xyOpsError

```
Write-xyOpsError [-Error] <ErrorRecord> [-Halt]
```

	.SYNOPSIS
		Expands the provided error record details and writes them to the job output.
	
	.DESCRIPTION
		This function is used in the Catch code block of a try/catch. It expands the details of the error record passed to it and writes them to the job output. 
	
	.PARAMETER Error
		The error record to expand.
	
	.PARAMETER Halt
		Setting this switch will halt the processing of the script and jump to the end.
	
	.PARAMETER NoDataProtection
		Setting this switch will disable passing the error through the Protect-xyOpsSensitiveText helper function so the full error details, including sensitive data like Authorization header details, will be written to the job output.

Examples:

```powershell
# Write out the error details to the job output while continuing script processing.
try {
	Invoke-WebRequest "https://doesnotexist.com/api/values/getall"
}
catch {
	Write-xyOpsError $_
}

# Write out the error details to the job output and halting script processing.
try {
	Invoke-WebRequest "https://doesnotexist.com/api/values/getall"
}
catch {
	Write-xyOpsError $_ -Halt
}
```
[Logging & Core Output](#logging--core-output)

---
> #### Set-xyOpsJobResult

```
Set-xyOpsJobResult [-Status] {success | warning | error | critical} [-Description] <string>
```

	.SYNOPSIS
		Set the final job result status and description.
	
	.DESCRIPTION
		This function sets the current job result status and description that will be passed to xyOps at the end of the script processing. It's designed so that the severity of the status can't be downgraded. For example, a warning can't be changed to a success, an error can't be changed to a warning or success, and so on.
	
	.PARAMETER Status
		The status of the job result to be set.
	
	.PARAMETER Description
		The description that will accompany the result.

Examples:

```powershell
# Set the job result to warning with a custom description.
Set-xyOpsJobResult -Status warning -Description 'A non-breaking issue occurred.'
```
[Logging & Core Output](#logging--core-output)

---
> #### Send-xyOpsStatus

```
Send-xyOpsStatus [-Status] <string>
```
	.SYNOPSIS
		Reports job status to xyOps.

	.DESCRIPTION
		Sends a status for the job that is displayed on the job status page as well as the jobs list.

	.PARAMETER Status
		The current status for the job.

Examples:

```powershell
# Report a status.
Send-xyOpsStatus "Building sites list..."

# Report a status.
Send-xyOpsStatus -Status "Processing $($itemNumber) of $($items.Count)..."
```
[Logging & Core Output](#logging--core-output)

---
> #### Send-xyOpsFile

```
Send-xyOpsFile [-Filename] <string>
```

	.SYNOPSIS
		Reports file changes to the xyOps system so that xyOps can upload the file and use it.
	
	.DESCRIPTION
		Uploads a file to the job output. The file is then accessible in the UI to download. It can also be passed to the input of a subsequent event within a workflow to be further processed.
	
	.PARAMETER Filename
		The path to the file to report.

Examples:


```powershell
# Report a generated file back to the job output.
$outfile = "people_$(New-Guid).csv"
$peopleList | Export-Csv -Path $outfile
Send-xyOpsFile $outfile

# Generate output and report the file in one event, then consume the file in a second event using a workflow.

######
#First Event Code (generate data and output file)
######

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
 
######
# Second Event Code (receiving input from previous event)
######

$files = Get-xyOpsInputFiles
$people = Import-Csv -Path $files[0].filename

foreach ($person in $people) {
	Write-xyOpsJobOutput "$($person.Name), $($person.Age), is from $($person.Country)."
}
```
[File & Data Management](#file--data-management)

---
> #### Send-xyOpsPerf

```
Send-xyOpsPerf [-Metrics] <hashtable> [-Scale <int>]
```

	.SYNOPSIS
		Reports performance metrics to xyOps.
	
	.DESCRIPTION
		Sends performance timing data to xyOps for display as a pie chart on the Job Details page. Metrics represent time spent in different categories.
	
	.PARAMETER Metrics
		Hashtable of performance metrics where keys are category names and values are time in seconds.
	
	.PARAMETER Scale
		Optional scale factor if metrics are not in seconds (e.g., 1000 for milliseconds).

Examples:

```powershell
# Metrics in seconds
Send-xyOpsPerf @{ db = 18.51; http = 3.22; gzip = 0.84 }

# Metrics in milliseconds
Send-xyOpsPerf @{ db = 1851; http = 3220; gzip = 840 } -Scale 1000
```
[File & Data Management](#file--data-management)

---
> #### Send-xyOpsLabel

```
Send-xyOpsLabel [-Label] <string>
```

	.SYNOPSIS
		Sets a custom label for the job.
	
	.DESCRIPTION
		Sets a custom label for the job which will be displayed alongside the Job ID in the xyOps UI. Useful for differentiating jobs with different parameters.
	
	.PARAMETER Label
		The label text to display.

Examples:

```powershell
# Set a label of 'Backup - Production DB'
Send-xyOpsLabel "Backup - Production DB"

# Set a label with a variable that would change depending on the environment it's running on.
Send-xyOpsLabel "Deploy to $env:TARGET_ENV"
```
[File & Data Management](#file--data-management)

---
> #### Send-xyOpsData

```
Send-xyOpsData [-Data] <object>
```

	.SYNOPSIS
		Sends arbitrary output data to be passed to the next job.
	
	.DESCRIPTION
		Outputs data that will be automatically passed to the next job in a workflow or via a run event action. Data can be any PowerShell object.
	
	.PARAMETER Data
		The data object to pass to the next job.

Examples:

```powershell
Send-xyOpsData @{ hostname = "server01"; status = "ok" }
```
[File & Data Management](#file--data-management)

---
> #### Send-xyOpsWorkflowData

```
Send-xyOpsWorkflowData [-Key] <string> [-Data] <object>
```

	.SYNOPSIS
		Sends arbitrary output data to be passed to into the workflow.
	
	.DESCRIPTION
		Outputs data that will be automatically passed to workflow, making it available to all subsequent jobs via the $xyops.workflowData object. Data can be any PowerShell object.
	
	.PARAMETER Key
		The key to pass to the workflow.

	.PARAMETER Data
		The data object to pass to the workflow.

Examples:

```powershell
Send-xyOpsWorkflowData -Key 'servers' -Data @(
	@{ hostname = "server01"; status = "ok" }
	@{ hostname = "server02"; status = "down" }
)

Send-xyOpsWorkflowData 'servers' @(
	@{ hostname = "server01"; status = "ok" }
	@{ hostname = "server02"; status = "down" }
)
```
[File & Data Management](#file--data-management)

---
> #### Get-xyOpsInputFiles

```
Get-xyOpsInputFiles
```

	.SYNOPSIS
		Gets the list of input files passed to the job.
	
	.DESCRIPTION
		Returns an array of input file metadata objects from the xyOps job input. Files are already downloaded to the current working directory.

Examples:

```powershell
$files = Get-xyOpsInputFiles
foreach ($file in $files) {
	Write-Host "Processing: $($file.filename)"
}
```
[File & Data Management](#file--data-management)

---
> #### Get-xyOpsBucketFile

```
Get-xyOpsBucketFile [-BucketId] <string> [-Filename] <string> [-OutFilename <string>]
```

	.SYNOPSIS
		Gets file from the specified bucket.
	
	.DESCRIPTION
		Uses the get_bucket API to retrieve a file from a specified bucket.
	
	.PARAMETER BucketId
		The ID of the bucket you want to access.

	.PARAMETER Filename
		The filename in the bucket you want to retrieve.

	.PARAMETER OutFilename
		Optionally, set the output filename to save as. Otherwise, the same filename as the original file is used.

Examples:

```powershell
Get-xyOpsBucketFile -BucketId 'bml2ut4ys4pt7raf' -Filename 'customers.csv'
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Add-xyOpsBucketFile

```
Add-xyOpsBucketFile [-BucketId] <string> [-Filename] <string>
```

	.SYNOPSIS
		Adds file to the specified bucket.
	
	.DESCRIPTION
		Uses the upload_bucket_files API to add a file to a specified bucket.
	
	.PARAMETER BucketId
		The ID of the bucket you want to access.
	
	.PARAMETER Filename
		The local filename you want to upload to the bucket.

Examples:

```powershell
$newFile = New-FileName -FileType csv
$customers | Export-Csv -Path $newFile
Add-xyOpsBucketFile -BucketId 'bml2ut4ys4pt7raf' -Filename $newFile
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Remove-xyOpsBucketFile

```
Remove-xyOpsBucketFile [-BucketId] <string> [-Filename] <string>
```

	.SYNOPSIS
		Deletes file from the specified bucket.
	
	.DESCRIPTION
		Uses the delete_bucket_file API to delete a file from a specified bucket.
	
	.PARAMETER BucketId
		The ID of the bucket you want to access.
	
	.PARAMETER Filename
		The filename you want to delete from the bucket.

Examples:

```powershell
Remove-xyOpsBucketFile -BucketId 'bml2ut4ys4pt7raf' -Filename 'customers.csv'
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Get-xyOpsBucketData

```
Get-xyOpsBucketData [-BucketId] <string>
```

	.SYNOPSIS
		Gets data from the specified bucket.
	
	.DESCRIPTION
		Uses the get_bucket API to retrieve JSON data from the specified bucket.
	
	.PARAMETER BucketId
		The ID of the bucket you want to access.

Examples:

```powershell
$bucketData = Get-xyOpsBucketData -BucketId 'bml2ut4ys4pt7raf'
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Set-xyOpsBucketData

```
Set-xyOpsBucketData [-BucketId] <string> [-Key] <string> [-InputObject] <object>
```

	.SYNOPSIS
		Sets data to the specified bucket.
	
	.DESCRIPTION
		Uses the write_bucket API to write a JSON converted object to a specified bucket data.

	.PARAMETER BucketId
		The ID of the bucket you want to access.
	
	.PARAMETER Key
		The key of the item you want to add to the bucket data.

	.PARAMETER InputObject
		The input object you want to add to the bucket data.

Examples:

```powershell
Set-xyOpsBucketData -BucketId 'bml2ut4ys4pt7raf' -Key 'Countries' -InputObject @('Canada','United States','United Kingdom')
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Clear-xyOpsBucket

```
Clear-xyOpsBucket [-BucketId] <string> [-All <switch>]
Clear-xyOpsBucket [-BucketId] <string> [-FilesOnly <switch>]
Clear-xyOpsBucket [-BucketId] <string> [-DataOnly <switch>]
```

	.SYNOPSIS
		Clears data in the specified bucket.
	
	.DESCRIPTION
		Uses the empty_bucket API to clear data and/or files from the specified bucket.

	.PARAMETER BucketId
		The ID of the bucket you want to clear.
	
	.PARAMETER All
		Clear both data and files from the bucket.
	
	.PARAMETER FilesOnly
		Clear only files from the bucket.

	.PARAMETER DataOnly
		Clear only data form the bucket.

Examples:

```powershell
Clear-xyOpsBucket -BucketId 'bml2ut4ys4pt7raf' -All
Clear-xyOpsBucket -BucketId 'bml2ut4ys4pt7raf' -FilesOnly
Clear-xyOpsBucket -BucketId 'bml2ut4ys4pt7raf' -DataOnly
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Get-xyOpsCache

```
Get-xyOpsCache [-Key] <string>
```

	.SYNOPSIS
		Gets data from the cache bucket.
	
	.DESCRIPTION
		Uses the get_bucket API to retrieve JSON data from a bucket configured for cache.

	.PARAMETER Key
		The key of the cached item you want to retrieve from the cache bucket.

Examples:

```powershell
$Countries = Get-xyOpsCache -Key Countries
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Set-xyOpsCache

```
Set-xyOpsCache [-Key] <string> [-InputObject] <object>
```

	.SYNOPSIS
		Sets data in the cache bucket.
	
	.DESCRIPTION
		Uses the write_bucket API to write a JSON converted object to a bucket's data configured for cache.

	.PARAMETER Key
		The key of the cache item you want to set.

	.PARAMETER InputObject
		The input object you want to save in the cache bucket data.

Examples:

```powershell
Set-xyOpsCache -Key Countries -InputObject @('Canada','United States','United Kingdom')
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Clear-xyOpsCache

```
Clear-xyOpsCache [-Keys] <array>
```

	.SYNOPSIS
		Clears data in the cache bucket.
	
	.DESCRIPTION
		Uses the write_bucket API to write an empty JSON converted object to a bucket's data configured for cache.

	.PARAMETER Keys
		The keys of the cachee items you want to clear.

Examples:

```powershell
Clear-xyOpsCache -Keys "Countries"
Clear-xyOpsCache -Keys @("People", "Countries")
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Get-xyOpsParam

```
Get-xyOpsParam [-Name <string>] [-Workflow]
```

	.SYNOPSIS
		Gets a parameter value from xyOps or environment variable.
	
	.DESCRIPTION
		Retrieves a parameter value. When called without a Name parameter, displays all available parameters in JSON format. By default, job parameters are accessed; to access workflow parameters, specify the -Workflow switch.
	
	.PARAMETER Name
		The parameter name to retrieve. If omitted, displays all available parameters.

	.PARAMETER Workflow
		Switch to indicate to pull from workflow parameters instead of job parameters.

Examples:

```powershell
# Get specific parameters
$timeout = Get-xyOpsParam -Name "timeout"
$apiKey = Get-xyOpsParam -Name "api_key"

# List all available parameters
Get-xyOpsParam

# List all available workflow parameters
Get-xyOpsParam -Workflow
```
[File & Data Management](#file--data-management)

---
> #### Get-xyOpsTags

```
Get-xyOpsTags [-Tags <list>] [-Indexed]
```

	.SYNOPSIS
		Gets available system tags.
	
	.DESCRIPTION
		Gets available system tags using the get_tags API. Optionally, you can supply tag titles so that only those are returned.

	.PARAMETER Tags
		Optionally supply a list of tag titles as an array or list. If the tags exist, they will be returned.

	.PARAMETER Indexed
		Optionally return the list of tags as a hashtable indexed on the tag titles.

Examples:

```powershell
# Get all tags.
Get-xyOpsTags

# Get all tags indexed.
Get-xyOpsTags -Indexed

# Get specific tags.
Get-xyOpsTags -Tags @('Canada','United States','United Kingdom')

# Get specific tags.
Get-xyOpsTags 'John','Joe','Jill','Jane'
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Send-xyOpsTags

```
Send-xyOpsTags [-Tags] <list>
```

	.SYNOPSIS
		Pushes tags to the job output.
	
	.DESCRIPTION
		Pushes one or more tags to be appended to the job output. The tags are provided as an array or list of tag names. Available tags are retrieved from the system to get the ID, which is used by xyOps to apply the correct tag.
	
	.PARAMETER Tags
		An array or list of tag titles or IDs to be set on the job. The tags must exist in the xyOps tags configuration, otherwise they will be ignored.

Examples:

```powershell
# Push tags to job output
Send-xyOpsTags -Tags @('Canada','United States','United Kingdom')

# Push tags to job output
Send-xyOpsTags 'John','Joe','Jill','Jane'
```

*API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Send-xyOpsEmail

```
Send-xyOpsEmail -To <string> [-From <string>] -Subject <string> -Body <string> [-CC <array[string]>] [-BCC <array[string]>] [-Title <string>] [-ButtonLabel <string>] [-ButtonUri <string>] [-Importance {low | normal | high}] [-Attachments <array[string]>]
```

	.SYNOPSIS
		Send an email using the built-in xyOps mechanism.
	
	.DESCRIPTION
		Sends an email using the built-in xyOps mechanism and configuration.

	.PARAMETER To
		The email address(es) of the recipient. Multiple recipients should be provided as an array.

	.PARAMETER From
		Optionally set the email address of the sender. e.g. 'alerts@example.com' or 'Alerts <alerts@example.com>'
	
	.PARAMETER Subject
		The email subject.

	.PARAMETER Body
		The email body. This parameter is processed as Markdown so your body text can be formatted using Markdown syntax. This also means
		you can supply pure HTML as Markdown supports HTML directly.

	.PARAMETER CC
		The email address(es) of the recipient(s) to CC. Multiple recipients should be provided as an array.
		
	.PARAMETER BCC
		The email address(es) of the recipient(s) to BCC. Multiple recipients should be provided as an array.

	.PARAMETER Title
		Title text that will be displayed at the top of the email in larger text.

	.PARAMETER ButtonLabel
		The label used in the optional button. Include this parameter to include a button in the top-right corner of the email.

	.PARAMETER ButtonUri
		The Uri to where the button will link to.

	.PARAMETER Importance
		Set the importance of the email. Choose between low, normal and high. This is set to normal by default.

	.PARAMETER Attachments
		Provide an array or list of file paths to files that you want to attach to the email.

Examples:

```powershell
# Send a basic email with high importance
Send-xyOpsEmail -To "user@domain.com" -Subject "Important Email Update" -Body "This is a test!" -Importance high

# Send a basic email with multiple recipients
Send-xyOpsEmail -To @("user@domain.com","user2@domain.com") -Subject "Multiple Recipients" -Body "Hello, both of you!" -Importance high

# Send an email with attachments
Send-xyOpsEmail -To "user@domain.com" -Subject "Reports" -Body "Please see attached." -Attachments './report1.pdf','./report_final.pdf'
```

*API Key Required, see **[Setting Up Email API Key](#setting-up-email-api-key)***

[File & Data Management](#file--data-management)

---
> #### Push-xyOpsAction

```
Push-xyOpsAction -Condition <string> -Email [-EmailUsers <array[string]>] [-EmailAddresses <array[string]>] [-ConditionTag <string>]
Push-xyOpsAction -Condition <string> -WebHook -WebHookId <string> [-WebHookText <string>] [-ConditionTag <string>]
Push-xyOpsAction -Condition <string> -RunEvent -RunEventId <string> [-RunEventParams <object>] [-RunEventIncludeOutput] [-ConditionTag <string>]
Push-xyOpsAction -Condition <string> -Channel -ChannelId <string> [-ConditionTag <string>]
Push-xyOpsAction -Condition <string> -Snapshot [-ConditionTag <string>]
Push-xyOpsAction -Condition <string> -Ticket -TicketType {issue | feature | release | change | maintenance | question | other} -TicketAssignees <array[string]> [-TicketTags <array[string]>] [-TicketDue <datetime>] [-ConditionTag <string>]
Push-xyOpsAction -Condition <string> -Plugin -PluginId <string> [-PluginParams <object>] [-ConditionTag <string>]
Push-xyOpsAction -Condition <string> -SuspendJob [-SuspendJobUsers <array[string]>] [-SuspendJobEmailAddresses <array[string]>] [-SuspendJobWebHookId <string>] [-SuspendJobWebHookText <string>] [-ConditionTag <string>]
Push-xyOpsAction -Condition <string> -DisableEvent [-ConditionTag <string>]
Push-xyOpsAction -Condition <string> -DeleteEvent [-ConditionTag <string>]
```

	.SYNOPSIS
		Adds actions to the job, workflow.
	
	.DESCRIPTION
		Pushes an action definition to the job, which is appended to the existing set of actions. Actions are normally configured on the event, but this lets your script add them dynamically while the job is running. Each action has a condition that determines when it fires and a type that determines what it does. Only one action type switch can be used per call, so call the function once for each action you want to add. Actions cannot be replaced or removed once pushed.
		Please refer to the [xyOps Action Types documentation](https://docs.xyops.io/#Docs/actions/action-types) for full details on each action type and how the payloads are generated.
	
	.PARAMETER Condition
		When the action should run. Choose from the following:
		`instant` - Run the action immediately, without waiting for the job to complete.
		`complete` - When the job completes, regardless of the outcome.
		`success` - When the job completes successfully (i.e. with a code of `0`).
		`error` - When the job completes with any error (i.e. a non-zero code).
		`user` - When the job completes with a custom error code (i.e. not `warning`, `critical` or `abort`).
		`warning` - When the job completes with the code set to `warning`.
		`critical` - When the job completes with the code set to `critical`.
		`abort` - When the job is aborted, either by a user or by a failure condition.
		`tag` - On job completion, only if the tag is present on the job. This condition requires the -ConditionTag parameter.
		`continue` - A special workflow condition that fires from a Controller node after all the connected jobs complete.

	.PARAMETER Email
		Switch to send an email notification to one or more users and/or explicit email addresses. For jobs, the message includes context such as links, log excerpts and performance data.

	.PARAMETER EmailUsers
		An array of xyOps usernames to email. At least one of -EmailUsers or -EmailAddresses is required for the Email action.

	.PARAMETER EmailAddresses
		An array of additional email addresses to notify. These are sent in addition to any users specified with -EmailUsers.

	.PARAMETER WebHook
		Switch to fire a configured outbound web hook. xyOps sends a templated payload containing the job context.

	.PARAMETER WebHookId
		The ID of the web hook you want to fire.

	.PARAMETER WebHookText
		Optional extra text that is appended to the generated web hook message.

	.PARAMETER RunEvent
		Switch to launch another event as a follow-up action. The new job inherits the context of the current job.

	.PARAMETER RunEventId
		The ID of the event you want to launch.

	.PARAMETER RunEventParams
		Optional object of parameters to override in the launched event.

	.PARAMETER RunEventIncludeOutput
		Switch to pass the captured text output of the current job to the launched job in `input.data.text`. The output must be smaller than the configured `max_inline_job_log_size`, which defaults to 1 MB. Only enable this for completion conditions, as the output is not available for `instant` actions. Note that job output can contain passwords or tokens, so review what your jobs print before forwarding it.

	.PARAMETER Channel
		Switch to notify a configured channel. Channels can bundle users (email/notify), a web hook and/or an event to run, and xyOps aggregates their results.

	.PARAMETER ChannelId
		The ID of the notification channel you want to notify.

	.PARAMETER Snapshot
		Switch to capture a server snapshot. For jobs, the job must target a specific server. Links to the snapshot are included in the results.

	.PARAMETER Ticket
		Switch to create a ticket with a generated body based on the job context. The ticket is inserted into the xyOps ticket system and linked back to the job.

	.PARAMETER TicketType
		The type of ticket to create. Choose from issue, feature, release, change, maintenance, question or other.

	.PARAMETER TicketAssignees
		An array of xyOps usernames to assign the ticket to.

	.PARAMETER TicketTags
		Optional array of tag titles or IDs to apply to the new ticket. Each tag is looked up against the system tags so a title can be used in place of the ID. If a tag does not exist, an error is written and the script halts.

	.PARAMETER TicketDue
		Optional due date for the new ticket.

	.PARAMETER Plugin
		Switch to invoke a custom Action Plugin. xyOps executes the plugin command or script with a structured JSON payload.

	.PARAMETER PluginId
		The ID of a plugin with a type of `action`.

	.PARAMETER PluginParams
		Optional object of plugin-defined parameter values.

	.PARAMETER SuspendJob
		Switch to suspend the running job until a user resumes it in the UI. Optionally notify users and/or fire a web hook about the suspension.

	.PARAMETER SuspendJobUsers
		An array of xyOps usernames to email about the suspension.

	.PARAMETER SuspendJobEmailAddresses
		An array of additional email addresses to notify about the suspension.

	.PARAMETER SuspendJobWebHookId
		The ID of a web hook to fire when the job is suspended.

	.PARAMETER SuspendJobWebHookText
		Optional extra text that is appended to the suspension web hook message.

	.PARAMETER DisableEvent
		Switch to disable the current event when the action runs. This is useful after repeated failures to prevent subsequent scheduled executions until the event is manually re-enabled.

	.PARAMETER DeleteEvent
		Switch to delete the current event when the action runs. Use with care, as the event is removed from the system. This is designed for ephemeral one-shot events that self-delete after running.

	.PARAMETER ConditionTag
		The tag title or ID used with the `tag` condition. This is required whenever -Condition is set to `tag`; otherwise an error is written and the script halts. The tag is looked up against the system tags so a title can be used in place of the ID, and the resolved condition is sent as `tag:TAGID`. If the tag does not exist, an error is written and the script halts. Tag lookups use the get_tags API, so this requires the bucket API key setup.

Examples:

```powershell
# Send an email to a user and an external address when the job completes with any error.
Push-xyOpsAction -Condition error -Email -EmailUsers @('oncall') -EmailAddresses 'ops@example.com'

# Fire a web hook immediately, without waiting for the job to complete.
Push-xyOpsAction -Condition instant -WebHook -WebHookId 'slack_ops' -WebHookText 'Paging on-call'

# Launch another event when the job completes successfully, passing the job output and overriding parameters.
Push-xyOpsAction -Condition success -RunEvent -RunEventId 'emi2d3f42zy' -RunEventParams @{ optimize = $true } -RunEventIncludeOutput

# Create a ticket when the job completes with a critical result. Tags can be supplied as titles or IDs.
Push-xyOpsAction -Condition critical -Ticket -TicketType 'issue' -TicketAssignees @('oncall') -TicketTags @('production','sev2') -TicketDue (Get-Date).AddDays(3)

# Invoke an Action Plugin when the job completes successfully.
Push-xyOpsAction -Condition success -Plugin -PluginId 'notify_grafana' -PluginParams @{ dashboard = 'builds' }

# Suspend the job for manual review and notify the deployers.
Push-xyOpsAction -Condition complete -SuspendJob -SuspendJobUsers @('deployers') -SuspendJobWebHookId 'slack_ops'

# Disable the event if the job fails, to stop further scheduled runs.
Push-xyOpsAction -Condition error -DisableEvent

# Run a follow-up event on job completion, but only if the job has the 'Production' tag.
Push-xyOpsAction -Condition tag -ConditionTag 'Production' -RunEvent -RunEventId 'emi2d3f42zy'
```

*API Key Required for tag resolution (`tag` condition and `-TicketTags`), see **[Setting Up Cache Bucket](#setting-up-cache-bucket)***

[File & Data Management](#file--data-management)

---
> #### Send-xyOpsTable

```
Send-xyOpsTable -Rows <array> -Header <array> [-Title <string>] [-Caption <string>]
```

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

Examples:

```powershell
# Provide data inline
Send-xyOpsTable -Rows @(@("192.168.1.1", "Server1", 100), @("192.168.1.2", "Server2", 200)) -Header @("IP", "Name", "Count")

# Setup data before sending
$rows = @(
	@("192.168.1.1", "Server1", "Online"),
	@("192.168.1.2", "Server2", "Offline")
)
Send-xyOpsTable -Rows $rows -Header @("IP", "Name", "Status") -Title "Server Status"
```
[UI Display Functions](#ui-display-functions)

---
> #### Send-xyOpsHtml

```
Send-xyOpsHtml -Content <string> [-Title <string>] [-Caption <string>]
```

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

Examples:

```powershell
$html = "<h3>Summary</h3><ul><li>Total: <b>1000</b></li></ul>"
Send-xyOpsHtml -Content $html -Title "Results"
```
[UI Display Functions](#ui-display-functions)

---
> #### Send-xyOpsText

```
Send-xyOpsText -Content <string> [-Title <string>] [-Caption <string>]
```

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

Examples:

```powershell
$logContent = Get-Content "/var/log/app.log" -Raw
Send-xyOpsText -Content $logContent -Title "Application Log"
```
[UI Display Functions](#ui-display-functions)

---
> #### Send-xyOpsMarkdown

```
Send-xyOpsMarkdown -Content <string> [-Title <string>] [-Caption <string>]
```

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

Examples:

```powershell
$md = "## Results`n- **Success**: 98%`n- **Failed**: 2%"
Send-xyOpsMarkdown -Content $md -Title "Summary"
```
[UI Display Functions](#ui-display-functions)

---
> #### New-Filename

```
New-Filename -Filetype <string> [-Prefix]
```

	.SYNOPSIS
		Generates a unique filename.
	
	.DESCRIPTION
		Generates a filename that uses a GUID for uniqueness.
	
	.PARAMETER Filetype
		This becomes the file extension.
	
	.PARAMETER Prefix
		This optional text will be included in the filename before the GUID value.

Examples:

```powershell
$OutputCsv = New-Filename -Filetype "csv" -Prefix "CityCenters"
```
[File & Data Management](#file--data-management)

---

## Setting Up Cache Bucket

In order to to use the cache and bucket management functionality built into this plugin, the following setup steps required.

#### Create Cache Bucket

1. In the menu pane under the **Scheduler** section, navigate to **Buckets**.
2. Click **`New Bucket...`**
3. Provide a *Bucket Title* as something recognizable, such as **Cache**.
4. Click **`Create Bucket`**
5. *Take note of the new bucket ID as it will be used in a later step.*

#### Create API Key for managing buckets
##### * Note that this API Key will also be used for the other API access helper functions.

1. In the menu pane under the **Admin** section, navigate to **API Keys**.
2. Click **`New API Key...`**
3. Provide an *App Title* as something recognizable, such as **Bucket Management**.
4. Modify the **Privileges** so that it only includes **Edit Buckets**.
5. Click **`Create Key`**
6. At this point, you'll see a pop-up saying **NEW API KEY CREATED**. This is the ***ONLY*** time you will have access to this new API key secret, so click **`Copy to Clipboard`** and paste it somewhere as it will be used in a later step.

#### Create Secret Vault

1. In the menu pane under the **Admin** section, navigate to **Secrets**.
2. Click **`New Vault...`**
3. Provide a *Secret Vault Title* as something recognizable, such as **Read/Write Buckets**.
4. For *Plugin Access*, select **PowerShell** from the list.
5. Under **Secret Variables**, click **`New Variable...`**
6. Enter **XYOPS_CACHE_BUCKET_ID** for the *Variable Name* for the cache bucket ID. 
7. Paste the bucket ID of the bucket created in previous steps into the *Variable Value*.
8. Click **`Add Variable`**
9. Under **Secret Variables**, click **`New Variable...`**
10. Enter **XYOPS_BUCKET_API_KEY** for the *Variable Name* for the bucket management API key secret.
11. Paste the API key value copied from the new API key created in previous steps into the *Variable Value*.
12. Click **`Add Variable`**
13. Click **`Create Vault`**

##### NOTE: If you use a different different variable name from the defaults, you'll need to make sure they're set properly every time you use the event plugin.

---
## Setting Up Email API Key

In order to to use the Send-xyOpsEmail function built into this plugin, the following setup steps required.

#### Create API Key for sending emails

1. In the menu pane under the **Admin** section, navigate to **API Keys**.
2. Click **`New API Key...`**
3. Provide an *App Title* as something recognizable, such as **Send Email**.
4. Modify the **Privileges** so that it only includes **Send Emails**.
5. Click **`Create Key`**
6. At this point, you'll see a pop-up saying **NEW API KEY CREATED**. This is the ***ONLY*** time you will have access to this new API key secret, so click **`Copy to Clipboard`** and paste it somewhere as it will be used in a later step.

#### Create Secret Vault

1. In the menu pane under the **Admin** section, navigate to **Secrets**.
2. Click **`New Vault...`**
3. Provide a *Secret Vault Title* as something recognizable, such as **Send Email API**.
4. For *Plugin Access*, select **PowerShell** from the list.
5. Under **Secret Variables**, click **`New Variable...`**
6. Enter **XYOPS_SENDEMAIL_API_KEY** for the *Variable Name* for the Send Email API key secret.
7. Paste the API key created in previous step into the *Variable Value*.
8. Click **`Add Variable`**
9. Click **`Create Vault`**

##### NOTE: If you use a different different variable name from the defaults, you'll need to make sure they're set properly every time you use the event plugin.

---

## Data Collection

This plugin **DOES NOT** collect any data or user information.

---
Author: Nick Dollimount