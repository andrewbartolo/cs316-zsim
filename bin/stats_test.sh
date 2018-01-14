#!/bin/bash
#Tahrina Ahmed (tahrina@cs.stanford.edu)
#stats collector script for CS316 Winter 17-18

set -e

CORES=`grep 'cores = .*;' zsim.cfg | awk '{print $3}' | cut -f1 -d \;`
#L3_SIZE=`pwd | grep -oPh 'l3size_(.)*' | cut -d'_' -f2`
L3_SIZE=`cut -f4 -d " " stats_args.txt`
#L3_REPLACEMENT=`pwd | grep -oPh 'rep_(.)*' | cut -d'_' -f2`
L3_REPLACEMENT=`cut -f5 -d " " stats_args.txt`
#DRAM_RANKS=`pwd | grep -oPh 'ranks_(.)*' | cut -d'_' -f2`
DRAM_RANKS=`cut -f6 -d " " stats_args.txt`
DRAM_TECH=`cut -f7 -d " " stats_args.txt`
APP=`cut -f8 -d " " stats_args.txt`
DRAM_BANKS=`cut -f9 -d " " stats_args.txt`
FREQUENCY=`grep frequency zsim.cfg | awk '{print $3}' | cut -f1 -d \;`
BINARY=`cut -f1 -d " " stats_args.txt`
VOLTAGE=`cut -f2 -d " " stats_args.txt`
TOTAL_AREA=`cut -f3 -d " " stats_args.txt`
TOTAL_INST=`grep 'instrs:' zsim.out | cut -f5 -d " " | paste -sd+ | bc`
MISS1=`sed -n -e '/l3:/,$p' zsim.out | grep 'mGETS:' | cut -f5 -d " "`
MISS2=`sed -n -e '/l3:/,$p' zsim.out | grep 'mGETXIM:' | cut -f5 -d " "`
MISS3=`sed -n -e '/l3:/,$p' zsim.out | grep 'mGETXSM:' | cut -f5 -d " "`
MPKI=`echo "(($MISS1+$MISS2+$MISS3)*1000)/$TOTAL_INST" | bc -l`

I_leak=0
if [ "$BINARY" == "wide" ]; then
    I_leak=1.3136495
else
    I_leak=0.45455
fi

L1_ENERGY=`cut -f6 -d " " cacti_L1.txt`
L1_POWER=`cut -f7 -d " " cacti_L1.txt`
L2_ENERGY=`cut -f6 -d " " cacti_L2.txt`
L2_POWER=`cut -f7 -d " " cacti_L2.txt`
L2_AREA=`cut -f8 -d " " cacti_L2.txt`
L3_ENERGY=`cut -f6 -d " " cacti_L3.txt`
L3_POWER=`cut -f7 -d " " cacti_L3.txt`
L3_AREA=`cut -f8 -d " " cacti_L3.txt`

#INSTRUCTIONS=`grep instrs heartbeat | head -1 | awk '{print $1}'`
INSTRUCTIONS=`awk '/instrs/ { sum += $2 } END { print sum }' zsim.out`
CYCLES=`grep 0\ cycles\$ heartbeat | head -1 | awk '{print $1}'`
CORE_CYCLES=`grep core\ cycles\$ heartbeat | head -1 | awk '{print $1}'`

echo "CYCLES = $CYCLES"

TIME=`echo $CYCLES / $FREQUENCY / 1000000 | bc -l`

CORE_DYN_ENERGY=0
CORE_STA_ENERGY=0
if [ "$BINARY" == "wide" ]; then
    CORE_DYN_ENERGY=`echo "2.22/10^9*$INSTRUCTIONS*($VOLTAGE/1.35)^2" | bc -l` #J
    CORE_STA_ENERGY=`echo $I_leak*$VOLTAGE*$TIME*$CORES | bc -l` #j
else
    CORE_DYN_ENERGY=`echo ".78/10^9*$INSTRUCTIONS*($VOLTAGE/1.16)^2" | bc -l` # J
    CORE_STA_ENERGY=`echo $I_leak*$VOLTAGE*$TIME*$CORES | bc -l` # J
fi

L1_hGETS=`grep hGETS zsim.out | head -$[2*CORES] | awk '{sum += $2} END {print sum}'`
L1_hGETX=`grep hGETX zsim.out | head -$[2*CORES] | awk '{sum += $2} END {print sum}'`
L1_mGETS=`grep mGETS zsim.out | head -$[2*CORES] | awk '{sum += $2} END {print sum}'`

L1_DYN_ENERGY=`echo "($L1_hGETS+$L1_hGETX+$L1_mGETS)*$L1_ENERGY/1000000000" | bc -l`
L1_STA_ENERGY=`echo "$CORES*$L1_POWER/1000*$TIME" | bc -l`

