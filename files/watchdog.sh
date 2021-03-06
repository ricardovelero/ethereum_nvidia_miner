#!/bin/bash

# Watchdog for Cyclenerd/ethereum_nvidia_miner based on nvOC v0019-2.0 - Community Release by papampi, Stubo and leenoox
# https://github.com/papampi/nvOC_by_fullzero_Community_Release/blob/19.2/5watchdog

echo "Watchdog"

# Set higher process and disk I/O priorities because we are essential service
sudo renice -n -15 -p $$ && sudo ionice -c2 -n0 -p$$ >/dev/null 2>&1
sleep 1

# Load global settings settings.conf
if ! source ~/settings.conf; then
	echo "FAILURE: Cannot load global settings 'settings.conf'"
	exit 9
fi

export DISPLAY=:0

# Global Variables
THRESHOLD=80         # Minimum allowed % utilization before taking action

# Set higher process and disk I/O priorities because we are essential service
sudo renice -n -19 -p $$ >/dev/null 2>&1 && sudo ionice -c2 -n0 -p$$ >/dev/null 2>&1
sleep 1

# Initialize vars
REBOOTRESET=0
GPU_COUNT=$(nvidia-smi -i 0 --query-gpu=count --format=csv,noheader,nounits)
COUNT=$((6 * $GPU_COUNT))
# Track how many times we have restarted the miner/3main
RESTART=0
# Dynamic sleep time, dstm zm miner takes a very long time to load GPUs
SLEEP_TIME=$((($GPU_COUNT * 10 ) + 10 ))
numtest='^[0-9.]+$'

# Check if Miner is running
if [[ -z $(ps ax | grep -i miner.sh) ]]
then
  echo "WARNING: $(date) - Miner is not running, starting watchdog in 10 seconds to look for problems"
else
  echo "$(date) - Miner is running, waiting $SLEEP_TIME seconds before going 'on watch'"
  sleep $SLEEP_TIME
fi



