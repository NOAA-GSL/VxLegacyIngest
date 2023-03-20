#!/usr/bin/python
###################
#
# Name: METAR_stations_model_ceiling.py
#
# Description: script for producing a text file of ceiling data, both METAR and model, for a user designated time, model, and station
#
# Input:
#   <record_secs> - desired time of record in epoch seconds
#   <model> - desired model to include
#   <fcst_len> - desired model forecast length
#   <station> - OPTIONAL, default is "all", but can specify one station
#
# Output:
#   station record text file
#
# Requirements:
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20171120
#
###################

# import need libraries/modules

import sys
import datetime
import time
import MySQLdb


# start of the main program

def METAR_stations_model_ceiling ( record_secs, model, fcst_len, station ):

    # connect to the database

    wolphin_db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="readonly", passwd="ReadOnly@2016!", db="ceiling_15")

    db = wolphin_db.cursor()

    # split forecast length into hour and minute

    record_secs = int(record_secs)

    fcst_tmp = fcst_len.split('.')

    fcst_hr = fcst_tmp[0]
    fcst_min = fcst_tmp[1]

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

    # test to see if 15-min data exists (0 - none, 1 - yes, 2 - hourly)

    min_data = 0
    query = "show tables like '%s'" % (model)
    db.execute("use ceiling_15")
    db.execute(query)

    if db.rowcount == 0:
        msg = "15 minute data does not exist for the model, trying hourly..."
        print(msg)
        db.execute("use ceiling2")
        db.execute(query)
        if db.rowcount == 0:
            msg = "ERROR: Hourly data does not exist for this model either, please try another"
            print(msg)
            exit(6)
        else:
            msg = "Hourly data exists, using that for %s hr fcst and moving valid time to an hour boundary" % (fcst_hr)
            print(msg)
            min_data = 2
            fcst_len = fcst_hr
            remainder = int(record_secs)%3600
            if remainder >= 1800:
                record_secs += (3600-remainder)
            else:
                record_secs -= remainder
    else:
        min_data = 1

    for s in station_list:
        sname = s[0]
        if sname is None:
            continue
        #msg = "Station Name: %s\n" % str(sname)
        #print(msg)

        db.execute("use ceiling_15")
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


        query = "SELECT s.name, o.time, o.ceil, m.ceil FROM metars as s, obs as o, %s as m WHERE o.madis_id = %s AND o.madis_id = s.madis_id AND s.madis_id = m.madis_id AND o.time >= %s - 450 AND o.time < %s + 450 AND o.time = m.time AND m.fcst_len = %s AND m.fcst_min = %s" % (model,sta_id,record_secs,record_secs,fcst_hr,fcst_min)
        query2 = "SELECT s.name, o.time, o.ceil, m.ceil FROM metars as s, obs as o, %s as m WHERE o.madis_id = %s AND o.madis_id = s.madis_id AND s.madis_id = m.madis_id AND o.time >= %s - 1800 AND o.time < %s + 1800 AND o.time = m.time AND m.fcst_len = %s" % (model, sta_id, record_secs, record_secs, fcst_hr)
        #print(query)
        if min_data == 1:
            db.execute("use ceiling_15")
            db.execute(query)
        elif min_data == 2:
            db.execute("use ceiling2")
            db.execute(query2)
        else:
            msg = "ERROR: No data is available for this model, please try another"
            print(msg)
            exit(5)

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

    metar_file = "METAR_station_ceiling_%s_%shr_%s.txt" % (model,fcst_len,file_time)

    msg = "Creating file %s" % (metar_file)
    print(msg)

    CreateFileHeader(metar_file, model, fcst_len)

    # push the data to the output file

    AppendData(metar_file,results)

# END METAR_archive

def CreateFileHeader ( metar_file, model, fcst_len):

    line_break = "########################################\n"

    header_line = "DATE , EPOCH , STATION , %s %s HR FCST CEILING AGL (FT), METAR CEILING AGL (FT)\n" % (model, fcst_len)

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

        model_ceil = line[0][3]
        model_ceiling = int(model_ceil) * 10

        if model_ceiling >= 60000:
            model_ceiling = "NO CLOUD CEILING"

        date_time = time.strftime('%Y-%m-%d %H:%M', time.gmtime(int(time_seconds)))

        # output data to text file

        text_line = "%s , %s , %s , %s , %s\n" % (date_time,str(time_seconds),name,str(model_ceiling),str(ceiling))

        file.write(text_line)

    file.close()

# END AppendData


if __name__ == '__main__':
    usage = 'python METAR_stations_ceiling.py <record_secs> <model> <fcst_length (HR.MM)> <station name (optional)>'
    example = 'Ex: python METAR_stations_ceiling.py 1511049600 HRRR 1.15 KDEN'
    utcnow = str(datetime.datetime.now())
    msg = 'METAR_archive START:' + utcnow
    if len(sys.argv) < 4 or len(sys.argv) > 5:
        msg = 'ERROR: incorrect number of arguments'
        print(msg)
        print(usage)
        print(example)
        exit(1)
    else:
        record_seconds = sys.argv[1]
        model = sys.argv[2]
        fcst_len = sys.argv[3]
        if len(sys.argv) == 5:
            station = sys.argv[4]
        else:
            station = None
        METAR_stations_model_ceiling(record_seconds,model,fcst_len,station)
        utcnow = str(datetime.datetime.now())
        msg = 'METAR_archive END:' + utcnow
