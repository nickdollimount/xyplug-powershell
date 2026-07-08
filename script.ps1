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
		[Parameter(Mandatory = $false)][ValidateSet('info', 'warning', 'error', 'critical', 'debug')][string]$Level = 'info',
		[Parameter(Mandatory = $false)][switch]$Halt = $false
	)

	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss:ffff"
	$logMessage = "$(($Script:enableLogTime) ? "[$($timestamp)] " : '')[$($Level)] $($Message)"

	if ($Level -in 'warning', 'error', 'critical') {
		Set-xyOpsJobResult -Status $Level -Description $Message
	}
	
	switch ($Level) {
		'info' {
			$ANSIOutput = $logMessage
			break
		}
		'warning' {
			$ANSIOutput = "`e[0;33m$($logMessage)`e[0m"
			break
		}
		'error' {
			$ANSIOutput = "`e[0;31m$($logMessage)`e[0m"
			break
		}
		'critical' {
			$ANSIOutput = "`e[0;35m$($logMessage)`e[0m"
			break
		}
		'debug' {
			$ANSIOutput = "`e[0;36m$($logMessage)`e[0m"
			break
		}
	}

	Send-xyOpsOutput $ANSIOutput

	if ($Halt) {
		$script:halted = $true
		throw
	}
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

# MARK: Write-xyOpsError
function Write-xyOpsError {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][System.Management.Automation.ErrorRecord]$Error,
		[Parameter(Mandatory = $false)][switch]$Halt = $false
	)

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Write-xyOpsError] Processing reported error..." -Level debug) : $null
	
	$Error | Format-List * -Force | Out-String | Write-xyOpsJobOutput -Level error
	
	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Write-xyOpsError] Processing reported error... Complete" -Level debug) : $null

	if ($Halt) {
		$script:halted = $true
		throw
	}
}

# MARK: Send-xyOpsProgress
function Send-xyOpsProgress {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][decimal]$Percent,
		[Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 1)][string]$Status
	)
	
	$dataObject = [pscustomobject]@{
		xy       = 1
		progress = $Percent / 100
		status   = $Status
	}

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsProgress] Sending job progress:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null

	Send-xyOpsOutput $dataObject
}

# MARK: Send-xyOpsStatus
function Send-xyOpsStatus {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][string]$Status
	)

	$dataObject = [pscustomobject]@{
		xy     = 1
		status = $Status
	}

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsStatus] Sending job status:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
	Send-xyOpsOutput $dataObject
}

# MARK: New-Filename
function New-Filename {
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]$Filetype,
		[Parameter(Mandatory = $false)]$Prefix
	)

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[New-Filename] Generating a new filename..." -Level debug) : $null
	
	$prefix = $Prefix -replace " ", "_"
	$guid = (New-Guid).Guid
	
	$filename = "$((![string]::IsNullOrEmpty($prefix)) ? "$($prefix)_" : $null)$($guid).$($fileType)"
	
	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[New-Filename] Generating a new filename... Complete" -Level debug) : $null

	return $filename
}

# MARK: Send-xyOpsFile
function Send-xyOpsFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$Filename
	)

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsFile] Adding file to job output list..." -Level debug) : $null
	
	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsFile] Checking if file exists..." -Level debug) : $null

	if (Test-Path $Filename) {
		$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsFile] Checking if file exists... EXISTS" -Level debug) : $null
		
		$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsFile] Opening file..." -Level debug) : $null
		$file = Get-ChildItem $Filename
		$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsFile] Opening file... Complete" -Level debug) : $null
		
		if ($file.Length -gt 0) {
			$null = $filesToUpload.add($Filename)
			$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsFile] File contains data; file added to job output list." -Level debug) : $null
		}
		else {
			Write-xyOpsJobOutput "[Send-xyOpsFile] The file is 0 bytes.`npath: $($Filename)" -Level error
		}
	}
 else {
		$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsFile] Checking if file exists... DOES NOT EXIST" -Level debug) : $null
		
		Write-xyOpsJobOutput "[Send-xyOpsFile] The file does not exist.`npath: $($Filename)" -Level error
	}

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsFile] Adding file to job output list... Complete" -Level debug) : $null
}

