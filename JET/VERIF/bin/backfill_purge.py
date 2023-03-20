#!/usr/bin/env python
#=====================================================================================

import MySQLdb
import os
import sys
import calendar
from datetime import datetime
from datetime import timedelta

def main():
    Year         = os.getenv("YEAR")
    Month        = os.getenv("MONTH")
    Day          = os.getenv("DAY")
    Hour         = os.getenv("HOUR")

    rt_dir       = os.getenv("REALTIMEDIR")
    models       = (os.getenv("MODELNAMES")).split()
    modelfiles   = (os.getenv("MODELDIRS")).split()
    
    # Use built-in Date/Time modules
    t = datetime(int(Year),int(Month),int(Day),int(Hour))

    for (model,modelfile) in zip(models,modelfiles):
        vx_dir = '%s/%s/%4d%02d%02d-%02dz/' % \
            (rt_dir,modelfile,t.year,t.month,t.day,t.hour)

        try:
          cmd = 'rm -rf %s' % vx_dir
          print cmd
          os.system(cmd) 
        except:
          print('Cannot delete %s data for %4d%02d%02d%02d' % (model,t.year,t.month,t.day,t.hour))               

#-----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()
