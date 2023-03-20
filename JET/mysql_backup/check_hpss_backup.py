#!/contrib/miniconda3/4.5.12/bin/python3
import  subprocess 
import shlex
#import StringIO
import os
import re
import sys
import time
from datetime import date,datetime
import smtplib

non_updating_dbs = ['ceiling']
currentMonth = datetime.now().strftime('%h')
#print("current month: {}".format(currentMonth))
#currentMonth = "Sep"
out_of_date = False
hsi_backup_dir = "/BMC/wrfruc/5year/amb-verif/MySQL_backups"
mail_input= "Latest files backed up to HPSS \nchecked by {script}\nunder \n{bd}\n".\
            format(script= os.path.realpath(__file__),bd=hsi_backup_dir)
cmd = shlex.split("hsi cd  {bd}; ls -arB *".format(bd=hsi_backup_dir))
#print(cmd)
output = subprocess.check_output(cmd,
                      stderr=subprocess.STDOUT,  # get all output
                      universal_newlines=True  # return string not bytes
                      )
s = output.split("\n")
i=1
while(True):
    try:
        line = s[i]
        i=i+1
        if re.search(":$",line):
            mail_input += "\t"+line+"\n"
            db = line[:-1]
            index = -1
            try:
                index = non_updating_dbs.index(db)
                mail_input += "(archival):"
            except ValueError:
                pass
            line = s[i]
            # if the db is NOT non-updating, and the month isn't current, warn.
            if index < 0 and not re.search(currentMonth,line):
                    out_of_date = True
                    mail_input += "OUT OF DATE: "
            mail_input += "\t"+line+"\n"
            i=i+1
    except:
        break

#print(mail_input)
#sys.exit()
subject = "MySQL HPSS backup report"
if(out_of_date):
    subject = "WARNING: some MySQL HPSS backups are out of date!"
SENDMAIL = "/usr/sbin/sendmail" # sendmail location
p = os.popen("%s -t" % SENDMAIL, "w")
p.write("To: William.R.Moninger@noaa.gov,verif-amb.gsl@noaa.gov\n")
p.write("From: (jet mysql_backup) verif-amb.gsl@noaa.gov\n")
p.write("Subject: {}\n".format(subject))
p.write("\n") # blank line separating headers from body
p.write(mail_input)
sts = p.close()
if sts != None:
    print("Sendmail exit status", sts)
