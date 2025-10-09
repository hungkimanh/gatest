# CVRP Solver Test Script for Windows PowerShell
# This script runs the CVRP solver with different instances using command line arguments

param(
    [int]$Generations = 1000,
    [int]$Population = 200,
    [string[]]$Instances = @("CMT1", "CMT2", "CMT3", "CMT4", "CMT5"),
    [switch]$Help
)

if ($Help) {
    Write-Host "CVRP Solver Batch Test Script"
    Write-Host "Usage: .\run_batch_test.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Generations NUMBER     Number of generations (default: 1000)"
    Write-Host "  -Population NUMBER      Population size (default: 200)"
    Write-Host "  -Instances LIST         Array of instances (default: CMT1,CMT2,CMT3,CMT4,CMT5)"
    Write-Host "  -Help                   Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run_batch_test.ps1 -Generations 2000 -Population 500"
    Write-Host "  .\run_batch_test.ps1 -Instances @('CMT1','CMT4')"
    exit 0
}

Write-Host "=== CVRP Solver Batch Test (PowerShell Version) ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date)"
Write-Host ""

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Generations: $Generations"
Write-Host "  Population: $Population"
Write-Host "  Instances: $($Instances -join ', ')"
Write-Host ""

# Create results directory
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$resultsDir = "results_$timestamp"
New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null

# Compile the solver
Write-Host "Compiling CVRP Solver..." -ForegroundColor Yellow
try {
    $compileProcess = Start-Process -FilePath "g++" -ArgumentList @("-std=c++17", "-O3", "-o", "cvrp_solver.exe", "ga8.cpp") -Wait -PassThru -NoNewWindow
    if ($compileProcess.ExitCode -ne 0) {
        throw "Compilation failed with exit code $($compileProcess.ExitCode)"
    }
    Write-Host "Compilation successful!" -ForegroundColor Green
} catch {
    Write-Host "Compilation failed: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Function to run solver for a specific instance
function Run-Instance {
    param(
        [string]$Instance,
        [int]$Gens,
        [int]$Pop
    )
    
    $outputFile = Join-Path $resultsDir "${Instance}_output.log"
    
    Write-Host "Processing ${Instance}.vrp..." -ForegroundColor Cyan
    
    # Check if VRP file exists
    if (-not (Test-Path "${Instance}.vrp")) {
        Write-Host "  Warning: ${Instance}.vrp not found, skipping..." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "  Running solver with parameters: generations=$Gens, population=$Pop"
    $startTime = Get-Date
    
    try {
        # Run with timeout - using command line arguments
        $process = Start-Process -FilePath ".\cvrp_solver.exe" -ArgumentList @("${Instance}.vrp", $Gens, $Pop) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile -RedirectStandardError "${outputFile}.err"
        
        $endTime = Get-Date
        $runtime = ($endTime - $startTime).TotalSeconds
        
        if ($process.ExitCode -eq 0) {
            Write-Host "  ✓ Completed successfully in $([math]::Round($runtime, 2))s" -ForegroundColor Green
            
            # Move results if they exist
            if (Test-Path "ga_results.csv") {
                $lastLine = Get-Content "ga_results.csv" | Select-Object -Last 1
                Add-Content -Path (Join-Path $resultsDir "all_results.csv") -Value $lastLine
                Copy-Item "ga_results.csv" (Join-Path $resultsDir "${Instance}_results.csv")
                Remove-Item "ga_results.csv"
            }
            return $true
        } else {
            Write-Host "  ✗ Failed with exit code $($process.ExitCode)" -ForegroundColor Red
            Write-Host "  Check log: $outputFile" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "  ✗ Error running solver: $_" -ForegroundColor Red
        return $false
    }
}

# Initialize results CSV with header
$headerPath = Join-Path $resultsDir "all_results.csv"
"Instance,Total Vehicles,Population Size,Best Cost" | Out-File -FilePath $headerPath -Encoding UTF8

# Run for each instance
$successCount = 0
foreach ($instance in $Instances) {
    # Customize parameters per instance
    switch ($instance) {
        "CMT1" {
            $instGens = [math]::Max(500, $Generations / 2)  # Smaller instance
            $instPop = [math]::Max(100, $Population / 2)
        }
        "CMT5" {
            $instGens = $Generations * 2  # Larger instance
            $instPop = $Population * 2
        }
        default {
            $instGens = $Generations
            $instPop = $Population
        }
    }
    
    if (Run-Instance -Instance $instance -Gens $instGens -Pop $instPop) {
        $successCount++
    }
    Write-Host ""
}

# Generate summary report
Write-Host "=== SUMMARY REPORT ===" -ForegroundColor Green
Write-Host "Total instances tested: $($Instances.Count)"
Write-Host "Successful runs: $successCount"
Write-Host "Results directory: $resultsDir"
Write-Host ""

if (Test-Path $headerPath) {
    $results = Get-Content $headerPath
    if ($results.Count -gt 1) {
        Write-Host "Results summary:" -ForegroundColor Yellow
        Write-Host "================"
        $results | ForEach-Object { Write-Host $_ }
        
        # Calculate average cost if possible
        $dataLines = $results | Select-Object -Skip 1
        if ($dataLines.Count -gt 0) {
            $costs = $dataLines | ForEach-Object { 
                $fields = $_ -split ','
                if ($fields.Count -ge 4) { [double]$fields[3] }
            } | Where-Object { $_ -gt 0 }
            
            if ($costs.Count -gt 0) {
                $avgCost = ($costs | Measure-Object -Average).Average
                Write-Host ""
                Write-Host "Average cost: $([math]::Round($avgCost, 2))" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host "No results generated." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Batch test completed! Check $resultsDir\ for detailed results." -ForegroundColor Green