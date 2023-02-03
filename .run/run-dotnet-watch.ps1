# STOP!
# This file is not meant to be run directly by YOU.
# Use this runner instead: https://github.com/dealdiane/dotnet-runner/blob/master/run-dev.ps1

param (
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    [string]$Environment = "Development",
    [string]$Urls = "http://*:5000",
    [string]$DotNetWatchArguments = "",
    [bool]$IsKeepWindowOnTop = $false,
    [bool]$IsEnableHotReload = $true,
    [string]$ClientAppDirectory = ""
)

$title = "dotnet watch: $projectName"
$isClearConsoleOnRestart = $true

# WARNING!
# These variables can still be overridden by configuration depending on how the dotnet app is configured:
#  a. In /Properties/launchSettings.json
#  b. In Program.cs
#  c. 

$ENV:ASPNETCORE_ENVIRONMENT=$Environment
$ENV:ASPNETCORE_URLS=$Urls
$ENV:DOTNET_WATCH_RESTART_ON_RUDE_EDIT=1

# Uncomment if running this script manualy (for testing)
# Get-Module BuildWatch | Remove-Module BuildWatch
Import-Module .\.run\BuildWatch.psm1

if ($IsKeepWindowOnTop -eq $true)
{
    Set-WindowTopMostByProcess $pid | Out-Null
}

# Run Webpack watch
$requiresWebPack = Test-Path "$($ClientAppDirectory)webpack.config.js"

if ($requiresWebPack -eq $true) {
    $webPackChoiceTimeout = 5

    Write-Warning "---------------------------------------------------------"
    Write-Warning "                 R U N    W E B P A C K ?                "
    Write-Warning "---------------------------------------------------------"
    Write-Warning "It looks like you might require webpack for this project."
    Write-Warning "If you do NOT REQUIRE WEBPACK, press 'n' now.            "
    Write-Warning "---------------------------------------------------------"

    # Clear key buffer. Ensures that the 'wait' will not be indefinite.
    $response = Get-UserResponse $webPackChoiceTimeout

    if ($response -eq "n") {
        Write-Warning "'Webpack watch' will not run."
        $requiresWebPack = $false
    } else {
        Write-Host "Automatically running 'Webpack watch' because no input was received."
    }
}

# Disabled until front-end dev has started
#$requiresWebPack = $false

if ($requiresWebPack -eq $true)
{
    # Run Webpack watcher
    Write-Host "Running 'Webpack watch'"
    # $webPackWatchProcess = Start-Process "npm" -ArgumentList 'run watch' -PassThru    
    
    $escapedClientAppDirectory = $ClientAppDirectory.replace(' ', '*')
    $webPackWatchProcess = Start-Process powershell.exe -Argument "-Nologo -Noprofile -ExecutionPolicy Bypass -File .\.run\run-webpack-watch.ps1 -ProjectName ""$ProjectName"" -IsKeepWindowOnTop ""$IsKeepWindowOnTop"" -WorkingDirectory ""$escapedClientAppDirectory"""
}

# Run Angular watch
$requiresAngular = Test-Path "$($ClientAppDirectory)angular.json"

if ($requiresAngular -eq $true) {
    $angularChoiceTimeout = 5

    Write-Warning "---------------------------------------------------------"
    Write-Warning "             R U N    A N G U L A R   J S ?              "
    Write-Warning "---------------------------------------------------------"
    Write-Warning "It looks like you might require angular for this project."
    Write-Warning "If you do NOT REQUIRE ANGULAR JS, press 'n' now.         "
    Write-Warning "---------------------------------------------------------"
    
    $response = Get-UserResponse $angularChoiceTimeout
    
    if ($response -eq "n") {
        Write-Warning "'Angular JS watch' will not run."
        $requiresAngular = $false
    } else {
        Write-Host "Automatically running 'Angular JS watch' because no input was received."
    }
}

if ($requiresAngular -eq $true)
{


    # Run Angular JS watcher
    Write-Host "Running 'Angular watch'"
    
    $escapedClientAppDirectory = $ClientAppDirectory.replace(' ', '*')
    $angularWatchProcess = Start-Process powershell.exe -Argument "-Nologo -Noprofile -ExecutionPolicy Bypass -File .\.run\run-angular-watch.ps1 -ProjectName ""$ProjectName"" -IsKeepWindowOnTop ""$IsKeepWindowOnTop"" -WorkingDirectory ""$escapedClientAppDirectory"" " -PassThru
}

$restart = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Restart dotnet web server"
$noRestart = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Terminate this script"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($restart, $noRestart)
$currentDirectory = (Get-Item -Path ".\").FullName

try
{
    $style = Get-WindowStyleByProcess $pid
    Set-ProcessPriority $pid 'BelowNormal'
    
    do
    {
        # The Webpack watcher window would've taken over the foreground. Bring this script back to foreground.
        Start-Sleep -s 1
        Set-ForegroundProcess $pid

        if ($IsKeepWindowOnTop -eq $true)
        {
            # Remove crap from window but will make it non-draggable
            Set-WindowStyleMinimizedByProcess $pid | Out-Null
        }
        
        if (-Not $IsEnableHotReload)
        {
            $DotNetWatchArguments = "$DotNetWatchArguments --no-hot-reload"
        }
        
        # When Hot Reload is required, a new console window is required to intercept keyboard commands (e.g. CTRL+R)
        $isUseSingleConsole = !$IsEnableHotReload

        Write-Host "`nRunning dotnet watch"
        # Start-DotnetWatch
        Start-Console "dotnet" "watch run $DotNetWatchArguments" $title -IsClearConsole $isClearConsoleOnRestart -WorkingDirectory $currentDirectory -IsUseSingleConsole $isUseSingleConsole

        if ($IsKeepWindowOnTop -eq $true)
        {
            # Make window draggable again
            Set-WindowStyleByProcess $pid $style | Out-Null
        }

        $restartChoice = $host.ui.PromptForChoice('Web server terminated', 'Do you want to restart the web server?', $options, 0);

        if ($restartChoice -ne 0) {
            break;
        }
        

    } until ($false)
}
finally
{
    if ($IsKeepWindowOnTop -eq $true)
    {
        Set-WindowNormalByProcess $pid | Out-Null
    }
    
    if ($requiresWebPack -eq $true)
    {
        Write-Host "`nTerminating Webpack watch process"
        Stop-Console $webPackWatchProcess.ID
        Start-Sleep -s 1
        
        if ($webPackWatchProcess.Id -gt 0)
        {
            Stop-Process $webPackWatchProcess -Force
        }
    }
    
    if ($requiresAngular -eq $true)
    {
        Write-Host "`nTerminating Angular watch process"
        Stop-Console $angularWatchProcess.ID
        Start-Sleep -s 1
        
        if ($angularkWatchProcess.Id -gt 0)
        {
            Stop-Process $angularkWatchProcess -Force
        }
    }

    if ($IsKeepWindowOnTop -eq $true)
    {
        Set-WindowStyleByProcess $pid $style | Out-Null
    }
}