#!/usr/bin/env python
###################
#
# Name: mvprocessing.py
#
# Description: script for loading MET output into GSD databases using mv_load
#
# Requirments: MUST have METViewer installed on the same system
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20181219
#
#   UPDATED: added logic to handle METviewer 2.10
#      - Jeff Hamilton 20190603
#
#   UPDATED: added logic to handle METviewer 2.11
#      - Jeff Hamilton 20190809
###################

import commands
import filecmp
import fileinput
import re 
import os
import shutil
import socket 
import sys
import smtplib
import subprocess
import xml.etree.ElementTree as ET

from datetime import date, time, datetime, timedelta
from email.mime.base import MIMEBase
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText
from email.utils import COMMASPACE, formatdate
from email import encoders
from os import stat
from pwd import getpwuid

######################################################################
def find_owner(filename):
  owner = getpwuid(stat(filename).st_uid).pw_name
  return str(owner)

#------------------------ main ---------------------------------#

myhostname = socket.gethostname()
startdt = datetime.utcnow()
startstr = startdt.strftime( '%Y/%m/%d %H:%M' )
print( "\n START: " + str(startstr) + " on " + str(myhostname) )

maintainers = "jeffrey.a.hamilton@noaa.gov"

# Grab environmental variables

year = os.getenv("YEAR")
month = os.getenv("MONTH")
day = os.getenv("DAY")
valid_time = os.getenv("HOUR")

cycle = "%4d%02d%02d-%02dz" % (int(year),int(month),int(day),int(valid_time)) 

rt_dir = os.getenv("REALTIMEDIR")
models = (os.getenv("MODELS")).split()
model_dirs = (os.getenv("DATA_DIRS")).split()
data_type_dirs = (os.getenv("DATA_TYPE")).split()

metviewer_root = os.getenv("METVIEWER_DIR")
mvloader_root = os.getenv("MVLOADER_DIR")

cfg_dir = os.getenv("CFG_DIR")
cfg_file = os.getenv("CFG_XML")
cfg_xml = cfg_dir + "/" + cfg_file

print( "\n metviewer root: " + metviewer_root ) 
print( "\n mv_load root: " + mvloader_root )
print( "\n Running for date " + cycle )
print( "\n Models to verify: " + str(models) )

if os.path.isfile(cfg_xml) is True:
  print ( "\n Using this template XML file: " + cfg_xml )
else:
  print ( "\n FATAL ERROR: " + cfg_xml + " doesn't exist. Exiting.." )
  sys.exit

for (model,model_dir) in zip(models,model_dirs):
 for data_type in data_type_dirs:
  work_dir = "%s/%s/%s/%s/tmp" % (rt_dir,model_dir,cycle,data_type)
  data_dir = "%s/%s" % (rt_dir,model_dir)
  work_xml = "%s_%s" % (model,cfg_file)  

  os.system('mkdir -p %s' % work_dir)

  os.chdir(work_dir)
  print( "\n changing to work dir: " + work_dir )
  
  print( "\n creating work XML file: " + work_xml )
  cmd = "cp %s %s" % (cfg_xml,work_xml)
  print(cmd)
  os.system(cmd)

