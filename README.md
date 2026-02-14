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
- **Data Passthrough** [optional] - If checked, data output from one event will pass through automatically to its output. Note that if an event outputs the same data property as existing data that was passed in, it will overwrite what was passed into it.
- **Bucket API Key Variable Name** [optional] - The variable name used for the API Key used for accessing buckets. (See **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)
- **Cache Bucket ID Variable Name** [optional] - The secret vault variable name used for the Bucket ID when configuring the cache bucket setup. (See **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)
- **Send Email API Key Variable Name** [optional] - The secret vault variable name used for the API Key for sending emails. (See **[Setting Up Email API Key](#setting-up-email-api-key)**)

## Usage

When creating an event, you will provide your PowerShell script code inside the **Code Block** parameter. The job data is made available as a PowerShell object variable called **$xyOps**. Enabling **Output xyOps JSON Data** will display the structure of this object.

### Platform Support:
- **Windows/Linux/macOS**: PowerShell 7+

## Helper Functions

This plugin includes the following helper functions:

#### Logging & Core Output
- [Write-xyOpsJobOutput](#write-xyopsjoboutput) - Write log messages with severity levels
- [Send-xyOpsOutput](#send-xyopsoutput) - Low-level structured output to xyOps
- [Send-xyOpsProgress](#send-xyopsprogress) - Report job progress percentage

#### File & Data Management
- [Send-xyOpsFile](#send-xyopsfile) - Upload files to job output
- [Send-xyOpsPerf](#send-xyopsperf) - Report performance metrics (pie chart)
- [Send-xyOpsLabel](#send-xyopslabel) - Set custom job label
- [Send-xyOpsData](#send-xyopsdata) - Pass data to next job in workflow
- [Get-xyOpsInputFiles](#get-xyopsinputfiles) - Get input file metadata
- [Get-xyOpsBucketFile](#get-xyopsbucketfile) - Gets file from the specified bucket
- [Add-xyOpsBucketFile](#add-xyopsbucketfile) - Adds file to the specified bucket
- [Remove-xyOpsBucketFile](#remove-xyopsbucketfile) - Deletes file from the specified bucket
- [Get-xyOpsBucketData](#get-xyopsbucketdata) - Gets data from the specified bucket
- [Set-xyOpsBucketData](#set-xyopsbucketdata) - Sets data in the cache bucket
- [Get-xyOpsCache](#get-xyopscache) - Gets data from the cache bucket
- [Set-xyOpsCache](#set-xyopscache) - Sets data in the cache bucket
- [Get-xyOpsParam](#get-xyopsparam) - Get parameter values (supports listing all params)
- [Get-xyOpsTags](#get-xyopstags) - Gets available system tags.
- [Send-xyOpsTags](#send-xyopstags) - Pushes tags to the job output.
- [Send-xyOpsEmail](#send-xyopsemail) - Send an email using the built-in xyOps mechanism.

#### UI Display Functions
- [Send-xyOpsTable](#send-xyopstable) - Display data tables
- [Send-xyOpsHtml](#send-xyopshtml) - Display HTML content
- [Send-xyOpsText](#send-xyopstext) - Display plain text (preserved formatting)
- [Send-xyOpsMarkdown](#send-xyopsmarkdown) - Display Markdown content


## Syntax
---
> #### Write-xyOpsJobOutput

        Write-xyOpsJobOutput [-Message] <string> [-Level {info | warning | error}]

The **Write-xyOpsJobOutput** helper function lets you report text back to the job output which will be displayed in the job details.

Examples:

```powershell
# Reporting text back to the job output.
Write-xyOpsJobOutput "Sample output to be passed to xyOps job output."

# Strings can be piped to the helper function.
"Log this information to the job output, please. Thanks." | Write-xyOpsJobOutput -Level warning
```
[Logging & Core Output](#logging--core-output)

---
> #### Send-xyOpsOutput

        Send-xyOpsOutput [-InputObject] <object>

The **Send-xyOpsOutput** helper function provides a simple way to report back updates to the job output using a PowerShell object or a hashtable. The input is converted to the proper JSON format that xyOps requires. Keep in mind that xyOps expects a specific structure, depending on what you're reporting back. Please refer to the [xyOps documentation](https://github.com/pixlcore/xyops/blob/main/docs/plugins.md) for more information.

Examples:

```powershell
# Bypass the Send-XyOpsProgress function and report the progress data directly using the Send-XyOpsOutput function.
Send-xyOpsOutput ([pscustomobject]@{
        xy       = 1
        progress = 0.75
})
```
[Logging & Core Output](#logging--core-output)

---
> #### Send-xyOpsProgress

        Send-xyOpsProgress [-Percent] <decimal> [-Status <string>]

Sends a progress update to the xyOps system with a percentage value between 0 and 100. Optionally, you can include a status with the progress update using the **-Status** parameter.

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
> #### Send-xyOpsStatus

        Send-xyOpsStatus [-Status] <string>

Sends a status for the job that is displayed on the job status page as well as the jobs list.

Examples:

```powershell
# Report a status.
Send-xyOpsStatus "Building sites list..."

# Report a status.
Send-xyOpsStatus -Status "Processing $($itemNumber) of $($items.Count)..."
```
[File & Data Management](#file--data-management)

---
> #### Send-xyOpsFile

        Send-xyOpsFile [-Filename] <string>

Uploads a file to the job output. The file is then accessible in the UI to download. It can also be passed to the input of a proceeding event within a workflow to be further processed.

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

        Send-xyOpsPerf [-Metrics] <hashtable> [-Scale <int>]

Sends performance metrics to xyOps for visualization as a pie chart.

Examples:

```powershell
# Metrics in seconds
Send-xyOpsPerf @{ database = 18.5; api_calls = 3.2; processing = 0.8 }

# Metrics in milliseconds
Send-xyOpsPerf @{ database = 1850; api_calls = 3200 } -Scale 1000
```
[File & Data Management](#file--data-management)

---
> #### Send-xyOpsLabel

        Send-xyOpsLabel [-Label] <string>

Sets a custom label for the job displayed in the UI.

Examples:

```powershell
Send-xyOpsLabel "Backup - Production DB"
Send-xyOpsLabel "Deploy to $env:TARGET_ENV"
```
[File & Data Management](#file--data-management)

---
> #### Send-xyOpsData

        Send-xyOpsData [-Data] <object>

Outputs arbitrary data to be passed to the next job in a workflow.

Examples:

```powershell
Send-xyOpsData @{ status = "complete"; records_processed = 1234 }
```
[File & Data Management](#file--data-management)

---
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
[File & Data Management](#file--data-management)

---
> #### Get-xyOpsBucketFile

        Get-xyOpsBucketFile [-BucketId] <string> [-Filename] <string> [-OutFilename <string>]

Gets file from the specified bucket. (API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)

Examples:

```powershell
Get-xyOpsBucketFile -BucketId 'bml2ut4ys4pt7raf' -Filename 'customers.csv'
```
[File & Data Management](#file--data-management)

---
> #### Add-xyOpsBucketFile

        Add-xyOpsBucketFile [-BucketId] <string> [-Filename] <string>

Adds file to the specified bucket. (API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)

Examples:

```powershell
$newFile = New-FileName -FileType csv
$customers | Export-Csv -FilePath $newFile
Add-xyOpsBucketFile -BucketId 'bml2ut4ys4pt7raf' -Filename $newFile
```
[File & Data Management](#file--data-management)

---
> #### Remove-xyOpsBucketFile

        Remove-xyOpsBucketFile [-BucketId] <string> [-Filename] <string>

Deletes file from the specified bucket. (API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)

Examples:

```powershell
Remove-xyOpsBucketFile -BucketId 'bml2ut4ys4pt7raf' -Filename 'customers.csv'
```
[File & Data Management](#file--data-management)

---
> #### Get-xyOpsBucketData

        Get-xyOpsBucketData [-BucketId] <string>

Gets data from the specified bucket. (API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)

Examples:

```powershell
$bucketData = Get-xyOpsBucketData -BucketId 'bml2ut4ys4pt7raf'
```
[File & Data Management](#file--data-management)

---
> #### Set-xyOpsBucketData

        Set-xyOpsBucketData [-BucketId] <string> [-Key] <string> [-InputObject] <object>

Sets data in the cache bucket. (API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)

Examples:

```powershell
Set-xyOpsBucketData -BucketId 'bml2ut4ys4pt7raf' -Key 'Countries' -InputObject @('Canada','United States','United Kingdom')
```
[File & Data Management](#file--data-management)

---
> #### Get-xyOpsCache

        Get-xyOpsCache [-Key] <string>

Gets data from the cache bucket. (API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)

Examples:

```powershell
$Countries = Get-xyOpsCache -Key Countries
```
[File & Data Management](#file--data-management)

---
> #### Set-xyOpsCache

        Set-xyOpsCache [-Key] <string> [-InputObject] <object>

Sets data in the cache bucket. (API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)

Examples:

```powershell
Set-xyOpsCache -Key Countries -InputObject @('Canada','United States','United Kingdom')
```
[File & Data Management](#file--data-management)

---
> #### Get-xyOpsParam

        Get-xyOpsParam [-Name <string>]

Retrieves parameter values from xyOps or environment variables. When called without parameters, displays all available parameters in a formatted table.

Examples:

```powershell
# Get specific parameters
$timeout = Get-xyOpsParam -Name "timeout"
$apiKey = Get-xyOpsParam -Name "api_key"

# List all available parameters
Get-xyOpsParam
```
[File & Data Management](#file--data-management)

---
> #### Get-xyOpsTags

        Get-xyOpsTags [-Tags <list>]

Gets available system tags using the get_tags API. Optionally, you can supply tag titles so that only those are returned. (API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)

Examples:

```powershell
# Get all tags.
Get-xyOpsTags

# Get specific tags.
Get-xyOpsTags -Tags @('Canada','United States','United Kingdom')

# Get specific tags.
Get-xyOpsTags 'John','Joe','Jill','Jane'
```
[File & Data Management](#file--data-management)

---
> #### Send-xyOpsTags

        Send-xyOpsTags [-Tags] <list>

Pushes one or more tags to be appended to the job output. The tags are provided as an array or list of tag names. Available tags are retrieved from the system to get the ID, which is used by xyOps to apply the correct tag. (API Key Required, see **[Setting Up Cache Bucket](#setting-up-cache-bucket)**)

Examples:

```powershell
# Push tags to job output
Send-xyOpsTags -Tags @('Canada','United States','United Kingdom')
    
# Push tags to job output
Send-xyOpsTags 'John','Joe','Jill','Jane'
```
[File & Data Management](#file--data-management)

---
> #### Send-xyOpsEmail

        Send-xyOpsEmail -To <string> -Subject <string> -Body <string> [-CC <array[string]>] [-BCC <array[string]>] [-Title <string>] [-ButtonLabel <string>] [-ButtonUri <string>] [-Importance {low | normal | high}] [-Attachments <array[string]>]

Sends an email using the built-in xyOps mechanism and configuration. (API Key Required, see **[Setting Up Email API Key](#setting-up-email-api-key)**)

Examples:

```powershell
# Send a basic email with high importance
Send-xyOpsEmail -To user@domain.com -Subject "Important Email Update" -Body "This is a test!" -Importance high
    
# Send an email with attachments
Send-xyOpsEmail -To user@domain.com -Subject "Reports" -Body "Please see attached." -Attachments './report1.pdf','./report_final.pdf'
```
[File & Data Management](#file--data-management)

---
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
[UI Display Functions](#ui-display-functions)

---
> #### Send-xyOpsHtml

        Send-xyOpsHtml -Content <string> [-Title <string>] [-Caption <string>]

Renders custom HTML in the Job Details page.

Examples:

```powershell
$html = "<h3>Summary</h3><ul><li>Total: <b>1000</b></li></ul>"
Send-xyOpsHtml -Content $html -Title "Results"
```
[UI Display Functions](#ui-display-functions)

---
> #### Send-xyOpsText

        Send-xyOpsText -Content <string> [-Title <string>] [-Caption <string>]

Renders plain text with preserved formatting.

Examples:

```powershell
$logContent = Get-Content "/var/log/app.log" -Raw
Send-xyOpsText -Content $logContent -Title "Application Log"
```
[UI Display Functions](#ui-display-functions)

---
> #### Send-xyOpsMarkdown

        Send-xyOpsMarkdown -Content <string> [-Title <string>] [-Caption <string>]

Renders Markdown content (converted to HTML).

Examples:

```powershell
$md = "## Results`n- **Success**: 98%`n- **Failed**: 2%"
Send-xyOpsMarkdown -Content $md -Title "Summary"
```
[UI Display Functions](#ui-display-functions)

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

#### Update Plugin Default Parameter Values
##### * Note that this is only necessary if in the **Create Secret Vault** section, you used different variable names than steps 6 and 10.

1. In the menu pane under **Admin** section, navigate to **Plugins**.
2. Click the **`Edit`** button to the right of the **PowerShell** plugin.
3. Scroll to the bottom to find the **Parameters** section.
4. Click **`Edit`** to the right of **Cache Bucket ID Variable Name**.
5. Set the **Default Value** to what was used in step 6 in the previous section.
6. Click **`Accept`**
7. Click **`Edit`** to the right of **Bucket API Key Variable Name**.
8. Set the **Default Value** to what was used in step 10 in the previous section.
9. Click **`Accept`**
10. Click **`Save Changes`**

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

#### Update Plugin Default Parameter Values
##### * Note that this is only necessary if in the **Create Secret Vault** section, you used different variable names than step 6.

1. In the menu pane under **Admin** section, navigate to **Plugins**.
2. Click the **`Edit`** button to the right of the **PowerShell** plugin.
3. Scroll to the bottom to find the **Parameters** section.
4. Click **`Edit`** to the right of **Send Email API Key Variable Name**.
5. Set the **Default Value** to what was used in step 6 in the previous section.
6. Click **`Accept`**
9. Click **`Save Changes`**
---

## Data Collection

This plugin **DOES NOT** collect any data or user information.

---
Author: Nick Dollimount

Contributors: Tim Alderweireldt
