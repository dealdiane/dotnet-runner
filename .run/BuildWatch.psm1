# STOP!
# These modules are not meant to be installed directly by YOU.
# Use this runner instead: https://github.com/dealdiane/dotnet-runner/blob/master/run-dev.ps1

#  Windows® constants
$WS_BORDER = 0x00800000
$WS_DLGFRAME = 0x00400000
$WS_CAPTION = $WS_BORDER -bOr $WS_DLGFRAME
$WS_THICKFRAME = 0x00040000
$WS_MINIMIZE = 0x20000000
$WS_MAXIMIZE = 0x01000000
$WS_SYSMENU = 0x00080000
$WS_EX_DLGMODALFRAME = 0x00000001
$WS_EX_CLIENTEDGE = 0x00000200
$WS_EX_STATICEDGE = 0x00020000
$WS_POPUP = 0x80000000L
$WS_DLGFRAME = 0x00400000L
$WS_EX_DLGMODALFRAME = 0x00000001L
$WS_MAXIMIZEBOX = 0x00010000L
$WS_HSCROLL = 0x00100000L
$WS_VSCROLL = 0x00200000L
$WS_EX_TOPMOST = 0x00000008L

$SWP_FRAMECHANGED = 0x0020
$SWP_NOMOVE = 0x0002
$SWP_NOSIZE = 0x0001
$SWP_NOZORDER = 0x0004

$GWL_EXSTYLE = -20
$GWL_STYLE = -16

# Create class for executing Win32 APIs
Add-Type @"
    using System;
    using System.Diagnostics;
    using System.Runtime.InteropServices;
    using System.Text.RegularExpressions;
    
    public class PInvoke {
    
        private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
        private static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
        
        private const UInt32 SWP_NOSIZE = 0x0001;
        private const UInt32 SWP_NOMOVE = 0x0002;
        private const UInt32 TOPMOST_FLAGS = SWP_NOMOVE | SWP_NOSIZE;
    
        [DllImport("user32.dll", SetLastError = true)] 
        public static extern int GetWindowLong(IntPtr hWnd, int nIndex); 

        [DllImport("user32.dll", SetLastError = true)] 
        public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
        
        [DllImport("user32.dll")]
        public static extern bool InvalidateRect(IntPtr hWnd, IntPtr lpRect, bool bErase);
        
        [DllImport("user32.dll")]
        public static extern bool UpdateWindow(IntPtr hWnd);
        
        [DllImport("user32.dll")]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
        
        public static void MakeTopMost(IntPtr fHandle)
        {
            SetWindowPos(fHandle, HWND_TOPMOST, 0, 0, 0, 0, TOPMOST_FLAGS);
        }
        
        public static void MakeNormal(IntPtr fHandle)
        {
            SetWindowPos(fHandle, HWND_NOTOPMOST, 0, 0, 0, 0, TOPMOST_FLAGS);
        }
    }
    
    public class ProcessHelper
    {
        public enum LastMessageType
        {
            Unknown,
            Warn,
            Error,
            Info,
        }
        
        public static Process StartConsoleProcess(string fileName, string arguments, string workingDirectory, bool isRedirectIO = true)
        {
            var startInfo = new ProcessStartInfo(fileName, arguments);

            startInfo.WorkingDirectory = workingDirectory;
            startInfo.RedirectStandardInput = isRedirectIO;
            startInfo.RedirectStandardError = isRedirectIO;
            startInfo.RedirectStandardOutput = isRedirectIO;
            startInfo.UseShellExecute = !isRedirectIO;
            startInfo.CreateNoWindow = isRedirectIO;

            var process = new Process();
            
            if (isRedirectIO)
            {
                var lastMessageType = LastMessageType.Unknown;

                process.OutputDataReceived += (sender, args) =>
                {
                    var message = args.Data;

                    if (!string.IsNullOrEmpty(message))
                    {
                        if ((Regex.IsMatch(message, @"^[\s-]+") && lastMessageType == LastMessageType.Warn) || Regex.IsMatch(message, "warn(ing)?"))
                        {
                            Console.ForegroundColor = ConsoleColor.Yellow;
                            Console.WriteLine(message);
                            Console.ResetColor();
                            lastMessageType = LastMessageType.Warn;
                        }
                        else if ((Regex.IsMatch(message, @"^[\s-]+") && lastMessageType == LastMessageType.Error) || Regex.IsMatch(message, @"(^\s*fail)|error|exception"))
                        {
                            Console.ForegroundColor = ConsoleColor.Red;
                            Console.WriteLine(message);
                            Console.ResetColor();
                            lastMessageType = LastMessageType.Error;

                        }
                        else if ((Regex.IsMatch(message, @"^[\s-]+") && lastMessageType == LastMessageType.Info) || Regex.IsMatch(message, @"^\s*info"))
                        {
                            Console.ForegroundColor = ConsoleColor.Green;
                            Console.WriteLine(message);
                            Console.ResetColor();
                            lastMessageType = LastMessageType.Info;
                        }
                        else
                        {
                            Console.WriteLine(message);
                            lastMessageType = LastMessageType.Unknown;
                        }
                    }
                };
                
                process.ErrorDataReceived += (sender, args) =>
                {
                    var message = args.Data;
                    
                    if (!string.IsNullOrEmpty(args.Data))
                    {
                        Console.Error.WriteLine(message);
                    }
                };
            }
            
            process.StartInfo = startInfo;
            
            //process.Start();
            //process.BeginOutputReadLine();
            //process.BeginErrorReadLine();
            
            return process;
        }
    }
