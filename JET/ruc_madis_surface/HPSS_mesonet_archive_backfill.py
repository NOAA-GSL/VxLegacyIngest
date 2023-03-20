#!/usr/bin/python

import sys
import os
from datetime import date, timedelta

mesonet_dir = "/pan2/projects/nrtrr/amb-verif/mesonet_uselists/"

for yy in (2012,2013,2014,2015):
   for mm in (1,2,3,4,5,6,7,8,9,10,11,12):
      for dd in (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31):

         mesonet_file = "%04d"%yy + "-" + "%02d"%mm + "-" + "%02d"%dd + "_meso_uselist.txt"
         mesonet_path = mesonet_dir + mesonet_file

         print(mesonet_file)

         hpss_dir = "/5year/BMC/wrfruc/amb-verif/mesonet_uselists/"

         if os.path.isfile(mesonet_path) is True:

            msg = "Mesonet file exists. Archiving..."
            print(msg) 
  
            try:

               cmd = "/apps/hpss/hsi put " + mesonet_path + " : " + hpss_dir + mesonet_file
               print cmd
               os.system(cmd)

            except:

               msg = "ERROR: Archiving for " + str(mm) + "/" + str(dd) + "/" + str(yy) + " failed!"
               print(msg)

            else:

               msg = "SUCCESS: Archiving for " + str(mm) + "/" + str(dd) + "/" + str(yy) + " completed!"
               print(msg)

         else:

            msg = "ERROR: " + mesonet_path + " does not exist!"
            print(msg)


