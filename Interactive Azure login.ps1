# Interactive Azure login
Connect-AzAccount -Tenant "1cdb53f5-bf60-4623-b11c-aecd0c81bc42" -UseDeviceAuthentication
 
# Set context to specified tenant (optional but good practice)
Set-AzContext -TenantId "1cdb53f5-bf60-4623-b11c-aecd0c81bc42"
Write-Host "✅ Successfully logged in and set context to tenant: 1cdb53f5-bf60-4623-b11c-aecd0c81bc42"
 
# Import VM list from external file
. "C:\Temp\CPU&Memory\vm-list.ps1"
 
# Date Range
$startTime = Get-Date "2025-03-01T00:00:00Z"
$endTime = Get-Date "2025-03-30T23:59:59Z"
 
$cpuMemoryData = @()
 
foreach ($vm in $vmList) {
    $resourceId = $vm.ResourceId
    $totalMemoryBytes = $vm.MemorySize
 
    # CPU Average
    $cpuAvgMetric = Get-AzMetric -ResourceId $resourceId `
        -TimeGrain 00:05:00 `
        -MetricName "Percentage CPU" `
        -Aggregation Average `
        -StartTime $startTime `
        -EndTime $endTime
 
    $cpuAvgData = $cpuAvgMetric.Data | Where-Object { $_.Average -ne $null }
    $avgCpu = ($cpuAvgData | Select-Object -ExpandProperty Average | Measure-Object -Average).Average
 
    # CPU Maximum
    $cpuMaxMetric = Get-AzMetric -ResourceId $resourceId `
        -TimeGrain 00:05:00 `
        -MetricName "Percentage CPU" `
        -Aggregation Maximum `
        -StartTime $startTime `
        -EndTime $endTime
 
    $cpuMaxData = $cpuMaxMetric.Data | Where-Object { $_.Maximum -ne $null }
    $maxCpu = ($cpuMaxData | Select-Object -ExpandProperty Maximum | Measure-Object -Maximum).Maximum
 
    if ($maxCpu -eq $null) {
        $maxCpu = 0
    }
 
    # Memory Metrics
    $memMetrics = Get-AzMetric -ResourceId $resourceId `
        -TimeGrain 00:05:00 `
        -MetricName "Available Memory Bytes" `
        -Aggregation Average `
        -StartTime $startTime `
        -EndTime $endTime
 
    $memUsedPercent = $memMetrics.Data | Where-Object { $_.Average -ne $null } | ForEach-Object {
        $available = $_.Average
        if ($available -ne $null) {
            $usedPct = ((($totalMemoryBytes - $available) / $totalMemoryBytes) * 100)
            [math]::Round($usedPct, 2)
        }
    }
 
    $avgMemUsedPct = ($memUsedPercent | Measure-Object -Average).Average
    $maxMemUsedPct = ($memUsedPercent | Measure-Object -Maximum).Maximum
    $minMemUsedPct = ($memUsedPercent | Measure-Object -Minimum).Minimum
 
    # Collect data for export
    $cpuMemoryData += [PSCustomObject]@{
        VMName      = $vm.VMName
        AvgCpu      = [math]::Round($avgCpu, 2)
        MaxCpu      = [math]::Round($maxCpu, 2)
        AvgMemUsed  = [math]::Round($avgMemUsedPct, 2)
        MaxMemUsed  = [math]::Round($maxMemUsedPct, 2)
        MinMemUsed  = [math]::Round($minMemUsedPct, 2)
    }
}
 
# Define the export path (set to C:\Temp)
$exportPath = "C:\Temp\VM_Metrics_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').xlsx"
 
# Export data to Excel
$cpuMemoryData | Export-Excel -Path $exportPath -AutoSize -WorksheetName "VM_Metrics"
 
Write-Host "Data exported to: $exportPath"