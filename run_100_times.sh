#!/bin/bash

# Script để chạy GA với CMT1.vrp 100 lần
echo "🚀 Starting 100 runs of GA with CMT1.vrp"
echo "========================================"

# Biên dịch chương trình
echo "📦 Compiling ga8.cpp..."
g++ -std=c++17 -O2 ga8.cpp -o ga8
if [ $? -ne 0 ]; then
    echo "❌ Compilation failed!"
    exit 1
fi
echo "✅ Compilation successful!"

# Xóa file kết quả cũ nếu có
rm -f ga_results.csv
rm -f run_summary.txt

# Tạo header cho file summary
echo "Run,Best_Cost,Is_Feasible,Vehicles_Used,Execution_Time" > run_summary.txt

echo ""
echo "🔄 Starting 100 runs..."
echo "======================="

# Chạy 100 lần
for i in {1..100}; do
    echo -n "Run $i/100: "
    
    # Ghi thời gian bắt đầu
    start_time=$(date +%s.%N)
    
    # Chạy GA và lưu output
    ./ga8 > temp_output_$i.txt 2>&1
    
    # Ghi thời gian kết thúc
    end_time=$(date +%s.%N)
    execution_time=$(echo "$end_time - $start_time" | bc -l)
    
    # Trích xuất kết quả từ output
    if [ -f "ga_results.csv" ]; then
        # Lấy dòng cuối của CSV (kết quả mới nhất)
        last_result=$(tail -n 1 ga_results.csv)
        
        # Parse kết quả
        instance=$(echo $last_result | cut -d',' -f1)
        vehicles=$(echo $last_result | cut -d',' -f2)
        population=$(echo $last_result | cut -d',' -f3)
        cost=$(echo $last_result | cut -d',' -f4)
        
        # Kiểm tra feasibility từ output
        if grep -q "FEASIBLE" temp_output_$i.txt && ! grep -q "INFEASIBLE" temp_output_$i.txt; then
            feasible="TRUE"
        else
            feasible="FALSE"
        fi
        
        # Ghi vào summary
        printf "%d,%.2f,%s,%s,%.3f\n" $i $cost $feasible $vehicles $execution_time >> run_summary.txt
        
        echo "Cost: $cost, Feasible: $feasible, Time: ${execution_time}s"
    else
        echo "❌ No results generated"
        printf "%d,ERROR,FALSE,0,%.3f\n" $i $execution_time >> run_summary.txt
    fi
    
    # Cleanup temp file
    rm -f temp_output_$i.txt
    
    # Progress indicator every 10 runs
    if [ $((i % 10)) -eq 0 ]; then
        echo ""
        echo "✓ Completed $i/100 runs..."
        echo ""
    fi
done

echo ""
echo "🎉 All 100 runs completed!"
echo "=========================="

# Phân tích kết quả
echo ""
echo "📊 STATISTICAL ANALYSIS:"
echo "========================"

# Đếm số lần feasible
feasible_count=$(grep -c "TRUE" run_summary.txt)
infeasible_count=$(grep -c "FALSE" run_summary.txt)

echo "Feasible solutions: $feasible_count/100 ($(echo "scale=1; $feasible_count * 100 / 100" | bc -l)%)"
echo "Infeasible solutions: $infeasible_count/100 ($(echo "scale=1; $infeasible_count * 100 / 100" | bc -l)%)"

# Phân tích chi phí (chỉ tính feasible solutions)
if [ $feasible_count -gt 0 ]; then
    echo ""
    echo "📈 FEASIBLE SOLUTIONS ANALYSIS:"
    echo "==============================="
    
    # Trích xuất chỉ các cost của feasible solutions
    grep "TRUE" run_summary.txt | cut -d',' -f2 > feasible_costs.txt
    
    # Tính min, max, average
    min_cost=$(sort -n feasible_costs.txt | head -1)
    max_cost=$(sort -n feasible_costs.txt | tail -1)
    avg_cost=$(awk '{sum+=$1} END {print sum/NR}' feasible_costs.txt)
    
    echo "Best cost: $min_cost"
    echo "Worst cost: $max_cost"
    echo "Average cost: $(printf "%.2f" $avg_cost)"
    
    # Tính standard deviation
    std_dev=$(awk -v avg=$avg_cost '{sum+=($1-avg)^2} END {print sqrt(sum/NR)}' feasible_costs.txt)
    echo "Standard deviation: $(printf "%.2f" $std_dev)"
    
    rm -f feasible_costs.txt
fi

# Phân tích thời gian thực thi
echo ""
echo "⏱️ EXECUTION TIME ANALYSIS:"
echo "==========================="

# Trích xuất thời gian (bỏ header)
tail -n +2 run_summary.txt | cut -d',' -f5 > execution_times.txt

min_time=$(sort -n execution_times.txt | head -1)
max_time=$(sort -n execution_times.txt | tail -1)
avg_time=$(awk '{sum+=$1} END {print sum/NR}' execution_times.txt)

echo "Fastest run: ${min_time}s"
echo "Slowest run: ${max_time}s"
echo "Average time: $(printf "%.3f" $avg_time)s"

rm -f execution_times.txt

# Tạo final summary file
echo ""
echo "💾 Creating final summary..."

cat > final_summary.txt << EOF
=================================
GA PERFORMANCE ANALYSIS (100 RUNS)
=================================
Date: $(date)
Problem: CMT1.vrp
Population: 500
Generations: 100

SOLUTION QUALITY:
- Feasible solutions: $feasible_count/100 ($(echo "scale=1; $feasible_count * 100 / 100" | bc -l)%)
- Infeasible solutions: $infeasible_count/100

EOF

if [ $feasible_count -gt 0 ]; then
    cat >> final_summary.txt << EOF
FEASIBLE COSTS:
- Best: $min_cost
- Worst: $max_cost  
- Average: $(printf "%.2f" $avg_cost)
- Std Dev: $(printf "%.2f" $std_dev)

EOF
fi

cat >> final_summary.txt << EOF
EXECUTION TIME:
- Fastest: ${min_time}s
- Slowest: ${max_time}s
- Average: $(printf "%.3f" $avg_time)s

DETAILED RESULTS: See run_summary.txt
EOF

echo "✅ Results saved to:"
echo "   - run_summary.txt (detailed results)"
echo "   - final_summary.txt (statistical summary)"
echo "   - ga_results.csv (latest GA output)"

echo ""
echo "📋 Quick Summary:"
cat final_summary.txt

echo ""
echo "🎯 Done!"