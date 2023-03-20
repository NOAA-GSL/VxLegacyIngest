#!/usr/bin/python
###################
#
# Name: METAR_archive.py
#
# Description: script for producing a text file of retro METAR data for a user designated station and time period
#
# Input:
#   <station> - station name (eg. KDEN)
#   <start_secs> - start of record in epoch seconds
#   <end_secs> - end of record in epoch seconds
#
# Output:
#   station record text file
#
# Requirements:
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20170913
#   Added retro support - Molly Smith, GSD/ADB, 20190322
#
###################

# import need libaries/modules

import sys
import datetime
import time
import MySQLdb


# start of the main program

def METAR_main ( station, start_secs, end_secs ):

    # connect to the database

    wolphin_db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="readonly", passwd="ReadOnly@2016!", db="madis3")

    db = wolphin_db.cursor()

    # grab station data

    db.execute("""SELECT * FROM stations WHERE name = %s and net = 'METAR'""", (station,))
    if db.rowcount == 0:
        msg = "ERROR: station does not exist!"
        print(msg)
        exit(2)
    row = db.fetchone()

    station_id = row[0]
    description = row[2]
    network = row[3]
    first_time = row[4]
    last_time = row[5]

    # grab location data

    db.execute("""SELECT * FROM metars WHERE madis_id = %s""", (station_id,))
    if db.rowcount == 0:
        msg = "ERROR: station locations are not available!"
        print(msg)
        exit(4)
    row = db.fetchone()

    latitude = float(row[2])/182
    longitude = float(row[3])/182
    elevation = float(row[4])*0.3048

    # define and create output file

    metar_file = "station_archive_%s_%s_%s.txt" % (station,start_secs,end_secs)

    CreateFileHeader(metar_file,station,description,network,latitude,longitude,elevation)

    # grab obs data from database

    results = []

    db.execute("""SELECT * FROM obs_retro WHERE sta_id = %s AND time >= %s and time <= %s""", (station_id,start_secs,end_secs))
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

def CreateFileHeader ( metar_file, station, description, network, latitude, longitude, elevation ):

    line_break = "########################################\n"

    header_line = "STATION: %s , LAT: %s , LON: %s , ELEV (M): %s , NET: %s , DESC: %s\n" % (station, latitude, longitude, elevation, network, description)

    var_header = "DATE TIME (UTC) , EPOCH TIME , TEMP (F) , DEWPOINT (F) , SLP (MB) , WS (MPH) , WD (DEG) , WG (MPH) , VIS (MI) , CEIL (FT) \n"

    lines = [ header_line, line_break, var_header]

    file = open(metar_file, "w")

    file.writelines(lines)

    file.close()

# END CreateFileHeader

def AppendData (metar_file, data):

    file = open(metar_file, "a")

    for line in data:

        # put the data into the proper format

	print(line)
        time_seconds = line[1]
        tmp = line[5]
        temp = float(tmp)/10
        dtmp = line[8]
        dp = float(dtmp)/10
        slp = line[10]
        press = float(slp)/10
        wd = line[12]
        ws = line[14]
        wg = line[16]
        sky_id = line[18]
        vtmp = line[20]
        vis = float(vtmp)/100

        ceiling = GetCeil(sky_id)

        date_time = time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(int(time_seconds)))

        # output data to text file

        text_line = "%s , %s , %s , %s , %s , %s , %s , %s , %s , %s\n" % (date_time,str(time_seconds),str(temp),str(dp),str(press),ws,wd,wg,vis,ceiling)

        file.write(text_line)

    file.close()

# END AppendData

def GetCeil (sky_id):

    #using the sky_id from the obs table, grab the METAR ceiling information
    wolphin_db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="readonly", passwd="ReadOnly@2016!", db="madis3")

    db = wolphin_db.cursor()

    db.execute("""SELECT cvr from sky where id = %s""", (sky_id,))
    if db.rowcount == 0:
        msg = "ERROR: ceiling data is not available!"
        print(msg)
        ceiling = "N/A"
    else:
        row = db.fetchone()
        ceiling = row[0]

    return(ceiling)

# END GetCeil

if __name__ == '__main__':
    usage = 'python METAR_archive_main.py <station_name> <start_secs> <end_secs>'
    utcnow = str(datetime.datetime.now())
    msg = 'METAR_archive START:' + utcnow
    if len(sys.argv) != 4:
        msg = 'ERROR: incorrect number of arguments'
        print(msg)
        print(usage)
        exit(1)
    else:
        station = sys.argv[1]
        start_secs = sys.argv[2]
        end_secs = sys.argv[3]
        METAR_main(station,start_secs,end_secs)
        utcnow = str(datetime.datetime.now())
        msg = 'METAR_archive END:' + utcnow

