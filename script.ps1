<#
.SYNOPSIS
	xyOps PowerShell event plugin - Executes PowerShell commands within the xyOps environment.

.NOTES
	Author:         Nick Dollimount
	Copyright:      2026
	Purpose:        xyOps PowerShell event plugin
	Features:       - Cross-platform compatibility
                    - Comprehensive helper functions for xyOps integration
					
	Please see the README.md file for full documentation of each function, including examples.
#>

class XyOpsPluginException : System.Exception {
	[string]$Code
	[string]$Stage
	[object]$Details

	XyOpsPluginException([string]$message) : base($message) {
		$this.Code = 'XYOPS_PLUGIN_ERROR'
		$this.Stage = 'Execution'
	}

	XyOpsPluginException([string]$message, [System.Exception]$innerException)
	: base($message, $innerException) {
		$this.Code = 'XYOPS_PLUGIN_ERROR'
		$this.Stage = 'Execution'
	}

	XyOpsPluginException([string]$message, [string]$code, [string]$stage, [object]$details, [System.Exception]$innerException)
	: base($message, $innerException) {
		$this.Code = if ($code) { $code } else { 'XYOPS_PLUGIN_ERROR' }
		$this.Stage = if ($stage) { $stage } else { 'Execution' }
		$this.Details = $details
	}
}

# MARK: New-xyOpsErrorRecord
function New-XyOpsErrorRecord {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Message,

		[Parameter()]
		[string]$ErrorId = 'XyOpsPluginError',

		[Parameter()]
		[System.Management.Automation.ErrorCategory]$Category = [System.Management.Automation.ErrorCategory]::NotSpecified,

		[Parameter()]
		[ValidateSet('Configuration', 'Execution')]
		[string]$Stage = 'Execution',

		[Parameter()]
		[string]$Code = 'XYOPS_PLUGIN_ERROR',

		[Parameter()]
		[object]$TargetObject = $null,

		[Parameter()]
		[object]$Details = $null,

		[Parameter()]
		[System.Management.Automation.ErrorRecord]$InnerErrorRecord = $null,

		[Parameter()]
		[System.Exception]$InnerException = $null
	)

	$rootException = if ($InnerException) {
		$InnerException
	}
 elseif ($InnerErrorRecord) {
		$InnerErrorRecord.Exception
	}
 else {
		$null
	}

	$Exception = [XyOpsPluginException]::new(
		$Message,
		$Code,
		$Stage,
		$Details,
		$rootException
	)

	return [System.Management.Automation.ErrorRecord]::new(
		$Exception,
		$ErrorId,
		$Category,
		$TargetObject
	)
}

# MARK: Send-xyOpsOutput
function Send-xyOpsOutput {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][object]$InputObject
	)

	process {
		try {
			Write-Information -MessageData (($InputObject -is [string]) ? $InputObject : ($InputObject | ConvertTo-Json -Depth 100 -Compress)) -InformationAction Continue -OutBuffer 0
		}
		catch {
			$errorRecord = New-XyOpsErrorRecord `
				-Message 'Invalid data type.' `
				-ErrorId 'InvalidData' `
				-Category ([System.Management.Automation.ErrorCategory]::InvalidData) `
				-Stage 'Execution' `
				-Code 'XYOPS_INVALID_DATA' `
				-TargetObject '$InputObject'

			throw $errorRecord
		}
	}
}

# MARK: Write-xyOpsJobOutput
function Write-xyOpsJobOutput {
	[CmdletBinding(DefaultParameterSetName = 'notStyled')]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][AllowEmptyString()][string]$Message,
		[Parameter(Mandatory = $false)][ValidateSet('info', 'warning', 'error', 'critical', 'debug')][string]$Level = 'info',
		[Parameter(Mandatory = $false)][switch]$Halt = $false,
		[Parameter(Mandatory = $true, ParameterSetName = 'styled')]
		[Parameter(Mandatory = $false, ParameterSetName = 'notStyled')]
		[ValidateSet('black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white')][string]$Color,
		[Parameter(Mandatory = $false, ParameterSetName = 'styled')]
		[ValidateSet('regular', 'bold', 'underline', 'background', 'highIntensity', 'boldHighIntensity', 'highIntensityBackground')][string]$Style,
		[Parameter(Mandatory = $false)][switch]$LogOnly
	)

	process {
		if ([string]::IsNullOrEmpty($Message)) { return }

		$timestamp = [System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss:ffff')
		$logMessage = "$(($enableLogTime) ? "[$($timestamp)] " : '')[$($Level)] $($Message)"

		if ($Level -in 'warning', 'error', 'critical' -and -not $LogOnly.IsPresent) {
			Set-xyOpsJobResult -Status $Level -Description $Message
		}

		if (![string]::IsNullOrWhiteSpace($Color)) {
			if ([string]::IsNullOrEmpty($Style)) {
				$Style = 'regular'
			}
			$ANSIOutput = "`e$($ansiStyleMap["$($Style)"]["$($Color)"])$($logMessage)`e[0m"
		}
 
		if ([string]::IsNullOrWhiteSpace($Color)) {
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
		}

		Send-xyOpsOutput $ANSIOutput

		if ($Halt) {
			$Script:halted = $true
			$errorRecord = New-XyOpsErrorRecord `
				-Message "Script halted by request.`n$($Message)" `
				-ErrorId 'ScriptHalted' `
				-Category ([System.Management.Automation.ErrorCategory]::NotSpecified) `
				-Stage 'Execution' `
				-Code 'XYOPS_SCRIPT_HALTED' `
				-TargetObject $null

			throw $errorRecord
		}
	}
}