# MARK: Send-xyOpsPerf
function Send-xyOpsPerf {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][hashtable]$Metrics,
		[Parameter(Mandatory = $false)][int]$Scale
	)

	$dataObject = [pscustomobject]@{
		xy   = 1
		perf = $Metrics
	}
	
	if ($Scale) {
		$dataObject.perf['scale'] = $Scale
	}

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsPerf] Sending performance data to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
	Send-xyOpsOutput $dataObject
}

# MARK: Send-xyOpsLabel
function Send-xyOpsLabel {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$Label
	)

	$dataObject = [pscustomobject]@{
		xy    = 1
		label = $Label
	}

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsLabel] Setting job label:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
	Send-xyOpsOutput $dataObject
}

# MARK: Send-xyOpsData
function Send-xyOpsData {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][object]$Data
	)

	$dataObject = [pscustomobject]@{
		xy   = 1
		data = $Data
	}

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsData] Sending data for xyOps processing:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
	Send-xyOpsOutput $dataObject
}

# MARK: Send-xyOpsTable
function Send-xyOpsTable {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)][array]$Rows,
		[Parameter(Mandatory = $true)][array]$Header,
		[Parameter(Mandatory = $false)][string]$Title,
		[Parameter(Mandatory = $false)][string]$Caption
	)

	$table = @{
		rows = $Rows
	}
	
	if ($Title) { $table['title'] = $Title }
	if ($Header) { $table['header'] = $Header }
	if ($Caption) { $table['caption'] = $Caption }

	$dataObject = [pscustomobject]@{
		xy    = 1
		table = $table
	}
	
	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsTable] Sending table to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
	Send-xyOpsOutput $dataObject
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

	$dataObject = [pscustomobject]@{
		xy   = 1
		html = $html
	}

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsHtml] Sending html to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null

	Send-xyOpsOutput $dataObject
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

	$dataObject = [pscustomobject]@{
		xy   = 1
		text = $text
	}

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsText] Sending text to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null

	Send-xyOpsOutput $dataObject
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

	$dataObject = [pscustomobject]@{
		xy       = 1
		markdown = $markdown
	}

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsMarkdown] Sending markdown to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
		
	Send-xyOpsOutput $dataObject
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

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Get-xyOpsBucketFile] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Get-xyOpsBucketFile] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Add-xyOpsBucketFile] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Remove-xyOpsBucketFile] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Get-xyOpsBucketData] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Set-xyOpsBucketData] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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

