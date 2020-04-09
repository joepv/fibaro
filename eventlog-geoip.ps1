<#
.Synopsis
   Get GeoIP from failed security event
.DESCRIPTION
   Script to get the country location from a failed security event.
.EXAMPLE
   Set up the correct variables and run the script in your domain.
.OUTPUTS
  An onscreen table.
.NOTES
   Author:         Joep Verhaeg <jverhaeg@insign.it>
   Creation Date:  April 2020
#>

# Variables.
$adfsServer = "SERVER1"
$library    = "C:\Users\Demo\.nuget\packages\maxmind.db\2.6.1\lib\net45\MaxMind.Db.dll"
$database   = "C:\Users\Demo\Downloads\GeoLite2-Country.mmdb"

# Create a table.
$logTable = New-Object System.Data.DataTable
$logTable.Columns.Add((New-Object System.Data.DataColumn TimeCreated,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn UserId,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn NetworkLocation,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn IpAddress,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn ForwardedIpAddress,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn ProxyIpAddress,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn NetworkIpAddress,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn ProxyServer,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn continent,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn country,([string])))
$logTable.Columns.Add((New-Object System.Data.DataColumn registeredCountry,([string])))

# Set time window to get all events from only the past hour.
$startTime = [datetime]::Now.AddHours(-1)
$endTime = [datetime]::Now

# Get the events.
$events = Get-WinEvent -ComputerName $adfsServer -FilterHashtable @{Logname = 'Security'; Id = 1203; StartTime = $startTime; EndTime = $endTime}

# Load the GeoIP library.
Add-Type -Path $library
$reader = [MaxMind.Db.Reader]::new($database)

# Create an index to show a nice progressbar.
$eventIndex = 0

# Loop though all events.
ForEach ($event in $events) {
    $eventXML = [xml]$event.Properties.Value[1]
    $TimeCreated        = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm")
    $UserId             = $eventXML.AuditBase.ContextComponents.Component[0].UserId
    $NetworkLocation    = $eventXML.AuditBase.ContextComponents.Component[3].NetworkLocation
    $IpAddresses        = $eventXML.AuditBase.ContextComponents.Component[3].IpAddress
    $ForwardedIpAddress = $eventXML.AuditBase.ContextComponents.Component[3].ForwardedIpAddress
    $ProxyIpAddress     = $eventXML.AuditBase.ContextComponents.Component[3].ProxyIpAddress
    $NetworkIpAddress   = $eventXML.AuditBase.ContextComponents.Component[3].NetworkIpAddress
    $ProxyServer        = $eventXML.AuditBase.ContextComponents.Component[3].ProxyServer

    # Get the IP address from the failed logon.
    $IpAddress = $IpAddresses.Substring(0, $IpAddresses.IndexOf(","))
    $ip = [System.Net.IPAddress]$IpAddresses.Substring(0, $IpAddresses.IndexOf(","))

    # Feed the IP address to the GeoIP database.
    $oldMethod = ($reader.GetType().GetMethods() |? {$_.Name -eq 'Find'})[0]
    $newMethod = $oldMethod.MakeGenericMethod(@([System.Collections.Generic.Dictionary`2[System.String,System.Object]]))
    $results = $newMethod.Invoke($reader, @($ip, $null))
    $continent = $results.continent.names.en
    $country   = $results.country.names.en
    $registeredCountry =$results.registered_country.names.en

    # Add the data to a new row in the table.
    $row = $logTable.NewRow()
    $row.TimeCreated        = $TimeCreated
    $row.UserId             = $UserId
    $row.NetworkLocation    = $NetworkLocation
    $row.IpAddress          = $IpAddress
    $row.ForwardedIpAddress = $ForwardedIpAddress
    $row.ProxyIpAddress     = $ProxyIpAddress
    $row.NetworkIpAddress   = $NetworkIpAddress
    $row.ProxyServer        = $ProxyServer
    $row.continent          = $continent
    $row.country            = $country
    $row.registeredCountry  = $registeredCountry
    $logTable.Rows.Add($row)

    # Show the nice progressbar.
    $percentComplete = ($eventIndex / $events.Count) * 100
    Write-Progress -Activity 'Parsing Security Event 1203' -Status "Matching Geolocation Data for $IpAddress..." -PercentComplete $percentComplete
    $eventIndex++
}

# Clean up.
$reader.Dispose()
$reader = $null

# Show the output on screen.
$logTable | Format-Table
