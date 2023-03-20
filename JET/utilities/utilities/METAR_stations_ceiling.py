#!/usr/bin/python
###################
#
# Name: METAR_stations_ceiling.py
#
# Description: script for producing a text file of METAR ceiling data for a user designated time and station
#
# Input:
#   <record_secs> - desired time of record in epoch seconds
#   <station> - OPTIONAL, default is "all", but can specify one station
#
# Output:
#   station record text file
#
# Requirements:
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20171031
#
###################

# import need libraries/modules

import sys
import datetime
import time
import MySQLdb


# start of the main program

def METAR_stations_ceiling ( record_secs, station ):

    # connect to the database

    wolphin_db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="readonly", passwd="ReadOnly@2016!", db="ceiling_15")

    db = wolphin_db.cursor()

    # grab station data

    station_list = []

    if station is None or station is "all":
        db.execute("""SELECT name FROM metars""")
    else:
        db.execute("""SELECT name FROM metars WHERE name = %s""", (station,))

    if db.rowcount == 0:
        msg = "ERROR: station(s) does not exist or cannot be found!"
        print(msg)
        exit(2)
    rows = db.fetchall()

    for r in rows:
        station_list.append(r)

    # grab obs data from database

    results = []

    stations_found = 0
    stations_missing = 0

    for s in station_list:
        sname = s[0]
        if sname is None:
            continue
        #msg = "Station Name: %s\n" % str(sname)
        #print(msg)

        db.execute("""SELECT madis_id FROM metars WHERE name = %s""", (str(sname),))
        if db.rowcount == 0:
            msg = "ERROR: station %s is missing an id! Will not be included!" % (sname)
            print(msg)
            continue
        else:
            station_id = db.fetchone()
            sta_id = station_id[0]

        #msg = "Station ID: %s\n" % str(sta_id)
        #print(msg)

        db.execute("""SELECT m.name, o.time, o.ceil FROM metars as m, obs as o WHERE o.madis_id = %s AND o.madis_id = m.madis_id AND o.time >= %s - 450 AND o.time < %s + 450""", (sta_id,record_secs,record_secs))
        if db.rowcount == 0:
            msg = "ERROR: station %s is missing for that time period!" % (str(sname))
            #print(msg)
            stations_missing += 1
        else:
            row = db.fetchall()
            results.append(row)
            stations_found += 1

    msg = "%d stations found, %d stations missing" % (stations_found,stations_missing)
    print(msg)

    # Check to see if any data was found

    if len(results) == 0:
        msg = "WARNING: No data was found for that time period. File is not being made!"
        print(msg)
        exit(3)

    # define and create output file

    file_time = time.strftime('%Y%m%d%H%M', time.gmtime(int(record_secs)))

    metar_file = "METAR_station_ceiling_%s.txt" % (file_time)

    msg = "Creating file %s" % (metar_file)
    print(msg)

    CreateFileHeader(metar_file)

    # push the data to the output file

    AppendData(metar_file,results)

# END METAR_archive

def CreateFileHeader ( metar_file ):

    line_break = "########################################\n"

    header_line = "DATE , EPOCH , STATION , CEILING AGL (FT)\n"

    lines = [ header_line, line_break]

    file = open(metar_file, "w")

    file.writelines(lines)

    file.close()

# END CreateFileHeader

def AppendData (metar_file, data):

    file = open(metar_file, "a")

    for line in data:

        # put the data into the proper format

        name = line[0][0]
        time_seconds = line[0][1]
        ceil = line[0][2]
        ceiling = int(ceil)*10

        if ceiling >= 60000:
            ceiling = "NO CLOUD CEILING"

        date_time = time.strftime('%Y-%m-%d %H:%M', time.gmtime(int(time_seconds)))

        # output data to text file

        text_line = "%s , %s , %s , %s\n" % (date_time,str(time_seconds),name,str(ceiling))

        file.write(text_line)

    file.close()

# END AppendData


if __name__ == '__main__':
    usage = 'python METAR_stations_ceiling.py <record_secs> <station (optional)>'
    utcnow = str(datetime.datetime.now())
    msg = 'METAR_archive START:' + utcnow
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        msg = 'ERROR: incorrect number of arguments'
        print(msg)
        print(usage)
        exit(1)
    else:
        record_seconds = sys.argv[1]
        if len(sys.argv) == 3:
            station = sys.argv[2]
        else:
            station = None
        METAR_stations_ceiling(record_seconds,station)
        utcnow = str(datetime.datetime.now())
        msg = 'METAR_archive END:' + utcnow
