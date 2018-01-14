#!/bin/bash
#Tahrina Ahmed (tahrina@cs.stanford.edu)
#zsim run script for CS316 Winter 17-18

set -e

debug() { echo "D> $*" 1>&2; }

usage() {
    if [ "$@" ]; then
        echo "$@"; echo
    fi
    cat <<EOF
This script generates a zsim configuration and then submits a
simulation job to the cluster.

Usage: do_zsim.sh [options]
   -B                  (submit as a batch job and return)
   -S                  (print cache statistics and exit)
   -a <APPLICATION>    (blackscholes, fluidanimate, streamcluster, swaptions, art, mix)
   -b <narrow or wide> (choose the wide issue or narrow issue processor, default: wide)
   -f <frequency>      (in MHz, $FREQUENCY_MIN to $FREQUENCY_MAX, default: $FREQUENCY)
   -c <# of cores>     ($CORES_W_MIN to $CORES_W_MAX wide, $CORES_N_MIN to $CORES_N_MAX narrow, default: $CORES)
   -t <# of threads>   (1 to CORES), how many threads the app should use
   --l1size <# of kB>  ($L1SIZE_MIN to $L1SIZE_MAX, default: $L1SIZE)
   --l1ways <assoc.>   ($L1WAYS_MIN to $L1WAYS_MAX, default: $L1WAYS)
   --l2size <# of kB>  ($L2SIZE_MIN to $L2SIZE_MAX, default: $L2SIZE)
   --l2ways <assoc.>   ($L2WAYS_MIN to $L2WAYS_MAX, default: $L2WAYS)
   --l3size <# of kB>  ($L3SIZE_MIN to $L3SIZE_MAX, default: $L3SIZE)
   --l3ways <assoc.>   ($L3WAYS_MIN to $L3WAYS_MAX, default: $L3WAYS)
   --l3repl <policy.>  (LRU, NRU, Rand, default: LRU)
   --memranks <#>      (1-4, default: 2)
   --memtech <id>      (DDR3-800-CL5, DDR3-1333-CL10, DDR3-1600-CL11, default: DDR3-1066-CL8)
   --l3model           (nuca, uca, default: uca)

   Note: You may only submit a limited number of batch jobs at a time.
   Type "qstat" or "showq" to inspect the job queue, and use
   "qdel <JOB ID>" to delete a job.
EOF
    exit 1
}

JSUB_ARGS="-I"

APPLICATION=""
APP_PATH="/afs/ir/class/cs316/pa1/zsim-apps/build/parsec"

MAIN_PATH=/afs/ir/class/cs316/pa1

## default
CORES=8
FREQUENCY=2000
L1SIZE=32
L1WAYS=2
L2SIZE=512
L2WAYS=8
L3SIZE=8192
L3WAYS=16
L3REPL="LRU"
MEMRANKS=2
MEMTECH="DDR3-1066-CL8"
BINARY="wide"
L3MODEL="uca"

## bounds
CORES_W_MAX=8
CORES_W_MIN=1
CORES_N_MAX=16
CORES_N_MIN=1
FREQUENCY_MAX=5000
FREQUENCY_MIN=400
L1SIZE_MAX=128
L1SIZE_MIN=4
L1WAYS_MAX=8
L1WAYS_MIN=1
L2SIZE_MAX=32768
L2SIZE_MIN=256
L2WAYS_MAX=32
L2WAYS_MIN=1
L3SIZE_MAX=16384
L3SIZE_MIN=512
L3WAYS_MAX=32
L3WAYS_MIN=1
BINARY="wide"
L1MODEL="uca"
L2MODEL="uca"
L3MODEL="uca"


TEMP=`getopt -l 'l1size:,l2size:,l1ways:,l2ways:,l3size:,l3repl:,l3ways:,l1model:,l2model:,l3model:,memranks:,memtech:' -o 'ha:c:f:t:b:BS' -- "$@"`

if [ $? != 0 ]; then usage "Error parsing arguments."; fi

eval set -- "$TEMP"