"@

function Stop-Console ([int]$processId) {
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("Add-Type -Names 'w' -Name 'k' -M '[DllImport(""kernel32.dll"")]public static extern bool FreeConsole();[DllImport(""kernel32.dll"")]public static extern bool AttachConsole(uint p);[DllImport(""kernel32.dll"")]public static extern bool SetConsoleCtrlHandler(uint h, bool a);[DllImport(""kernel32.dll"")]public static extern bool GenerateConsoleCtrlEvent(uint e, uint p);public static void SendCtrlC(uint p){FreeConsole();AttachConsole(p);GenerateConsoleCtrlEvent(0, 0);}';[w.k]::SendCtrlC($processId)"))
    Start-Process powershell.exe -Argument "-Nologo -Noprofile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand" -NoNewWindow
}

function Restart-HotReload ([int]$processId) {
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("Add-Type -Names 'w' -Name 'k' -M '[DllImport(""user32.dll"")]public static extern bool SetForegroundWindow(IntPtr hWnd);[DllImport(""user32.dll"")]public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);[DllImport(""kernel32.dll"")]public static extern IntPtr GetConsoleWindow();[DllImport(""kernel32.dll"")]public static extern bool FreeConsole();[DllImport(""kernel32.dll"")]public static extern bool AttachConsole(int p);[DllImport(""User32.Dll"", EntryPoint = ""PostMessageA"")]private static extern bool PostMessage(IntPtr hWnd, uint msg, int wParam, int lParam);const int KEYEVENTF_KEYUP = 0x0002;const int WM_KEYDOWN = 0x100;const int VK_LCONTROL = 0xA2;const int VK_R = 0x52;public static void SendCtrlR(int p){FreeConsole();AttachConsole(p);var hWnd = GetConsoleWindow();SetForegroundWindow(hWnd);keybd_event(VK_LCONTROL, 0, 0, 0);PostMessage(hWnd, WM_KEYDOWN, VK_R, 0);keybd_event(VK_LCONTROL, 0, KEYEVENTF_KEYUP, 0);}';[w.k]::SendCtrlR($processId)"))
    Start-Process powershell.exe -Argument "-Nologo -Noprofile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand" -NoNewWindow -Wait
    
    $childProcesses = Get-WmiObject Win32_Process -Filter "ParentProcessId=$processId"

    foreach($childProcess in $childProcesses) {
        if ($childProcess.ProcessName -eq "dotnet.exe") {
            Restart-HotReload $childProcess.ProcessId
        }
    }
}

