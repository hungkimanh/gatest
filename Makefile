# Makefile for CVRP Solver

# Compiler settings
CXX = g++
CXXFLAGS = -std=c++17 -O3 -Wall -Wextra
TARGET = cvrp_solver
SOURCE = ga8.cpp

# Default target
all: $(TARGET)

# Build the main executable
$(TARGET): $(SOURCE)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SOURCE)

# Build with debug information
debug: CXXFLAGS += -g -DDEBUG
debug: $(TARGET)

# Quick test build (reduced optimizations for faster compilation)
quick: CXXFLAGS = -std=c++17 -O1
quick: $(TARGET)

# Clean build artifacts
clean:
	rm -f $(TARGET) $(TARGET).exe *.o *.log
	rm -rf results_*

# Test with default instance
test: $(TARGET)
	./$(TARGET) CMT4.vrp 1000 200

# Test multiple instances
test-all: $(TARGET)
	@echo "Testing multiple instances..."
	@for instance in CMT1 CMT2 CMT3 CMT4 CMT5; do \
		if [ -f "$$instance.vrp" ]; then \
			echo "Testing $$instance.vrp..."; \
			./$(TARGET) "$$instance.vrp" 500 100; \
		else \
			echo "Warning: $$instance.vrp not found"; \
		fi; \
	done

# Performance test (longer run)
perf-test: $(TARGET)
	./$(TARGET) CMT4.vrp 5000 1000

# Install dependencies (Ubuntu/Debian)
install-deps:
	sudo apt-get update
	sudo apt-get install -y build-essential g++

# Check code with static analysis (if cppcheck is available)
check:
	@if command -v cppcheck >/dev/null 2>&1; then \
		cppcheck --enable=all --std=c++17 $(SOURCE); \
	else \
		echo "cppcheck not found, skipping static analysis"; \
	fi

# Format code (if clang-format is available)
format:
	@if command -v clang-format >/dev/null 2>&1; then \
		clang-format -i $(SOURCE); \
		echo "Code formatted with clang-format"; \
	else \
		echo "clang-format not found, skipping formatting"; \
	fi

# Show help
help:
	@echo "Available targets:"
	@echo "  all          - Build the CVRP solver (default)"
	@echo "  debug        - Build with debug information"
	@echo "  quick        - Quick build with reduced optimization"
	@echo "  clean        - Remove build artifacts and results"
	@echo "  test         - Run test with CMT4.vrp"
	@echo "  test-all     - Test all available VRP instances"
	@echo "  perf-test    - Run performance test (long)"
	@echo "  install-deps - Install build dependencies (Ubuntu/Debian)"
	@echo "  check        - Run static code analysis"
	@echo "  format       - Format code with clang-format"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make                    # Build the solver"
	@echo "  make test               # Quick test"
	@echo "  make test-all           # Test all instances"
	@echo "  make clean all          # Clean build"

# Declare phony targets
.PHONY: all debug quick clean test test-all perf-test install-deps check format help