#!/bin/bash

interval=60
gpu_memory_cap=75000
count=0
sum_utilization=0
low_util_count=0
msg_sent=0

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
		if (($(echo "$average_utilization<60" | bc -l))); then
			low_util_count=$(($low_util_count+1))
			if (($low_util_count==10)); then
			if (($msg_sent==0)); then
			response=$(curl --location --request POST 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' --header 'Content-Type: application/json; charset=utf-8' --data-raw '{"app_id": "cli_a4e729a2653a100c","app_secret": "LdqEmQ1QEICOCiYt05Qa0crETgXF0C2z"}')
			#tenant_access_token=$(echo "$response" | grep -oP '(?<="tenant_access_token": ")[^"]+')
			tenant_access_token=$(echo "$response" | /root/workspace/anaconda3/bin/jq -r '.tenant_access_token')

			curl --location --request POST 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id' \
				--header "Authorization: Bearer $tenant_access_token" \
				--header 'Content-Type: application/json; charset=utf-8' \
				--data-raw '{
			    "receive_id": "ou_4c99b9ebf24e96f96c95c14715fb0b40",
			        "msg_type": "text",
				    "content": "{\"text\":\"<at user_id=\\\"ou_4c99b9ebf24e96f96c95c14715fb0b40\\\">stone</at> <Warning> GPU Utilization too low. \"}"
			    }'
		    	curl -X POST -H "Content-Type: application/json" -d '{"msg_type":"text","content":{"text":"GPU Utilization is too low(<60%). There is only one or no running task. Please check the running tasks(8004&8005)!"}}' https://open.feishu.cn/open-apis/bot/v2/hook/ca0017f1-2679-4edb-a318-cc1e0f4957f9
		    	msg_sent=1
		    	fi
		    	fi
		else
			low_util_count=0
			if (($msg_sent==1)); then
				response=$(curl --location --request POST 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' --header 'Content-Type: application/json; charset=utf-8' --data-raw '{"app_id": "cli_a4e729a2653a100c","app_secret": "LdqEmQ1QEICOCiYt05Qa0crETgXF0C2z"}')
				tenant_access_token=$(echo "$response" | /root/workspace/anaconda3/bin/jq -r '.tenant_access_token')									                        
				
				curl --location --request POST 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id' \
					--header "Authorization: Bearer $tenant_access_token" \
					--header 'Content-Type: application/json; charset=utf-8' \
					--data-raw '{
					"receive_id": "ou_4c99b9ebf24e96f96c95c14715fb0b40",								
					"msg_type": "text",							
					"content": "{\"text\":\"<at user_id=\\\"ou_4c99b9ebf24e96f96c95c14715fb0b40\\\">stone</at> <Warning> GPU Utilization is back to normal(>=60%) \"}"
					}'
			
				curl -X POST -H "Content-Type: application/json" -d '{"msg_type":"text","content":{"text":"GPU Utilization is back to normal(>=60%)."}}' https://open.feishu.cn/open-apis/bot/v2/hook/ca0017f1-2679-4edb-a318-cc1e0f4957f9
	
				msg_sent=0
			fi
		fi
	fi

	if (($(echo "$gpu_memory_usage>$gpu_memory_cap" | bc -l))); then
		response=$(curl --location --request POST 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' --header 'Content-Type: application/json; charset=utf-8' --data-raw '{"app_id": "cli_a4e729a2653a100c","app_secret": "LdqEmQ1QEICOCiYt05Qa0crETgXF0C2z"}')

		tenant_access_token=$(echo "$response" | /root/workspace/anaconda3/bin/jq  -r '.tenant_access_token')
		curl --location --request POST 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id' \
			--header "Authorization: Bearer $tenant_access_token" \
			--header 'Content-Type: application/json; charset=utf-8' \
			--data-raw '{
		    "receive_id": "ou_4c99b9ebf24e96f96c95c14715fb0b40",
		        "msg_type": "text",
			    "content": "{\"text\":\"<at user_id=\\\"ou_4c99b9ebf24e96f96c95c14715fb0b40\\\">stone</at> <Warning> Insufficient GPU Memory.\"}"
		    }'
	fi
	# Print GPU utilization and memory usage
	#echo "GPU Utilization: $gpu_utilization% , GPU Memory Usage: $gpu_memory_usage"
	# Wait for a certain period of time before retrieving GPU information again
	sleep 1
done
