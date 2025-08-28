# PowerShell script to ping store devices and log to a single CSV file.
# Program made by Xion
# This code belongs to CGI INC/Circlek Incorporated

# Path to your CSV
$csvBaseName = "StoreDevices"
$csvPath = Get-ChildItem -Path "." -Filter "$csvBaseName*.csv" | Select-Object -First 1 | ForEach-Object { $_.FullName }

if (-not $csvPath) {
    Write-Host "ERROR: CSV file not found in current directory." -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit"
    exit
}

# Import CSV and normalize headers
$dataRaw = Import-Csv -Path $csvPath
$data = foreach ($row in $dataRaw) {
    $newRow = @{}
    foreach ($col in $row.PSObject.Properties) {
        $cleanName = $col.Name -replace ' ', ''
        $newRow[$cleanName] = $col.Value
    }
    [PSCustomObject]$newRow
}

# Prepare the output CSV
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logDir = ".\Logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$globalCsvPath = Join-Path $logDir "PingResults_${timestamp}.csv"

# Create CSV header (changed order)
"IP,Store,Device,Status,ResponseTime (ms)" | Out-File -FilePath $globalCsvPath -Encoding UTF8

# Loop for user input
while ($true) {
    $storeNumbersInput = Read-Host "Enter store numbers (e.g., 2652001, 2652002) or 'exit' to quit"

    if ($storeNumbersInput -eq 'exit') {
        Write-Host "Exiting script..." -ForegroundColor Cyan
        break
    }

    $storeNumbers = $storeNumbersInput.Split(',') | ForEach-Object { $_.Trim() }

    foreach ($storeNumber in $storeNumbers) {
        $storeRow = $data | Where-Object { $_.Store -eq $storeNumber }

        if (-not $storeRow) {
            Write-Host "ERROR: Store $storeNumber not found in CSV." -ForegroundColor Red
            continue
        }

        # Banner for clarity
        Write-Host "`n======================" -ForegroundColor Blue
        Write-Host "Pinging Store $storeNumber..." -ForegroundColor Blue
        Write-Host "======================`n" -ForegroundColor Blue

        $devices = $storeRow.PSObject.Properties | Where-Object { $_.Name -ne "Store" }
        $devicesSorted = $devices | Sort-Object {
            if ($_.Value -match "\d+\.\d+\.\d+\.(\d+)$") { [int]$matches[1] } else { 999 }
        }

        foreach ($device in $devicesSorted) {
            $deviceName = $device.Name
            $ip = $device.Value.Trim()

            if (-not $ip) {
                Write-Host "${deviceName}: No IP, skipping..." -ForegroundColor Yellow
                "$ip,$storeNumber,$deviceName,Skipped (no IP)," | Out-File -FilePath $globalCsvPath -Append
                continue
            }

            Write-Host "Pinging ${deviceName} (${ip}) ..." -NoNewline
            try {
                $ping = Test-Connection -ComputerName $ip -Count 1 -ErrorAction Stop
                $time = $ping.ResponseTime
                Write-Host " Success (${time} ms)" -ForegroundColor Green
                "$ip,$storeNumber,$deviceName,Success,$time" | Out-File -FilePath $globalCsvPath -Append
            } catch {
                Write-Host " Failed" -ForegroundColor Red
                "$ip,$storeNumber,$deviceName,Failed," | Out-File -FilePath $globalCsvPath -Append
            }
        }

        Write-Host "Logged results for store $storeNumber." -ForegroundColor Cyan
    }

    Write-Host "------------------------"
}

Write-Host "All results saved to: $globalCsvPath" -ForegroundColor Cyan
Write-Host "Script has ended." -ForegroundColor Cyan