tmp_L2_hGETS=`grep hGETS zsim.out | head -$[3*CORES] | awk '{sum += $2} END {print sum}'`
L2_hGETS=$[tmp_L2_hGETS - L1_hGETS]
tmp_L2_hGETX=`grep hGETX zsim.out | head -$[3*CORES] | awk '{sum += $2} END {print sum}'`
L2_hGETX=$[tmp_L2_hGETX - L1_hGETX]
tmp_L2_mGETS=`grep mGETS zsim.out | head -$[3*CORES] | awk '{sum += $2} END {print sum}'`
L2_mGETS=$[tmp_L2_mGETS - L1_mGETS]

L2_DYN_ENERGY=`echo "($L2_hGETS+$L2_hGETX+$L2_mGETS)*$L2_ENERGY/1000000000" | bc -l`
L2_STA_ENERGY=`echo "$CORES*$L2_POWER/1000*$TIME" | bc -l`

L3_hGETS=`grep hGETS zsim.out | tail -1 | awk '{print $2}'`
L3_hGETX=`grep hGETX zsim.out | tail -1 | awk '{print $2}'`
L3_mGETS=`grep mGETS zsim.out | tail -1 | awk '{print $2}'`

L3_DYN_ENERGY=`echo "($L3_hGETS+$L3_hGETX+$L3_mGETS)*$L3_ENERGY/1000000000" | bc -l`
L3_STA_ENERGY=`echo "$L3_POWER/1000*$TIME" | bc -l`

MEM_RD=`grep -w rd zsim.out | awk '{print $2}' | paste -sd+ | bc`
MEM_WR=`grep -w wr zsim.out | awk '{print $2}' | paste -sd+ | bc`

#MEM_DYN_ENERGY=`echo "200/10^9*($MEM_RD+$MEM_WR)" | bc -l`
#MEM_STA_ENERGY=`echo "50.63 / 1000 * $TIME" | bc -l`

#echo "python /afs/ir/class/cs316/pa2/bin/mem.py $DRAM_TECH $MEM_RD $MEM_WR $TIME"
MEM_DYN_ENERGY=`python /file0/bartolo/CS316/cs316/pa1/bin/mem.py $DRAM_TECH $MEM_RD $MEM_WR $TIME false`
MEM_STA_ENERGY=`python /file0/bartolo/CS316/cs316/pa1/bin/mem.py $DRAM_TECH $MEM_RD $MEM_WR $TIME true`

TOTAL_ENERGY=`echo $CORE_DYN_ENERGY+$CORE_STA_ENERGY+$L1_DYN_ENERGY+$L1_STA_ENERGY+$L2_DYN_ENERGY+$L2_STA_ENERGY+$L3_DYN_ENERGY+$L3_STA_ENERGY+$MEM_DYN_ENERGY+$MEM_STA_ENERGY | bc -l`
EDP=`echo $TOTAL_ENERGY*$TIME | bc -l`

#echo "App, Cores, L3size, l3replacement, dram_ranks, dram_banks, dram_tech, Frequency_MHz, Area_mm2, Time_s, Total_Energy_J, EDP, MPKI, dram_energy"
#echo "$APP, $CORES, $L3_SIZE, $L3_REPLACEMENT, $DRAM_RANKS, $DRAM_BANKS, $DRAM_TECH, $FREQUENCY, $TOTAL_AREA, $TIME, $TOTAL_ENERGY, $EDP, $MPKI, $MEM_FANCY_ENERGY"

echo "Cores                  : $CORES"
echo "Frequency (MHz)        : $FREQUENCY"
echo "Voltage (V)            : $VOLTAGE"
echo "Area (mm^2)            : $TOTAL_AREA"
echo
echo "Time (s)               : $TIME"
echo "Total energy (J)       : $TOTAL_ENERGY"
echo "Energy-Delay Product   : $EDP"
echo
echo "Core dynamic energy (J): $CORE_DYN_ENERGY"
echo "Core static energy (J) : $CORE_STA_ENERGY"
echo "L1 dynamic energy (J)  : $L1_DYN_ENERGY"
echo "L1 static energy (J)   : $L1_STA_ENERGY"
echo "L2 dynamic energy (J)  : $L2_DYN_ENERGY"
echo "L2 static energy (J)   : $L2_STA_ENERGY"
echo "L3 dynamic energy (J)  : $L3_DYN_ENERGY"
echo "L3 static energy (J)   : $L3_STA_ENERGY"
echo "Mem dynamic energy (J) : $MEM_DYN_ENERGY"
echo "Mem static energy (J)  : $MEM_STA_ENERGY"