# MARK: Write-xyOpsError
function Write-xyOpsError {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline)][System.Management.Automation.ErrorRecord]$ErrorRecord,
		[Parameter(Mandatory = $false)][switch]$Halt,
		[Parameter(Mandatory = $false)][switch]$NoDataProtection
	)

	process {
		$enableDebug ? (Write-xyOpsJobOutput '[Write-xyOpsError] Processing reported error...' -Level debug) : $null
	
		if ($Halt.IsPresent) {
			$Script:halted = $true
			if ($NoDataProtection.IsPresent) {
				$Script:NoDataProtectionOnHalt = $true
			}
			throw $errorRecord
		}
		else {
			if ($NoDataProtection.IsPresent) {
				$ErrorRecord | Format-List * -Force | Out-String -Width 4096 | Write-xyOpsJobOutput -Level error
			}
			else {
				$ErrorRecord | Format-List * -Force | Out-String -Width 4096 | Protect-xyOpsSensitiveText | Write-xyOpsJobOutput -Level error
			}
		}
	
		$enableDebug ? (Write-xyOpsJobOutput '[Write-xyOpsError] Processing reported error... Complete' -Level debug) : $null
	}
}

# MARK: Send-xyOpsProgress
function Send-xyOpsProgress {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][decimal]$Percent,
		[Parameter(Mandatory = $false, Position = 1)][string]$Status
	)
	
	$dataObject = [pscustomobject]@{
		xy       = 1
		progress = $Percent / 100
		status   = $Status
	}

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsProgress] Sending job progress:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null

	Send-xyOpsOutput $dataObject
}

# MARK: Send-xyOpsStatus
function Send-xyOpsStatus {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$Status
	)

	$dataObject = [pscustomobject]@{
		xy     = 1
		status = $Status
	}

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsStatus] Sending job status:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
	Send-xyOpsOutput $dataObject
}

# MARK: New-Filename
function New-Filename {
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$Filetype,
		[Parameter(Mandatory = $false, Position = 1)][string]$Prefix
	)

	if ($Filetype -notmatch '^[a-zA-Z0-9]+$') {
		Write-xyOpsJobOutput "Invalid Filetype '$($Filetype)'. Filetype can only contain alphanumeric characters." -Level error
		return $null
	}

	$enableDebug ? (Write-xyOpsJobOutput '[New-Filename] Generating a new filename...' -Level debug) : $null
	
	if ($Prefix.IsPresent) {
		$prefix = $Prefix -replace ' ', '_'
	}

	$guid = (New-Guid).Guid
	
	$filename = "$((![string]::IsNullOrEmpty($prefix)) ? "$($prefix)_" : $null)$($guid).$($fileType)"
	
	$enableDebug ? (Write-xyOpsJobOutput '[New-Filename] Generating a new filename... Complete' -Level debug) : $null

	return $filename
}

# MARK: Send-xyOpsFile
function Send-xyOpsFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$Filename
	)

	$enableDebug ? (Write-xyOpsJobOutput '[Send-xyOpsFile] Adding file to job output list...' -Level debug) : $null
	
	$enableDebug ? (Write-xyOpsJobOutput '[Send-xyOpsFile] Checking if file exists...' -Level debug) : $null

	$file = @(Get-ChildItem $Filename -ErrorAction SilentlyContinue)
	if ($file) {
		if ($file.Length -gt 0) {
			$null = $filesToUpload.add($Filename)
			$enableDebug ? (Write-xyOpsJobOutput '[Send-xyOpsFile] File contains data; file added to job output list.' -Level debug) : $null
		}
		else {
			Write-xyOpsJobOutput "[Send-xyOpsFile] The file is 0 bytes.`npath: $($Filename)" -Level error
		}
	}
 else {
		$enableDebug ? (Write-xyOpsJobOutput '[Send-xyOpsFile] Checking if file exists... DOES NOT EXIST' -Level debug) : $null
		Write-xyOpsJobOutput "[Send-xyOpsFile] The file does not exist.`npath: $($Filename)" -Level error
	}

	$enableDebug ? (Write-xyOpsJobOutput '[Send-xyOpsFile] Adding file to job output list... Complete' -Level debug) : $null
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

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsPerf] Sending performance data to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
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

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsLabel] Setting job label:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
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

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsData] Sending data for xyOps processing:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
	Send-xyOpsOutput $dataObject
}

# MARK: Send-xyOpsWorkflowData
function Send-xyOpsWorkflowData {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$Key,
		[Parameter(Mandatory = $true, Position = 1)][object]$Data
	)

	$dataObject = [pscustomobject]@{
		xy           = 1
		workflowData = @{
			"$($Key)" = $Data
		}
	}

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsWorkflowData] Sending workflow data for xyOps processing:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
	
	Send-xyOpsOutput $dataObject
}

