#!/usr/bin/python
import sys 
import os 
from time import gmtime,strftime
#from datetime import datetime,timedelta
import datetime
import smtplib
from  subprocess import Popen,PIPE
import StringIO


def check_model(day,julian_day,regional,model):

    if regional == 1:
       if model == 'HRRR':
          gribfile = '/lfs3/BMC/nrtrr/' + model + '/run/' + day + '/postprd/wrfprs_hrconus_00.grib2'
       else:
          gribfile = '/lfs3/BMC/nrtrr/' + model + '/cycle/' + day + '/postprd/wrfprs_rr_00.grib2'
    elif regional == 2:
       gribfile = '/pan2/projects/fim-njet/' + model + '/FIMrun_jet_p/' + day + '/post_C/fim/NAT/grib2/' + julian_day + '000000'
    else:
       gribfile = '/pan2/projects/fim-njet/' + model + '/FIMrun/' + day + '/post_C/fim/NAT/grib2/' + julian_day + '000000'

    check_file = os.path.exists(gribfile)

    if check_file is not False:
       return 0
    else:
       return 1

global_job_list= [ 'FIM7','FIMX' ]   
main_global_job_list= [ 'FIM8','FIM9' ]   
regional_job_list= [ 'HRRR','RAP' ]   

mail_out_header = StringIO.StringIO()
print >>mail_out_header, """\
To: %(recipients)s
From: (Checking model runs on Jet) amb-verif@localhost""" % {
  'recipients':
  'jeffrey.a.hamilton@noaa.gov,bonny.strong@noaa.gov'
  }
mail_bad_data = StringIO.StringIO()
mail_good_data = StringIO.StringIO()

today_time = datetime.datetime.utcnow()
one_day = datetime.timedelta(days=1)
yesterday_time = today_time - one_day

date = yesterday_time.strftime('%Y%m%d')
julian = yesterday_time.strftime('%y%j')

global_cycles = [ '00','12' ]
regional_cycles = [ '00','01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16','17','18','19','20','21','22','23' ]

some_bad=0
bad = 1

for cycle in global_cycles:
    day = date + cycle
    julian_day = julian + cycle
    print day
    regional = 0
    for model in global_job_list:
        result = check_model(day,julian_day,regional,model)
        if result is bad  :
           some_bad += 1
           print >>mail_bad_data, " JET: '%s' model has failed. Cycle: '%s' " % (model,day),
           print >>mail_bad_data, ""
        else:
           print >>mail_good_data, "JET: '%s' model has completed. Cycle: '%s'" % (model,day),
           print >>mail_good_data, ""

for cycle in global_cycles:
    day = date + cycle
    julian_day = julian + cycle
    print day
    regional = 2
    for model in main_global_job_list:
        result = check_model(day,julian_day,regional,model)
        if result is bad  :
           some_bad += 1
           print >>mail_bad_data, " JET: '%s' model has failed. Cycle: '%s' " % (model,day),
           print >>mail_bad_data, ""
        else:
           print >>mail_good_data, "JET: '%s' model has completed. Cycle: '%s'" % (model,day),
           print >>mail_good_data, ""

for cycle in regional_cycles:
    day = date + cycle
    julian_day = julian + cycle
    print day
    regional = 1
    for model in regional_job_list:
        result = check_model(day,julian_day,regional,model)
        if result is bad  :
           some_bad += 1
           print >>mail_bad_data, " JET: '%s' model has failed. Cycle: '%s' " % (model,day),
           print >>mail_bad_data, ""
        else:
           print >>mail_good_data, "JET: '%s' model has completed. Cycle: '%s'" % (model,day),
           print >>mail_good_data, ""

# mail the results to 'recipients'
if some_bad > 0:
  print >>mail_out_header,  """Subject: WARNING: some Jet model runs have failed

"""
  p = Popen(["/usr/sbin/sendmail","-t"],stdin=PIPE)
  print >>p.stdin, mail_out_header.getvalue(), mail_bad_data.getvalue()
  mail_bad_data.close()
else:
  print >>mail_out_header, \
        "Subject: GOOD: No Jet model runs have failed\n\nGOOD: No Jet model runs have failed"
  p = Popen(["/usr/sbin/sendmail","-t"],stdin=PIPE)
  print >>p.stdin, mail_out_header.getvalue(), mail_good_data.getvalue()
  mail_good_data.close()

mail_out_header.close()