function Stop-ConsoleTree ([int]$Id) {
    $childProcesses = Get-WmiObject Win32_Process -Filter "ParentProcessId=$Id"

    foreach($childProcess in $childProcesses) {
        Stop-ConsoleTree $childProcess.ProcessId
    }

    Stop-Console $Id
}

function Stop-ProcessTree ([int]$Id) {
    $childProcesses = Get-WmiObject Win32_Process -Filter "ParentProcessId=$Id"

    foreach($childProcess in $childProcesses) {
        Stop-ProcessTree $childProcess.ProcessId
    }

    Stop-Process -Id $Id -Force
}

function Set-ProcessPriority {

    param (
        [Parameter(Mandatory = $true)]
        $Id,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('AboveNormal', 'BelowNormal', 'High', 'Idle', 'Normal', 'RealTime')]
        [String]$Priority
    )

    (Get-Process -id $Id).PriorityClass = $Priority;
}

function Set-ProcessPriorityTree {
    
    param (
        [Parameter(Mandatory = $true)]
        $Id,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('AboveNormal', 'BelowNormal', 'High', 'Idle', 'Normal', 'RealTime')]
        [String]$Priority
    )

    $childProcesses = Get-WmiObject Win32_Process -Filter "ParentProcessId=$Id"

    foreach($childProcess in $childProcesses) {
        Set-ProcessPriorityTree -Id $childProcess.ProcessId -Priority $Priority
    }

    Set-ProcessPriority -Id $Id -Priority $Priority
}

function Get-MainWindowHandle {
    
    param (
        [Parameter(Mandatory = $true)]
        $Id
    )

    $mainProcessId = $Id
    $lastHwnd = 0
    
    $explorerProcesses = $(Get-Process -Name "explorer")

    do
    {
        $lastProcessId = (gwmi win32_process | ? processid -eq  $mainProcessId).ParentProcessId
        
        # Stop if this is Windows™ Explorer
        if ($explorerProcesses | ?{$_.Id -match $lastProcessId}) {
            break
        }

        if ($lastProcessId -gt 0) {
            $currentProcess = (gwmi win32_process | ? processid -eq  $lastProcessId)
        
            if ($currentProcess.Name -ne "cmd.exe" -And $currentProcess.Name -ne "powershell.exe") {
                break
            }
          
            try {
                $hwnd = (Get-Process -Id $lastProcessId).MainWindowHandle
            }
            catch {
                # Process no longer active?
                $hwnd = 0
            }

            if ($hwnd -ne 0 -And $hwnd -ne $null) {
                $lastHwnd = $hwnd
            }
            
            $mainProcessId = $lastProcessId
            
        } else {
            break
        }

    }
    until($false)

    return $lastHwnd
}

function Set-ForegroundProcess([int]$Id) {
    
    $hWnd = Get-MainWindowHandle $Id

    if ($hWnd -ne $null) {
        [PInvoke]::SetForegroundWindow($hwnd) | Out-Null
    }
}

