#!/bin/bash

# CVRP Solver Advanced Batch Testing Script
# Usage: ./run_advanced_batch.sh [OPTIONS]

# Default configuration
DEFAULT_INSTANCES=("CMT1" "CMT2" "CMT3" "CMT4" "CMT5")
DEFAULT_GENERATIONS=1000
DEFAULT_POPULATION=500
DEFAULT_RUNS=5

# Current configuration (will be updated by command line args)
INSTANCES=("${DEFAULT_INSTANCES[@]}")
GENERATIONS=$DEFAULT_GENERATIONS
POPULATION=$DEFAULT_POPULATION
NUM_RUNS=$DEFAULT_RUNS
RESULTS_DIR="cvrp_results_$(date +%Y%m%d_%H%M%S)"
EXCEL_OUTPUT=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
    echo "🚛 CVRP Solver Advanced Batch Testing Script"
    echo "============================================"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --instances LIST        Comma-separated VRP instances (default: CMT1,CMT2,CMT3,CMT4,CMT5)"
    echo "  -g, --generations NUMBER    Number of generations (default: $DEFAULT_GENERATIONS)"
    echo "  -p, --population NUMBER     Population size (default: $DEFAULT_POPULATION)"
    echo "  -r, --runs NUMBER           Number of runs per instance (default: $DEFAULT_RUNS)"
    echo "  -o, --output DIR            Output directory (default: auto-generated)"
    echo "  -e, --excel                 Generate Excel-compatible output"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -g 2000 -p 800 -r 10"
    echo "  $0 -i CMT1,CMT4 -r 20 --excel"
    echo "  $0 --instances CMT1,CMT2 --generations 1500 --runs 5"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--instances)
            IFS=',' read -ra INSTANCES <<< "$2"
            shift 2
            ;;
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
        -o|--output)
            RESULTS_DIR="$2"
            shift 2
            ;;
        -e|--excel)
            EXCEL_OUTPUT=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validation
if [[ $GENERATIONS -le 0 ]]; then
    echo "❌ Error: Generations must be positive"
    exit 1
fi

if [[ $POPULATION -le 0 ]]; then
    echo "❌ Error: Population size must be positive"
    exit 1
fi

if [[ $NUM_RUNS -le 0 ]]; then
    echo "❌ Error: Number of runs must be positive"
    exit 1
fi

# Display configuration
echo -e "${BLUE}🚛 CVRP SOLVER ADVANCED BATCH TESTING${NC}"
echo "====================================="
echo -e "${YELLOW}Configuration:${NC}"
echo "  Instances: ${INSTANCES[*]}"
echo "  Generations: $GENERATIONS"
echo "  Population: $POPULATION"
echo "  Runs per instance: $NUM_RUNS"
echo "  Results directory: $RESULTS_DIR"
echo "  Excel output: $([ "$EXCEL_OUTPUT" = true ] && echo "Yes" || echo "No")"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"
echo -e "${GREEN}✅ Created results directory: $RESULTS_DIR${NC}"

# Compile the solver
echo -e "${YELLOW}🔨 Compiling CVRP Solver...${NC}"
if [ -f "ga8.cpp" ]; then
    g++ -std=c++17 -O3 -o ga8 ga8.cpp
elif [ -f "gatest/ga8.cpp" ]; then
    echo "Working from parent directory..."
    cd gatest
    g++ -std=c++17 -O3 -o ga8 ga8.cpp
else
    echo -e "${RED}❌ Error: ga8.cpp not found${NC}"
    exit 1
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Compilation failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Compilation successful!${NC}"
echo ""

# Initialize consolidated results file with Excel-friendly headers
CONSOLIDATED_CSV="../$RESULTS_DIR/consolidated_results.csv"
echo "Instance,Total_Vehicles,Population_Size,Max_Generations,Best_Cost,Optimal_Cost,GAP_Percent,Execution_Time_Seconds,Number_of_Runs" > "$CONSOLIDATED_CSV"

