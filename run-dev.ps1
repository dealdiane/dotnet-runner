# Grab the latest script from https://github.com/dealdiane/dotnet-runner/blob/master/run-dev.ps1

$projectName = "" # Enter project name
$environment = "Development"
$clientAppDirectory = "" # If using webpack or angular, enter the its root directory here

# If project name is empty, try get from containing folder
if ([string]::IsNullOrWhiteSpace($projectName))
{
    $projectName = Get-Location | Split-Path -leaf
}

function GetWebFile($fileName) {
    $tempWebFile = "$env:TEMP\" + [guid]::NewGuid() + "-$fileName";

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Download new 'run' file from BitBucket
    Invoke-WebRequest "https://raw.githubusercontent.com/dealdiane/dotnet-runner/master/.run/$fileName" -OutFile $tempWebFile -Headers @{"Cache-Control"="no-cache"}

    Return $tempWebFile
}

$buildDirectory = '.run'

function CheckForUpdate($localFile) {
    $fileName = Split-Path $localFile -leaf

    Write-Host "Checking updates for $fileName..."

    $webFile = GetWebFile $fileName

    $localFileHash = Get-FileHash $localFile -Algorithm MD5
    $webFileHash = Get-FileHash $webFile -Algorithm MD5

    if ($localFileHash.Hash -eq $webFileHash.Hash) {
        Write-Host "Your local run script is up-to-date" -ForegroundColor Green
    } else {
    
        $restart = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Update"
        $noRestart = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Do not update"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($restart, $noRestart)

        $result = $host.ui.PromptForChoice('An updated script was found', 'Do you want to update your local copy?', $options, 0);

        if ($result -eq 0) {
            Move-Item $webFile $localFile -Force -Confirm:$False
            Write-Host "$fileName successfully updated"
        } else {
            Remove-Item $webFile
            Write-Warning "$fileName script was not updated"
        }
    }
}

$checkForUpdates = $true

$buildFiles =  @('BuildWatch.psm1', 'run-dotnet-watch.ps1', 'run-webpack-watch.ps1', 'run-angular-watch.ps1')

if (!(Test-Path -Path ".run" )){
    New-Item -ItemType directory -Path ".run"
}

foreach ($buildFile in $buildFiles) {
    
    $buildFilePath = "$buildDirectory/$buildFile"
    
    if (-Not (Test-Path $buildFilePath)) {
        Write-Host "Local script '$buildFile' was not found in the current directory."
        Write-Host 'Downloading current version from BitBucket...'

        $webFile = GetWebFile $buildFile

        Move-Item $webFile $buildFilePath -Force -Confirm:$False
    } elseif ($checkForUpdates -eq $true) {
        try
        {
            CheckForUpdate $buildFilePath
        } 
        catch
        {
            Write-Warning "An error has occurred while checking for an update."
        }
    }
}

$onTopChoiceTimeout = 5
$isKeepWindowOnTop = $false

# Uncomment if running this script manualy (for testing)
# Get-Module BuildWatch | Remove-Module BuildWatch
Import-Module .\.run\BuildWatch.psm1

Write-Host ""
Write-Warning "To keep this window on-top, press 'y' in the next $onTopChoiceTimeout seconds OR any key to continue."

$response = Get-UserResponse $onTopChoiceTimeout

if ($response -eq "y") {
    Write-Warning "Window will be optimised for logging and displayed on-top of other windows. To move or resize the window, press ALT+SPACE."
    $isKeepWindowOnTop = $true
}

$isDisableHotReloadChoiceTimeout = 2
$isEnableHotReload = $true

#Write-Host ""
Write-Warning "To DISABLE Hot Reload, press 'y' in the next $isDisableHotReloadChoiceTimeout seconds OR any key to continue."

$response = Get-UserResponse $isDisableHotReloadChoiceTimeout

if ($response -eq "y") {
    Write-Warning "Hot Reload will be disabled. Single-window mode will be used."
    $isEnableHotReload = $false
} else {
    Write-Warning "Hot Reload will be enabled. The dotnet watch process will be launched in a new console window."
}

Start-Sleep -Seconds 2

Invoke-Expression ".\.run\run-dotnet-watch.ps1 -projectName '$projectName' -environment '$environment' -isKeepWindowOnTop `$$isKeepWindowOnTop -isEnableHotReload `$$isEnableHotReload -clientAppDirectory '$clientAppDirectory'"

# For testing
#Remove-Item $runFile