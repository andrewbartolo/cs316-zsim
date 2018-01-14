#!/bin/bash
#Tahrina Ahmed (tahrina@cs.stanford.ed)
#cacti run script for CS316 Winter 17-18

CACTI=/afs/ir/class/cs316/pa1/cacti65/cacti

set -e

debug() { echo "D> $*" 1>&2; }

usage() {
    if [ "$#" ]; then
        echo "$@"; echo
    fi
    cat <<EOF
Usage: gen_cacti.sh [options]
   -s <size in KB>
   -w <ways>
   -t <fast|normal|sequential>
EOF
    exit 1
}

TEMP=`getopt -l '' -o 's:w:t:' -- "$@"`

if [ $? != 0 ]; then usage "Error parsing arguments."; fi

eval set -- "$TEMP"

SIZE=0
WAYS=0
STYLE="normal"

while true; do
    case "$1" in
        -s) SIZE="$2"; shift 2 ;;
        -w) WAYS="$2"; shift 2 ;;
        -t) STYLE="$2"; shift 2 ;;
        --) shift; break ;;
        ?) usage ;;
    esac
done

## Input validation
validate() {
    if [ $1 -lt $2 -o $1 -gt $3 ]; then
        usage "$4 ($5) should be between $2 and $3."
    fi

    if [ "$6" ]; then
        if ! echo "l($1)/l(2)" | bc -l | grep -E '(00000000000|^0$)' > /dev/null; then
            usage "$4 ($5) should be a power of 2."
        fi
    fi
}

validate $SIZE 4 65536 "Size" "-s" 1
validate $WAYS 1 32 "Ways" "-w" 1

case "$STYLE" in
    normal|fast|sequential) ;;
    *) usage "Invalid style $STYLE." ;;
esac

mkdir ~/.cacti_cache 2> /dev/null || true

if [ -f ~/.cacti_cache/${SIZE}_${WAYS}_${STYLE} ]; then
    cat ~/.cacti_cache/${SIZE}_${WAYS}_${STYLE}
    exit
fi

trap "rm -f x.cfg x.out" EXIT

cat <<EOF > x.cfg
-size (bytes) $[SIZE*1024]
-block size (bytes) 64
-associativity ${WAYS}

-read-write port 1
-exclusive read port 0
-exclusive write port 0
-single ended read ports 0

-UCA bank count 0
//-technology (u) 0.032
-technology (u) 0.045
//-technology (u) 0.068
//-technology (u) 0.090

-page size (bits) 8192 
-burst length 8
-internal prefetch width 8

# following parameter can have one of five values -- (itrs-hp, itrs-lstp, itrs-lop, lp-dram, comm-dram)
//-Data array cell type - "comm-dram"
-Data array cell type - "itrs-hp"
//-Data array cell type - "itrs-lstp"
//-Data array cell type - "itrs-lop"

# following parameter can have one of three values -- (itrs-hp, itrs-lstp, itrs-lop)
-Data array peripheral type - "itrs-hp"
//-Data array peripheral type - "itrs-lstp"
//-Data array peripheral type - "itrs-lop"

# following parameter can have one of five values -- (itrs-hp, itrs-lstp, itrs-lop, lp-dram, comm-dram)
-Tag array cell type - "itrs-hp"
//-Tag array cell type - "itrs-lstp"

# following parameter can have one of three values -- (itrs-hp, itrs-lstp, itrs-lop)
-Tag array peripheral type - "itrs-hp"
//-Tag array peripheral type - "itrs-lstp"

# Bus width include data bits and address bits required by the decoder
-output/input bus width 256

-operating temperature (K) 350

-cache type "cache"

-tag size (b) "default"

# fast - data and tag access happen in parallel
# sequential - data array is accessed after accessing the tag array
# normal - data array lookup and tag access happen in parallel
#          final data block is broadcasted in data array h-tree 
#          after getting the signal from the tag array
//-access mode (normal, sequential, fast) - "fast"
//-access mode (normal, sequential, fast) - "normal"
-access mode (normal, sequential, fast) - "$STYLE"


# DESIGN OBJECTIVE for UCA (or banks in NUCA)
-design objective (weight delay, dynamic power, leakage power, cycle time, area) 0:0:0:0:100