# MARK: Clear-xyOpsBucket
function Clear-xyOpsBucket {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][string]$BucketId,
		[Parameter(Mandatory = $true, ParameterSetName = 'FilesOnly')][switch]$FilesOnly,
		[Parameter(Mandatory = $true, ParameterSetName = 'DataOnly')][switch]$DataOnly,
		[Parameter(Mandatory = $true, ParameterSetName = 'All')][switch]$All
	)

	if ([string]::IsNullOrEmpty($Script:xyOps.Secrets)) {
		throw "No secrets have been assigned to this plugin or event. Bucket access is currently unavailable."
	}

	$bucketApiKey = $Script:xyOps.secrets."$($Script:xyOps.params.bucketapikeyvariable)"
	$apiUri = "$($Script:xyOps.base_url)/api/app/empty_bucket/v1?id=$($BucketId)"

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Clear-xyOpsBucket] Invoking xyOps API: $($apiUri)" -Level debug) : $null

	$requestSplat = @{
		Uri         = $apiUri
		Method      = 'POST'
		Headers     = @{
			'X-API-KEY' = $bucketApiKey
		}
		ContentType = 'application/json'
		Body        = @{
			files = ($FilesOnly -or $All) ? $true : $false
			data  = ($DataOnly -or $All) ? $true : $false
		} | ConvertTo-Json -Depth 100
	}

	try {
		$null = Invoke-RestMethod @requestSplat
		Write-xyOpsJobOutput "Bucket [$($BucketId)] data cleared."
	}
	catch {
		throw "There was an issue clearing bucket [$($BucketId)] data."
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
		[Parameter(Mandatory = $false)][string]$Name,
		[Parameter(Mandatory = $false)][switch]$Workflow
	)

	# If no name specified, display all parameters
	if ([string]::IsNullOrEmpty($Name)) {
		$paramList = [System.Collections.Generic.List[object]]::new()
		
		# Collect xyOps params
		if ($Workflow) {
			if ($Script:xyOps.workflow.params) {
				$Script:xyOps.workflow.params.PSObject.Properties | ForEach-Object {
					[void]$paramList.Add([PSCustomObject]@{
							Source = "Workflow"
							Name   = $_.Name
							Value  = $_.Value
						})
				}
			}
		}
		else {
			if ($Script:xyOps.params) {
				$Script:xyOps.params.PSObject.Properties | ForEach-Object {
					[void]$paramList.Add([PSCustomObject]@{
							Source = "Job"
							Name   = $_.Name
							Value  = $_.Value
						})
				}
			}
		}
		
		return $paramList | ConvertTo-Json -Depth 100
	}

	if ($Workflow) {
		if ($Script:xyOps.workflow.params.$Name) {
			return $Script:xyOps.workflow.params.$Name
		}
	}
 else {
		if ($Script:xyOps.params.$Name) {
			return $Script:xyOps.params.$Name
		}
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

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Get-xyOpsTags] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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

	$dataObject = [pscustomobject]@{
		xy   = 1
		push = @{
			tags = $pushTags
		}
	}
	
	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsTags] Sending job tags:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null

	Send-xyOpsOutput $dataObject
}

# MARK: Send-xyOpsEmail
function Send-xyOpsEmail {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)][array]$To,
		[Parameter(Mandatory = $true)][string]$Subject,
		[Parameter(Mandatory = $true)][string]$Body,
		[Parameter(Mandatory = $false)][array]$CC,
		[Parameter(Mandatory = $false)][array]$BCC,
		[Parameter(Mandatory = $false)][string]$Title,
		[Parameter(Mandatory = $false)][string]$ButtonLabel,
		[Parameter(Mandatory = $false)][string]$ButtonUri,
		[Parameter(Mandatory = $false)][ValidateSet('low', 'normal', 'high')][string]$Importance = 'normal',
		[Parameter(Mandatory = $false)][array]$Attachments
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
				to      = $To -join ','
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

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsEmail] Email form data: $($requestSplat.Form.json)" -Level debug) : $null
	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Send-xyOpsEmail] Invoking xyOps API: $($apiUri)" -Level debug) : $null

	try {
		$null = Invoke-RestMethod @requestSplat
		Write-xyOpsJobOutput "Email Sent"
	}
	catch {
		Write-xyOpsJobOutput "There was an issue sending the email." -Level error
		Write-xyOpsError $_
	}
}

# MARK: Set-xyOpsJobResult
function Set-xyOpsJobResult {
	param(
		[Parameter(Mandatory = $true, Position = 0)][ValidateSet('success', 'warning', 'error', 'critical')][string]$Status,
		[Parameter(Mandatory = $true, Position = 2)][string]$Description
	)

	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Set-xyOpsJobResult] Setting job status" -Level debug) : $null
	switch ($Status) {
		'success' {
			if ($jobStatus.Status -in @($xyOpsJobStatusEnum.success)) {
				$jobStatus.Description = $Description
			}
			break
		}
		'warning' {
			if ($jobStatus.Status -in @($xyOpsJobStatusEnum.Success, $xyOpsJobStatusEnum.Warning)) {
				$jobStatus.Status = $xyOpsJobStatusEnum.Warning
				$jobStatus.Description = $Description
			}
			break
		}
		'error' {
			if ($jobStatus.Status -in @($xyOpsJobStatusEnum.Success, $xyOpsJobStatusEnum.Warning, $xyOpsJobStatusEnum.Error)) {
				$jobStatus.Status = $xyOpsJobStatusEnum.Error
				$jobStatus.Description = $Description
			}
			break
		}
		'critical' {
			if ($jobStatus.Status -in @($xyOpsJobStatusEnum.Success, $xyOpsJobStatusEnum.Warning, $xyOpsJobStatusEnum.Error, $xyOpsJobStatusEnum.Critical)) {
				$jobStatus.Status = $xyOpsJobStatusEnum.Critical
				$jobStatus.Description = $Description
			}
			break
		}
	}
}

