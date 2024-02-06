#Requires -RunAsAdministrator
## Updated Jan 15 2024
<#
    .SYNOPSIS
        This is the basic script for formatting a USB drive and copying data from an ISO file and additional folder to the drive
#>
function runDiskPart {
    <#
    .SYNOPSIS
        Function to format USB drives based on "Boots with the Fur"
    .DESCRIPTION
        Format
    #>
    $diskPartParam=@(
        "select disk ${usbDiskNumber}",
        "clean",
        "create part primary",
        "active",
        "format fs=${fileSystemType} label=${mriLabel} quick",
        "assign letter=T",
        "exit"
    )
    $diskPartParam | Out-File -FilePath ".\diskpart.txt" -Encoding ascii
    Start-Process diskpart -ArgumentList "/s .\diskpart.txt" -verb runAs -Wait
    Remove-Item -Path ".\diskpart.txt"
}


## Define the drive letter for the USB drive
do {
 $usbDriveLetter = Read-Host -Prompt "Input current USB drive letter"
 if($usbDriveLetter -eq "C") {
    Write-Host "Drive letter cannot be 'C'"
 }
} while($usbDriveLetter -eq "C")
## Define the number of the drive as shown in Disk Management
do{
    $usbDiskNumber = Read-Host -Prompt "Input the disk number as shown in Disk Management or diskpart"
    if ($usbDiskNumber -eq 0) {
        Write-Host "Disk number cannot be 0"
    }
} while($usbDiskNumber -eq 0)
## Define MRI number to label the drive with
$mriNumberLabel = Read-Host -Prompt "Input the number to label the MRI with"
$mriLabel = "MRI_${mriNumberLabel}"

## Get the size of the USB drive
$usbDrive = Get-CimInstance -Query "SELECT * FROM Win32_LogicalDisk WHERE DeviceID='${usbDriveLetter}:'"
$usbDriveSizeGB = [math]::Round($usbDrive.Size / 1GB, 2)

## Define network drive path and letter
$networkDrivePath = "\\10.32.209.242\gsiso"

$files = Get-ChildItem "${networkDrivePath}\MRI_BDE"
$fileChoices = @()

for ($i=0; $i -lt $files.Count; $i++) {
  $fileChoices += [System.Management.Automation.Host.ChoiceDescription]("$($files[$i].Name) &$($i+1) `n")
}

$userChoice = $host.UI.PromptForChoice('Select File', 'Choose a file', $fileChoices, 0)

$isoImagePath = $files[$userChoice].FullName
Write-Host "you chose $isoImagePath"

## Check if ISO is mounted
if(!(Get-DiskImage -ImagePath $isoImagePath).attached) {
    $mountResult = Mount-DiskImage $isoImagePath -PassThru
    $isoDriveLetter = ($mountResult | Get-Volume).DriveLetter
}
else {
    $isoDriveLetter = (Get-DiskImage -ImagePath $isoImagePath | Get-Volume).DriveLetter
}

## Check if Drive is less than 32 GB
if ($usbDriveSizeGB -le 32) {
    $fileSystemType = "FAT32"
    runDiskPart
    $usbDriveLetter = "T"
}
else {
    $fileSystemType = "exFAT"
    runDiskPart
    $usbDriveLetter = "T"
    Write-Output "This prompt will ask you to press 'y' to format as FAT32"
    Start-Process ".\fat32format.exe" -ArgumentList "${usbDriveLetter}" -Wait
    label "${usbDriveLetter}:" $mriLabel
}

robocopy "${isoDriveLetter}:\\" "${usbDriveLetter}:\\" /DCOPY:T /COPY:DAT /E /R:0
robocopy "C:\\!Toolz!" "${usbDriveLetter}:\\!Toolz!" /DCOPY:T /COPY:DAT /E /R:0

Read-Host -Prompt "Press Enter to Exit..."