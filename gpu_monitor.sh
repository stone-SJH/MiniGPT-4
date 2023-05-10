#!/bin/bash

interval=20
count=0
sum_utilization=0

while true; do
	# Use nvidia-smi to retrieve GPU information
	gpu_info=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
	gpu_mem_info=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)

	# Extract GPU utilization and memory usage values
	gpu_utilization=$(echo $gpu_info | awk '{print $1}')
	gpu_memory_usage=$(echo $gpu_mem_info | awk '{print $1}')

	sum_utilization=$(echo "$sum_utilization + $gpu_utilization" | bc -l)
	count=$(($count+1))
	    # Check if the interval has elapsed
	if [ $count -eq $interval ]; then
		average_utilization=$(echo "scale=2; $sum_utilization / $count" | bc -l)
		echo "Average GPU Utilization (Last $interval seconds): $average_utilization%"
		count=0
		sum_utilization=0
	fi
	# Print GPU utilization and memory usage
	echo "GPU Utilization: $gpu_utilization% , GPU Memory Usage: $gpu_memory_usage"
	# Wait for a certain period of time before retrieving GPU information again
	sleep 1
done
