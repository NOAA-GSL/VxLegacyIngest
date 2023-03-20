#!/lfs1/BMC/fim/whitaker/bin/python
import MySQLdb
import sys
from time import gmtime,strftime
from calendar import timegm
import smtplib
from  subprocess import Popen,PIPE
import StringIO

def find_latest_secs(conn,row):
  db=row[0]
  table=row[1]
  column=row[2]
  sec_or_date=row[3]
  """returns latest date in the given db.table.

  sec_or_date = 'date' if the column is a date column
              = 'sec' if the column is a seconds since epoch column
              """
  full_table = db +'.'+table
  cursor = conn.cursor()
  query = "select max(%s) from %s.%s" % \
          (column,db,table)
  if sec_or_date == 'date' :
      query = "select unix_timestamp(max(%s)) from %s.%s" % \
              (column,db,table)

  if len(row) > 4:
    test_column = row[4]
    test_value = row[5]
    query += " where %s = '%s'" % (test_column,test_value)
      
  print "query is %s" % query
  cursor.execute(query)
  row = cursor.fetchone()
  cursor.close()
  return row[0]
 
try:
    conn = MySQLdb.connect (read_default_file="~/.my.cnf")
except MySQLdb.Error, e:
    print "Error %d: %s" % (e.args[0], e.args[1])
    sys.exit (1)

big_list = [ 
    'ceiling_sums        Bak13_100_1_E_US        time       secs',
    'ceiling_sums        rap_dev1_100_1_E_US     time       secs',
    'ceiling_sums        rap_dev2_100_1_E_US     time       secs',
    'ceiling_sums        rap_dev3_100_1_E_US     time       secs',
    'ceiling_sums        STMAS_CI_100_1_E_US     time       secs',
    'ceiling_sums        STMAS_HWT_100_1_E_US     time       secs',
    'ceiling_sums        LAPS_HWT_100_1_E_US     time       secs',
    'ceiling_sums        LAPS_CONUS_100_1_E_US     time       secs',     
    'ceiling_sums        HRRR_100_1_E_US         time       secs', 
    'ceiling_sums        NAM_100_3_E_US          time       secs', 
    #'ceiling_sums        NoTAM13_100_1_E_US      time       secs', 
    'ceiling_sums        RR1h_prs_100_1_E_US     time       secs', 
    'ceiling_sums        persis_100_1_E_US       time       secs', 
    'ruc_ua_sums2        Bak13_Areg0              date       date', 
    #'ruc_ua_sums2        Dev1320_reg0            date       date', 
    #'ruc_ua_sums2        Dev13_reg0              date       date', 
    'ruc_ua_sums2        FIM_reg0                date       date',
    'ruc_ua_sums2        FIMZEUS_reg0             date       date', 
    'ruc_ua_sums2        FIM_prs_reg0            date       date', 
    'ruc_ua_sums2        FIMX_reg0               date       date', 
    'ruc_ua_sums2        GFS_reg0                date       date', 
    'ruc_ua_sums2        HRRR_Areg0               date       date', 
    'ruc_ua_sums2        RAP20_Areg0           date       date', 
    'ruc_ua_sums2        NAM_reg0                date       date', 
    #'ruc_ua_sums2        NoTAM13_reg0            date       date', 
    'ruc_ua_sums2        RR1h_Areg0               date       date',
    'ruc_ua_sums2        RAP_dev1_Areg0               date       date', 
    'ruc_ua_sums2        RAP_dev2_Areg0               date       date',
    'ruc_ua_sums2        RAP_dev3_Areg0               date       date', 
    #'ruc_ua_sums2        RR1h_dev_Areg0               date       date', 
    #'ruc_ua_sums2        RR1h_dev2_Areg0               date       date', 
    'ruc_ua_sums2        RRnc_reg0               date       date', 
    'ruc_ua_sums2        RRrapx_Areg0               date       date', 
    'surface_sums        Bak13_1_metar_q_ALL_HRRR  valid_day  secs', 
    'surface_sums        HRRR_1_metar_q_ALL_HRRR   valid_day  secs', 
    'surface_sums        RR1h_1_metar_q_ALL_HRRR   valid_day  secs', 
    'surface_sums        RAP_dev1_1_metar_q_ALL_HRRR   valid_day  secs',
    'surface_sums        RAP_dev2_1_metar_q_ALL_HRRR   valid_day  secs', 
    'surface_sums        RAP_dev3_1_metar_q_ALL_HRRR   valid_day  secs', 
    'surface_sums        STMAS_CI_1_metar_q_STMAS_CI   valid_day  secs', 
    'surface_sums        STMAS_HWT_1_metar_q_HWT   valid_day  secs', 
    'surface_sums        LAPS_HWT_0_metar_q_HWT   valid_day  secs', 
    'visibility_sums     Bak13_100_1_E_US        time       secs', 
    'visibility_sums     HRRR_100_1_E_US         time       secs', 
    #'visibility_sums     NoTAM13_100_1_E_US      time       secs', 
    'visibility_sums     persis_100_1_E_US       time       secs', 
    'visibility_sums     persis_100_1_E_US       time       secs', 
    'madis3              obs                     time       secs',
    'madis3              RR1hqp                   time       secs',
    #'madis3              RR1h_devqp               time       secs',
    'madis3              RRrapxqp                 time       secs',
    'madis3              RR1hqp1f                 time       secs',
    'madis3              HRRRqp1f                 time       secs',
    'madis3              Bak13qp1f                time       secs',
    'madis3              NAMqp                    time       secs',
    'files_on_jet        files_avail_new         ts         date',
    'anomaly_corr_stats  stats                   valid_date date',
    'acars9              acars                   date       date',
    'acars_RR            acars                   date       date',
#    'acars_RUC           acars                   date       date',
    'soundings           model_airport_soundings time       date',
    'soundings           HRRR_raob_soundings     time       date',
    'soundings           RR1h_raob_soundings     time       date',
    'soundings           RRnc_raob_soundings     time       date',
    'soundings           FIM_raob_soundings      time       date', 
    'soundings           FIMX_raob_soundings     time       date',
    #'soundings           FIMY_raob_soundings     time       date',
    #'soundings           FIMZ_raob_soundings     time       date',
    'soundings           GFS_raob_soundings      time       date', 
    'soundings           NAM_raob_soundings      time       date',
    'wind_profiler           sum_hrrr_cap_6      time       secs',
    'wind_profiler           sum_rr_cap_6      time       secs',
    'wind_tower           rr_restricted_ground          time       secs',
    'wind_tower           hrrr_restricted_ground          time       secs',
    ]

