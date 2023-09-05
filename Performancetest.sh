#!/bin/bash

# Function to validate IP address
validate_ip() {
    local ip="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"

    if [[ $ip =~ $regex ]]; then
        return 0 # Valid IP
    else
        return 1 # Invalid IP
    fi
}

# Function to validate domain name
validate_domain() {
    local domain="$1"
    local regex="^([a-zA-Z0-9_-]+\.)+[a-zA-Z]{2,}$"

    if [[ $domain =~ $regex ]]; then
        return 0 # Valid domain
    else
        return 1 # Invalid domain
    fi
}

# Prompt for input
read -p "Enter your server's IP address or domain name: " server_input

# Check if it's a valid IP address or domain name
if validate_ip "$server_input"; then
    echo "You entered a valid IP address: $server_input"
elif validate_domain "$server_input"; then
    echo "You entered a valid domain name: $server_input"
else
    echo "Invalid input. Please enter a valid IP address or domain name."
    exit 1
fi

# Update and upgrade system
echo "Updating and upgrading system..."
sudo apt update && sudo apt upgrade

# Install required software
echo "Installing required software..."
sudo apt install sysbench iperf3 apache2-utils fio

# Prepare benchmark file for File Write
# Define the file name and content
FILE_NAME="disk_benchmark.fio"
CONTENT="[sequential-write]\nrw=write\nbs=1M\nsize=1G\ndirectory=/tmp"

# Check if the file already exists and prompt for overwrite if needed
if [ -e "$FILE_NAME" ]; then
    read -p "The file '$FILE_NAME' already exists. Overwrite? (Y/n): " OVERWRITE
    if [ "$OVERWRITE" != "Y" ] && [ "$OVERWRITE" != "y" ]; then
        echo "File not overwritten. Exiting."
        exit 1
    fi
fi

# Write the content to the file
echo -e "$CONTENT" > "$FILE_NAME"

echo "File '$FILE_NAME' created with the following content:"
cat "$FILE_NAME"

# Now run tests and capture results in log files
echo "Running benchmark tests..."
sysbench cpu --cpu-max-prime=20000 run > Sysbench_CPU_Test_Result.log
sysbench memory --memory-block-size=1M --memory-total-size=10G run > Sysbench_Mem_Test_Result.log
fio disk_benchmark.fio > FileIO_Test_Result.log
ab -n 1000 -c 100 http://$server_input/ > Web_Server_Test_Result.log

echo "Benchmark tests completed. Results are saved in log files."
