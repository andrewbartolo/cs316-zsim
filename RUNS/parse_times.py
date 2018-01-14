#!/file0/bartolo/usr/bin/python3.5

print("Parsing times...")

time = 0.0
with open('stats.txt') as f:
     statsLines = list(f)
     timeStr = statsLines[5].split()[3]
     time = float(timeStr)


print("Time was %f" % time)
