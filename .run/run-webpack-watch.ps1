# STOP!
# This file is not meant to be run directly by YOU.
# Use this runner instead: https://github.com/dealdiane/dotnet-runner/blob/master/run-dev.ps1

param (
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    [string]$IsKeepWindowOnTop = "false",
    [string]$WorkingDirectory = ""
)

# Uncomment if running this script manualy (for testing)
# Get-Module BuildWatch | Remove-Module BuildWatch
Import-Module .\.run\BuildWatch.psm1

$IsKeepWindowOnTop = [System.Convert]::ToBoolean($IsKeepWindowOnTop)

$restart = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Restart webpack watch"
$noRestart = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Terminate this script"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($restart, $noRestart)

if ([System.String]::IsNullOrWhitespace($WorkingDirectory)) {
    $currentDirectory = (Get-Item -Path ".\").FullName
} else {
write-host $WorkingDirectory
    $currentDirectory = Resolve-Path $WorkingDirectory.replace('*', ' ') | Select -ExpandProperty Path
}

$env:Path += ";$([System.IO.Path]::Combine($currentDirectory, 'node_modules\.bin'));"

try { 
    $hWnd = (Get-Process -Id $pid).MainWindowHandle
    $style = Get-WindowStyle $hWnd
    
    if ($IsKeepWindowOnTop -eq $true)
    {
        Set-WindowTopMost $hWnd | Out-Null
    }
    
    Set-ProcessPriority $pid 'BelowNormal'

    do
    {
        Write-Host "`nRunning webpack watch"
        $path = (Get-Command webpack).Source

        if ($IsKeepWindowOnTop -eq $true)
        {
            # Remvove crap from window but will make it non-draggable
            Set-WindowStyleMinimized $hWnd | Out-Null
        }

        Start-Console $path "--config webpack.config.js --watch --progress --profile --mode=development" "webpack watch: $ProjectName" -IsClearConsole $false -IsAutoKill $true -KillWaitTimeout 100 -WorkingDirectory $currentDirectory

        if ($IsKeepWindowOnTop -eq $true)
        {
            # Make window draggable again
            Set-WindowStyle $hWnd $style | Out-Null
        }
        
        $result = $host.ui.PromptForChoice('Webpack watch terminated', 'Do you want to restart the webpack watch?', $options, 0);

        if ($result -ne 0) {
            break;
        }

    } until ($false)
} catch {
    Write-Error 'Failed to run Webpack watch'
    Write-Error $_.Exception
    
    Write-Host 'Press any key to exit'
    [System.Console]::Read()
}
finally {
    if ($IsKeepWindowOnTop -eq $true)
    {
        Set-WindowStyle $hWnd $style | Out-Null
        Set-WindowTopMost $hWnd | Out-Null
    }
}