while true; do
    case "$1" in
        -B) JSUB_ARGS=""; shift 1 ;;
        -S) STATS=1; shift 1 ;;
        -a) APPLICATION="$2"; shift 2 ;;
	-b) BINARY="$2"; shift 2 ;;
        -c) CORES="$2"; shift 2 ;;
        -f) FREQUENCY="$2"; shift 2 ;;
        --l1ways) L1WAYS="$2"; shift 2 ;;
        --l1size) L1SIZE="$2"; shift 2 ;;
	--l1model) L1MODEL="$2"; shift 2 ;;
        --l2ways) L2WAYS="$2"; shift 2 ;;
        --l2size) L2SIZE="$2"; shift 2 ;;
	--l2model) L2MODEL="$2"; shift 2 ;;
	--l3size) L3SIZE="$2"; shift 2 ;;
	--l3ways) L3WAYS="$2"; shift 2 ;;
	--l3repl) L3REPL="$2"; shift 2 ;;
	--l3model) L3MODEL="$2"; shift 2 ;;
	--memranks) MEMRANKS="$2"; shift 2;;
	--memtech) MEMTECH="$2"; shift 2;;
        -t) THREADS="$2"; shift 2 ;;
        --) shift; break ;;
        *) usage ;;
    esac
done

## Input validation
validate() {
    if [ $1 -lt $2 -o $1 -gt $3 ]; then
        usage "$4 ($5) should be between $2 and $3."
    fi

    if [ "$6" ] && [ "$5" != "--membw" ]; then
        if ! echo "l($1)/l(2)" | bc -l | grep -E '(00000000000|^0$)' > /dev/null; then
            usage "$4 ($5) should be a power of 2."
        fi
    fi
}

if [ "$BINARY" == "wide" ]; then
    validate $CORES $CORES_W_MIN $CORES_W_MAX "# of wide issue cores" "-c"
else
    validate $CORES $CORES_N_MIN $CORES_N_MAX "# of narrow issue cores" "-c"
fi

validate $FREQUENCY $FREQUENCY_MIN $FREQUENCY_MAX "Frequency" "-f"
validate $L1SIZE $L1SIZE_MIN $L1SIZE_MAX "L1 size" "--l1size" 1
validate $L1WAYS $L1WAYS_MIN $L1WAYS_MAX "L1 ways" "--l1ways" 1
validate $L2SIZE $L2SIZE_MIN $L2SIZE_MAX "L2 size" "--l2size" 1
validate $L2WAYS $L2WAYS_MIN $L2WAYS_MAX "L2 ways" "--l2ways" 1
validate $L3SIZE $L3SIZE_MIN $L3SIZE_MAX "L3 size" "--l3size" 1
validate $L3WAYS $L3WAYS_MIN $L3WAYS_MAX "L3 ways" "--l3ways" 1
#validate $MEMBW $MEMBW_MIN $MEMBW_MAX "mem bandwidth" "--membw" 1

if [ -z "$THREADS" ]; then THREADS=$CORES; fi
validate $THREADS 1 $CORES "# of threads" "-t"

#ART_IN=/hd/spec/omp2001_m/benchspec/OMPM2001/330.art_m/data/train/input
INDIR=$MAIN_PATH/input

case "$BINARY" in
    wide) ZSIM_CORE_TYPE="OOO" ;;
    narrow) ZSIM_CORE_TYPE="Timing" ;;
    *) usage "Specify valid core type (wide or narrow)"
esac

case "$APPLICATION" in
    blackscholes)  CMD="process0 = { command = \"$APP_PATH/blackscholes/blackscholes $THREADS 10000000\"; startFastForwarded = True; };" ;;
    swaptions)     CMD="process0 = { command = \"$APP_PATH/swaptions/swaptions -ns 128 -sm 1000000 -nt $THREADS\"; startFastForwarded = True; };" ;;
#    canneal)       CMD="$APP_PATH/canneal/canneal $THREADS 16384 2000 2500000.bnets 10000" ;;
    streamcluster) CMD="process0 = { command = \"$APP_PATH/streamcluster/streamcluster 10 20 128 1000000 200000 5000 none output.txt $THREADS\"; startFastForwarded = True; };" ;;
    fluidanimate)  CMD="process0 = { command = \"$APP_PATH/fluidanimate/fluidanimate $THREADS 500 $INDIR/in_300K.fluid out.fluid\"; startFastForwarded = True; };" ;;
    art)           CMD="process0 = { command = \"$APP_PATH/../specomp2001/art_m/art_m -scanfile $INDIR/c756hel.in -trainfile1 $INDIR/a10.img -stride 2 -startx 134 -starty 220 -endx 184 -endy 240 -objects 3\"; startFastForwarded = True; };" ;;
    mix)           CMD="process0 = { command = \"$APP_PATH/../specomp2001/art_m/art_m -scanfile $INDIR/c756hel.in -trainfile1 $INDIR/a10.img -stride 2 -startx 134 -starty 220 -endx 184 -endy 240 -objects 3\"; startFastForwarded = True; }; process1 = { command = \"$APP_PATH/../specomp2001/art_m/art_m -scanfile $INDIR/c756hel.in -trainfile1 $INDIR/a10.img -stride 2 -startx 134 -starty 220 -endx 184 -endy 240 -objects 3\"; startFastForwarded = True; }; process2 = { command = \"$APP_PATH/../specomp2001/art_m/art_m -scanfile $INDIR/c756hel.in -trainfile1 $INDIR/a10.img -stride 2 -startx 134 -starty 220 -endx 184 -endy 240 -objects 3\"; startFastForwarded = True; }; process3 = { command = \"$APP_PATH/../specomp2001/art_m/art_m -scanfile $INDIR/c756hel.in -trainfile1 $INDIR/a10.img -stride 2 -startx 134 -starty 220 -endx 184 -endy 240 -objects 3\"; startFastForwarded = True; }; process4 = { command = \"$APP_PATH/streamcluster/streamcluster 10 20 128 1000000 200000 5000 none output.txt $THREADS\"; startFastForwarded = True; };" ;;
