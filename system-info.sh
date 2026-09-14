#!/bin/sh
echo "===CPU==="
top -bn1 2>/dev/null | head -5 | grep "Cpu(s)" || echo "Cpu(s): 0%id"
cat /proc/cpuinfo 2>/dev/null | grep "model name" | head -1 || echo "model name: Unknown"
nproc 2>/dev/null || echo 1
cat /proc/cpuinfo 2>/dev/null | grep -c "^processor" || echo 1
cat /proc/cpuinfo 2>/dev/null | grep "cpu MHz" | head -1 || echo "cpu MHz: 0"
cat /proc/loadavg 2>/dev/null || echo "0 0 0"
echo "===MEM==="
free -h 2>/dev/null | grep Mem || echo "Mem: 0 0 0 0 0 0"
free -h 2>/dev/null | grep Swap || echo "Swap: 0 0 0"
echo "===DISK==="
df -h 2>/dev/null | grep -E "^/dev" | head -10 || true
echo "===NET==="
ip -o link show 2>/dev/null | awk -F": " '{print $2}' | grep -v lo | head -1 || echo "eth0"
NET_IF=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
cat /sys/class/net/$NET_IF/statistics/rx_bytes 2>/dev/null || echo 0
cat /sys/class/net/$NET_IF/statistics/tx_bytes 2>/dev/null || echo 0
hostname -I 2>/dev/null | awk '{print $1}' || echo ""
echo "===GPU==="
nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader 2>/dev/null || echo "NO_NVIDIA"
lspci 2>/dev/null | grep -i vga | head -1 || echo ""
echo "===UPTIME==="
uptime -p 2>/dev/null || uptime 2>/dev/null || echo "unknown"