# MARK: Send-xyOpsTable
function Send-xyOpsTable {
	[CmdletBinding(DefaultParameterSetName = 'ObjectData')]
	param(
		[Parameter(Mandatory = $true, ParameterSetName = 'ObjectData', Position = 0, ValueFromPipeline)][object[]]$InputObject,
		[Parameter(Mandatory = $true, ParameterSetName = 'ArrayData')][array]$Rows,
		[Parameter(Mandatory = $true, ParameterSetName = 'ArrayData')][array]$Header,
		[Parameter(Mandatory = $false)][string]$Title,
		[Parameter(Mandatory = $false)][string]$Caption
	)
	begin {
		$table = @{}
		$rowsFromInputObject = [System.Collections.Generic.List[object]]::new()

		if ($Title) {
			$table['title'] = $Title 
		}

		if ($Caption) {
			$table['caption'] = $Caption 
		}
	}

	process {
		if ($InputObject.Count -eq 1) {
			if ($InputObject[0] -is [pscustomobject]) {
				$rowsFromInputObject.Add(@($InputObject[0].PSObject.Properties.Value))
			}
			elseif ($InputObject[0] -is [hashtable]) {
				$rowsFromInputObject.Add(@($InputObject[0].Values))
			}
		}
		if ($InputObject.Count -gt 1) {
			foreach ($row in $InputObject) {
				if ($row -is [pscustomobject]) {
					$rowsFromInputObject.Add(@($row.PSObject.Properties.Value))
				}
				elseif ($row -is [hashtable]) {
					$rowsFromInputObject.Add(@($row.Values))
				}
			}
		}
	}
	
	end {
		if ($InputObject) {
			$table['rows'] = $rowsFromInputObject
			if ($InputObject[0] -is [pscustomobject]) {
				$table['header'] = $InputObject[0].PSObject.Properties.Name
			}
			elseif ($InputObject[0] -is [hashtable]) {
				$table['header'] = @($InputObject[0].Keys)
			}
			
		}
		else {
			if ($Header) {
				$table['header'] = $Header 
			}

			$table['rows'] = $Rows
		}

		$dataObject = [pscustomobject]@{
			xy    = 1
			table = $table
		}

		$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsTable] Sending table to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
		
		Send-xyOpsOutput $dataObject
	}
	
	
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
	
	if ($Title) {
		$html['title'] = $Title 
	}
	if ($Caption) {
		$html['caption'] = $Caption 
	}

	$dataObject = [pscustomobject]@{
		xy   = 1
		html = $html
	}

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsHtml] Sending html to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null

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
	
	if ($Title) {
		$text['title'] = $Title 
	}
	if ($Caption) {
		$text['caption'] = $Caption 
	}

	$dataObject = [pscustomobject]@{
		xy   = 1
		text = $text
	}

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsText] Sending text to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null

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
	
	if ($Title) {
		$markdown['title'] = $Title 
	}
	if ($Caption) {
		$markdown['caption'] = $Caption 
	}

	$dataObject = [pscustomobject]@{
		xy       = 1
		markdown = $markdown
	}

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsMarkdown] Sending markdown to job output:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null
		
	Send-xyOpsOutput $dataObject
}

# MARK: Get-xyOpsInputFiles
function Get-xyOpsInputFiles {
	$files = [System.Collections.Generic.List[object]]::new()

	foreach ($file in $xyOps.input.files) {
		$files.Add($file)
	}
	
	return , $files
}

