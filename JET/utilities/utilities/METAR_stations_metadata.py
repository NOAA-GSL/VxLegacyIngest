#!/usr/bin/python
###################
#
# Name: METAR_stations_metadata.py
#
# Description: script for producing a text file of metadata for all METAR stations
#
# Input:
#
#
# Output:
#   station metadata text file
#
# Requirements:
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20171030
#
###################

# import need libraries/modules

import sys
import datetime
import time
import MySQLdb


# start of the main program

def METAR_stations_metadata ( ):

    # connect to the database

    wolphin_db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="readonly", passwd="ReadOnly@2016!", db="ceiling2")

    db = wolphin_db.cursor()

    # grab station data

    results = []

    db.execute("""SELECT * FROM metars""")
    if db.rowcount == 0:
        msg = "ERROR: cannot find stations!"
        print(msg)
        exit(4)
    rows = db.fetchall()

    for r in rows:
        results.append(r)

    # define and create output file

    metar_file = "METAR_station_metadata.txt"

    CreateFileHeader(metar_file)

    # push the data to the output file

    AppendData(metar_file,results)

# END METAR_archive

def CreateFileHeader ( metar_file ):

    line_break = "########################################\n"

    header_line = "ICAO , LATITUDE , LONGITUDE , ELEV(FT) , DESCRIPTION\n"

    lines = [ header_line, line_break]

    file = open(metar_file, "w")

    file.writelines(lines)

    file.close()

# END CreateFileHeader

def AppendData (metar_file, data):

    file = open(metar_file, "a")

    for line in data:

        # put the data into the proper format

        name = line[1]
        latitude_f = float(line[2]) / 100
        longitude_f = float(line[3]) / 100
        elevation_f = float(line[4])
        if latitude_f is None:
            latitude = "N/A"
        else:
            latitude = str(latitude_f)
        if longitude_f is None:
            longitude = "N/A"
        else:
            longitude = str(longitude_f)
        if elevation_f is None:
            elevation = "N/A"
        else:
            elevation = str(elevation_f)
        description = line[8]
        if description is None:
            description = "NONE"

        # output data to text file

        text_line = "%s , %s , %s , %s , %s\n" % (name,latitude,longitude,elevation,description)

        file.write(text_line)

    file.close()

# END AppendData


if __name__ == '__main__':
    usage = 'python METAR_stations_metadata.py'
    utcnow = str(datetime.datetime.now())
    msg = 'METAR_archive START:' + utcnow
    METAR_stations_metadata()
    utcnow = str(datetime.datetime.now())
    msg = 'METAR_archive END:' + utcnow
