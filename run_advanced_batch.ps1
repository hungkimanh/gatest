# CVRP Solver Advanced Batch Testing Script (PowerShell)
# Usage: .\run_advanced_batch.ps1 [OPTIONS]

param(
    [string[]]$Instances = @("CMT1", "CMT2", "CMT3", "CMT4", "CMT5"),
    [int]$Generations = 1000,
    [int]$Population = 500,
    [int]$Runs = 5,
    [string]$OutputDir = "",
    [switch]$Excel = $false,
    [switch]$Help = $false
)

# Function to display help
function Show-Help {
    Write-Host "🚛 CVRP Solver Advanced Batch Testing Script (PowerShell)" -ForegroundColor Blue
    Write-Host "=========================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Usage: .\run_advanced_batch.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -Instances      Array of VRP instances (default: CMT1,CMT2,CMT3,CMT4,CMT5)"
    Write-Host "  -Generations    Number of generations (default: 1000)"
    Write-Host "  -Population     Population size (default: 500)"
    Write-Host "  -Runs           Number of runs per instance (default: 5)"
    Write-Host "  -OutputDir      Output directory (default: auto-generated)"
    Write-Host "  -Excel          Generate Excel-compatible output"
    Write-Host "  -Help           Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run_advanced_batch.ps1 -Generations 2000 -Population 800 -Runs 10"
    Write-Host "  .\run_advanced_batch.ps1 -Instances @('CMT1','CMT4') -Runs 20 -Excel"
    Write-Host "  .\run_advanced_batch.ps1 -Instances @('CMT1','CMT2') -Generations 1500"
    Write-Host ""
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

# Validation
if ($Generations -le 0) {
    Write-Host "❌ Error: Generations must be positive" -ForegroundColor Red
    exit 1
}

if ($Population -le 0) {
    Write-Host "❌ Error: Population size must be positive" -ForegroundColor Red
    exit 1
}

if ($Runs -le 0) {
    Write-Host "❌ Error: Number of runs must be positive" -ForegroundColor Red
    exit 1
}

# Set output directory if not specified
if ([string]::IsNullOrEmpty($OutputDir)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = "cvrp_results_$timestamp"
}

# Display configuration
Write-Host "🚛 CVRP SOLVER ADVANCED BATCH TESTING" -ForegroundColor Blue
Write-Host "====================================="
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Instances: $($Instances -join ', ')"
Write-Host "  Generations: $Generations"
Write-Host "  Population: $Population"
Write-Host "  Runs per instance: $Runs"
Write-Host "  Results directory: $OutputDir"
Write-Host "  Excel output: $Excel"
Write-Host ""

# Create results directory
try {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "✅ Created results directory: $OutputDir" -ForegroundColor Green
} catch {
    Write-Host "❌ Error creating results directory: $_" -ForegroundColor Red
    exit 1
}

# Compile the solver
Write-Host "🔨 Compiling CVRP Solver..." -ForegroundColor Yellow

$cppFile = $null
$currentDir = Get-Location

if (Test-Path "ga8.cpp") {
    $cppFile = "ga8.cpp"
} elseif (Test-Path "gatest\ga8.cpp") {
    Set-Location "gatest"
    $cppFile = "ga8.cpp"
} else {
    Write-Host "❌ Error: ga8.cpp not found" -ForegroundColor Red
    exit 1
}

try {
    $compileResult = & g++ -std=c++17 -O3 -o ga8.exe $cppFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Compilation failed!" -ForegroundColor Red
        Write-Host $compileResult
        exit 1
    }
    Write-Host "✅ Compilation successful!" -ForegroundColor Green
} catch {
    Write-Host "❌ Compilation error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Initialize consolidated results file
$consolidatedCsv = Join-Path $currentDir "$OutputDir\consolidated_results.csv"
"Instance,Total_Vehicles,Population_Size,Max_Generations,Best_Cost,Optimal_Cost,GAP_Percent,Execution_Time_Seconds,Number_of_Runs" | Out-File -FilePath $consolidatedCsv -Encoding UTF8

# Function to run solver for specific instance
function Invoke-InstanceRun {
    param(
        [string]$Instance,
        [int]$Gens,
        [int]$Pop,
        [int]$RunCount
    )
    
    # Determine VRP file path
    $vrpFile = $null
    if (Test-Path "..\$Instance.vrp") {
        $vrpFile = "..\$Instance.vrp"
    } elseif (Test-Path "$Instance.vrp") {
        $vrpFile = "$Instance.vrp"
    } else {
        Write-Host "  ❌ Error: $Instance.vrp not found" -ForegroundColor Red
        return $false
    }
    
    $instanceDir = Join-Path $currentDir "$OutputDir\$Instance"
    
    Write-Host "📊 Processing $Instance ($RunCount runs)..." -ForegroundColor Magenta
    
    # Create instance directory
    try {
        New-Item -ItemType Directory -Path $instanceDir -Force | Out-Null
    } catch {
        Write-Host "  ❌ Error creating instance directory: $_" -ForegroundColor Red
        return $false
    }
    
    Write-Host "  📂 Running solver with parameters:"
    Write-Host "     - VRP file: $vrpFile"
    Write-Host "     - Generations: $Gens"
    Write-Host "     - Population: $Pop"
    Write-Host "     - Runs: $RunCount"
    
    $startTime = Get-Date
    
    # Run solver with timeout (1 hour = 3600 seconds)
    try {
        $outputFile = Join-Path $instanceDir "output.log"
        $process = Start-Process -FilePath ".\ga8.exe" -ArgumentList $vrpFile, $Gens, $Pop, $RunCount -RedirectStandardOutput $outputFile -RedirectStandardError $outputFile -NoNewWindow -PassThru
        
        if (-not $process.WaitForExit(3600000)) { # 1 hour timeout in milliseconds
            $process.Kill()
            Write-Host "  ❌ Timeout after 1 hour" -ForegroundColor Red
            return $false
        }
        
        $exitCode = $process.ExitCode
    } catch {
        Write-Host "  ❌ Error running solver: $_" -ForegroundColor Red
        return $false
    }
    
    $endTime = Get-Date
    $runtime = [math]::Round(($endTime - $startTime).TotalSeconds, 0)
    
    if ($exitCode -eq 0) {
        Write-Host "  ✅ Completed successfully in ${runtime}s" -ForegroundColor Green
        
        # Check for results file
        if (Test-Path "ga_results.csv") {
            # Copy results to instance directory
            Copy-Item "ga_results.csv" $instanceDir -Force
            
            # Parse results and append to consolidated CSV
            $results = Import-Csv "ga_results.csv"
            foreach ($result in $results) {
                "$($result.Instance),$($result.Total_Vehicles),$($result.Population_Size),$($result.Max_Generations),$($result.Best_Cost),$($result.Optimal_Cost),$($result.GAP_Percent),$runtime,$RunCount" | Out-File -FilePath $consolidatedCsv -Append -Encoding UTF8
            }
            
            # Display key results
            foreach ($result in $results) {
                Write-Host "  📈 Results: Cost=$($result.Best_Cost), Vehicles=$($result.Total_Vehicles)" -ForegroundColor Green
                if ($result.GAP_Percent -ne "-1.00" -and ![string]::IsNullOrEmpty($result.GAP_Percent)) {
                    Write-Host "     GAP=$($result.GAP_Percent)%, Optimal=$($result.Optimal_Cost)" -ForegroundColor Green
                } else {
                    Write-Host "     GAP=N/A (optimal unknown)" -ForegroundColor Green
                }
            }
            
            # Generate Excel format if requested
            if ($Excel) {
                $excelFile = Join-Path $instanceDir "results_excel.tsv"
                (Get-Content (Join-Path $instanceDir "ga_results.csv")) -replace ',', "`t" | Out-File -FilePath $excelFile -Encoding UTF8
                Write-Host "  📊 Excel format created: results_excel.tsv" -ForegroundColor Green
            }
            
            # Clean up
            Remove-Item "ga_results.csv" -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "  ⚠️  Warning: ga_results.csv not found" -ForegroundColor Yellow
        }
        
        # Create instance summary
        New-InstanceSummary -Instance $Instance -InstanceDir $instanceDir -Runtime $runtime -RunCount $RunCount
        return $true
    } else {
        Write-Host "  ❌ Failed with exit code $exitCode" -ForegroundColor Red
        Write-Host "  📄 Check detailed log: $(Join-Path $instanceDir 'output.log')" -ForegroundColor Yellow
        return $false
    }
}

# Function to create detailed instance summary
function New-InstanceSummary {
    param(
        [string]$Instance,
        [string]$InstanceDir,
        [int]$Runtime,
        [int]$RunCount
    )
    
    $resultsFile = Join-Path $InstanceDir "ga_results.csv"
    if (Test-Path $resultsFile) {
        $results = Import-Csv $resultsFile
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Create markdown summary
        $summaryFile = Join-Path $InstanceDir "summary_report.md"
        $markdownContent = @"
# CVRP Solver Results - $Instance

## Test Configuration
- **Instance**: $Instance
- **Generations**: $Generations
- **Population Size**: $Population
- **Number of Runs**: $RunCount
- **Execution Time**: $Runtime seconds
- **Timestamp**: $timestamp

## Results Summary
``````
$(Get-Content $resultsFile | Out-String)
``````

## Detailed Analysis
"@

        foreach ($result in $results) {
            $markdownContent += @"

### Performance Metrics
- **Best Cost Found**: $($result.Best_Cost)
- **Optimal Cost (from file)**: $($result.Optimal_Cost)
"@
            
            if ($result.GAP_Percent -ne "-1.00" -and ![string]::IsNullOrEmpty($result.GAP_Percent)) {
                $gap = [double]$result.GAP_Percent
                $markdownContent += "- **GAP from Optimal**: $($result.GAP_Percent)%`n"
                
                if ($gap -lt 5.0) {
                    $markdownContent += "  - 🎯 **Excellent** performance (< 5% gap)`n"
                } elseif ($gap -lt 10.0) {
                    $markdownContent += "  - ✅ **Good** performance (< 10% gap)`n"
                } else {
                    $markdownContent += "  - ⚠️ **Needs improvement** (> 10% gap)`n"
                }
            } else {
                $markdownContent += "- **GAP from Optimal**: Unknown (optimal cost not available)`n"
            }
            
            $markdownContent += @"
- **Vehicles Used**: $($result.Total_Vehicles)
- **Population Size**: $($result.Population_Size)
- **Execution Time**: ${Runtime}s
"@
        }
        
        # Add execution log
        $logFile = Join-Path $InstanceDir "output.log"
        if (Test-Path $logFile) {
            $logLines = Get-Content $logFile | Select-Object -Last 30
            $markdownContent += @"

## Execution Log (Last 30 lines)
``````
$($logLines -join "`n")
``````
"@
        }
        
        $markdownContent | Out-File -FilePath $summaryFile -Encoding UTF8
        
        # Create CSV summary
        $csvSummaryFile = Join-Path $InstanceDir "instance_summary.csv"
        $csvContent = @"
Metric,Value
Instance,$Instance
Best_Cost,$($results[0].Best_Cost)
Optimal_Cost,$($results[0].Optimal_Cost)
GAP_Percent,$($results[0].GAP_Percent)
Vehicles_Used,$($results[0].Total_Vehicles)
Population_Size,$Population
Generations,$Generations
Runs,$RunCount
Execution_Time_Seconds,$Runtime
"@
        $csvContent | Out-File -FilePath $csvSummaryFile -Encoding UTF8
    }
}

# Main execution
Write-Host "🏃 Starting advanced batch execution..." -ForegroundColor Blue
Write-Host "========================================"

$totalInstances = $Instances.Length
$current = 0
$successfulRuns = 0

foreach ($instance in $Instances) {
    $current++
    Write-Host "[$current/$totalInstances] Processing $instance" -ForegroundColor Blue
    
    if (Invoke-InstanceRun -Instance $instance -Gens $Generations -Pop $Population -RunCount $Runs) {
        $successfulRuns++
    }
    Write-Host ""
}

# Generate comprehensive final report
Set-Location $currentDir
Write-Host "📈 Generating comprehensive consolidated report..." -ForegroundColor Yellow

$batchSummaryFile = Join-Path $OutputDir "batch_summary.md"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$successRate = [math]::Round(($successfulRuns * 100.0 / $totalInstances), 1)

$summaryContent = @"
# CVRP Advanced Batch Testing Results

## Executive Summary
- **Test Date**: $timestamp
- **Total Instances Tested**: $totalInstances
- **Successfully Completed**: $successfulRuns
- **Success Rate**: $successRate%

## Test Configuration
- **Instances**: $($Instances -join ', ')
- **Generations per Run**: $Generations
- **Population Size**: $Population
- **Runs per Instance**: $Runs
- **Total Expected Runs**: $($totalInstances * $Runs)

## Results Overview
"@

# Process consolidated results if available
if (Test-Path $consolidatedCsv) {
    $consolidatedResults = Import-Csv $consolidatedCsv -ErrorAction SilentlyContinue
    
    if ($consolidatedResults -and $consolidatedResults.Count -gt 0) {
        $summaryContent += @"

### Detailed Results Table
``````
$(Get-Content $consolidatedCsv | Out-String)
``````
"@
        
        # Generate Excel format if requested
        if ($Excel) {
            $excelFile = Join-Path $OutputDir "consolidated_results_excel.tsv"
            (Get-Content $consolidatedCsv) -replace ',', "`t" | Out-File -FilePath $excelFile -Encoding UTF8
            Write-Host "📊 Excel format consolidated results created" -ForegroundColor Green
        }
        
        # Calculate statistics
        $actualRuns = $consolidatedResults.Count
        $validGaps = $consolidatedResults | Where-Object { $_.GAP_Percent -ne "-1.00" -and ![string]::IsNullOrEmpty($_.GAP_Percent) -and [double]$_.GAP_Percent -gt -999 }
        
        if ($validGaps) {
            $avgGap = [math]::Round(($validGaps | Measure-Object -Property GAP_Percent -Average).Average, 2)
            $bestGap = [math]::Round(($validGaps | Measure-Object -Property GAP_Percent -Minimum).Minimum, 2)
        } else {
            $avgGap = "N/A"
            $bestGap = "N/A"
        }
        
        $totalTime = ($consolidatedResults | Measure-Object -Property Execution_Time_Seconds -Sum).Sum
        $totalMinutes = [math]::Round($totalTime / 60.0, 1)
        
        $summaryContent += @"

### Performance Statistics
- **Actual Completed Runs**: $actualRuns
- **Average GAP from Optimal**: $avgGap%
- **Best GAP Achieved**: $bestGap%
- **Total Execution Time**: ${totalTime}s ($totalMinutes minutes)
"@
        
        if ($actualRuns -gt 0) {
            $avgTime = [math]::Round($totalTime / $actualRuns, 1)
            $summaryContent += "- **Average Time per Run**: ${avgTime}s`n"
        }
        
        # Performance ranking
        if ($validGaps) {
            $summaryContent += @"

### Instance Performance Ranking (by GAP)
"@
            $rankedResults = $validGaps | Sort-Object { [double]$_.GAP_Percent }
            $rank = 1
            foreach ($result in $rankedResults) {
                $summaryContent += "$rank. **$($result.Instance)**: $($result.GAP_Percent)% GAP (Cost: $($result.Best_Cost))`n"
                $rank++
            }
        }
    }
}

$summaryContent | Out-File -FilePath $batchSummaryFile -Encoding UTF8

# Final summary display
Write-Host ""
Write-Host "🎉 ADVANCED BATCH TESTING COMPLETED!" -ForegroundColor Green
Write-Host "========================================"
Write-Host "📁 Results Directory: $OutputDir" -ForegroundColor Yellow
Write-Host "📊 Generated Files:" -ForegroundColor Yellow
Write-Host "   • consolidated_results.csv - All results in CSV format"
if ($Excel) {
    Write-Host "   • consolidated_results_excel.tsv - Excel-compatible format"
}
Write-Host "   • batch_summary.md - Comprehensive analysis report"
Write-Host "   • Individual instance directories with detailed results"

# Display final statistics
if (Test-Path $consolidatedCsv) {
    $results = Import-Csv $consolidatedCsv -ErrorAction SilentlyContinue
    if ($results -and $results.Count -gt 0) {
        Write-Host ""
        Write-Host "📈 Final Statistics:" -ForegroundColor Blue
        Write-Host "=================================="
        Write-Host "✅ Completed runs: $($results.Count)"
        
        $totalTime = ($results | Measure-Object -Property Execution_Time_Seconds -Sum).Sum
        $totalMinutes = [math]::Round($totalTime / 60.0, 1)
        Write-Host "⏱️  Total execution time: ${totalTime}s ($totalMinutes minutes)"
        
        Write-Host ""
        Write-Host "🏆 Best Results per Instance:" -ForegroundColor Magenta
        
        $grouped = $results | Group-Object -Property Instance
        foreach ($group in $grouped) {
            $bestResult = $group.Group | Sort-Object { [double]$_.Best_Cost } | Select-Object -First 1
            $output = "  $($group.Name): Cost = $($bestResult.Best_Cost)"
            
            if ($bestResult.GAP_Percent -ne "-1.00" -and ![string]::IsNullOrEmpty($bestResult.GAP_Percent)) {
                $output += " (GAP: $($bestResult.GAP_Percent)%)"
            }
            $output += ", Vehicles = $($bestResult.Total_Vehicles)"
            
            Write-Host $output
        }
    }
}

Write-Host ""
Write-Host "✅ All advanced batch testing tasks completed successfully!" -ForegroundColor Green
Write-Host "📖 For detailed analysis, see: $(Join-Path $OutputDir 'batch_summary.md')" -ForegroundColor Blue