# MARK: Get-xyOpsBucketFile
function Get-xyOpsBucketFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$BucketId,
		[Parameter(Mandatory = $true, Position = 1)][string]$Filename,
		[Parameter(Mandatory = $false, Position = 2)][string]$OutFilename
	)

	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Bucket access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$bucketApiKey = $xyOps.secrets."$($xyOps.params.bucketapikeyvariable)"
	$apiUri = "$($xyOps.base_url)/api/app/get_bucket/v1?id=$($BucketId)"

	$enableDebug ? (Write-xyOpsJobOutput "[Get-xyOpsBucketFile] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'There was a problem retrieving the specified bucket details.' `
			-ErrorId 'APIError' `
			-Category ([System.Management.Automation.ErrorCategory]::ReadError) `
			-Stage 'Execution' `
			-Code 'XYOPS_API_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}

	if ([string]::IsNullOrEmpty($bucketData.files)) {
		Write-xyOpsJobOutput 'There are no files in specified bucket.'
		return
	}

	$filePath = $bucketData.files.Where({ $_.filename -eq $Filename }).path

	if ([string]::IsNullOrEmpty($filePath)) {
		Write-xyOpsJobOutput 'The requested file does not exist in the specified bucket.'
		return
	}

	$apiUri = "$($xyOps.base_url)/$($filePath)"

	$enableDebug ? (Write-xyOpsJobOutput "[Get-xyOpsBucketFile] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'There was a problem downloading the requested file.' `
			-ErrorId 'APIError' `
			-Category ([System.Management.Automation.ErrorCategory]::ReadError) `
			-Stage 'Execution' `
			-Code 'XYOPS_API_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}
}

# MARK: Add-xyOpsBucketFile
function Add-xyOpsBucketFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$BucketId,
		[Parameter(Mandatory = $true, Position = 1)][string]$Filename
	)

	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Bucket access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$bucketApiKey = $xyOps.secrets."$($xyOps.params.bucketapikeyvariable)"
	$apiUri = "$($xyOps.base_url)/api/app/upload_bucket_files/v1?id=$($BucketId)"

	$enableDebug ? (Write-xyOpsJobOutput "[Add-xyOpsBucketFile] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'There was a problem uploading the requested file.' `
			-ErrorId 'APIError' `
			-Category ([System.Management.Automation.ErrorCategory]::ReadError) `
			-Stage 'Execution' `
			-Code 'XYOPS_API_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}
}

# MARK: Remove-xyOpsBucketFile
function Remove-xyOpsBucketFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$BucketId,
		[Parameter(Mandatory = $true, Position = 1)][string]$Filename
	)
	
	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Bucket access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$bucketApiKey = $xyOps.secrets."$($xyOps.params.bucketapikeyvariable)"
	$apiUri = "$($xyOps.base_url)/api/app/delete_bucket_file/v1"

	$enableDebug ? (Write-xyOpsJobOutput "[Remove-xyOpsBucketFile] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'There was a problem deleting the specified bucket details.' `
			-ErrorId 'APIError' `
			-Category ([System.Management.Automation.ErrorCategory]::ReadError) `
			-Stage 'Execution' `
			-Code 'XYOPS_API_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}
}

# MARK: Get-xyOpsBucketData
function Get-xyOpsBucketData {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$BucketId
	)

	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Bucket access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$bucketApiKey = $xyOps.secrets."$($xyOps.params.bucketapikeyvariable)"
	$apiUri = "$($xyOps.base_url)/api/app/get_bucket/v1?id=$($BucketId)"

	$enableDebug ? (Write-xyOpsJobOutput "[Get-xyOpsBucketData] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'There was a problem retrieving the specified bucket details.' `
			-ErrorId 'APIError' `
			-Category ([System.Management.Automation.ErrorCategory]::ReadError) `
			-Stage 'Execution' `
			-Code 'XYOPS_API_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}

	return $bucketData
}

# MARK: Set-xyOpsBucketData
function Set-xyOpsBucketData {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$BucketId,
		[Parameter(Mandatory = $true, Position = 1)][string]$Key,
		[Parameter(Mandatory = $true, Position = 2)][object]$InputObject
	)

	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Bucket access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$bucketApiKey = $xyOps.secrets."$($xyOps.params.bucketapikeyvariable)"
	$apiUri = "$($xyOps.base_url)/api/app/write_bucket_data/v1?id=$($BucketId)"

	$enableDebug ? (Write-xyOpsJobOutput "[Set-xyOpsBucketData] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'There was a problem updating the specified bucket.' `
			-ErrorId 'APIError' `
			-Category ([System.Management.Automation.ErrorCategory]::WriteError) `
			-Stage 'Execution' `
			-Code 'XYOPS_API_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}
}

# MARK: Clear-xyOpsBucket
function Clear-xyOpsBucket {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$BucketId,
		[Parameter(Mandatory = $true, ParameterSetName = 'FilesOnly')][switch]$FilesOnly,
		[Parameter(Mandatory = $true, ParameterSetName = 'DataOnly')][switch]$DataOnly,
		[Parameter(Mandatory = $true, ParameterSetName = 'All')][switch]$All
	)

	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Bucket access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$bucketApiKey = $xyOps.secrets."$($xyOps.params.bucketapikeyvariable)"
	$apiUri = "$($xyOps.base_url)/api/app/empty_bucket/v1?id=$($BucketId)"

	$enableDebug ? (Write-xyOpsJobOutput "[Clear-xyOpsBucket] Invoking xyOps API: $($apiUri)" -Level debug) : $null

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
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'There was a problem clearing the specified bucket.' `
			-ErrorId 'APIError' `
			-Category ([System.Management.Automation.ErrorCategory]::ReadError) `
			-Stage 'Execution' `
			-Code 'XYOPS_API_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}
}

# MARK: Get-xyOpsCache
function Get-xyOpsCache {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$Key
	)
	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Cache is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$cacheBucketId = $xyOps.secrets."$($xyOps.params.cachebucketidvariable)"

	try {
		$bucketData = Get-xyOpsBucketData -BucketId $cacheBucketId
		$cacheData = $bucketData."$($Key)"
		return $cacheData
	}
	catch {
		Write-xyOpsJobOutput "There was an issue retrieving cache [$($Key)]." -Level error
	}
}

# MARK: Set-xyOpsCache
function Set-xyOpsCache {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$Key,
		[Parameter(Mandatory = $true, Position = 1)][object]$InputObject
	)

	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Bucket access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$cacheBucketId = $xyOps.secrets."$($xyOps.params.cachebucketidvariable)"

	try {
		Set-xyOpsBucketData -BucketId $cacheBucketId -Key $Key -InputObject $InputObject
		Write-xyOpsJobOutput "Cache updated [$($Key)]."
	}
	catch {
		Write-xyOpsJobOutput "There was an issue updating cache [$($Key)]." -Level error
	}
}

# MARK: Clear-xyOpsCache
function Clear-xyOpsCache {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][array]$Keys
	)

	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Bucket access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$cacheBucketId = $xyOps.secrets."$($xyOps.params.cachebucketidvariable)"

	foreach ($Key in $Keys) {
		try {
			Set-xyOpsBucketData -BucketId $cacheBucketId -Key $Key -InputObject @{}
			Write-xyOpsJobOutput "Cache cleared [$($Key)]."
		}
		catch {
			Write-xyOpsJobOutput "There was an issue updating cache [$($Key)]." -Level error
		}
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
			if ($xyOps.workflow.params) {
				foreach ($param in $xyOps.workflow.params.PSObject.Properties) {
					[void]$paramList.Add([PSCustomObject]@{
							Source = 'Workflow'
							Name   = $param.Name
							Value  = $param.Value
						})
				}
			}
		}
		else {
			if ($xyOps.params) {
				foreach ($param in $xyOps.params.PSObject.Properties) {
					[void]$paramList.Add([PSCustomObject]@{
							Source = 'Job'
							Name   = $param.Name
							Value  = $param.Value
						})
				}
			}
		}
		
		return , $paramList
	}

	if ($Workflow) {
		if ($Name -in $xyOps.workflow.params.PSObject.Properties.Name) {
			return $xyOps.workflow.params."$($Name)"
		}
	}
 else {
		if ($Name -in $xyOps.params.PSObject.Properties.Name) {
			return $xyOps.params."$($Name)"
		}
	}
	
	return $null
}

# MARK: Get-xyOpsTags
function Get-xyOpsTags {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false, Position = 0)][System.Collections.Generic.List[string]]$Tags,
		[Parameter(Mandatory = $false)][switch]$Indexed
	)

	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Tags access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$bucketApiKey = $xyOps.secrets."$($xyOps.params.bucketapikeyvariable)"
	$apiUri = "$($xyOps.base_url)/api/app/get_tags/v1"

	$enableDebug ? (Write-xyOpsJobOutput "[Get-xyOpsTags] Invoking xyOps API: $($apiUri)" -Level debug) : $null

	$requestSplat = @{
		Uri     = $apiUri
		Method  = 'GET'
		Headers = @{
			'X-API-KEY' = $bucketApiKey
		}
	}

	try {
		$allTags = [System.Collections.Generic.List[object]]::new(((Invoke-RestMethod @requestSplat).rows))
	}
	catch {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'There was an issue getting tags.' `
			-ErrorId 'APIError' `
			-Category ([System.Management.Automation.ErrorCategory]::ReadError) `
			-Stage 'Execution' `
			-Code 'XYOPS_API_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}

	if ($Tags) {
		if ($Indexed.IsPresent) {
			$returnTagsIndexed = @{}

			foreach ($tag in $allTags) {
				if ($tag.title -in $Tags) {
					$returnTagsIndexed["$($tag.title)"] = $tag
				}
			}

			return $returnTagsIndexed
		}
		else {
			$returnTags = [System.Collections.Generic.List[object]]::new()
	
			foreach ($tag in $allTags) {
				if ($tag.title -in $Tags) {
					$returnTags.Add($tag)
				}
			}

			return , $returnTags
		}

	}

	if ($Indexed.IsPresent) {
		$allTagsIndexed = @{}

		foreach ($tag in $allTags) {
			$allTagsIndexed["$($tag.title)"] = $tag
		}

		return $allTagsIndexed
	}
 else {
		return , $allTags
	}
}

# MARK: Send-xyOpsTags
function Send-xyOpsTags {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][System.Collections.Generic.List[string]]$Tags
	)

	$systemTags = Get-xyOpsTags

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
				Write-xyOpsJobOutput -Message "[Send-xyOpsTags] The tag '$($tag)' does not exist. Create the tag under [Scheduler > Tags]." -Level error -Halt
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
	
	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsTags] Sending job tags:`n$($dataObject | ConvertTo-Json -Depth 100)" -Level debug) : $null

	Send-xyOpsOutput $dataObject
}

