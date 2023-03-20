#!/usr/bin/env python
#=====================================================================================

import os
import sys
from datetime import datetime

def main():
    Year         = os.getenv("YEAR")
    Month        = os.getenv("MONTH")
    Day          = os.getenv("DAY")
    Hour         = os.getenv("HOUR")

    rt_dir       = os.getenv("REALTIMEDIR")
    hpss_dir     = os.getenv("HPSSDIR")
    vx_type      = os.getenv("VERIFTYPE")
    models       = (os.getenv("MODELNAMES")).split()
    
    # Use built-in Date/Time modules
    for model in models:
        pull_dir = '%s/%s/%s' % (hpss_dir,vx_type,model)
        pull_file = '%s%s%s%s.tgz' % (Year,Month,Day,Hour)
        vx_dir = '%s/%s/%s/backfill/%4d%02d%02d-%02dz' % (rt_dir,vx_type,model,int(Year),int(Month),int(Day),int(Hour))
        sub_dir_model = '%s/%s/%s/realtime/%4d%02d%02d-%02dz' % (rt_dir,vx_type,model,int(Year),int(Month),int(Day),int(Hour))
        sub_dir_vx = '%s/%s/%svStageIV/realtime/%4d%02d%02d-%02dz' % (rt_dir,vx_type,model,int(Year),int(Month),int(Day),int(Hour))

        cmd = 'mkdir -p %s' % vx_dir
        print cmd
        os.system(cmd)

        os.chdir(vx_dir)

        try:
          cmd = '/apps/hpss/hsi get %s/%s' % (pull_dir,pull_file)
          print cmd
          os.system(cmd)

          cmd = 'tar -xvf %s' % pull_file
          print cmd
          os.system(cmd)

          cmd = 'cd %s/%s' % (vx_dir,sub_dir_model)
          print cmd
          os.chdir('%s/%s' % (vx_dir,sub_dir_model))

          cmd = 'mv * %s' % vx_dir
          print cmd
          os.system(cmd)

          cmd = 'cd %s/%s' % (vx_dir,sub_dir_vx)
          print cmd
          os.chdir('%s/%s' % (vx_dir,sub_dir_vx))

          cmd = 'mv * %s' % vx_dir
          print cmd
          os.system(cmd)

        except:

          cmd = 'Cannot grab data for %s on %s%s%s%s' % (model,Year,Month,Day,Hour)
          print cmd

#-----------------------------------end------------------------------------------------

if __name__ == "__main__":
    main()