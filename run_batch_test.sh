#!/bin/bash

# CVRP Solver Test Script - Using Command Line Arguments
# This script runs the CVRP solver with different instances and configurations

echo "=== CVRP Solver Batch Test (Command Line Version) ==="
echo "Date: $(date)"
echo ""

# Configuration
INSTANCES=("CMT1" "CMT2" "CMT3" "CMT4" "CMT5")
GENERATIONS=1000
POPULATION=200
NUM_RUNS=5  # Number of times to run each instance
RESULTS_DIR="results_$(date +%Y%m%d_%H%M%S)"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--generations)
            GENERATIONS="$2"
            shift 2
            ;;
        -p|--population)
            POPULATION="$2"
            shift 2
            ;;
        -r|--runs)
            NUM_RUNS="$2"
            shift 2
            ;;
        -i|--instances)
            IFS=',' read -ra INSTANCES <<< "$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -g, --generations NUMBER    Number of generations (default: 1000)"
            echo "  -p, --population NUMBER     Population size (default: 200)"
            echo "  -r, --runs NUMBER           Number of runs per instance (default: 5)"
            echo "  -i, --instances LIST        Comma-separated list of instances (default: CMT1,CMT2,CMT3,CMT4,CMT5)"
            echo "  -h, --help                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 -g 2000 -p 500 -r 10"
            echo "  $0 -i CMT1,CMT4 -r 20"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo "Configuration:"
echo "  Generations: $GENERATIONS"
echo "  Population: $POPULATION"
echo "  Runs per instance: $NUM_RUNS"
echo "  Instances: ${INSTANCES[*]}"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# Compile the solver
echo "Compiling CVRP Solver..."
g++ -std=c++17 -O3 -o cvrp_solver ga8.cpp
if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi
echo "Compilation successful!"
echo ""

# Function to run solver for a specific instance
run_instance() {
    local instance=$1
    local gens=$2
    local pop=$3
    local runs=$4
    local output_file="$RESULTS_DIR/${instance}_output.log"
    
    echo "Processing $instance.vrp ($runs runs)..."
    
    # Check if VRP file exists
    if [ ! -f "${instance}.vrp" ]; then
        echo "  Warning: ${instance}.vrp not found, skipping..."
        return 1
    fi
    
    echo "  Running solver with parameters: generations=$gens, population=$pop, runs=$runs"
    start_time=$(date +%s)
    
    # Run with timeout and capture output - using command line arguments
    timeout 600 ./cvrp_solver "${instance}.vrp" "$gens" "$pop" "$runs" > "$output_file" 2>&1
    exit_code=$?
    
    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    
    # Check results
    if [ $exit_code -eq 0 ]; then
        echo "  ✓ Completed successfully in ${runtime}s"
        if [ -f ga_results.csv ]; then
            # Get the last result from CSV and add instance info
            tail -n 1 ga_results.csv >> "$RESULTS_DIR/all_results.csv"
        fi
    elif [ $exit_code -eq 124 ]; then
        echo "  ✗ Timeout after 600s"
    else
        echo "  ✗ Failed with exit code $exit_code"
        echo "  Check log: $output_file"
    fi
    
    # Move results
    if [ -f ga_results.csv ]; then
        cp ga_results.csv "$RESULTS_DIR/${instance}_results.csv"
        rm ga_results.csv  # Clean up for next run
    fi
    
    echo ""
}

# Initialize results CSV with header
echo "Instance,Total Vehicles,Population Size,Best Cost,Generations,Runtime" > "$RESULTS_DIR/all_results.csv"

# Run for each instance with potentially different parameters
for instance in "${INSTANCES[@]}"; do
    # You can customize generations and population per instance here
    case $instance in
        "CMT1")
            inst_gens=$((GENERATIONS / 2))  # Smaller instance, fewer generations
            inst_pop=$((POPULATION / 2))
            ;;
        "CMT5")
            inst_gens=$((GENERATIONS * 2))  # Larger instance, more generations  
            inst_pop=$((POPULATION * 2))
            ;;
        *)
            inst_gens=$GENERATIONS
            inst_pop=$POPULATION
            ;;
    esac
    
    run_instance "$instance" "$inst_gens" "$inst_pop" "$NUM_RUNS"
done

# Generate summary report
echo "=== SUMMARY REPORT ===" | tee "$RESULTS_DIR/summary.txt"
echo "Total instances tested: ${#INSTANCES[@]}" | tee -a "$RESULTS_DIR/summary.txt"
echo "Results directory: $RESULTS_DIR" | tee -a "$RESULTS_DIR/summary.txt"
echo "" | tee -a "$RESULTS_DIR/summary.txt"

if [ -f "$RESULTS_DIR/all_results.csv" ] && [ $(wc -l < "$RESULTS_DIR/all_results.csv") -gt 1 ]; then
    echo "Results summary:" | tee -a "$RESULTS_DIR/summary.txt"
    echo "================" | tee -a "$RESULTS_DIR/summary.txt"
    cat "$RESULTS_DIR/all_results.csv" | tee -a "$RESULTS_DIR/summary.txt"
    echo "" | tee -a "$RESULTS_DIR/summary.txt"
    
    # Calculate average cost (excluding header)
    if command -v awk >/dev/null 2>&1; then
        avg_cost=$(tail -n +2 "$RESULTS_DIR/all_results.csv" | awk -F',' '{sum+=$4; count++} END {printf "%.2f", sum/count}')
        echo "Average cost: $avg_cost" | tee -a "$RESULTS_DIR/summary.txt"
    fi
else
    echo "No results generated." | tee -a "$RESULTS_DIR/summary.txt"
fi

echo ""
echo "Batch test completed! Check $RESULTS_DIR/ for detailed results."