# MARK: Send-xyOpsEmail
function Send-xyOpsEmail {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)][array]$To,
		[Parameter(Mandatory = $false)][string]$From,
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

	if ([string]::IsNullOrEmpty($xyOps.Secrets)) {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'No secrets have been assigned to this plugin or event. Email access is currently unavailable.' `
			-ErrorId 'MissingSecrets' `
			-Category ([System.Management.Automation.ErrorCategory]::ObjectNotFound) `
			-Stage 'Execution' `
			-Code 'XYOPS_MISSING_SECRETS' `
			-TargetObject '$xyOps.Secrets'

		Write-xyOpsError $errorRecord -Halt
	}

	$apiKey = $xyOps.secrets."$($xyOps.params.sendemailapikeyvariable)"
	$apiUri = "$($xyOps.base_url)/api/app/send_email/v1"

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
						'low' {
							5 
						}
						'normal' {
							3 
						}
						'high' {
							1 
						}
					}
					'X-Priority'        = switch ($Importance) {
						'low' {
							5 
						}
						'normal' {
							3 
						}
						'high' {
							1 
						}
					}
				}
			}
		}
	}

	if (![string]::IsNullOrEmpty($From)) {
		$requestSplat.Form.json['from'] = $From
	}

	$requestSplat.Form.json = $requestSplat.Form.json | ConvertTo-Json -Depth 100

	if ($Attachments.Count -gt 0) {
		$counter = 0
		foreach ($attachment in $Attachments) {
			$counter++
			$requestSplat.Form["file$($counter)"] = (Get-Item -Path $attachment)
		}
	}

	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsEmail] Email form data: $($requestSplat.Form.json)" -Level debug) : $null
	$enableDebug ? (Write-xyOpsJobOutput "[Send-xyOpsEmail] Invoking xyOps API: $($apiUri)" -Level debug) : $null

	try {
		$null = Invoke-RestMethod @requestSplat
		Write-xyOpsJobOutput 'Email Sent'
	}
	catch {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'There was an issue sending the email.' `
			-ErrorId 'APIError' `
			-Category ([System.Management.Automation.ErrorCategory]::ReadError) `
			-Stage 'Execution' `
			-Code 'XYOPS_API_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}
}

# MARK: Set-xyOpsJobResult
function Set-xyOpsJobResult {
	param(
		[Parameter(Mandatory = $true, Position = 0)][ValidateSet('success', 'warning', 'error', 'critical')][string]$Status,
		[Parameter(Mandatory = $true, Position = 2)][string]$Description
	)

	$enableDebug ? (Write-xyOpsJobOutput '[Set-xyOpsJobResult] Setting job status' -Level debug) : $null
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

# MARK: Push-xyOpsAction
function Push-xyOpsAction {
	[CmdletBinding(DefaultParameterSetName = $null)]
	param(
		[Parameter(Mandatory = $true)][ValidateSet('instant', 'complete', 'success', 'error', 'user', 'warning', 'critical', 'abort', 'tag', 'continue' )][string]$Condition,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_Email')][switch]$Email,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_WebHook')][switch]$WebHook,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_RunEvent')][switch]$RunEvent,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_Channel')][switch]$Channel,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_Snapshot')][switch]$Snapshot,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_Ticket')][switch]$Ticket,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_Plugin')][switch]$Plugin,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_SuspendJob')][switch]$SuspendJob,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_DisableEvent')][switch]$DisableEvent,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_DeleteEvent')][switch]$DeleteEvent,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_Email')][string[]]$EmailUsers,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_Email')][string[]]$EmailAddresses,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_WebHook')][string]$WebHookId,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_WebHook')][string]$WebHookText,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_RunEvent')][string]$RunEventId,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_RunEvent')][object]$RunEventParams,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_RunEvent')][switch]$RunEventIncludeOutput,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_Channel')][string]$ChannelId,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_Ticket')][ValidateSet('issue', 'feature', 'release', 'change', 'maintenance', 'question', 'other')][string]$TicketType,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_Ticket')][string[]]$TicketAssignees,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_Ticket')][string[]]$TicketTags,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_Ticket')][datetime]$TicketDue,
		[Parameter(Mandatory = $true, ParameterSetName = 'type_Plugin')][string]$PluginId,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_Plugin')][object]$PluginParams,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_SuspendJob')][string[]]$SuspendJobUsers,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_SuspendJob')][string[]]$SuspendJobEmailAddresses,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_SuspendJob')][string]$SuspendJobWebHookId,
		[Parameter(Mandatory = $false, ParameterSetName = 'type_SuspendJob')][string]$SuspendJobWebHookText,
		[Parameter(Mandatory = $false)][string]$ConditionTag
	)
	
	if ($Condition -eq 'tag' -and !$ConditionTag) {
		Write-xyOpsJobOutput "Using the 'tag' condition requires supplying the tag in the -ConditionTag parameter." -Level error -Halt
	}

	if ($Condition -eq 'tag') {
		$systemTags = Get-xyOpsTags

		switch ($ConditionTag) {
			{ $_ -in $systemTags.title } {
				$conditionTagId = ($systemTags.Find({ $args.title -eq $ConditionTag })).id
				break
			}
			{ $_ -in $systemTags.id } {
				$conditionTagId = $ConditionTag
				break
			}
			default {
				Write-xyOpsJobOutput -Message "[Push-xyOpsAction] The tag '$($ConditionTag)' does not exist. Create the tag under [Scheduler > Tags]." -Level error -Halt
				break
			}
		}
	}

	$actionHash = @{
		enabled   = $true
		condition = ($Condition -eq 'tag') ? "tag:$($conditionTagId)" : $Condition
	}

	if ($Email.IsPresent) {
		if (!$EmailUsers -and !$EmailAddresses) {
			Write-xyOpsJobOutput '[Push-xyOpsAction] Please specify at least one user using the -EmailUsers parameter or at least one email address using the -EmailAddresses parameter.' -Level error
			return
		}

		$actionHash['type'] = 'email'
		if ($EmailUsers) {
			$actionHash['users'] = $EmailUsers
		}
		if ($EmailAddresses) {
			$actionHash['email'] = $EmailAddresses -join ', '
		}
	}

	if ($WebHook.IsPresent) {
		$actionHash['type'] = 'web_hook'
		$actionHash['web_hook'] = $WebHookId
		if ($WebHookText) {
			$actionHash['text'] = $WebHookText 
		}
	}
	
	if ($RunEvent.IsPresent) {
		$actionHash['type'] = 'run_event'
		$actionHash['event_id'] = $RunEventId
		if ($RunEventParams) {
			$actionHash['params'] = $RunEventParams 
		}
		if ($RunEventIncludeOutput.IsPresent) {
			$actionHash['include_output'] = $true
		}
	}

	if ($Channel.IsPresent) {
		$actionHash['type'] = 'channel'
		$actionHash['channel_id'] = $ChannelId
	}
	
	if ($Snapshot.IsPresent) {
		$actionHash['type'] = 'snapshot'
	}
	
	if ($Ticket.IsPresent) {
		$actionHash['type'] = 'ticket'
		$actionHash['ticket_type'] = $TicketType
		$actionHash['ticket_assignees'] = $TicketAssignees
		if ($TicketTags) {
			if (!$systemTags) {
				$systemTags = Get-xyOpsTags
			}

			$pushTags = [System.Collections.Generic.List[object]]::new()

			foreach ($tag in $TicketTags) {
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
						Write-xyOpsJobOutput -Message "[Push-xyOpsAction] The tag '$($tag)' does not exist. Create the tag under [Scheduler > Tags]." -Level error -Halt
						break
					}
				}
			}
			$actionHash['ticket_tags'] = $pushTags
		}
		if ($TicketDue) {
			$actionHash['ticket_due'] = [System.DateTimeOffset]::new($TicketDue).ToUnixTimeSeconds()   
		}
	}
	
	if ($Plugin.IsPresent) {
		$actionHash['type'] = 'plugin'
		$actionHash['plugin_id'] = $PluginId
		if ($PluginParams) {
			$actionHash['params'] = $PluginParams
		}
	}

	if ($SuspendJob.IsPresent) {
		$actionHash['type'] = 'suspend'
		if ($SuspendJobUsers) {
			$actionHash['users'] = $SuspendJobUsers
		}
		if ($SuspendJobEmailAddresses) {
			$actionHash['email'] = $SuspendJobEmailAddresses -join ', '
		}
		if ($SuspendJobWebHookId) {
			$actionHash['web_hook'] = $SuspendJobWebHookId
		}
		if ($SuspendJobWebHookText) {
			$actionHash['text'] = $SuspendJobWebHookText
		}
	}

	if ($DisableEvent.IsPresent) {
		$actionHash['type'] = 'disable'
	}

	if ($DeleteEvent.IsPresent) {
		$actionHash['type'] = 'delete'
	}

	$enableDebug ? (Write-xyOpsJobOutput "[Push-xyOpsAction] Pushing Action:`n$($actionHash | ConvertTo-Json -Depth 100)" -Level debug) : $null

	Send-xyOpsOutput @{
		xy   = 1
		push = @{
			actions = @($actionHash)
		}
	}
}

