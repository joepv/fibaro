<#
.Synopsis
   Set Microsoft Windows 10 light or dark mode automatically based on the sunsise/sunset times.
.DESCRIPTION
   Automatically set the Windows 10 light or dark mode based on the sunsise/sunset times retrieved
   from Internet based on the set latitude and longitude.

   Set the variables for your settings:
   - Latitude and Longitude of where you live (https://www.latlong.net/)
   - LightTaskbar if you want full light mode, else only the applications are light at day.
   - RegistryPath if you want to name the registry key for caching to something else.
.EXAMPLE
   Set up the correct variables and run the script every 5 minutes with task scheduler.
.OUTPUTS
  Some logging.
.NOTES
   Author:         Joep Verhaeg <info@joepverhaeg.nl>
   Creation Date:  April 2020
#>

# Venlo, Limburg
$latitude     = '51.373329'
$longitude    = '6.173340'
$lightTaskbar = 1
$registryPath = 'HKCU:\Software\Joep'

if (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath
    New-ItemProperty -Path $registryPath -Name 'LastCheck' -Value ''
    New-ItemProperty -Path $registryPath -Name 'Sunrise' -Value ''
    New-ItemProperty -Path $registryPath -Name 'Sunset' -Value ''
}
else {
    $lastCheck = Get-Date (Get-ItemPropertyValue -Path $registryPath -Name 'LastCheck')
    $sunrise = Get-Date (Get-ItemPropertyValue -Path $registryPath -Name 'Sunrise')
    $sunset  = Get-Date (Get-ItemPropertyValue -Path $registryPath -Name 'Sunset')
}

$now = Get-Date
if ($now.Date -ne $lastCheck.Date) {
    $daylight = (Invoke-RestMethod "https://api.sunrise-sunset.org/json?lat=$latitude&lng=$longitude").results

    $sunrise = (Get-Date $daylight.Sunrise).ToLocalTime()
    $sunset  = (Get-Date $daylight.Sunset).ToLocalTime()

    Set-ItemProperty -Path $registryPath -Name 'LastCheck' -Value $now.ToString('f')
    Set-ItemProperty -Path $registryPath -Name 'Sunrise' -Value $sunrise.ToString('HH:mm')
    Set-ItemProperty -Path $registryPath -Name 'Sunset' -Value $sunset.ToString('HH:mm')
    Write-Host 'Refresh sunrise/sunset information...'
}
else {
    Write-Output 'Using cached sunrise/sunset information...'
}

if ($sunrise.TimeOfDay -le $now.TimeOfDay -and $sunset.TimeOfDay -ge $now.TimeOfDay) {
    # day light
    Write-Host "Setting light mode..."
    $systemUsesLightTheme = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme'
    if ($systemUsesLightTheme -eq 0) {
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Value $lightTaskbar
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -Value 1
    }
    else {
        Write-Host "Light theme already set!"
    }
}
else {
    # evening light
    Write-Host "Setting dark mode..."
    $systemUsesLightTheme = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme'
    if ($systemUsesLightTheme -eq 1) {
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Value 0
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -Value 0
    }
    else {
        Write-Host "Dark theme already set!"
    }
}