#    artlarge)      CMD="$APP_PATH/../specomp2001/art_m/art_m -scanfile /hd/spec/omp2001_m/benchspec/OMPM2001/330.art_m/data/ref/input/c756hel.in -trainfile1 /hd/spec/omp2001_m/benchspec/OMPM2001/330.art_m/data/ref/input/a10.img -trainfile2 /hd/spec/omp2001_m/benchspec/OMPM2001/330.art_m/data/ref/input/hc.img -stride 1 -startx 110 -starty 220 -endx 172 -endy 260 -objects 1000" ;;
    *) usage "Specify valid application."
esac

TAG="${APPLICATION}_${BINARY}_${CORES}_${THREADS}_${FREQUENCY}_L1_${L1SIZE}_${L1WAYS}_${L1MODEL}_L2_${L2SIZE}_${L2WAYS}_${L2MODEL}_L3_${L3SIZE}_${L3WAYS}_${L3REPL}_${L3MODEL}_MEMRANKS_${MEMRANKS}_${MEMTECH}"

mkdir $TAG 2> /dev/null || true
cd $TAG

echo "Running CACTI to determine cache characteristics."

## Run CACTI 6.5 to get cache parameters
if [ "$L1MODEL" == "nuca" ]; then
   echo "Using NUCA cache model for L1."
   L1_CACTI=`$MAIN_PATH/bin/gen_cacti_nuca.sh -s $L1SIZE -w $L1WAYS`
else
   echo "Using UCA cache model for L1."
   L1_CACTI=`$MAIN_PATH/bin/gen_cacti.sh -s $L1SIZE -w $L1WAYS`
fi
if [ "$L2MODEL" == "nuca" ]; then
   echo "Using NUCA cache model for L2."
   L2_CACTI=`$MAIN_PATH/bin/gen_cacti_nuca.sh -s $L2SIZE -w $L2WAYS`
else
   echo "Using UCA cache model for L2."
   L2_CACTI=`$MAIN_PATH/bin/gen_cacti.sh -s $L2SIZE -w $L2WAYS`
fi
if [ "$L3MODEL" == "nuca" ]; then
   echo "Using NUCA cache model for L3."
   L3_CACTI=`$MAIN_PATH/bin/gen_cacti_nuca.sh -s $L3SIZE -w $L3WAYS`
else
   echo "Using UCA cache model for L3."
   L3_CACTI=`$MAIN_PATH/bin/gen_cacti.sh -s $L3SIZE -w $L3WAYS`
fi

# <size> <way> <type> <cycle time> <access time> <energy> <power> <area>
echo $L1_CACTI > cacti_L1.txt
echo $L2_CACTI > cacti_L2.txt
echo $L3_CACTI > cacti_L3.txt

L1_RATE=`echo $L1_CACTI | awk '{print int(1000/$4)}'`
L1_ACCESS=`echo $L1_CACTI | awk 'function ceil(x) { return (x==int(x)) ? x : int(x)+1 } { print ceil($5/(1000/'$FREQUENCY')) }'`
L2_ACCESS=`echo $L2_CACTI | awk 'function ceil(x) { return (x==int(x)) ? x : int(x)+1 } { print ceil($5/(1000/'$FREQUENCY')) }'`
L2_AREA=`echo $L2_CACTI | awk '{print $8}'`
L3_ACCESS=`echo $L3_CACTI | awk 'function ceil(x) { return (x==int(x)) ? x : int(x)+1 } { print ceil($5/(1000/'$FREQUENCY')) }'`
L3_AREA=`echo $L3_CACTI | awk '{print $8}'`
# Assume 70ns memory latency
MEM_LATENCY=`awk 'BEGIN { print int(70/(1000/'$FREQUENCY')) }'`
echo "ACCESS TIMES: L1=$L1_ACCESS L2=$L2_ACCESS L3=$L3_ACCESS"
if [ $L1_RATE -lt $FREQUENCY ]; then
    echo "Validation error."
    echo
    echo "The ${L1SIZE}k/${L1WAYS}-way L1 cache has a maximum clock rate of $L1_RATE MHz."
    echo "You asked for $FREQUENCY MHz.  Try a smaller cache or a slower clock."
    exit 1