mail_out_header = StringIO.StringIO()
print >>mail_out_header, """\
To: %(recipients)s
From: (Database checking from jet) amb-verif@localhost""" % {
  'recipients':
  'Bill.Moninger@noaa.gov,Susan.R.Sahm@noaa.gov,xue.wei@noaa.gov'
  }
mail_bad_data = StringIO.StringIO()
mail_good_data = StringIO.StringIO()

now_secs = timegm(gmtime())
day_start_secs = now_secs - now_secs%(24*3600)
test_secs = day_start_secs - 24*3600
print "test secs is "+strftime("%a, %d %b %Y %H:%M:%S +0000",gmtime(test_secs))

predix = "jet:/home/amb-verif/utilities/check_update.py"
#print >>mail_bad_data, predix

some_bad=0
for str in big_list:
    row = str.split()
    max_secs = find_latest_secs(conn,row)
    if max_secs < test_secs  :
      some_bad += 1
      print >>mail_bad_data, " table '%s.%s' is out of date. max '%s': " % (row[0],row[1],row[2]),
      if max_secs > 0 :
        print >>mail_bad_data, strftime("%a, %d %b %Y %H:%M:%S", gmtime(max_secs)),
      else:
        print >>mail_bad_data, " null",
      if len(row) > 4:
        print >>mail_bad_data, " for %s %s" % (row[4],row[5])
      else:
        print >>mail_bad_data, ""
        
    else:
      print >>mail_good_data, " table '%s.%s' is up to date:" % (row[0],row[1]),
      print >>mail_good_data,  strftime("%a, %d %b %Y %H:%M:%S", gmtime(max_secs)),
      if len(row) > 4:
        print >>mail_good_data, " for %s %s." % (row[4],row[5])
      else:
        print >>mail_good_data, ""
conn.close ()
#print >>mail_bad_data, "."
#print >>mail_good_data, "."

print >>mail_bad_data, predix
print >>mail_good_data,predix


# mail the results to 'recipients'
if some_bad > 0:
  print >>mail_out_header,  """Subject: WARNING: some tables not updating

"""
  p = Popen(["/usr/sbin/sendmail","-t"],stdin=PIPE)
  print >>p.stdin, mail_out_header.getvalue(), mail_bad_data.getvalue()
  mail_bad_data.close()
else:
  print >>mail_out_header, \
        "Subject: GOOD: database tables up-to-date\n\nGOOD: database tables up-to-date"
  p = Popen(["/usr/sbin/sendmail","-t"],stdin=PIPE)
  print >>p.stdin, mail_out_header.getvalue(), mail_good_data.getvalue()
  mail_good_data.close()

mail_out_header.close()