# MARK: Protect-xyOpsSensitiveText
function Protect-xyOpsSensitiveText {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[AllowEmptyString()][string]$Text,

		[Parameter()][string[]]$SensitiveName = @(
			'Authorization', 'Proxy-Authorization', 'WWW-Authenticate',
			'X-API-Key', 'ApiKey', 'Api-Key', 'X-Auth-Token',
			'Cookie', 'Set-Cookie', 'Password', 'Secret', 'ClientSecret', 'Client-Secret'
		),

		[Parameter()][string]$Mask
	)

	process {
		if ([string]::IsNullOrEmpty($xyOps.params.globaltextprotectionmask)) {
			$enableDebug ? (Write-xyOpsJobOutput '[Protect-xyOpsSensitiveText] No custom mask set; using default mask.' -Level debug) : $null
			$Mask = '********'
		}
		else {
			$enableDebug ? (Write-xyOpsJobOutput "[Protect-xyOpsSensitiveText] Using custom mask: $($xyOps.params.globaltextprotectionmask)" -Level debug) : $null
			$Mask = $xyOps.params.globaltextprotectionmask
		}

		if ([string]::IsNullOrEmpty($Text)) {
			return $Text 
		}

		$names = @(foreach ($name in $SensitiveName) {
				[regex]::Escape($name) 
			}) -join '|'
		$scheme = '(?<scheme>(?:Basic|Bearer|Digest|Negotiate|NTLM|OAuth|Token|AWS4-HMAC-SHA256)\s+)?'
		$safeMask = $Mask -replace '\$', '$$$$'
		$to = '${pre}${scheme}' + $safeMask

		# "Authorization": "Bearer xxx"   (JSON / quoted)
		$Text = $Text -replace "(?i)(?<pre>[""'](?:$names)[""']\s*:\s*[""'])$scheme[^""']*", $to

		# [Authorization, Bearer xxx]  /  {Authorization, xxx}   (header dictionaries)
		$Text = $Text -replace "(?i)(?<pre>[\[\{]\s*(?:$names)\s*,\s*)$scheme[^\]\}\r\n]+", $to

		# Authorization: Bearer xxx  /  Authorization = xxx   (Format-List, raw headers)
		$Text = $Text -replace "(?im)(?<pre>(?:^|[\s,\[\{\(])(?:$names)\s*[:=]\s*)$scheme[^\r\n,\]\}\)]*", $to

		return $Text
	}
}