# Main Loop [infinite]
while true; do

  # Echo status
  UTILIZATIONS=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
  echo "GPU UTILIZATION: " $UTILIZATIONS
  echo "      GPU_COUNT: " $GPU_COUNT
  echo " "

  # Set/increment vars
  NUM_GPU_BLW_THRSHLD=0              # Track how many GPU are below threshold
  REBOOTRESET=$(($REBOOTRESET + 1))

  # Loop over each GPU and check utilization
  for ((GPU=0;GPU < $GPU_COUNT;GPU++)); do
    { IFS=', ' read UTIL CURRENT_TEMP CURRENT_FAN PWRLIMIT POWERDRAW ; } < <(nvidia-smi -i $GPU --query-gpu=utilization.gpu,temperature.gpu,fan.speed,power.limit,power.draw --format=csv,noheader,nounits)

    # Numeric check: if any are not numeric, we have a mining problem

    # Workaround for 1050's reporting "[Not Supported]" or "[Unknown Error]" when power.draw is queried from nvidia-smi
    if [[ $(nvidia-smi -i $GPU --query-gpu=name --format=csv,noheader,nounits | grep "1050") ]]; then
      if ! [[ ( $UTIL =~ $numtest ) && ( $CURRENT_TEMP =~ $numtest ) && ( $CURRENT_FAN =~ $numtest ) && ( $PWRLIMIT =~ $numtest ) ]]; then
        # Not numeric so: Help we've lost a GPU, so reboot
        echo "$(date) - Lost GPU so restarting system. Found GPU's:" | tee -a ${LOG_FILE}
        echo ""
        # Hope PCI BUS info will help find the faulty GPU
        nvidia-smi --query-gpu=gpu_bus_id --format=csv | tee -a ${LOG_FILE}
        echo "$(date) - reboot in 10 seconds"  | tee -a ${LOG_FILE}
        echo ""
        if [[ $TELEGRAM_ALERTS == "YES" ]]; then
          bash '/home/m1/telegram'
        fi
        sleep 10
        sudo reboot
      elif [ $UTIL -lt $THRESHOLD ] # If utilization is lower than threshold, decrement counter
      then
        echo "$(date) - GPU $GPU under threshold found - GPU UTILIZATION:  " $UTIL  | tee -a ${LOG_FILE}
        COUNT=$(($COUNT - 1))
        NUM_GPU_BLW_THRSHLD=$(($NUM_GPU_BLW_THRSHLD + 1))
      fi
    else
      if ! [[ ( $UTIL =~ $numtest ) && ( $CURRENT_TEMP =~ $numtest ) && ( $CURRENT_FAN =~ $numtest ) && ( $POWERDRAW =~ $numtest ) && ( $PWRLIMIT =~ $numtest ) ]]; then
        # Not numeric so: Help we've lost a GPU, so reboot
        echo "$(date) - Lost GPU so restarting system. Found GPU's:" | tee -a ${LOG_FILE}
        echo ""
        # Hope PCI BUS info will help find the faulty GPU
        nvidia-smi --query-gpu=gpu_bus_id --format=csv | tee -a ${LOG_FILE}
        echo "$(date) - reboot in 10 seconds"  | tee -a ${LOG_FILE}
        echo ""
        if [[ $TELEGRAM_ALERTS == "YES" ]]; then
          bash '/home/m1/telegram'
        fi
        sleep 10
        sudo reboot
      elif [ $UTIL -lt $THRESHOLD ] # If utilization is lower than threshold, decrement counter
      then
        echo "$(date) - GPU $GPU under threshold found - GPU UTILIZATION:  " $UTIL
        COUNT=$(($COUNT - 1))
        NUM_GPU_BLW_THRSHLD=$(($NUM_GPU_BLW_THRSHLD + 1))
      fi
    fi

    sleep 0.2    # 0.2 seconds delay until querying the next GPU
  done

  # If we found at least one GPU below the utilization threshold
  if [ $NUM_GPU_BLW_THRSHLD -gt 0 ]
  then
    #echo "$(date) - Debug: NUM_GPU_BLW_THRSHLD=$NUM_GPU_BLW_THRSHLD, COUNT=$COUNT, RESTART=$RESTART, REBOOTRESET=$REBOOTRESET" | tee -a ${LOG_FILE}

    # Check for Internet and wait if down
    if ! nc -vzw1 google.com 443;
    then
      echo "WARNING: $(date) - Internet is down, checking..." | tee -a ${LOG_FILE}
    fi
    while ! nc -vzw1 google.com 443;
    do
      echo "WARNING: $(date) - Internet is down, checking again in 30 seconds..."
      sleep 30
      # When we come out of the loop, reset to skip additional checks until the next time through the loop
      if nc -vzw1 google.com 443;
      then
        echo "$(date) - Internet was down, Now it's ok" | tee -a ${LOG_FILE}
        REBOOTRESET=0; RESTART=0; COUNT=$((6 * $GPU_COUNT))
        #### Now that internet comes up check and restart miner if needed, no need to restart 3main, problem was the internet.
        if [[ -z $(ps ax | grep -i miner.sh) ]]
        then
          echo "$(date) - miner is not running, start miner"
          bash /home/prospector/miner.sh
          #wait for miner to start hashing
          sleep $SLEEP_TIME
        else
          echo "$(date) - miner is running, waiting $SLEEP_TIME seconds before going 'on watch'"
          sleep $SLEEP_TIME
        fi
      fi
    done

    # Look for no miner screen and get right to miner restart
    if [[ $(ps ax | grep miner.sh | wc -l) -eq 0 ]]
    then
      COUNT=0
      echo "WARNING: $(date) - Found no miner, jumping to 3main restart"
    fi

    # Percent of GPUs below threshold
    PCT_GPU_BAD=$((100 * NUM_GPU_BLW_THRSHLD / GPU_COUNT ))

    #  If we have had too many GPU below threshold over time OR
    #     we have ALL GPUs below threshold AND had at least (#GPUs + 1)
    #        occurrences of below threshold (2nd run through the loop
    #        to allow miner to fix itself)
    if [[ $COUNT -le 0 || ($PCT_GPU_BAD -eq 100 && $COUNT -lt $((5 * $GPU_COUNT))) ]]
    then
      # Get some some diagnostics to the logs before restarting or rebooting
      echo "" | tee -a ${LOG_FILE}; echo "" | tee -a ${LOG_FILE}
      echo "WARNING: $(date) - Problem found: See diagnostics below: " | tee -a ${LOG_FILE}
      echo "Percent of GPUs bellow threshold: $PCT_GPU_BAD %"  | tee -a ${LOG_FILE}
      echo "$(nvidia-smi --query-gpu=name,pstate,temperature.gpu,fan.speed,utilization.gpu,power.draw,power.limit --format=csv)" | tee -a ${LOG_FILE}
      #echo "$(tail -15 /home/m1/nvoc_logs/screenlog.0)" | tee -a ${LOG_FILE}


      # If we have had 4 miner restarts and still have low utilization
      if [[ $RESTART -gt 4 ]]
      then
        echo "CRITICAL: $(date) - Utilization is too low: reviving did not work so restarting system in 10 seconds" | tee -a ${LOG_FILE}
        echo ""
        if [[ $TELEGRAM_ALERTS == "YES" ]]; then
          bash '/home/m1/telegram'
        fi
        sleep 10
        sudo reboot
      fi

      # Kill the miner to be sure it's gone
      pkill -e miner.sh
      echo "CRITICAL: $(date) - GPU Utilization is too low: restarting 3main..." | tee -a ${LOG_FILE}
      if [[ $TELEGRAM_ALERTS == "YES" ]]; then
        bash '/home/m1/telegram'
      fi
      # Best to restart 1bash - settings might be adjusted already [Do we need this kill?]
      target=$(ps -ef | awk '$NF~"miner.sh" {print $2}')
      kill $target
      
      # Restar the miner screen
      screen -t miner bash "/home/prospector/miner.sh"

      RESTART=$(($RESTART + 1))
      REBOOTRESET=0
      COUNT=$GPU_COUNT

      # Give 3main time to restart to prevent reboot
      sleep $SLEEP_TIME
      echo "$(date) - Back 'on watch' after miner restart"
    else
      echo "$(date) - Low Utilization Detected: 3main will reinit if there are $COUNT consecutive failures"
      echo ""
    fi
    # No below threshold GPUs detected for this pass
  else
    # All is good, reset the counter
    COUNT=$((6 * $GPU_COUNT))
    echo "$(date) - No mining issues detected."

    # No need for a reboot after 5 times through the main loop with no issues
    if [ $REBOOTRESET -gt 5 ]
    then
      RESTART=0
      REBOOTRESET=0
    fi
  fi
  # Delay until next cycle
  sleep 10
done
