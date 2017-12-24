################################# GPU Info ######################################
GPUinfo()
{
   # Get device IDs
   DEVICE_IDS=$(nvidia-smi --query-gpu=pci.sub_device_id --format=csv,noheader,nounits)
   i=0

   echo ""
   echo "ID,VENDOR,MODEL,PSTATE,TEMP,FAN,UTILIZATION,POWER,POWERLIMIT,MAXPOWER,GPUCLOCK,MEMCLOCK"
   echo "--------------------------------------------------------------------------------"              
   
   for ID in $DEVICE_IDS
   do
      # Get vendor id substring
      VENDOR_ID=${ID:6:5}
      
      # GPU Query, 3842=EVGA, 1462=MSI, 10DE=Nvidia, 19DA=Zotac, 807D=Asus, 1458=Gigabyte
      case $VENDOR_ID in
         3842) VENDOR_ID="EVGA";;
         1462) VENDOR_ID="MSI";;
         10DE) VENDOR_ID="NVIDIA";;
         19DA) VENDOR_ID="ZOTAC";;
         807D|1043) VENDOR_ID="ASUS";;
         1458) VENDOR_ID="GIGABYTE";;
         196E) VENDOR_ID="PNY";;
         1569) VENDOR_ID="PALIT";;
      esac
      
      # Get most GPU info here
      { IFS=', ' read PSTATE CURRENT_TEMP CURRENT_FAN UTILIZATION PWRLIMIT POWERDRAW; } < <(nvidia-smi -i $i --query-gpu=pstate,temperature.gpu,fan.speed,utilization.gpu,power.limit,power.draw --format=csv,noheader,nounits)
      
      # Some GPU info requires special tactics
      MODEL=$(nvidia-smi -i $i --query-gpu=name --format=csv,noheader,nounits | tail -1)
      POWERMAX=$(nvidia-smi -i $i -q|grep "Max Power"|cut -f 2 -d ":"|cut -f 2 -d " ")
      GPUCLOCK=$(nvidia-smi -i $i -q -d CLOCK |grep Graphics |head -1|cut -f 2 -d ":"|cut -f 2 -d " ")
      MEMCLOCK=$(nvidia-smi -i $i -q -d CLOCK |grep Memory |head -1|cut -f 2 -d ":"|cut -f 2 -d " ")
      
      # Memory clock display on Nvidia X Server Settings is doubled
      #   uncomment this line if you want it displayed that way 
#      MEMCLOCK=$(($MEMCLOCK * 2))

      echo "$i, $VENDOR_ID, $MODEL, $PSTATE, $CURRENT_TEMP, $CURRENT_FAN, $UTILIZATION, $POWERDRAW, $PWRLIMIT, $POWERMAX, $GPUCLOCK, $MEMCLOCK"
      
      i=$(($i + 1))
   done
}
