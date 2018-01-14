tCK = [2.5, 1.875, 1.5, 1.25]
tRAS = [37.5, 37.5, 36, 35]
tRC = [50, 50.625, 49.5, 47.5]
tRFC = [110, 110, 110, 110]
tREFI = [7800, 7800, 7800, 7800]
IDD0 = [90, 100, 110, 120]
IDD2N = [50, 55, 65, 70]
IDD3N = [52, 57, 62, 67]
IDD4R = [130, 160, 200, 250]
IDD4W = [160, 160, 220, 250]
IDD5 = [200, 220, 240, 260]

memmap={'DDR3-800-CL5':0, 'DDR3-1066-CL8':1, 'DDR3-1333-CL10':2, 'DDR3-1600-CL11':3};

def calcmodel( memtype, num_rd, num_wr, T, static):
#    print("MODEL",memtype,num_rd,num_wr,T)
    T = T*1e9
    i = memmap[memtype]
    num_acc = num_rd+num_wr
    background = IDD3N[i] * num_acc * tRAS[i] + IDD2N[i] * ((32*T) - num_acc * tRAS[i])
    activate = (IDD0[i] * tRC[i] - IDD3N[i] * tRAS[i] - IDD2N[i] * (tRC[i] - tRAS[i])) * num_acc
    read = (IDD4R[i] - IDD3N[i]) * 4*tCK[i] * num_rd
    write = (IDD4W[i] - IDD3N[i]) * 4*tCK[i] * num_wr
    refresh = (IDD5[i] - IDD3N[i]) * tRFC[i] / tREFI[i] * (32*T)
#    print("BKG",background/1e12,"ACT",activate/1e12,"RD",read/1e12,"WR",write/1e12,"RFH",refresh)
#   return ((background+activate+read+write+refresh)*1.5)/1e12 # in joules
    if static:
        return (background*1.5)/1e12 # joules
    else:
        return ((activate+read+write+refresh)*1.5)/1e12 # joules


import sys
#print(sys.argv)
print(calcmodel(sys.argv[1],float(sys.argv[2]),float(sys.argv[3]),float(sys.argv[4]),sys.argv[5]=="true"))
