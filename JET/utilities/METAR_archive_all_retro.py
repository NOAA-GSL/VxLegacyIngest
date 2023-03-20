#!/usr/bin/python
###################
#
# Name: METAR_archive_all_retro.py
#
# Description: script for producing a text file of retro METAR data for a user designated time period
#
# Input:
#   <start_secs> - start of record in epoch seconds
#   <end_secs> - end of record in epoch seconds
#
# Output:
#   record text file
#
# Requirements:
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20190924
#
###################

# import need libaries/modules

import sys
import datetime
import time
import MySQLdb


# start of the main program

def METAR_main ( start_secs, end_secs ):

    # connect to the database

    wolphin_db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="readonly", passwd="ReadOnly@2016!", db="madis3")

    db = wolphin_db.cursor()

    # define and create output file

    metar_file = "station_archive_%s_%s.txt" % (start_secs,end_secs)

    CreateFileHeader(metar_file)

    # grab obs data from database

    results = []

    db.execute("""SELECT s.name, m.lat, m.lon, o.time, o.temp, o.dp, o.slp, o.ws, o.wd, o.wg FROM stations as s, metars as m, obs_retro as o WHERE s.id = m.madis_id and m.madis_id = o.sta_id and o.time >= %s and o.time <= %s order by o.time""", (start_secs,end_secs))
    if db.rowcount == 0:
        msg = "ERROR: station data is missing for that time period!"
        print(msg)
        exit(5)
    rows = db.fetchall()

    for r in rows:
        results.append(r)

    # push the data to the output file

    AppendData(metar_file,results)

# END METAR_archive

def CreateFileHeader ( metar_file ):

    line_break = "########################################\n"

    header_line = "STATION, LAT, LON, DATE TIME (UTC), EPOCH TIME, TEMP (F), DEWPOINT (F), SLP (MB), WS (MPH), WD (DEG), WG (MPH) \n"

    lines = [ header_line, line_break]

    file = open(metar_file, "w")

    file.writelines(lines)

    file.close()

# END CreateFileHeader

def AppendData (metar_file, data):

    file = open(metar_file, "a")

    for line in data:

        # put the data into the proper format

	print(line)
        station = line[0]
        latitude = float(line[1])/182
        longitude = float(line[2])/182
        time_seconds = line[3]
        tmp = line[4]
        try: 
          temp = float(tmp)/10
        except:
          temp = None
        dtmp = line[5]
        try:
          dp = float(dtmp)/10
        except:
          dp = None
        slp = line[6]
        try:
          press = float(slp)/10
        except:
          press = None
        wd = line[7]
        ws = line[8]
        wg = line[9]

        date_time = time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(int(time_seconds)))

        # output data to text file

        text_line = "%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s\n" % (station,latitude,longitude,date_time,str(time_seconds),str(temp),str(dp),str(press),ws,wd,wg)

        file.write(text_line)

    file.close()

# END AppendData

if __name__ == '__main__':
    usage = 'python METAR_archive_all_retro.py <start_secs> <end_secs>'
    utcnow = str(datetime.datetime.now())
    msg = 'METAR_archive START:' + utcnow
    if len(sys.argv) != 3:
        msg = 'ERROR: incorrect number of arguments'
        print(msg)
        print(usage)
        exit(1)
    else:
        start_secs = sys.argv[1]
        end_secs = sys.argv[2]
        METAR_main(start_secs,end_secs)
        utcnow = str(datetime.datetime.now())
        msg = 'METAR_archive END:' + utcnow

