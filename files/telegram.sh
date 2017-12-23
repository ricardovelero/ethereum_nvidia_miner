

SYSTEM_BOOT_TIME=$(uptime -s)

SYSTEM_UP_TIME=$(uptime -p)

GPU_COUNT=$(nvidia-smi -L | tail -n 1| cut -c 5 |awk '{ SUM += $1+1} ; { print SUM }')

MINER_UP_TIME=$(ps -p `pgrep miner` -o etime | grep -v ELAPSED)

CURRENTLY_MINING=$(ps aux | grep miner)

GPU_UTILIZATIONS=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)

TEMP=$(/usr/bin/nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

PD=$(/usr/bin/nvidia-smi --query-gpu=power.draw --format=csv,noheader)

FAN=$(/usr/bin/nvidia-smi --query-gpu=fan.speed --format=csv,noheader)

CURRENTHASH=`/usr/bin/curl -s http://localhost:3333 | sed '/Total/!d; /Speed/!d;' | awk '{print $6}' | awk 'NR == 3'`

LF=$'\n'

MSG=" Worker: $WORKERNAME
Current Hashrate: $CURRENTHASH
System Boot Time: $SYSTEM_BOOT_TIME
System Up Time: $SYSTEM_UP_TIME
Miner Uptime: $MINER_UP_TIME
GPU Count: $GPU_COUNT
$LF GPU_UTILIZATIONS: $GPU_UTILIZATIONS
$LF TEMPS: $TEMP
$LF POWERDRAW: $PD
$LF FAN SPEEDS: $FAN
$LF $CURRENTLY_MINING"

/usr/bin/curl -m 5 -s -X POST --output /dev/null https://api.telegram.org/bot${APIKEY}/sendMessage -d "text=${MSG}" -d chat_id=${CHATID}
