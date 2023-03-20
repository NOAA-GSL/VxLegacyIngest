#!/usr/bin/python
import sys
import time

try:
    hrs_ago = abs(int(sys.argv[1]))
    #print('hours ago: {}'.format(hrs_ago))
except IndexError:
    hrs_ago=0
    
run_time1 = time.time() - hrs_ago*3600
# put on 12-hour boundary
run_time1 -= run_time1 % (12*3600)
print("{:.0f}".format(run_time1))

