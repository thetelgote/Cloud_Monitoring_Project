#!/bin/bash

# -------- CONFIGURATION ------------
THRESHOLD_CPU=80
THRESHOLD_MEM=80
THRESHOLD_DISK=80
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/$(hostname)_syslog_$(date +'%Y-%m-%d_%H-%M-%S').log"
S3_BUCKET="s3://system-health-logs-sushant"  # Replace with your bucket name
SNS_TOPIC_ARN="arn:aws:sns:ap-south-1:123456789012:SystemAlert"  # Replace with your SNS Topic ARN
# -----------------------------------

mkdir -p "$LOG_DIR"

# ---- Collect OS Information ----
HOSTNAME=$(hostname)
OS_TYPE=$(uname -o)
OS_KERNEL=$(uname -r)
OS_ARCH=$(uname -m)
UPTIME_INFO=$(uptime -p)

# ---- Collect System Metrics ----
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')

# ---- Write to Log File ----
echo "---- System OS Information ----" >> "$LOG_FILE"
echo "Hostname: $HOSTNAME" >> "$LOG_FILE"
echo "OS Type: $OS_TYPE" >> "$LOG_FILE"
echo "Kernel Version: $OS_KERNEL" >> "$LOG_FILE"
echo "Architecture: $OS_ARCH" >> "$LOG_FILE"
echo "Uptime: $UPTIME_INFO" >> "$LOG_FILE"
echo "---------------------------------" >> "$LOG_FILE"

echo "---- System Health Report ----" >> "$LOG_FILE"
echo "Timestamp: $(date)" >> "$LOG_FILE"
echo "CPU Usage: ${CPU_USAGE}%" >> "$LOG_FILE"
echo "Memory Usage: ${MEM_USAGE}%" >> "$LOG_FILE"
echo "Disk Usage: ${DISK_USAGE}" >> "$LOG_FILE"
echo "---------------------------------" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# ---- Upload Log to S3 ----
aws s3 cp "$LOG_FILE" "$S3_BUCKET" --quiet

# ---- Alert if thresholds exceeded ----
CPU_INT=${CPU_USAGE%.*}
MEM_INT=${MEM_USAGE%.*}
DISK_INT=${DISK_USAGE%\%}

if (( CPU_INT > THRESHOLD_CPU )) || (( MEM_INT > THRESHOLD_MEM )) || (( DISK_INT > THRESHOLD_DISK )); then
    ALERT_MSG="⚠️ ALERT! $HOSTNAME CPU=${CPU_USAGE}% MEM=${MEM_USAGE}% DISK=${DISK_USAGE}"
    echo "$ALERT_MSG" >> "$LOG_FILE"
    aws sns publish --topic-arn "$SNS_TOPIC_ARN" --message "$ALERT_MSG" --subject "System Health Alert"
fi

# ---- Log Rotation: Keep last 7 days ----
find "$LOG_DIR" -type f -mtime +7 -name "*.log" -exec rm {} \;
