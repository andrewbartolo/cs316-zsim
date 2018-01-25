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
# (2, 8, 16)-way

#####

# Gonna define these up here, and then use throughout
L1S = 8
L2S = 256
L3S = 8192 #8192

L1W = 1
L2W = 8
L3W = 32

L3P = 'LRU'
L3M = 'uca'

#####

COMBINED_SCRIPT = '/file0/bartolo/CS316/cs316/pa1/zsim.sh'

# ferret is currently broken
apps = ['blackscholes', 'streamcluster', 'swaptions', 'art', 'mix']
l3repls = ['LRU', 'NRU', 'Rand']
l3models = ['uca', 'nuca']


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

# Wrapper to validate a config
# TODO: dedup w/Sim()
# TODO: validating requires app parameter; same result for all apps?
def Validate(l1size, l1ways, l2size, l2ways, l3size, l3ways, l3repl, l3model):
     return [COMBINED_SCRIPT, '-S', '-a', apps[0], '-t', '8', '--l1size', str(l1size),'--l1ways', str(l1ways), '--l2size', str(l2size), '--l2ways', str(l2ways), '--l3size', str(l3size), '--l3ways', str(l3ways), '--l3repl', l3repl, '--l3model', l3model]

def FolderName(app, l1size, l1ways, l2size, l2ways, l3size, l3ways, l3repl, l3model):
     '''
     Example:
     streamcluster_wide_8_8_2000_L1_32_2_uca_L2_512_8_uca_L3_8192_16_LRU_uca_MEMRANKS_2_DDR3-1066-CL8
     '''
     return app + '_wide_8_8_2000_L1_' + str(l1size) + '_' + str(l1ways) + '_uca_L2_' + str(l2size) + '_' + str(l2ways) + '_uca_L3_' + str(l3size) + '_' + str(l3ways) + '_' + l3repl + '_' + l3model + '_MEMRANKS_2_DDR3-1066-CL8'

# Returns a short info string for the config (across all apps)
# TODO convert to '-'.join() (cleaner)
def ShortName(l1size, l1ways, l2size, l2ways, l3size, l3ways, l3repl, l3model):
    return str(l1size) + '-' + str(l1ways) + '-' + str(l2size) + '-' + str(l2ways) + '-' + str(l3size) + '-' + str(l3ways) + '-' + l3repl + '-' + l3model

if os.path.isfile('TOTALS/' + ShortName(L1S, L1W, L2S, L2W, L3S, L3W, L3P, L3M)):
    print("You've already evaluated that configuration!")
    print("Check the TOTALS directory.")
    sys.exit(0)

print("Beginning zsim parameter sweep...")

# Should be synchronous. Prints to stdout by default.
valid = os.system(' '.join(Validate(L1S, L1W, L2S, L2W, L3S, L3W, L3P, L3M)))

if (valid != 0):
     print("CACTI validation error; exiting...")
     sys.exit(0)
else:
     print("CACTI validation complete.")


pipes = []
folderNames = []
for app in apps:
    pipes.append(subprocess.Popen(Sim(app, L1S, L1W, L2S, L2W, L3S, L3W, L3P, L3M)))
    folderNames.append(FolderName(app, L1S, L1W, L2S, L2W, L3S, L3W, L3P, L3M))

for p in pipes:
    p.wait()
    #pass

print("Sim batch complete; aggregating stats...")

sumTimes = 0.0
for f in folderNames:
    path = f + '/stats.txt'
    with open(path) as fd:
         statsLines = list(fd)
         timeStr = statsLines[5].split()[3]
         time = float(timeStr)
         print(time)
         sumTimes = sumTimes + time

# Write a the single sum line to a file
sn = ShortName(L1S, L1W, L2S, L2W, L3S, L3W, L3P, L3M)
print("Total runtime for %s was %f." % (sn, sumTimes))
with open('TOTALS/' + sn, 'w') as f:
    f.write(str(sumTimes) + '\n')

pipes = []
folderNames = []

print("Done.")