# MARK: Begin

$filesToUpload = [System.Collections.Generic.HashSet[string]]::new()

$xyOpsJobStatusEnum = [PSCustomObject]@{
	Success  = 0
	Warning  = 'warning'
	Error    = 999
	Critical = 'critical'
}

# Assume status of success
$jobStatus = [PSCustomObject]@{
	Status      = $xyOpsJobStatusEnum.Success
	Description = 'Job completed successfully!'
}

# Read job parameters from JSON input
[PSCustomObject]$Script:xyOps = ConvertFrom-Json -Depth 100 (Read-Host)

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

$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[MAIN] Loading module files..." -Level debug) : $null

# Import any .psm1 module files provided from a bucket fetch action.
if ($Script:xyOps.params.processmodules) {
	$moduleFiles = Get-xyOpsInputFiles | Where-Object { $_.filename -like "*.psm1" }
	foreach ($moduleFile in $moduleFiles) {
		$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[MAIN] Module file found: $((Get-ChildItem $moduleFile.filename).FullName)" -Level debug) : $null
		try {
			Write-xyOpsJobOutput "Loading module file: $($moduleFile.filename)" -Level info
			Import-Module "./$($moduleFile.filename)"
		}
		catch {
			Write-xyOpsJobOutput 'Error loading module.' -Level error
			Write-xyOpsError $_
		}
	}
}
else {
	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[MAIN] No module files to load" -Level debug) : $null
}

$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[MAIN] Loading module files... Complete" -Level debug) : $null

Write-xyOpsJobOutput 'Job Started'

$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[MAIN] Checking code block..." -Level debug) : $null

try {
	$command = [scriptblock]::create($Script:xyOps.params.command)
	$commandGenerated = $true
}
catch {
	Write-xyOpsJobOutput "The code block provided is invalid. Please use a proper code editor to verify your script." -Level error
	Set-xyOpsJobResult -Status error -Description 'Invalid code block.'
}

$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Main] Checking code block... Complete" -Level debug) : $null

try {
	if ($commandGenerated) {
		$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Main] Executing code block..." -Level debug) : $null
		& $command
		$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[Main] Executing code block... Complete" -Level debug) : $null
	}
}
catch {
	Write-xyOpsError -Error $_

	if ($halted) {
		Write-xyOpsJobOutput "SCRIPT HALTED"
	}
}
finally {
	if ($filesToUpload.Count -gt 0) {
		$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[MAIN] There are $($filesToUpload.Count) files to upload to the job output." -Level debug) : $null
		$output = [pscustomobject]@{
			xy    = 1
			files = @()
		}

		foreach ($file in $filesToUpload) {
			$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[MAIN] Attaching file: $($file)" -Level debug) : $null
			$output.files += @{
				path   = $file
				delete = $false
			}
		}

		Send-xyOpsOutput $output
	}
	
	Write-xyOpsJobOutput 'Job Finished'
	# Report status
	$xyOps.params.enabledebuglogging ? (Write-xyOpsJobOutput "[MAIN] Reporting job status" -Level debug) : $null
	Send-xyOpsOutput ([pscustomobject]@{
			xy          = 1
			code        = $jobStatus.Status
			description = $jobStatus.Description
		})
}