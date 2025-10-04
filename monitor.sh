#!/bin/bash

# -------- CONFIGURATION ------------
THRESHOLD_CPU=80
THRESHOLD_MEM=80
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/system_health_$(date +'%Y-%m-%d_%H-%M-%S').log"
S3_BUCKET="s3://system-health-logs-sushant"  # Replace with your bucket name
# -----------------------------------

mkdir -p "$LOG_DIR"

# Collect system metrics
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')

# Write data to log file
echo "---- System Health Report ----" >> "$LOG_FILE"
echo "Timestamp: $(date)" >> "$LOG_FILE"
echo "CPU Usage: ${CPU_USAGE}%" >> "$LOG_FILE"
echo "Memory Usage: ${MEM_USAGE}%" >> "$LOG_FILE"
echo "Disk Usage: ${DISK_USAGE}" >> "$LOG_FILE"
echo "---------------------------------" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Upload log file to AWS S3
aws s3 cp "$LOG_FILE" "$S3_BUCKET" --quiet

# Alert if threshold exceeded
if (( ${CPU_USAGE%.*} > THRESHOLD_CPU )) || (( ${MEM_USAGE%.*} > THRESHOLD_MEM )); then
    echo "⚠️ High usage alert! CPU=${CPU_USAGE}% MEM=${MEM_USAGE}%" >> "$LOG_FILE"
fi
