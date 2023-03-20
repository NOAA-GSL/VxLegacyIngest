#!/usr/bin/python
import sys 
import os 
from time import gmtime,strftime
from datetime import datetime,timedelta
import smtplib
from  subprocess import Popen,PIPE
import StringIO


def check_workflow(today,row):
    model=row[0]
    verif_type=row[1]
    error=row[2]

    if model == 'FIM8':
       machine = '_sjet'
#    if model == 'FIM9':
#       machine = '_ujet'
    if model == 'FIM7' or model == 'FIMX' or model == 'FIM9':
       machine = ''
 
    logfile = '/pan2/projects/fim-njet/' + model + '/FIMwfm/log/workflow/workflow_' + today + machine + '.log'
    output = [ ] 

    check_file = os.path.exists(logfile)

    if check_file is not False:
         with open(logfile, "r") as reading_log:
              for line in reading_log:
                 #print line
                 if verif_type in line:
                    if error in line:
                       output.append(line)
         if not output:
            return 0
         else:
            print output
            return 1
    else:
         return 1

job_list= [
      'FIM8 FIMVerif DEAD',
      'FIM9 FIMVerif DEAD',
      'FIM7 FIMVerif DEAD',
      'FIMX FIMVerif DEAD',
      'FIM8 soundings DEAD',
      'FIM9 soundings DEAD',
      'FIM7 soundings DEAD',
      'FIMX soundings DEAD',
      'FIM8 surface DEAD',
      'FIM9 surface DEAD',
      'FIMX surface DEAD',
      ]   

mail_out_header = StringIO.StringIO()
print >>mail_out_header, """\
To: %(recipients)s
From: (Verification Workflow checking from Jet) amb-verif@localhost""" % {
  'recipients':
  'jeffrey.a.hamilton@noaa.gov,Bill.Moninger@noaa.gov,bonny.strong@noaa.gov'
  }
mail_bad_data = StringIO.StringIO()
mail_good_data = StringIO.StringIO()

today_time = datetime.utcnow()

today_date = today_time.strftime('%Y%m%d')

cycles = [ '00','12' ]

some_bad=0
bad = 1

for cycle in cycles:
    today = today_date + cycle
    print today
    for str in job_list:
        row = str.split()
        result = check_workflow(today,row)
        if result is bad  :
           some_bad += 1
           print >>mail_bad_data, " JET: '%s %s' verification job has failed. Cycle: '%s' " % (row[0],row[1],today),
           print >>mail_bad_data, ""
        else:
           print >>mail_good_data, "JET: '%s %s' verification job completed. Cycle: '%s'" % (row[0],row[1],today),
           print >>mail_good_data, ""
#print >>mail_bad_data, "."
#print >>mail_good_data, "."

#print >>mail_bad_data, predix
#print >>mail_good_data,predix

# mail the results to 'recipients'
if some_bad > 0:
  print >>mail_out_header,  """Subject: WARNING: some Jet workflow jobs have failed

"""
  p = Popen(["/usr/sbin/sendmail","-t"],stdin=PIPE)
  print >>p.stdin, mail_out_header.getvalue(), mail_bad_data.getvalue()
  mail_bad_data.close()
else:
  print >>mail_out_header, \
        "Subject: GOOD: No Jet workflow jobs have failed\n\nGOOD: No Jet workflow jobs have failed"
  p = Popen(["/usr/sbin/sendmail","-t"],stdin=PIPE)
  print >>p.stdin, mail_out_header.getvalue(), mail_good_data.getvalue()
  mail_good_data.close()

mail_out_header.close()

