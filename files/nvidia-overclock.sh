#!/usr/bin/env bash

#
# nvidia-overclock.sh
# Author: Nils Knieling - https://github.com/Cyclenerd/ethereum_nvidia_miner
#
# Overclocking with nvidia-settings
#

# Load global settings settings.conf
if ! source ~/settings.conf; then
	echo "FAILURE: Can not load global settings 'settings.conf'"
	exit 9
fi

export DISPLAY=:0

#Common commands
NVD=nvidia-settings
SMI="sudo nvidia-smi"

#Declare variables
typeset -i i GPUS

# Determine the number of available GPU's
GPUS=$(nvidia-smi -i 0 --query-gpu=count --format=csv,noheader,nounits)

echo -e "Detected: $GPUS GPU's"
echo ""

# Loop to setup found gpus
for ((MY_DEVICE=0;MY_DEVICE<=GPUS;++MY_DEVICE))
do
        # Check if card exists
        if ${SMI} -i $MY_DEVICE >> /dev/null 2>&1; then
                ${NVD} -a "[gpu:$MY_DEVICE]/GPUPowerMizerMode=1"
                # Manual Fan speed
                ${NVD} -a "[gpu:$MY_DEVICE]/GPUFanControlState=1"
                ${NVD} -a "[fan:$MY_DEVICE]/GPUTargetFanSpeed=$MY_FAN"
                # Graphics clock
                ${NVD} -a "[gpu:$MY_DEVICE]/GPUGraphicsClockOffset[2]=$MY_CLOCK"
                # Memory clock
                ${NVD} -a "[gpu:$MY_DEVICE]/GPUMemoryTransferRateOffset[2]=$MY_MEM"
                # Set watt/powerlimit. This is also set in miner.sh at autostart.
                ${SMI} -i "$MY_DEVICE" -pl "$MY_WATT"
        fi
done

echo
echo "Done"
echo