fi

CORE_AREA=0 #$[10 * CORES]
CORE_VOLTAGE=0
if  [ "$BINARY" == "wide" ]; then
    CORE_AREA=`echo "(37.57 + $L2_AREA) * $CORES" | bc -l`
    CORE_VOLTAGE=`awk 'BEGIN { print '$FREQUENCY/1000' * .30914 + .552688 }'`
else
    CORE_AREA=`echo "(13 + $L2_AREA) * $CORES" | bc -l`
    CORE_VOLTAGE=`awk 'BEGIN { print '$FREQUENCY/1000' * .21967 + .66066 }'`
fi

TOTAL_AREA=`awk 'BEGIN { print int('$L3_AREA' + '$CORE_AREA')}'`

# Derived the area limit from max(8*wide_area, 16*narrow_area) with L1SIZE=32, L2SIZE = 256K, L3SIZE = 4M
if [ $TOTAL_AREA -gt 350 ]; then
    echo "Validation error."
    echo
    echo "The total area ($TOTAL_AREA mm^2) is larger than the area budget of 350mm^2."
    echo "Try reducing core count ($CORE_AREA mm^2) or L3 cache size ($L3_AREA mm^2)."
    exit 1
fi

if [ "$STATS" ]; then
    echo "# of cores: $CORES"
    echo "Frequency: $FREQUENCY"
    echo "Core voltage: $CORE_VOLTAGE"
    echo
    echo "L2 Area: $L2_AREA"
    echo "L3 Area: $L3_AREA"
    echo "Core area: $CORE_AREA"
    echo "Total area: $TOTAL_AREA"
    exit
fi

cat << EOF > zsim.cfg
sys = {
  frequency = $FREQUENCY;
  lineSize = 64;

  cores = {
    core = {
      type = "$ZSIM_CORE_TYPE";
      cores = $CORES;
      icache = "l1i";
      dcache = "l1d";
    };
  };

  caches = {
    l1i = {
      caches = $CORES;
      size = $[L1SIZE * 1024];
      array = {
        type = "SetAssoc";
        ways = $L1WAYS;
      };
      latency = 1;
    };

    l1d = {
      caches = $CORES;
      size = $[L1SIZE * 1024];
      array = {
        type = "SetAssoc";
        ways = $L1WAYS;
      };
      latency = $[1+L1_ACCESS];
    };

    l2 = {
      caches = $CORES;
      size = $[L2SIZE * 1024];
      latency = $[2+L2_ACCESS];
      array = {
        type = "SetAssoc";
        ways = $L2WAYS;
      };
      children = "l1i|l1d";
    };

    l3 = {
      caches = 1;
      size = $[L3SIZE * 1024];
      latency = $[5+L3_ACCESS];
      array = {
        type = "SetAssoc";
        ways = $L3WAYS;
      };
      repl = {
        type = "$L3REPL";
      };
      children = "l2";
    };
  };

  mem = {
    type = "DDR";
    controllers = 2;
    ranksPerChannel = $MEMRANKS;
    tech = "$MEMTECH";
  };
};

sim = {
  statsPhaseInterval = 0;
  phaseLength = 10000;
  maxTotalInstrs = 5000000000L;
  parallelism = 1;
};

$CMD

EOF

#process0 = {
#  command = "$CMD";
#  startFastForwarded = True;
#};


echo "Running zsim in $PWD."
echo "See zsim.out after completion for statistics."
echo

export OMP_NUM_THREADS=$THREADS

# Set up args for stats.sh
# <core type> <core voltage> <total area>
echo "$BINARY $CORE_VOLTAGE $TOTAL_AREA $L3SIZE $L3REPL $MEMRANKS $MEMTECH $APPLICATION" > stats_args.txt

jsub - I -q corn-cs316 -- /afs/ir/class/cs316/pa1/zsim_github/build/opt/zsim zsim.cfg; /afs/ir/class/cs316/pa1/bin/stats.sh | tee stats.txt
