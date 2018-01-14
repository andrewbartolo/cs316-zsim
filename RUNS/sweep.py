#!/file0/bartolo/usr/bin/python3.5

import sys, os
import subprocess

#####

# Turns out the only three configs to fit *precisely* within the 12MiB envelope are:
# (note: this assumes power-of-two sizes only)
# (also note: CACTI might not validate all of these for n-way)
#
# L1: 64K; L2: 256K; L3: 8192K
# L1: 64K; L2: 1024K; L3: 2048K
# L1: 128K; L2: 512K; L3: 4096K

# Defaults: L1: 32K; L2: 512K; L3: 8192K

#####

# Gonna define these up here, and then use throughout
L1S = 32
L2S = 512
L3S = 8192

L3P = 'Rand'
L3M = 'nuca'

#####

'''
Example command:
     ./zsim.sh -a blackscholes -c 8 -t 8 --l1size 32 --l1ways 2 --l2size 512 --l2ways 8 --l3size 8192 --l3ways 16 --l3repl LRU --memranks 2 --l3model uca
     or, better,
     ./zsim.sh -a blackscholes -t 8 --l1size 32 --l1ways 2 --l2size 512 --l2ways 8 --l3size 8192 --l3ways 16 --l3repl LRU --l3model uca
'''

# Wrapper method to name some of the sim parameters
# Fix num. threads at 8 (optimal perf. except on art)
def Sim(app, l1size, l1ways, l2size, l2ways, l3size, l3ways, l3repl, l3model):
     return [COMBINED_SCRIPT, '-a', app, '-t', '8', '--l1size', str(l1size),'--l1ways', str(l1ways), '--l2size', str(l2size), '--l2ways', str(l2ways), '--l3size', str(l3size), '--l3ways', str(l3ways), '--l3repl', l3repl, '--l3model', l3model]

def FolderName(app, l1size, l1ways, l2size, l2ways, l3size, l3ways, l3repl, l3model):
     '''
     Example:
     streamcluster_wide_8_8_2000_L1_32_2_uca_L2_512_8_uca_L3_8192_16_LRU_uca_MEMRANKS_2_DDR3-1066-CL8
     '''
     return app + '_wide_8_8_2000_L1_' + str(l1size) + '_' + str(l1ways) + '_uca_L2_' + str(l2size) + '_' + str(l2ways) + '_uca_L3_' + str(l3size) + '_' + str(l3ways) + '_' + l3repl + '_' + l3model + '_MEMRANKS_2_DDR3-1066-CL8'

# Returns a short info string for the config (across all apps)
def ShortName(l1size, l1ways, l2size, l2ways, l3size, l3ways, l3repl, l3model):
    return str(l1size) + '-' + str(l1ways) + '-' + str(l2size) + '-' + str(l2ways) + '-' + str(l3size) + '-' + str(l3ways) + '-' + l3repl + '-' + l3model

COMBINED_SCRIPT = '/file0/bartolo/CS316/cs316/pa1/zsim.sh'
# Not currently used
MAX_CONCURRENT_JOBS = 8

#apps = ['blackscholes', 'ferret', 'streamcluster', 'swaptions', 'art', 'mix']
# ferret is currently broken
apps = ['blackscholes', 'streamcluster', 'swaptions', 'art', 'mix']
l3repls = ['LRU', 'NRU', 'Rand']
l3models = ['uca', 'nuca']



print("Beginning zsim parameter sweep...")

pipes = []
folderNames = []
for app in apps:
    # TODO
    # TODO parameterize args (ways)
    pipes.append(subprocess.Popen(Sim(app, L1S, 2, L2S, 8, L3S, 16, L3P, L3M)))
    folderNames.append(FolderName(app, L1S, 2, L2S, 8, L3S, 16, L3P, L3M))

print("Sim batch complete; aggregating stats...")
#sys.exit(0)

for p in pipes:
    p.wait()
    #pass

sumTimes = 0.0
for f in folderNames:
    path = f + '/stats.txt'
    with open(path) as fd:
         statsLines = list(fd)
         timeStr = statsLines[5].split()[3]
         time = float(timeStr)
         print(time)
         sumTimes = sumTimes + time

# TODO parameterize args (ways)
sn = ShortName(L1S, 2, L2S, 8, L3S, 16, L3P, L3M)
print("Total runtime for %s was %f." % (sn, sumTimes))
# Write a the single sum line to a file
with open('TOTALS/' + sn, 'w') as f:
    f.write(str(sumTimes) + '\n')

pipes = []
folderNames = []

print("Done.")