# Percentage deviation from the minimum value 
# Ex: A deviation value of 10:1000:1000:1000:1000 will try to find an organization
# that compromises at most 10% delay. 
# NOTE: Try reasonable values for % deviation. Inconsistent deviation
# percentage values will not produce any valid organizations. For example,
# 0:0:100:100:100 will try to identify an organization that has both
# least delay and dynamic power. Since such an organization is not possible, CACTI will
# throw an error. Refer CACTI-6 Technical report for more details
-deviate (delay, dynamic power, leakage power, cycle time, area) 60:100000:100000:100000:1000000

# Objective for NUCA
-NUCAdesign objective (weight delay, dynamic power, leakage power, cycle time, area) 100:100:0:0:100
-NUCAdeviate (delay, dynamic power, leakage power, cycle time, area) 10:10000:10000:10000:10000

# Set optimize tag to ED or ED^2 to obtain a cache configuration optimized for
# energy-delay or energy-delay sq. product
# Note: Optimize tag will disable weight or deviate values mentioned above
# Set it to NONE to let weight and deviate values determine the 
# appropriate cache configuration
//-Optimize ED or ED^2 (ED, ED^2, NONE): "ED"
//-Optimize ED or ED^2 (ED, ED^2, NONE): "ED^2"
-Optimize ED or ED^2 (ED, ED^2, NONE): "NONE"

//-Cache model (NUCA, UCA)  - "UCA"
-Cache model (NUCA, UCA)  - "NUCA"

# In order for CACTI to find the optimal NUCA bank value the following
# variable should be assigned 0.
-NUCA bank count 4 

# NOTE: for nuca network frequency is set to a default value of 
# 5GHz in time.c. CACTI automatically
# calculates the maximum possible frequency and downgrades this value if necessary

# By default CACTI considers both full-swing and low-swing 
# wires to find an optimal configuration. However, it is possible to 
# restrict the search space by changing the signalling from "default" to 
# "fullswing" or "lowswing" type.
-Wire signalling (fullswing, lowswing, default) - "Global_10"
//-Wire signalling (fullswing, lowswing, default) - "default"
//-Wire signalling (fullswing, lowswing, default) - "lowswing"

-Wire inside mat - "global"
//-Wire inside mat - "semi-global"
-Wire outside mat - "global"

-Interconnect projection - "conservative"
//-Interconnect projection - "aggressive"

# Contention in network (which is a function of core count and cache level) is one of
# the critical factor used for deciding the optimal bank count value
# core count can be 4, 8, or 16
//-Core count 4
-Core count 8
//-Core count 16
-Cache level (L2/L3) - "L3"

-Add ECC - "true"

//-Print level (DETAILED, CONCISE) - "CONCISE"
-Print level (DETAILED, CONCISE) - "DETAILED"

# for debugging
-Print input parameters - "true"
//-Print input parameters - "false"
# force CACTI to model the cache with the 
# following Ndbl, Ndwl, Nspd, Ndsam,
# and Ndcm values
//-Force cache config - "true"
-Force cache config - "false"
-Ndwl 64
-Ndbl 64
-Nspd 64
-Ndcm 1
-Ndsam1 4
-Ndsam2 1
EOF

$CACTI -infile x.cfg > x.out

CYCLE_TIME=`grep "Cycle time" x.out | awk '{print $4}'`
ACCESS_TIME=`grep "Access time" x.out | awk '{print $4}'`
DYNAMIC_ENERGY=`grep "Total dynamic read energy per access" x.out | awk '{print $8}'`
STATIC_POWER=`grep "Total leakage power of a bank" x.out | awk '{print $8}'`
AREA=`grep "Cache height x width" x.out | awk '{print $6*$8}'`

# ns ns nJ mW mm^2
echo $SIZE $WAYS $STYLE $CYCLE_TIME $ACCESS_TIME $DYNAMIC_ENERGY $STATIC_POWER $AREA | tee ~/.cacti_cache/${SIZE}_${WAYS}_${STYLE}

# | tee cacti_cache/${SIZE}_${WAYS}_${STYLE}
