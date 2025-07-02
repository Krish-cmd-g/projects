<#
.SYNOPSIS
    Remove unwanted built-in apps, enforce AppLocker restrictions to allow only admins,
    monitor and block app launches by non-admins with popup, and auto-run at startup.

.DESCRIPTION
    This script:
    - Removes unwanted built-in apps and provisioned packages.
    - Imports AppLocker policy allowing only Administrators to run these apps.
    - Monitors process creation to kill blocked apps launched by non-admins and shows a popup.
    - Creates a scheduled task to run itself at system startup with highest privileges.
    - Designed for Windows 11 Pro/Enterprise/Education.

.NOTES
    - Run once as Administrator to set up.
    - Script runs indefinitely to monitor processes.
    - To stop monitoring, terminate the PowerShell process or disable the scheduled task.
#>

# --- 1. Remove unwanted apps function ---
function Remove-AppxPackageByName {
    param (
        [string]$namePattern
    )
    $packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$namePattern*" }
    foreach ($pkg in $packages) {
        try {
            Write-Output "Removing $($pkg.Name)"
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to remove $($pkg.Name): $_"
        }
    }
}

Write-Output "Starting removal of unwanted built-in apps..."

# List of unwanted app name patterns (same as before)
$unwantedApps = @(
    "xbox",
    "zunevideo",
    "solitairecollection",
    "king.com.CandyCrush",
    "mspaint",
    "3dviewer",
    "zunemusic",
    "soundrecorder",
    "skypeapp",
    "yourphone",
    "messaging",
    "people",
    "bingnews",
    "bingweather",
    "getstarted",
    "cortana",
    "mixedrealityportal",
    "windowsalarms",
    "officehub",
    "onenote",
    "maps",
    "feedbackhub",
    "windowscamera",
    "photos"
)

foreach ($app in $unwantedApps) {
    Remove-AppxPackageByName -namePattern $app
}

Write-Output "Removal of unwanted apps completed."

# Remove provisioned packages to prevent reinstall for new users
Write-Output "Removing provisioned packages..."

foreach ($pattern in $unwantedApps) {
    try {
        Write-Output "Removing provisioned packages matching $pattern"
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$pattern*" } | ForEach-Object {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Warning "Failed to remove provisioned package $pattern: $_"
    }
}

Write-Output "Provisioned package removal completed."

# --- 2. Import AppLocker policy ---

