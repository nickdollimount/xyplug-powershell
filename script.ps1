<#
.SYNOPSIS
	xyOps PowerShell event plugin - Executes PowerShell commands within the xyOps environment.

.NOTES
	Author:         Nick Dollimount
	Contributor:    Tim Alderweireldt
	Copyright:      2026
	Purpose:        xyOps PowerShell event plugin
	Features:       - Cross-platform compatibility
                    - Comprehensive helper functions for xyOps integration
					
	Please see the README.md file for full documentation of each function, including examples.
#>

# MARK: Write-xyOpsJobOutput
function Write-xyOpsJobOutput {
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
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][decimal]$Percent,
		[Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 1)][string]$Status
	)

	Send-xyOpsOutput ([pscustomobject]@{
			xy       = 1
			progress = $Percent / 100
			status   = $Status
		})
}

# MARK: Send-xyOpsStatus
function Send-xyOpsStatus {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][string]$Status
	)

	Send-xyOpsOutput ([pscustomobject]@{
			xy     = 1
			status = $Status
		})
}

# MARK: New-Filename
function New-Filename {
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
	$files = [System.Collections.Generic.List[object]]::new()

	foreach ($file in $Script:xyOps.input.files) {
		$files.Add($file)
	}
	
	return $files
}

# MARK: Get-xyOpsBucketFile
function Get-xyOpsBucketFile {
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
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)][string]$Name
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

# MARK: Get-xyOpsTags
function Get-xyOpsTags {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)][System.Collections.Generic.List[string]]$Tags
	)

	if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
		throw "No secrets have been assigned to this plugin or event. Tags access is currently unavailable."
	}

	$bucketApiKey = $Script:xyOps.secrets."$($Script:xyOps.params.bucketapikeyvariable)"
	$apiUri = "$($Script:xyOps.base_url)/api/app/get_tags/v1"

	$requestSplat = @{
		Uri     = $apiUri
		Method  = 'GET'
		Headers = @{
			'X-API-KEY' = $bucketApiKey
		}
	}

	try {
		$allTags = (Invoke-RestMethod @requestSplat).rows
	}
	catch {
		$_
	}

	if ($Tags) {
		$returnTags = [System.Collections.Generic.List[object]]::new()

		foreach ($tag in $allTags) {
			if ($tag.title -in $Tags) {
				$returnTags.Add($tag)
			}
		}

		return $returnTags
	}

	return $allTags
}

# MARK: Send-xyOpsTags
function Send-xyOpsTags {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][System.Collections.Generic.List[string]]$Tags
	)

	try {
		$systemTags = [System.Collections.Generic.List[object]](Get-xyOpsTags)
	}
	catch {
		throw $_
	}

	$pushTags = [System.Collections.Generic.List[object]]::new()

	foreach ($tag in $Tags) {
		switch ($tag) {
			{ $_ -in $systemTags.title } {
				$pushTags.Add(($systemTags.Find({ $args.title -eq $tag })).id)
				break
			}
			{ $_ -in $systemTags.id } {
				$pushTags.Add($tag)
				break
			}
			default {
				Write-xyOpsJobOutput -Message "[Send-xyOpsTags] The tag '$($tag)' does not exist. Create the tag under [Scheduler > Tags]."
				break
			}
		}
	}

	Send-xyOpsOutput ([pscustomobject]@{
			xy   = 1
			push = @{
				tags = $pushTags
			}
		})
}

# MARK: Send-xyOpsEmail
function Send-xyOpsEmail {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)][string]$To,
		[Parameter(Mandatory = $true)][string]$Subject,
		[Parameter(Mandatory = $true)][string]$Body,
		[Parameter(Mandatory = $false)][System.Collections.Generic.List[object]]$CC,
		[Parameter(Mandatory = $false)][System.Collections.Generic.List[object]]$BCC,
		[Parameter(Mandatory = $false)][string]$Title,
		[Parameter(Mandatory = $false)][string]$ButtonLabel,
		[Parameter(Mandatory = $false)][string]$ButtonUri,
		[Parameter(Mandatory = $false)][ValidateSet('low', 'normal', 'high')][string]$Importance = 'normal',
		[Parameter(Mandatory = $false)][System.Collections.Generic.List[object]]$Attachments
	)

	if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
		throw "No secrets have been assigned to this plugin or event. Email access is currently unavailable."
	}

	$apiKey = $Script:xyOps.secrets."$($Script:xyOps.params.sendemailapikeyvariable)"
	$apiUri = "$($Script:xyOps.base_url)/api/app/send_email/v1"

	$requestSplat = @{
		Uri         = $apiUri
		Method      = 'POST'
		Headers     = @{
			'X-API-KEY' = $apiKey
		}
		ContentType = 'multipart/form-data'
		Form        = @{
			json = @{
				to      = $To
				subject = $Subject
				body    = $Body
				cc      = $CC -join ','
				bcc     = $BCC -join ','
				title   = $Title
				button  = (-not [string]::IsNullOrEmpty($ButtonLabel) -and -not [string]::IsNullOrEmpty($ButtonUri)) ? "$($ButtonLabel) | $($ButtonUri)" : $null
				headers = @{
					Importance          = $Importance
					'X-MSMail-Priority' = switch ($Importance) {
						'low' { 5 }
						'normal' { 3 }
						'high' { 1 }
					}
					'X-Priority'        = switch ($Importance) {
						'low' { 5 }
						'normal' { 3 }
						'high' { 1 }
					}
				}
			} | ConvertTo-Json -Depth 100
		}
	}

	if ($Attachments.Count -gt 0) {
		$counter = 0
		foreach ($attachment in $Attachments) {
			$counter++
			$requestSplat.Form["file$($counter)"] = (Get-Item -Path $attachment)
		}
	}

	try {
		$null = Invoke-RestMethod @requestSplat
		Write-xyOpsJobOutput "Email Sent"
	}
	catch {
		throw "There was an issue sending the email."
		$_
	}
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
	}
	else {
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