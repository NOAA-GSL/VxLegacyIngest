#!/usr/bin/python

import sys
import os
from datetime import date, timedelta

mesonet_dir = "/lfs1/BMC/amb-verif/"

mesonet_types = ['mesonet_uselists','hrrr_mesonet_uselists','rap_ops_mesonet_uselists','rtma_mesonet_uselists']
mesonet_models = ['meso','HRRR_meso','meso','RTMA_meso']

yesterday = date.today() - timedelta(1)

year = yesterday.year
month = yesterday.month
day = yesterday.day

for (types,model) in zip(mesonet_types,mesonet_models):

   mesonet_file = "%04d"%year + "-" + "%02d"%month + "-" + "%02d"%day + "_" + model + "_uselist.txt"
   mesonet_path = mesonet_dir + types + "/" + mesonet_file

   print(mesonet_path)

   hpss_dir = "/5year/BMC/wrfruc/amb-verif/" + types + "/"

   if os.path.isfile(mesonet_path) is True:

      msg = "Mesonet file exists. Archiving..."
      print(msg) 
  
      try:

         cmd = "/apps/hpss/hsi put " + mesonet_path + " : " + hpss_dir + mesonet_file
         print cmd
         os.system(cmd)

      except:

         msg = "ERROR: Archiving for " + str(month) + "/" + str(day) + "/" + str(year) + " failed!"
         print(msg)

      else:

         msg = "SUCCESS: Archiving for " + str(month) + "/" + str(day) + "/" + str(year) + " completed!"
         print(msg)

   else:

      msg = "ERROR: " + mesonet_path + " does not exist!"
      print(msg)