# Embedded AppLocker XML policy string
$AppLockerPolicyXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <!-- Allow Xbox for Administrators -->
    <FilePathRule Id="allow_xbox_admin" Name="Allow Xbox for Admins" Description="Allow Xbox app for Administrators" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.XboxApp_*\XboxApp.exe" />
      </Conditions>
    </FilePathRule>
    <!-- Deny Xbox for Everyone else -->
    <FilePathRule Id="deny_xbox_others" Name="Deny Xbox for Others" Description="Deny Xbox app for non-admins" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.XboxApp_*\XboxApp.exe" />
      </Conditions>
    </FilePathRule>

    <!-- Allow Microsoft Store for Administrators -->
    <FilePathRule Id="allow_msstore_admin" Name="Allow Microsoft Store for Admins" Description="Allow Microsoft Store for Administrators" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.WindowsStore_*\WinStore.App.exe" />
      </Conditions>
    </FilePathRule>
    <!-- Deny Microsoft Store for Everyone else -->
    <FilePathRule Id="deny_msstore_others" Name="Deny Microsoft Store for Others" Description="Deny Microsoft Store for non-admins" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.WindowsStore_*\WinStore.App.exe" />
      </Conditions>
    </FilePathRule>

    <!-- Allow Movies & TV for Administrators -->
    <FilePathRule Id="allow_movies_admin" Name="Allow Movies & TV for Admins" Description="Allow Movies & TV for Administrators" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.ZuneVideo_*\Video.UI.exe" />
      </Conditions>
    </FilePathRule>
    <!-- Deny Movies & TV for Everyone else -->
    <FilePathRule Id="deny_movies_others" Name="Deny Movies & TV for Others" Description="Deny Movies & TV for non-admins" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.ZuneVideo_*\Video.UI.exe" />
      </Conditions>
    </FilePathRule>

    <!-- Allow Groove Music for Administrators -->
    <FilePathRule Id="allow_groove_admin" Name="Allow Groove Music for Admins" Description="Allow Groove Music for Administrators" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.ZuneMusic_*\Music.UI.exe" />
      </Conditions>
    </FilePathRule>
    <!-- Deny Groove Music for Everyone else -->
    <FilePathRule Id="deny_groove_others" Name="Deny Groove Music for Others" Description="Deny Groove Music for non-admins" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.ZuneMusic_*\Music.UI.exe" />
      </Conditions>
    </FilePathRule>

    <!-- Allow Paint 3D for Administrators -->
    <FilePathRule Id="allow_paint3d_admin" Name="Allow Paint 3D for Admins" Description="Allow Paint 3D for Administrators" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.MSPaint_*\PaintStudio.View.exe" />
      </Conditions>
    </FilePathRule>
    <!-- Deny Paint 3D for Everyone else -->
    <FilePathRule Id="deny_paint3d_others" Name="Deny Paint 3D for Others" Description="Deny Paint 3D for non-admins" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.MSPaint_*\PaintStudio.View.exe" />
      </Conditions>
    </FilePathRule>

    <!-- Allow 3D Viewer for Administrators -->
    <FilePathRule Id="allow_3dviewer_admin" Name="Allow 3D Viewer for Admins" Description="Allow 3D Viewer for Administrators" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.Microsoft3DViewer_*\3DViewer.exe" />
      </Conditions>
    </FilePathRule>
    <!-- Deny 3D Viewer for Everyone else -->
    <FilePathRule Id="deny_3dviewer_others" Name="Deny 3D Viewer for Others" Description="Deny 3D Viewer for non-admins" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.Microsoft3DViewer_*\3DViewer.exe" />
      </Conditions>
    </FilePathRule>

    <!-- Allow Voice Recorder for Administrators -->
    <FilePathRule Id="allow_voicerecorder_admin" Name="Allow Voice Recorder for Admins" Description="Allow Voice Recorder for Administrators" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.WindowsSoundRecorder_*\SoundRecorder.exe" />
      </Conditions>
    </FilePathRule>
    <!-- Deny Voice Recorder for Everyone else -->
    <FilePathRule Id="deny_voicerecorder_others" Name="Deny Voice Recorder for Others" Description="Deny Voice Recorder for non-admins" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.WindowsSoundRecorder_*\SoundRecorder.exe" />
      </Conditions>
    </FilePathRule>

    <!-- Allow Photos for Administrators -->
    <FilePathRule Id="allow_photos_admin" Name="Allow Photos for Admins" Description="Allow Photos for Administrators" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.Windows.Photos_*\PhotosApp.exe" />
      </Conditions>
    </FilePathRule>
    <!-- Deny Photos for Everyone else -->
    <FilePathRule Id="deny_photos_others" Name="Deny Photos for Others" Description="Deny Photos for non-admins" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.Windows.Photos_*\PhotosApp.exe" />
      </Conditions>
    </FilePathRule>

    <!-- Allow Camera for Administrators -->
    <FilePathRule Id="allow_camera_admin" Name="Allow Camera for Admins" Description="Allow Camera for Administrators" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.WindowsCamera_*\WindowsCamera.exe" />
      </Conditions>
    </FilePathRule>
    <!-- Deny Camera for Everyone else -->
    <FilePathRule Id="deny_camera_others" Name="Deny Camera for Others" Description="Deny Camera for non-admins" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%ProgramFiles%\WindowsApps\Microsoft.WindowsCamera_*\WindowsCamera.exe" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
  <RuleCollection Type="Dll" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Msi" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Script" EnforcementMode="NotConfigured" />
</AppLockerPolicy>
"@

# Save AppLocker policy XML
$policyPath = "C:\Scripts\AppLockerPolicy.xml"
if (-not (Test-Path "C:\Scripts")) {
    New-Item -Path "C:\" -Name "Scripts" -ItemType Directory | Out-Null
}
$AppLockerPolicyXml | Out-File -FilePath $policyPath -Encoding UTF8

# Import AppLocker policy
try {
    Import-AppLockerPolicy -XMLPolicy $policyPath -Merge
    Write-Output "AppLocker policy imported successfully."
} catch {
    Write-Warning "Failed to import AppLocker policy: $_"
}

# --- 3. Monitor and block app launches by non-admins ---

function Show-BlockedPopup {
    param (
        [string]$AppName
    )
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("Access to $AppName is restricted. Please contact your administrator.", "Access Denied", 'OK', 'Warning')
}

# List of blocked app executable names to monitor
$blockedApps = @(
    "XboxApp.exe",
    "WinStore.App.exe",
    "Video.UI.exe",
    "Music.UI.exe",
    "PaintStudio.View.exe",
    "3DViewer.exe",
    "SoundRecorder.exe",
    "PhotosApp.exe",
    "WindowsCamera.exe"
)

# Register WMI event to monitor process creation
Register-WmiEvent -Query "SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Process'" -SourceIdentifier "ProcessMonitor" -Action {
    $process = $Event.SourceEventArgs.NewEvent.TargetInstance
    if ($blockedApps -contains $process.Name) {
        # Check if current user is NOT an administrator
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            # Kill the process
            try {
                Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
            } catch {}

            # Show popup
            Show-BlockedPopup -AppName $process.Name
        }
    }
}

Write-Output "Monitoring started. Press Ctrl+C to stop."

# --- 4. Create Scheduled Task to run this script at startup ---

$taskName = "EnforceAppRestrictions"
$taskPath = "\"

# Check if task exists
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $taskExists) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings
    Write-Output "Scheduled task '$taskName' created to run this script at startup."
} else {
    Write-Output "Scheduled task '$taskName' already exists."
}

# --- 5. Keep script running to monitor processes ---
while ($true) {
    Start-Sleep -Seconds 10
}
