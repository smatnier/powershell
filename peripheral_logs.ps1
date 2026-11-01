<#
.SYNOPSIS
General Peripheral Troubleshooting Collection

.DESCRIPTION
Collects event logs and hardware information useful for troubleshooting:
- Docks
- Printers
- USB devices
- Monitors
- Other Plug and Play peripherals
#>

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFolder = "C:\Temp\PeripheralSupport_$TimeStamp"

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

Write-Host "Collecting support data..."

###########################################################
# Event Logs
###########################################################

$Logs = @(
    "System",
    "Application",
    "Microsoft-Windows-DriverFrameworks-UserMode/Operational",
    "Microsoft-Windows-PrintService/Admin"
)

foreach ($Log in $Logs)
{
    try
    {
        $SafeName = $Log.Replace("/", "_")
        $OutputFile = Join-Path $OutputFolder "$SafeName.txt"

        Get-WinEvent -LogName $Log -MaxEvents 300 |
        Select-Object `
            TimeCreated,
            Id,
            LevelDisplayName,
            ProviderName,
            Message |
        Format-List |
        Out-File $OutputFile -Width 4000
    }
    catch
    {
        "Unable to query $Log" |
        Out-File (Join-Path $OutputFolder "$SafeName-error.txt")
    }
}

###########################################################
# PnP Devices
###########################################################

Get-PnpDevice |
Sort-Object Class, FriendlyName |
Format-Table Status, Class, FriendlyName, InstanceId -AutoSize |
Out-File (Join-Path $OutputFolder "PnPDevices.txt") -Width 4000

###########################################################
# Problem Devices
###########################################################

Get-PnpDevice |
Where-Object { $_.Status -ne 'OK' } |
Format-Table Status, Class, FriendlyName, InstanceId -AutoSize |
Out-File (Join-Path $OutputFolder "ProblemDevices.txt") -Width 4000

###########################################################
# USB Devices
###########################################################

Get-PnpDevice |
Where-Object {
    $_.Class -match "USB"
} |
Format-Table Status, Class, FriendlyName, InstanceId -AutoSize |
Out-File (Join-Path $OutputFolder "USBDevices.txt") -Width 4000

###########################################################
# Printers
###########################################################

try
{
    Get-Printer |
    Format-List * |
    Out-File (Join-Path $OutputFolder "Printers.txt") -Width 4000

    Get-PrinterDriver |
    Format-List * |
    Out-File (Join-Path $OutputFolder "PrinterDrivers.txt") -Width 4000
}
catch
{
    "Printer information unavailable." |
    Out-File (Join-Path $OutputFolder "PrinterError.txt")
}

###########################################################
# Installed Drivers
###########################################################

Get-CimInstance Win32_PnPSignedDriver |
Select-Object `
    DeviceName,
    DriverVersion,
    DriverProviderName,
    DriverDate |
Sort-Object DeviceName |
Out-File (Join-Path $OutputFolder "InstalledDrivers.txt") -Width 4000

###########################################################
# Devices With Driver Problems
###########################################################

pnputil /enum-devices /problem > `
    (Join-Path $OutputFolder "DevicesWithProblems.txt")

###########################################################
# Display Adapters
###########################################################

Get-PnpDevice -Class Display |
Format-Table Status, FriendlyName, InstanceId -AutoSize |
Out-File (Join-Path $OutputFolder "DisplayDevices.txt") -Width 4000

###########################################################
# Network Devices
###########################################################

Get-NetAdapter |
Format-Table Name, InterfaceDescription, Status, LinkSpeed -AutoSize |
Out-File (Join-Path $OutputFolder "NetworkAdapters.txt") -Width 4000

###########################################################
# System Information
###########################################################

systeminfo > (Join-Path $OutputFolder "SystemInfo.txt")

###########################################################
# Zip Results
###########################################################

$ZipFile = "$OutputFolder.zip"

Compress-Archive `
    -Path "$OutputFolder\*" `
    -DestinationPath $ZipFile `
    -Force

Write-Host ""
Write-Host "Collection Complete"
Write-Host "Results: $ZipFile"
