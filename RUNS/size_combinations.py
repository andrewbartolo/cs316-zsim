#!/file0/bartolo/usr/bin/python3.5

# NOTE - this assumes powers-of-2 only
# NOTE - all sizes in KiB
# NOTE - 12MiB = 12288 KiB

l1sizes = [1, 2, 4, 8, 16, 32, 64, 128]
l2sizes = [256, 512, 1024, 2048, 4096, 8192, 16384, 32768]
l3sizes = [512, 1024, 2048, 4096, 8192, 16384, 32768]

combs = []
for l1s in l1sizes:
    for l2s in l2sizes:
        for l3s in l3sizes:
             combs.append((l1s, l2s, l3s))

print(len(combs)) 

# TODO - assuming increased cache size always outweighs the delay below...
filtered_combs = [tup for tup in combs if 4*8*tup[0] + 8*tup[1] + tup[2] == 12288]
print(len(filtered_combs))

for tup in filtered_combs:
     print("L1: %dK; L2: %dK; L3: %dK" % tup)
