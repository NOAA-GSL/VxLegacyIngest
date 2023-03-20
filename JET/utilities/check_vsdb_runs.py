#!/usr/bin/python
import sys 
import os 
from time import gmtime,strftime
#from datetime import datetime,timedelta
import datetime
import smtplib
from  subprocess import Popen,PIPE
import StringIO


def check_vsdb(day,model,cycle):

    vsdbfile = '/pan2/projects/wrfruc/amb-verif/VRFY/nwpvrfy_hiwpp_realtime_' + cycle + '/stats/' + day + '/' + model + '/anom/' + model + '_' + day + '.vsdb'

    check_file_exists = os.path.exists(vsdbfile)
 
    if check_file_exists is not False:
 
       check_file = os.stat(vsdbfile).st_size
 
       if check_file == 0:
          return 1
       else:
          return 0

    else:
       return 1

model_list= [ 'FIM8','FIM9' ]   

mail_out_header = StringIO.StringIO()
print >>mail_out_header, """\
To: %(recipients)s
From: (Checking VSDB jobs on Jet) amb-verif@localhost""" % {
  'recipients':
  'jeffrey.a.hamilton@noaa.gov'
  }
mail_bad_data = StringIO.StringIO()
mail_good_data = StringIO.StringIO()

today_time = datetime.datetime.utcnow()
one_day = datetime.timedelta(days=2)
yesterday_time = today_time - one_day

date = yesterday_time.strftime('%Y%m%d')

cycles = [ '00','12' ]

some_bad=0
bad = 1

for cycle in cycles:
    day = date + cycle
    print day
    for model in model_list:
        result = check_vsdb(day,model,cycle)
        if result is bad:
           some_bad += 1
           print >>mail_bad_data, " JET: '%s' VSDB generation has failed. Cycle: '%s' " % (model,day),
           print >>mail_bad_data, ""
        else:
           print >>mail_good_data, "JET: '%s' VSDB generation has completed. Cycle: '%s'" % (model,day),
           print >>mail_good_data, ""

# mail the results to 'recipients'
if some_bad > 0:
  print >>mail_out_header,  """Subject: WARNING: some Jet VSDB jobs have failed

"""
  p = Popen(["/usr/sbin/sendmail","-t"],stdin=PIPE)
  print >>p.stdin, mail_out_header.getvalue(), mail_bad_data.getvalue()
  mail_bad_data.close()
#else:
#  print >>mail_out_header, \
#        "Subject: GOOD: No Jet VSDB jobs have failed\n\nGOOD: No Jet VSDB jobs have failed"
#  p = Popen(["/usr/sbin/sendmail","-t"],stdin=PIPE)
#  print >>p.stdin, mail_out_header.getvalue(), mail_good_data.getvalue()
#  mail_good_data.close()

mail_out_header.close()

