#!/usr/bin/env python

import sys
import os
import time
from string import *

# find tar files to load into hsi
jet_backup_dir = '/lfs4/BMC/amb-verif/backup'
for file in [f for f in os.listdir(jet_backup_dir) if f.endswith('.tar')]:
    print file
    full_path = jet_backup_dir+"/"+file
    print full_path
    db = split(file,".")[1]
    print db
    # create the directory (apparently returns no error if the db already exists)
    cmd = "hsi mkdir /BMC/wrfruc/5year/amb-verif/MySQL_backups/{db}".format(db=db)
    if os.system(cmd) != 0:
         print "error making directory!"
         sys.exit(1)
    cmd = "hsi put {full_path} : /BMC/wrfruc/5year/amb-verif/MySQL_backups/{db}/{file}".\
          format(full_path=full_path,file=file,db=db)
    print cmd
    if os.system(cmd) == 0:
        try:
            os.remove(full_path)
            pass
        except OSError as e:
            print "could not remove {}. error = {}".format(full_path,e)
    else:
        print "hsi storage failed"

    