# Function to run solver for a specific instance
run_instance() {
    local instance=$1
    local gens=$2
    local pop=$3
    local runs=$4
    
    # Determine VRP file path
    local vrp_file
    if [ -f "../${instance}.vrp" ]; then
        vrp_file="../${instance}.vrp"
    elif [ -f "${instance}.vrp" ]; then
        vrp_file="${instance}.vrp"
    else
        echo -e "${RED}  ❌ Error: ${instance}.vrp not found${NC}"
        return 1
    fi
    
    local instance_dir="../$RESULTS_DIR/${instance}"
    
    echo -e "${PURPLE}📊 Processing $instance ($runs runs)...${NC}"
    
    # Create instance-specific directory
    mkdir -p "$instance_dir"
    
    echo "  📂 Running solver with parameters:"
    echo "     - VRP file: $vrp_file"
    echo "     - Generations: $gens"
    echo "     - Population: $pop"
    echo "     - Runs: $runs"
    
    start_time=$(date +%s)
    
    # Run with timeout and capture output
    timeout 3600 ./ga8 "$vrp_file" "$gens" "$pop" "$runs" > "$instance_dir/output.log" 2>&1
    exit_code=$?
    
    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    
    # Check results
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}  ✅ Completed successfully in ${runtime}s${NC}"
        
        if [ -f "ga_results.csv" ]; then
            # Copy results to instance directory
            cp ga_results.csv "$instance_dir/"
            
            # Parse the result and append to consolidated CSV
            tail -n +2 ga_results.csv | while IFS=',' read -r inst vehicles pop_size max_gens cost optimal gap; do
                echo "$inst,$vehicles,$pop_size,$max_gens,$cost,$optimal,$gap,$runtime,$runs" >> "$CONSOLIDATED_CSV"
            done
            
            # Display key results
            tail -n +2 ga_results.csv | while IFS=',' read -r inst vehicles pop_size max_gens cost optimal gap; do
                echo -e "${GREEN}  📈 Results: Cost=$cost, Vehicles=$vehicles"
                if [ "$gap" != "-1.00" ] && [ -n "$gap" ]; then
                    echo -e "     GAP=${gap}%, Optimal=$optimal, Gens=$max_gens${NC}"
                else
                    echo -e "     GAP=N/A (optimal unknown), Gens=$max_gens${NC}"
                fi
            done
            
            # Generate Excel format if requested
            if [ "$EXCEL_OUTPUT" = true ]; then
                # Create tab-separated version for Excel
                sed 's/,/\t/g' ga_results.csv > "$instance_dir/results_excel.tsv"
                echo -e "${GREEN}  📊 Excel format created: ${instance}_results_excel.tsv${NC}"
            fi
            
            # Clean up for next run
            rm ga_results.csv
        else
            echo -e "${YELLOW}  ⚠️  Warning: ga_results.csv not found${NC}"
        fi
        
        # Create detailed instance summary
        create_instance_summary "$instance" "$instance_dir" "$runtime" "$runs"
        
    elif [ $exit_code -eq 124 ]; then
        echo -e "${RED}  ❌ Timeout after 3600s (1 hour)${NC}"
    else
        echo -e "${RED}  ❌ Failed with exit code $exit_code${NC}"
        echo -e "${YELLOW}  📄 Check detailed log: $instance_dir/output.log${NC}"
    fi
    
    echo ""
}