function Start-Console {

    param (
        [Parameter(Mandatory = $true)]
        $FileName,
        $Arguments, 
        $ProcessName,
        $IsClearConsole, 
        $WorkingDirectory = $null,
        $IsAutoKill = $false, 
        $KillWaitTimeout = 10000, 
        $ProcessPriority = 'Normal',
        $IsUseSingleConsole = $false
    )

    $Host.UI.RawUI.WindowTitle = "Running: $ProcessName"
    
    if ($IsClearConsole -eq $true) {
        Clear-Host
    }

    # In NET6 we want the CTRL + R to work so we can't redirect the output.
    # The console process will require its own window to work.
    $isRedirectConsoleIO = $IsUseSingleConsole
    
    $consoleProcess = [ProcessHelper]::StartConsoleProcess($FileName, $Arguments, $WorkingDirectory, $isRedirectConsoleIO)

    # Do not kill script on CTRL+C 
    [Console]::TreatControlCAsInput = $true

    [void]$consoleProcess.Start()

    if ($isRedirectConsoleIO -eq $true) 
    {
        $consoleProcess.BeginOutputReadLine()
        $consoleProcess.BeginErrorReadLine()
    }
    else
    {
        Write-Host "Running $ProcessName on a separate window."
    }

    $dpid = $consoleProcess.ID

    Set-ProcessPriorityTree $dpid 'BelowNormal'

    # Listen for CTRL+C key presses and send kill signal to dotnet watch when detected
    while ($consoleProcess.HasExited -eq $false)
    {
        if ([Console]::KeyAvailable)
        {
            $key = [System.Console]::ReadKey($true)

            if (($key.modifiers -bAnd [consolemodifiers]"control") -and ($key.key -eq "C"))
            {
                Write-Warning "Exit command received. Terminating $ProcessName."
                $Host.UI.RawUI.WindowTitle = "Terminating: $ProcessName"

                # Kill console
                Stop-ConsoleTree $dpid

                $hasExited = $consoleProcess.WaitForExit($KillWaitTimeout)

                if ($hasExited -eq $false) {

                    if ($IsAutoKill -eq $true) {
                        $killResult = 0
                    } else {
                        $kill = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Terminate the process forcefully"
                        $noKill = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Wait for the process to exit gracefully"
                        $options = [System.Management.Automation.Host.ChoiceDescription[]]($kill, $noKill)
                        $killResult = $host.ui.PromptForChoice("The $ProcessName process is taking longer than usual to terminate", 'Do you want to forcefully terminate the process now?', $options, 0);
                    }

                    if ($killResult -eq 0) {
                        Stop-ProcessTree $dpid
                        if ($consoleProcess.HasExited -eq $false) {
                            $consoleProcess.Kill()
                        }
                    }

                    if ($consoleProcess.HasExited -eq $false) {
                        $consoleProcess.WaitForExit();
                    }
                }

                $Host.UI.RawUI.WindowTitle = "Terminated: $ProcessName"

                break
            }
            elseif (($key.modifiers -bAnd [consolemodifiers]"control") -and ($key.key -eq "R"))
            {
                Write-Host "Hot reload command received. Sending reload command to $ProcessName."
                Restart-HotReload $dpid
                Clear-ConsoleKeyBuffer
            }
        }
        
        Start-Sleep -Milliseconds 700
    }
}

function Set-WindowTopMostByProcess {
    param (
        [Parameter(Mandatory = $true)]
        $Id
    )
    
    $hWnd = Get-MainWindowHandle $Id
    Set-WindowTopMost $hWnd
}

function Set-WindowTopMost {
    param (
        [Parameter(Mandatory = $true)]
        $WindowHandle
    )
    
    $style = [PInvoke]::GetWindowLong($WindowHandle, $GWL_EXSTYLE)
    [PInvoke]::SetWindowLong($WindowHandle, $GWL_EXSTYLE, ($style -bAnd $WS_EX_TOPMOST))
    [PInvoke]::MakeTopMost($WindowHandle)
}

function Set-WindowNormalByProcess {
    param (
        [Parameter(Mandatory = $true)]
        $Id
    )
    
    $hWnd = Get-MainWindowHandle $Id
    Set-WindowNormal $hWnd
}

function Set-WindowNormal {
    param (
        [Parameter(Mandatory = $true)]
        $WindowHandle
    )
    
    $style = [PInvoke]::GetWindowLong($WindowHandle, $GWL_EXSTYLE)
    [PInvoke]::SetWindowLong($WindowHandle, $GWL_EXSTYLE, ($style -bAnd -bNot($WS_EX_TOPMOST)))
    [PInvoke]::MakeNormal($WindowHandle)
}