# List files in this configuration's path
  names = []
  allnames = os.listdir( "." )
  for n in allnames:
    if os.path.isfile(n) is True:
      if (not n[0:1] == '.') and (cfg_file in n) and (not "withpwd" in n):
        names.append(n)
  
  names.sort()   
  #print( "names: " + str(names) )
  numnames = len(names)
  print( "  processing " + str(numnames) + " xml files found in " + work_dir )
  i = int(0)
  for name in names:
    print( "    chdir( " + work_dir + " )" )
    os.chdir( work_dir )
    #print( "    pwd: " + str(os.getcwd()) )

    i = i + int(1)
    print( "  " + str(i) + " of " + str(numnames) + ": " + name )

    basename = os.path.basename(name)
    src = work_dir + "/" + basename
    print( "    src = " + src )

    owner = find_owner(src)
    print( "    owner = " + owner )

    xmltype = '' 
    xmlbytag = {}
    organization = 'unknown' 
    try:
      xmltree = ET.parse(src)
      xmlroot = xmltree.getroot()
      xmltype = xmlroot.tag
      for e in xmlroot:
        xmlbytag[e.tag] = e.text
      database = xmltree.find( "connection/database" )
      xmlbytag['database'] = database.text
      organization = xmlbytag['organization'] 
    except:
      print( "    error parsing xmlfile  " + src )
      continue 

    exception_lockfile = str(organization) + "_exception_email_lock_" + name
    exception_lockfile = exception_lockfile.replace( ".xml", ".txt" )

    workpath = work_dir
    try:
      workpath = xmlbytag['workpath'] 
    except:
      pass

    reload_interval = int(sys.maxint)
    try:
      reload_interval = int(xmlbytag['reload_interval'])
    except:
      pass

    drop_database = False 
    try:
      drop_database = bool(xmlbytag['drop_database'])
    except:
      pass

    mvhost = '127.0.0.1'
    # assume mysql in on default 3306
    mvport = '3306'
    mvhostname = 'localhost'
    metviewer_root = "/home/amb-verif/metviewer/v2.7/metviewer"

    if organization == "gsddev":
        mvhostname = 'metvgsddev'
        if xmltype == 'plot_spec': 
          # plot specs will be processed locally (137.75.x.y) -- DB is on 3306
          mvhost = '137.75.133.51'
        else:
          # dtgi
          mvhost = '137.75.133.134'
          mvport = '3310'
          #mvhost = '137.75.133.51'
          #mvport = '3306'
        metviewer_root = "/home/amb-verif/metviewer/v2.8_gsddev/metviewer"

    if organization == "gsd":
        if xmltype == 'plot_spec': 
          # plot specs will be processed locally (137.75.x.7) -- DB is on 3306
          mvhost = '137.75.133.81'
        else:
          # dtgi
          mvhost = '137.75.133.134'
          mvport = '3309'
        mvhostname = 'metvgsd'
        metviewer_root = "/home/amb-verif/metviewer/v2.11_int/metviewer"
        #metviewer_root = "/home/amb-verif/metviewer/v2.7_gsd/metviewer"
        #metviewer_root = "/home/amb-verif/metviewer/v2.10_int/metviewer"

    if organization == "emc":
        if xmltype == 'plot_spec': 
          # plot specs will be processed locally (137.75.x.y)
          mvhost = '137.75.133.52'
        else:
          # dtgi
          mvhost = '137.75.133.134'
          mvport = '3311'
          #mvhost = '137.75.133.52'
        mvhostname = 'metvemc'
        metviewer_root = "/home/amb-verif/metviewer/v2.7_emc/metviewer"
        #metviewer_root = "/home/amb-verif/metviewer/v2.10_int/metviewer"

    if organization == "vxt":
        if xmltype == 'plot_spec': 
          # plot specs will be processed locally (137.75.x.y)
          mvhost = '137.75.129.120'
        else:
          # dtgi
          mvhost = '137.75.133.134'
        # mysql is 3312 on model-vxtest  (3306 was for a legacy connection)
        mvport = '3312'
        mvhostname = 'model-vxtest'
        metviewer_root = "/home/amb-verif/metviewer/v2.11_int/metviewer"
        #metviewer_root = "/home/amb-verif/metviewer/v2.8_vxt/metviewer"
        #metviewer_root = "/home/amb-verif/metviewer/v2.10_int/metviewer"

    if mvhost == '127.0.0.1':
        exceptemail_msg = exceptemail_msg + " organization " + str(organization) + " not supported by this MV version!"
        print(exceptemail_msg)
        continue 

    met_admin_cfgfile =  mvloader_root + "/" + str(organization) + "_met_admin_my.cnf"

    email = 'unknown' 
    try:
      email = xmlbytag['email'] 
    except:
      pass

    initdb = False 
    try:
      test = xmlbytag['initialize_db'] 
      if 'true' in test.lower():
        initdb = True 
    except:
      pass

    deletedata = False 
    try:
      test = xmlbytag['delete_data'] 
      if 'true' in test.lower():
        deletedata = True 
    except:
      pass

    db_schema_prefix = 'mv_mysql' 
    try:
      db_schema_prefix = xmlbytag['db_schema_prefix'] 
      schema_file =  metviewer_root + "/sql/" + db_schema_prefix + ".sql"
      if os.path.isfile( schema_file ) is False:
        print( "    could not find db schema file " + schema_file )
        continue 
    except:
      pass

    dbname = 'unknownDBname'
    try:
      dbname = xmlbytag['database'] 
      # enforce naming convention expected by MV java code -- the user may not know or might forget to add it
      if dbname[0:3] != "mv_":
         dbname = "mv_" + dbname
    except:
      continue

    db_fix_script = 'None'
    try:
      db_fix_script = xmlbytag['db_fix_script'] 
    except:
      pass

    apply_indexes_found = False 
    try:
      test = xmlbytag['apply_indexes'] 
      if 'true' in test.lower():
        apply_indexes_found= True 
    except:
      pass

    execute_apply_indexes_found = False 
    try:
      test = xmlbytag['execute_apply_indexes'] 
      if 'true' in test.lower():
        execute_apply_indexes_found= True 
    except:
      pass

    if email == 'unknown':
      print( "  could not find email in xml file " + str(src) )
      continue 

    if organization == 'unknown':
      print( "  could not find organization in xml file " + str(src) )
      continue 

    if apply_indexes_found == False and execute_apply_indexes_found == True:
      print( "   found execute_apply_indexes True while apply_indexes is False in xml file " + str(src) + " -- creating exception_lockfile " + str(exception_lockfile) )
      continue 

    metadminpwd = "could_not_read_met_admin_cfgfile"
    fin4 = fileinput.input( met_admin_cfgfile )
    for line in fin4:
       line = line.replace( "\n", "")
       if 'password=' in line:
         line = line.replace( "password=", "")
         line = line.replace( " ", "", 100 )
         line = line.replace( "\"", "", 100 )
         line = line.replace( "&", "&#38;" )
         metadminpwd = line 
    fin4.close()

    dest = os.path.basename(src)
    try:
      if os.path.exists(src) is True and os.path.exists(dest) is True:
        state = filecmp.cmp( src, dest )
        if state is False:
          shutil.copyfile( src, dest )
      else:
        shutil.copyfile( src, dest )
          #os.chmod( dest, 0o644 )
    except:
      print( "    exception running-- shutil.copyfile( " + src + ", " + dest + " )" )
      continue 

    dest = "withpwd_" + dest 
    try:
      if os.path.exists(src) is True and os.path.exists(dest) is True:
        if filecmp.cmp( src, dest ) is False:
          shutil.copyfile( src, dest )
      else:
        shutil.copyfile( src, dest )
    except:
      print( "    exception running-- shutil.copyfile( " + src + ", " + dest + " )" )

    utcnow = datetime.utcnow()
    try:
      destfp = open( dest, 'w' )
      fin5 = fileinput.input( src )
      for line in fin5:
        line = line.replace( "\n", "")
        hostandport = mvhost + ":" + mvport
        line = line.replace( "MVHOST", hostandport )
        line = line.replace( "DATABASE_NAME", dbname )
        line = line.replace( "MVUSERPWD", metadminpwd )
        line = line.replace( "MVUSER", "met_admin" )
        line = line.replace( "{DATA_DIR}", data_dir)
        line = line.replace( "{DATA_TYPE}", data_type)
        line = line.replace( "{CYCLE_DIR}", cycle)
  
        line = line.replace( "\n", "")
        db = ['','']
        daysback = int(0)
        if re.search( 'DAYSBACK', line ):
            db = line.split( 'DAYSBACK(' )
            #print( "db is " + str(db) )
            if re.search( '\)', str(db[1]) ):
                (daysback, junk) = db[1].split( ")" )
                #print( "daysback is " + str(daysback) )
            daysback = int(daysback)
            #print( "daysback is " + str(daysback) )
            td = timedelta( days=daysback )
            #print( "td is " + str(td) )
            ymd = utcnow + td
            ymd = ymd.replace(hour=0, minute=0, second=0, microsecond=0)
            if xmltype == 'plot_spec': 
               #<val name="2018-07-10 00:00:00" />
               ymd = ymd.strftime( '%Y-%m-%d %H:%M:%S' )
            else:
               ymd = ymd.strftime( '%Y%m%d' )
            val = "DAYSBACK(" + str(daysback) + ")"
            #print( "ymd is " + ymd )
            #print( "val is " + val )
            line = line.replace( val, ymd )

        line = line + "\n"
        destfp.write(line)
      destfp.close()
      fin5.close()
      # set perms to 'read/write' for user only to prevent end users from viewing the database credentials
      os.chmod( dest, 0o600 )
    except:
      print( "Metviewer data loader error: could not open destination file " + dest )
   
    enddt = datetime.utcnow()
    endstr = enddt.strftime( '%Y/%m/%d %H:%M' )
    endutc = enddt.strftime( '%s' )
    if organization == "gsddev":
       weblink = "https://www.esrl.noaa.gov/gsd/metvgsddev/?utc=" + str(endutc) + "&db=" + dbname + "\n"
    if organization == "gsd":
       weblink = "https://www.esrl.noaa.gov/gsd/metvgsd/?utc=" + str(endutc) + "&db=" + dbname + "\n"
    if organization == "emc":
       weblink = "https://www.esrl.noaa.gov/gsd/metvemc/?utc=" + str(endutc) + "&db=" + dbname + "\n"
    if organization == "vxt":
       weblink = "http://137.75.129.120:8080/metviewer/?utc=" + str(endutc) + "&db=" + dbname + "\n"

    if xmltype == 'load_spec': 
       cmd = mvloader_root + "/" + str(organization) + "_mv_load.py " + metviewer_root + " " + mvloader_root + " " + dbname + " " + workpath + " " + owner + " " + dest + " " + str(initdb) + " " + str(db_schema_prefix) + " " + str(execute_apply_indexes_found)  + " " + str(db_fix_script) + " " + str(drop_database)
       if drop_database is False:
          email_body = "Metviewer case " + name + " is being loaded into database " + dbname + " on mvhost " + str(mvhostname) + " from host " + str(myhostname) + "\n"
          doneemail_body = "Metviewer case " + name + " has been loaded into database " + dbname + " on mvhost " + str(mvhostname) + " from host " + str(myhostname) + " -- see " + str(weblink)
          doneemail_msg_subject = "Metviewer case " + name + " loaded"
          erroremail_msg_subject = "Metviewer case " + name + " load error"
          erroremail_body = "An error was detected while loading metviewer case " + name + " into database " + dbname + " from host " + str(myhostname) + "\n\n  -- see " + str(weblink)
       else:
          email_body = "Metviewer case " + name + " dropping database " + dbname + " on mvhost " + str(mvhostname) + " from host " + str(myhostname) + "\n"
          doneemail_body = "Metviewer case " + name + " has been dropped from database " + dbname + " on mvhost " + str(mvhostname) + " from host " + str(myhostname) + " -- see " + str(weblink)
          doneemail_msg_subject = "Metviewer case " + name + " database dropped"
          erroremail_msg_subject = "Metviewer case " + name + " database drop error"
          erroremail_body = "An error was detected while dropping metviewer case " + name + " database " + dbname + " from host " + str(myhostname) + "\n\n  -- see " + str(weblink)

          email_msg.attach( MIMEText(email_body, 'plain') )
          email_msg = email_msg.as_string()
          server = smtplib.SMTP( 'localhost' )
          server.sendmail( fromaddr, [toaddr, maintainers], email_msg )

       print( "    Running: " + cmd )
       result = commands.getstatusoutput( cmd )
       #print( "     -- result: " )
       for line in result:
          print( str(line) )

     #  retval = result[0]
     #  print( "retval = " + str(retval) )
     #  mvlresult = str(result[1]).split("|")
     #  print( "mvlresult = " + str(mvlresult) )
     #  mvlretval = mvlresult[0]
     #  print( "mvlretval = " + str(mvlretval) )
     #  error_filename = mvlresult[1]
     #  print( "    error filename = " + str(error_filename) )

     #  if int(mvlretval) == 0:
     #     print( "    Successfully completed: " + str(cmd) )
     #     print( "    Removing password xml file: " + str(dest))
     #     os.system('rm -f %s' % str(dest))
     #  else:
     #     print( "    ERROR running:" + str(cmd) )
     #     print( "     -- retval = " + str(retval) )
     #     print( "     -- mvlretval = " + str(mvlretval) )

  enddt = datetime.utcnow()
  endstr = enddt.strftime( '%Y/%m/%d %H:%M' )
  print( "---- finished ----- " + str(endstr) + " on " + str(myhostname) )
    
#except:
#    exceptemail = MIMEMultipart()
#    exceptemail['Subject'] = "process_mv_loadrequests.py EXCEPTION on host " + str(myhostname)
#    exceptemail_body = "Processing started at " + str(startstr) + "\n"
#    exceptemail_body = exceptemail_body + "\n\n" + str(sys.exc_info()) + "\n-------\n"
#  
#    exceptemail.attach( MIMEText(exceptemail_body, 'plain') )
#    exceptemail = exceptemail.as_string()
#    server = smtplib.SMTP( 'localhost' )
#    server.sendmail( fromaddr, maintainers, exceptemail )