# MARK: Begin
try {
	$ansiStyleMap = @{
		'Regular'                 = @{
			'Black'  = '[0;30m'
			'Red'    = '[0;31m'
			'Green'  = '[0;32m'
			'Yellow' = '[0;33m'
			'Blue'   = '[0;34m'
			'Purple' = '[0;35m'
			'Cyan'   = '[0;36m'
			'White'  = '[0;37m'
		}
		'Bold'                    = @{
			'Black'  = '[1;30m'
			'Red'    = '[1;31m'
			'Green'  = '[1;32m'
			'Yellow' = '[1;33m'
			'Blue'   = '[1;34m'
			'Purple' = '[1;35m'
			'Cyan'   = '[1;36m'
			'White'  = '[1;37m'
		}
		'Underline'               = @{
			'Black'  = '[4;30m'
			'Red'    = '[4;31m'
			'Green'  = '[4;32m'
			'Yellow' = '[4;33m'
			'Blue'   = '[4;34m'
			'Purple' = '[4;35m'
			'Cyan'   = '[4;36m'
			'White'  = '[4;37m'
		}
		'Background'              = @{
			'Black'  = '[40m'
			'Red'    = '[41m'
			'Green'  = '[42m'
			'Yellow' = '[43m'
			'Blue'   = '[44m'
			'Purple' = '[45m'
			'Cyan'   = '[46m'
			'White'  = '[47m'
		}
		'HighIntensity'           = @{
			'Black'  = '[0;90m'
			'Red'    = '[0;91m'
			'Green'  = '[0;92m'
			'Yellow' = '[0;93m'
			'Blue'   = '[0;94m'
			'Purple' = '[0;95m'
			'Cyan'   = '[0;96m'
			'White'  = '[0;97m'
		}
		'BoldHighIntensity'       = @{
			'Black'  = '[1;90m'
			'Red'    = '[1;91m'
			'Green'  = '[1;92m'
			'Yellow' = '[1;93m'
			'Blue'   = '[1;94m'
			'Purple' = '[1;95m'
			'Cyan'   = '[1;96m'
			'White'  = '[1;97m'
		}
		'HighIntensityBackground' = @{
			'Black'  = '[0;100m'
			'Red'    = '[0;101m'
			'Green'  = '[0;102m'
			'Yellow' = '[0;103m'
			'Blue'   = '[0;104m'
			'Purple' = '[0;105m'
			'Cyan'   = '[0;106m'
			'White'  = '[0;107m'
		}
	}

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

	try {
		# Read job parameters from JSON input
		[PSCustomObject]$xyOps = ConvertFrom-Json -Depth 100 (Read-Host)
	}
	catch {
		Send-xyOpsOutput ([pscustomobject]@{
				xy          = 1
				code        = 'critical'
				description = 'FATAL ERROR.'
			})

		$errorRecord = New-XyOpsErrorRecord `
			-Message 'Unable to read host JSON from xyops Job.' `
			-ErrorId 'FatalError' `
			-Category ([System.Management.Automation.ErrorCategory]::InvalidOperation) `
			-Stage 'Configuration' `
			-Code 'XYOPS_FATAL_ERROR' `
			-TargetObject $null `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}

	$enableLogTime = $xyOps.params.logtime
	$enableDebug = $xyOps.params.enabledebuglogging
	$NoDataProtectionOnHalt = $false

	if ($xyOps.input -and ($xyOps.params.passdata -eq $true)) {
		if ($xyOps.input.data) {
			Send-xyOpsData $xyOps.input.data
		}
		else {
			Send-xyOpsData $xyOps.input
		}
	}

	# Set current directory to the working directory of the job
	Set-Location $xyOps.cwd

	# Output xyOps Json data
	if ($xyOps.params.outputxyops) {
		$formattedJson = $xyOps | ConvertTo-Json -Depth 100 | Protect-xyOpsSensitiveText -SensitiveName $xyOps.secrets.PSObject.Properties.Name
		$markdownContent = "``````json`n$($formattedJson)`n``````"
		Send-xyOpsMarkdown -Content $markdownContent -Title 'Job Data - Json'
	}

	# Output if running in Test mode
	if ($xyOps.test) {
		Write-xyOpsJobOutput 'Running in Test mode' -Level debug
	}

	# Output PowerShell Version
	Write-xyOpsJobOutput "PowerShell Version: $($PSVersionTable.PSVersion)"

	$enableDebug ? (Write-xyOpsJobOutput '[MAIN] Loading module files...' -Level debug) : $null

	# Import any .psm1 module files provided from a bucket fetch action.
	if ($xyOps.params.processmodules) {
		$moduleFiles = (Get-xyOpsInputFiles).FindAll({ $args.filename -like '*.psm1' })
		foreach ($moduleFile in $moduleFiles) {
			$enableDebug ? (Write-xyOpsJobOutput "[MAIN] Module file found: $((Get-ChildItem $moduleFile.filename).FullName)" -Level debug) : $null
			try {
				Write-xyOpsJobOutput "Loading module file: $($moduleFile.filename)"
				Import-Module "./$($moduleFile.filename)"
			}
			catch {
				$errorRecord = New-XyOpsErrorRecord `
					-Message 'Failed to load module.' `
					-ErrorId 'ModuleError' `
					-Category ([System.Management.Automation.ErrorCategory]::InvalidOperation) `
					-Stage 'Configuration' `
					-Code 'XYOPS_MODULE_ERROR' `
					-TargetObject '$moduleFile' `
					-InnerErrorRecord $_

				Write-xyOpsError $errorRecord -Halt
			}
		}
	}
	else {
		$enableDebug ? (Write-xyOpsJobOutput '[MAIN] No module files to load' -Level debug) : $null
	}

	$enableDebug ? (Write-xyOpsJobOutput '[MAIN] Loading module files... Complete' -Level debug) : $null

	Write-xyOpsJobOutput 'Job Started'

	$enableDebug ? (Write-xyOpsJobOutput '[MAIN] Checking code block...' -Level debug) : $null

	try {
		$command = [scriptblock]::create($xyOps.params.command)
	}
	catch {
		$errorRecord = New-XyOpsErrorRecord `
			-Message 'The code block provided is invalid. Please use a proper code editor to verify your script.' `
			-ErrorId 'InvalidData' `
			-Category ([System.Management.Automation.ErrorCategory]::InvalidData) `
			-Stage 'Configuration' `
			-Code 'XYOPS_INVALID_CODEBLOCK' `
			-TargetObject '$xyOps.params.command' `
			-InnerErrorRecord $_

		Write-xyOpsError $errorRecord -Halt
	}

	$enableDebug ? (Write-xyOpsJobOutput '[MAIN] Checking code block... Complete' -Level debug) : $null
	
	$enableDebug ? (Write-xyOpsJobOutput '[MAIN] Executing code block...' -Level debug) : $null
	& $command
}
catch {
	$errorRecord = $_

	if ($NoDataProtectionOnHalt) {
		Write-xyOpsError $errorRecord -NoDataProtection
	}
	else {
		Write-xyOpsError $errorRecord
	}
}
finally {
	$enableDebug ? (Write-xyOpsJobOutput '[MAIN] Executing code block... Complete' -Level debug) : $null
	if ($filesToUpload.Count -gt 0) {
		$enableDebug ? (Write-xyOpsJobOutput "[MAIN] There are $($filesToUpload.Count) files to upload to the job output." -Level debug) : $null
		$output = [pscustomobject]@{
			xy    = 1
			files = @()
		}

		if ($enableDebug) {
			foreach ($file in $filesToUpload) {
				Write-xyOpsJobOutput "[MAIN] Attaching file: $($file)" -Level debug
			}
		}

		$output.files = @(foreach ($file in $filesToUpload) {
				@{ path = $file; delete = $false }
			})

		Send-xyOpsOutput $output
	}
	
	Write-xyOpsJobOutput 'Job Finished'
	# Report status
	$enableDebug ? (Write-xyOpsJobOutput '[MAIN] Reporting job status...' -Level debug) : $null
	Send-xyOpsOutput ([pscustomobject]@{
			xy          = 1
			code        = $jobStatus.Status
			description = $jobStatus.Description
		})
	$enableDebug ? (Write-xyOpsJobOutput '[MAIN] Reporting job status... Complete' -Level debug) : $null
}