function Set-WindowStyleMinimized {
    param (
        [Parameter(Mandatory = $true)]
        $WindowHandle
    )

    $style = [PInvoke]::GetWindowLong($WindowHandle, $GWL_STYLE)
    $style = $style -bAnd -bNot($WS_DLGFRAME -bOr $WS_CAPTION -bOr $WS_MINIMIZE -bOr $WS_MAXIMIZEBOX -bOr $WS_HSCROLL -bOr $WS_VSCROLL)
    Set-WindowStyle $WindowHandle $style
}

function Set-WindowStyleMinimizedByProcess {
    param (
        [Parameter(Mandatory = $true)]
        $Id
    )

    $hWnd = Get-MainWindowHandle $Id
    Set-WindowStyleMinimized $hWnd
}

function Set-WindowStyle {
    param (
        [Parameter(Mandatory = $true)]
        $WindowHandle,

        [Parameter(Mandatory = $true)]
        $Style
    )

    [PInvoke]::SetWindowLong($WindowHandle, $GWL_STYLE, $Style)
    
    # Redraw window
    [PInvoke]::InvalidateRect($WindowHandle, 0, $true)
    [PInvoke]::UpdateWindow($WindowHandle)
    [PInvoke]::SetWindowPos($WindowHandle, 0, 0, 0, 0, 0, ($SWP_FRAMECHANGED -bOr $SWP_NOMOVE -bOr $SWP_NOSIZE -bOr $SWP_NOZORDER))
}

function Set-WindowStyleByProcess {

    param (
        [Parameter(Mandatory = $true)]
        $Id,

        [Parameter(Mandatory = $true)]
        $Style
    )

    $hWnd = Get-MainWindowHandle $Id
    Set-WindowStyle $hWnd $Style
}

function Get-WindowStyle {
    param (
        [Parameter(Mandatory = $true)]
        $WindowHandle
    )

    [PInvoke]::GetWindowLong($WindowHandle, $GWL_STYLE)
}

function Get-WindowStyleByProcess {
    param (
        [Parameter(Mandatory = $true)]
        $Id
    )

    $hWnd = Get-MainWindowHandle $Id
    Get-WindowStyle $hWnd
}

function Clear-ConsoleKeyBuffer {
    while ($Host.UI.RawUI.KeyAvailable) {
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp,IncludeKeyDown") | Out-Null
    }
}

function Get-UserResponse {
    param (
        [Parameter(Mandatory = $true)]
        $Timeout = 5
    )

    # Clear key buffer. Ensures that the 'wait' will not be indefinite.
    Clear-ConsoleKeyBuffer
    
    $secondsRunning = 0;

    while ((-Not $Host.UI.RawUI.KeyAvailable) -And ($secondsRunning -lt $Timeout)) {
        Start-Sleep -Seconds 1
        $secondsRunning++
        Write-Host "." -NoNewline
    }

    Write-Host ""

    if ($Host.ui.RawUI.KeyAvailable) {
        return ($Host.ui.RawUI.ReadKey("IncludeKeyDown,NoEcho")).Character
    }
    
    return ""
}


export-modulemember -function Stop-ProcessTree
export-modulemember -function Set-ForegroundProcess
export-modulemember -function Stop-Console
export-modulemember -function Start-Console
export-modulemember -function Set-ProcessPriority
export-modulemember -function Set-ProcessPriorityTree
export-modulemember -function Get-WindowStyleByProcess
export-modulemember -function Set-WindowStyleByProcess
export-modulemember -function Set-WindowStyleMinimizedByProcess
export-modulemember -function Get-WindowStyle
export-modulemember -function Set-WindowStyle
export-modulemember -function Set-WindowStyleMinimized
export-modulemember -function Set-WindowTopMostByProcess
export-modulemember -function Set-WindowTopMost
export-modulemember -function Set-WindowNormalByProcess
export-modulemember -function Set-WindowNormalMost
export-modulemember -function Clear-ConsoleKeyBuffer
export-modulemember -function Get-UserResponse
export-modulemember -function Restart-HotReload