# Function to create detailed instance summary
create_instance_summary() {
    local instance=$1
    local instance_dir=$2
    local runtime=$3
    local runs=$4
    
    if [ -f "$instance_dir/ga_results.csv" ]; then
        cat > "$instance_dir/summary_report.md" << EOF
# CVRP Solver Results - $instance

## Test Configuration
- **Instance**: $instance
- **Generations**: $GENERATIONS
- **Population Size**: $POPULATION
- **Number of Runs**: $runs
- **Execution Time**: ${runtime} seconds
- **Timestamp**: $(date)

## Results Summary
\`\`\`
$(cat "$instance_dir/ga_results.csv")
\`\`\`

## Detailed Analysis
$(tail -n +2 "$instance_dir/ga_results.csv" | while IFS=',' read -r inst vehicles pop cost optimal gap; do
    echo "### Performance Metrics"
    echo "- **Best Cost Found**: $cost"
    echo "- **Optimal Cost (from file)**: $optimal"
    if [ "$gap" != "-1.00" ] && [ -n "$gap" ]; then
        echo "- **GAP from Optimal**: $gap%"
        if (( $(echo "$gap < 5.0" | bc -l) )); then
            echo "  - 🎯 **Excellent** performance (< 5% gap)"
        elif (( $(echo "$gap < 10.0" | bc -l) )); then
            echo "  - ✅ **Good** performance (< 10% gap)"
        else
            echo "  - ⚠️ **Needs improvement** (> 10% gap)"
        fi
    else
        echo "- **GAP from Optimal**: Unknown (optimal cost not available)"
    fi
    echo "- **Vehicles Used**: $vehicles"
    echo "- **Population Size**: $pop"
    echo "- **Execution Time**: ${runtime}s"
done)

## Execution Log (Last 30 lines)
\`\`\`
$(tail -30 "$instance_dir/output.log" 2>/dev/null || echo "No detailed log available")
\`\`\`
EOF
        
        # Create a simple CSV summary for this instance
        cat > "$instance_dir/instance_summary.csv" << EOF
Metric,Value
Instance,$instance
Best_Cost,$(tail -n +2 "$instance_dir/ga_results.csv" | cut -d',' -f4)
Optimal_Cost,$(tail -n +2 "$instance_dir/ga_results.csv" | cut -d',' -f5)
GAP_Percent,$(tail -n +2 "$instance_dir/ga_results.csv" | cut -d',' -f6)
Vehicles_Used,$(tail -n +2 "$instance_dir/ga_results.csv" | cut -d',' -f2)
Population_Size,$POPULATION
Generations,$GENERATIONS
Runs,$runs
Execution_Time_Seconds,$runtime
EOF
    fi
}

# Main execution starts here
echo -e "${BLUE}🏃 Starting advanced batch execution...${NC}"
echo "========================================"

total_instances=${#INSTANCES[@]}
current=0
successful_runs=0

for instance in "${INSTANCES[@]}"; do
    current=$((current + 1))
    echo -e "${BLUE}[$current/$total_instances] Processing $instance${NC}"
    
    if run_instance "$instance" "$GENERATIONS" "$POPULATION" "$NUM_RUNS"; then
        successful_runs=$((successful_runs + 1))
    fi
done

# Generate comprehensive final report
cd ..
echo -e "${YELLOW}📈 Generating comprehensive consolidated report...${NC}"

# Create main batch summary
cat > "$RESULTS_DIR/batch_summary.md" << EOF
# CVRP Advanced Batch Testing Results

## Executive Summary
- **Test Date**: $(date)
- **Total Instances Tested**: $total_instances
- **Successfully Completed**: $successful_runs
- **Success Rate**: $(echo "scale=1; $successful_runs * 100 / $total_instances" | bc)%

## Test Configuration
- **Instances**: ${INSTANCES[*]}
- **Generations per Run**: $GENERATIONS
- **Population Size**: $POPULATION
- **Runs per Instance**: $NUM_RUNS
- **Total Expected Runs**: $(echo "$total_instances * $NUM_RUNS" | bc)

## Results Overview
EOF

# Add consolidated results table if available
if [ -f "$RESULTS_DIR/consolidated_results.csv" ] && [ $(wc -l < "$RESULTS_DIR/consolidated_results.csv") -gt 1 ]; then
    echo "### Detailed Results Table" >> "$RESULTS_DIR/batch_summary.md"
    echo '```' >> "$RESULTS_DIR/batch_summary.md"
    cat "$RESULTS_DIR/consolidated_results.csv" >> "$RESULTS_DIR/batch_summary.md"
    echo '```' >> "$RESULTS_DIR/batch_summary.md"
    
    # Generate Excel format for consolidated results
    if [ "$EXCEL_OUTPUT" = true ]; then
        sed 's/,/\t/g' "$RESULTS_DIR/consolidated_results.csv" > "$RESULTS_DIR/consolidated_results_excel.tsv"
        echo -e "${GREEN}📊 Excel format consolidated results created${NC}"
    fi
    
    # Calculate comprehensive statistics
    echo "" >> "$RESULTS_DIR/batch_summary.md"
    echo "### Performance Statistics" >> "$RESULTS_DIR/batch_summary.md"
    
    # Count successful runs
    actual_runs=$(tail -n +2 "$RESULTS_DIR/consolidated_results.csv" | wc -l)
    echo "- **Actual Completed Runs**: $actual_runs" >> "$RESULTS_DIR/batch_summary.md"
    
    # Average GAP (excluding -1.00 values)
    avg_gap=$(tail -n +2 "$RESULTS_DIR/consolidated_results.csv" | awk -F',' '
        $6 != "-1.00" && $6 != "" && $6 > -999 {sum+=$6; count++} 
        END {if(count>0) printf "%.2f", sum/count; else print "N/A"}')
    echo "- **Average GAP from Optimal**: ${avg_gap}%" >> "$RESULTS_DIR/batch_summary.md"
    
    # Best GAP achieved
    best_gap=$(tail -n +2 "$RESULTS_DIR/consolidated_results.csv" | awk -F',' '
        $6 != "-1.00" && $6 != "" && $6 > -999 {if(min=="" || $6<min) min=$6} 
        END {if(min!="") printf "%.2f", min; else print "N/A"}')
    echo "- **Best GAP Achieved**: ${best_gap}%" >> "$RESULTS_DIR/batch_summary.md"
    
    # Total execution time
    total_time=$(tail -n +2 "$RESULTS_DIR/consolidated_results.csv" | awk -F',' '{sum+=$7} END {print sum}')
    total_minutes=$(echo "scale=1; $total_time / 60" | bc)
    echo "- **Total Execution Time**: ${total_time}s (${total_minutes} minutes)" >> "$RESULTS_DIR/batch_summary.md"
    
    # Average time per run
    if [ $actual_runs -gt 0 ]; then
        avg_time=$(echo "scale=1; $total_time / $actual_runs" | bc)
        echo "- **Average Time per Run**: ${avg_time}s" >> "$RESULTS_DIR/batch_summary.md"
    fi
    
    # Performance ranking
    echo "" >> "$RESULTS_DIR/batch_summary.md"
    echo "### Instance Performance Ranking (by GAP)" >> "$RESULTS_DIR/batch_summary.md"
    tail -n +2 "$RESULTS_DIR/consolidated_results.csv" | sort -t',' -k6,6n | awk -F',' '
        $6 != "-1.00" && $6 != "" && $6 > -999 {
            printf "1. **%s**: %.2f%% GAP (Cost: %.2f)\n", $1, $6, $4
        }' >> "$RESULTS_DIR/batch_summary.md"
    
else
    echo "❌ **No consolidated results available**" >> "$RESULTS_DIR/batch_summary.md"
fi

# Final summary display
echo ""
echo -e "${GREEN}🎉 ADVANCED BATCH TESTING COMPLETED!${NC}"
echo "========================================"
echo -e "${YELLOW}📁 Results Directory:${NC} $RESULTS_DIR"
echo -e "${YELLOW}📊 Generated Files:${NC}"
echo "   • consolidated_results.csv - All results in CSV format"
if [ "$EXCEL_OUTPUT" = true ]; then
    echo "   • consolidated_results_excel.tsv - Excel-compatible format"
fi
echo "   • batch_summary.md - Comprehensive analysis report"
echo "   • Individual instance directories with detailed results"
echo "   • Per-instance summary reports and logs"

# Display final statistics
if [ -f "$RESULTS_DIR/consolidated_results.csv" ] && [ $(wc -l < "$RESULTS_DIR/consolidated_results.csv") -gt 1 ]; then
    echo ""
    echo -e "${BLUE}📈 Final Statistics:${NC}"
    echo "=================================="
    actual_runs=$(tail -n +2 "$RESULTS_DIR/consolidated_results.csv" | wc -l)
    total_time=$(tail -n +2 "$RESULTS_DIR/consolidated_results.csv" | awk -F',' '{sum+=$7} END {print sum}')
    echo "✅ Completed runs: $actual_runs"
    echo "⏱️  Total execution time: ${total_time}s ($(echo "scale=1; $total_time / 60" | bc) minutes)"
    
    # Show best results summary
    echo ""
    echo -e "${PURPLE}🏆 Best Results per Instance:${NC}"
    tail -n +2 "$RESULTS_DIR/consolidated_results.csv" | sort -t',' -k1,1 -k4,4n | awk -F',' '
    {
        if ($1 != last_instance) {
            if (last_instance != "") {
                printf "  %s: Cost = %.2f", last_instance, best_cost;
                if (best_gap != "-1.00" && best_gap != "" && best_gap > -999) printf " (GAP: %.2f%%)", best_gap;
                printf ", Vehicles = %d\n", best_vehicles;
            }
            last_instance = $1;
            best_cost = $4;
            best_gap = $6;
            best_vehicles = $2;
        }
    }
    END {
        if (last_instance != "") {
            printf "  %s: Cost = %.2f", last_instance, best_cost;
            if (best_gap != "-1.00" && best_gap != "" && best_gap > -999) printf " (GAP: %.2f%%)", best_gap;
            printf ", Vehicles = %d\n", best_vehicles;
        }
    }'
fi

echo ""
echo -e "${GREEN}✅ All advanced batch testing tasks completed successfully!${NC}"
echo -e "${BLUE}📖 For detailed analysis, see: $RESULTS_DIR/batch_summary.md${NC}"