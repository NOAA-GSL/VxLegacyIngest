#!/usr/bin/python
###################
#
# Name: METAR_MODEL_util.py
#
# Description: script for producing a text file of METAR-MODEL diff data
#
# Input:
#   <xml_file> - XML file with various options. See "~/ruc_madis_surface/METAR_MODEL_util_template.xml"
#
# Output:
#   MODEL-OBS difference files for each variable desired
#
# Requirements:
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20180328
#
###################

# import need libaries/modules

import sys
import datetime
import os
import time
import MySQLdb
import xml.etree.ElementTree as ET

# start of the main program

def METAR_MODEL_util ( xmlfile ):

    # Process XML file

    xmlbytag = {}

    try:
        xmltree = ET.parse(xmlfile)
        xmlroot = xmltree.getroot()
        xmltype = xmlroot.tag
        for e in xmlroot:
            xmlbytag[e.tag] = e.text
    except:
        print("ERROR: problem parsing XML file: " + xmlfile)
        print("EXITING")
        exit(2)

    output_dir = xmlbytag['output_dir']

    model = xmlbytag['model']
    start_secs = xmlbytag['start_time']
    end_secs = xmlbytag['end_time']

    fcst_lens_flag = xmlbytag['all_fcst_lens']
    if 'true' in fcst_lens_flag.lower():
        fcst_lens_flag = True
    stations_flag = xmlbytag['all_stations']
    if 'true' in stations_flag.lower():
        stations_flag = True
    variable_flag = xmlbytag['all_variables']
    if 'true' in variable_flag.lower():
        variable_flag = True

    fcst_lens = []

    if fcst_lens_flag is True:
        print("Including all forecast lengths")
    else:
        print("Using forecast lengths specified in the XML file")
       # for e in xmlroot.iter('fcst_len'):
        for e in xmlroot.findall('fcst_len'):
            values = e.getchildren()
            for value in values:
                fcst_lens.append(int(value.text))

    stations = ['']
    min_lat = ''
    min_lon = ''
    max_lat = ''
    max_lon = ''

    if stations_flag is True:
        print("Including all stations, but will use the lat-lon box in the XML file")
        min_lat = xmlbytag['min_latitude']
        max_lat = xmlbytag['max_latitude']
        min_lon = xmlbytag['min_longitude']
        max_lon = xmlbytag['max_longitude']
    else:
        print("Using stations specified in the XML file")
        # for e in xmlroot.iter('stations'):
        for e in xmlroot.findall('stations'):
            values = e.getchildren()
            for value in values:
                stations.append(str(value.text))

    variables = []
    var_unit_map = {"temp": "degree F","dp": "degree F","press": "mb","rh": "%","ws": "mph"}
    var_title_map = {"temp": "Temperature", "dp": "Dewpoint", "press": "Surface Pressure", "rh": "Relative Humidity", "ws": "Wind Speed"}

    if variable_flag is True:
        print("Including all variables")
        variables = ['temp','dp','press','rh','ws']
    else:
        print("Using variables specified in the XML file")
        # for e in xmlroot.iter('variables'):
        for e in xmlroot.findall('variables'):
            values = e.getchildren()
            for value in values:
                variables.append(str(value.text))



    # Connect to the database
    wolphin_db = MySQLdb.connect(host="wolphin.fsl.noaa.gov", user="readonly", passwd="ReadOnly@2016!", db="madis3")
    db = wolphin_db.cursor()

    if fcst_lens_flag is True:
        fcst_lens_query = "SELECT distinct(fcst_len) from " + model + "qp where time >= " + start_secs + " and time <= " + end_secs + ";"
        db.execute(fcst_lens_query)
        if db.rowcount == 0:
            print("ERROR: No forecast hours available for "+model+" in that time period")
            print("Exiting")
            exit(4)
        rows = db.fetchall()

        for r in rows:
            fcst_lens.append(r[0])
        if 1 not in fcst_lens:
            fcst_lens.append(1)
        fcst_lens.sort()


    print("Grabbing data fron the database...")

    for var in variables:
        title = var_title_map[var]
        unit = var_unit_map[var]

        filename = "%s/%s-METAR_%s_%s_%s.txt" % (output_dir,model,start_secs,end_secs,var)

        try:
            os.remove(filename)
        except OSError:
            pass

        try:
            print("Creating file for "+var)
            createOutputFile(filename, title, unit)
        except:
            print("ERROR: Problem creating file "+filename)
            print("Exiting")
            exit(3)

        query = """SELECT m.time as epoch_time, 
                 {fcst_len_select}, 
                 s.name as station_name, 
                 s.lat/100 as latitude, 
                 s.lon/100 as longitude, 
                 s.elev as elevation, 
                 m.{variable} - o.{variable} as model_ob_diff 
                 from metars as s, obs as o, {model} as m 
                 where 1 = 1 
                 and s.madis_id = m.sta_id 
                 and s.madis_id = o.sta_id 
                 and m.time = o.time 
                 {station_clause} 
                 {coordinates_clause}
                 {fcst_len_clause} 
                 and m.time >= {fromSecs} 
                 and m.time <= {toSecs} 
                 order by epoch_time
                 ;"""

        table = model + "qp"
        query = query.replace("{model}", table)
        query = query.replace("{fromSecs}",start_secs)
        query = query.replace("{toSecs}",end_secs)

        if var is "ws":
            var_state = var
        else:
            var_state = var + "/10"

        query = query.replace("{variable}",var_state,2)

        #query_list = []

        for fcst in fcst_lens:
            if fcst is 1:
                queryf = query.replace(table,table+"1f")
                fcst_select = "1 as fcst_len "
                fcst_clause = ""
            else:
                queryf = query
                fcst_select = "m.fcst_len as fcst_len "
                fcst_clause = "and m.fcst_len = %s " % (fcst)

            queryf = queryf.replace("{fcst_len_select}",fcst_select)
            queryf = queryf.replace("{fcst_len_clause}",fcst_clause)

            results = []
            for station in stations:
                if station is '' and len(stations) == 1:
                    queryfs = queryf.replace("{station_clause}","")
                    coordinates_clause = "and s.lat/100 >= %s and s.lat/100 <= %s and s.lon/100 >= %s and s.lon/100 <= %s" % (min_lat,max_lat,min_lon,max_lon)
                    queryfs = queryfs.replace("{coordinates_clause}",coordinates_clause)
                elif station is '' and len(stations) != 1:
                    continue
                else:
                    station_clause = "and s.name = '%s' " % (station)
                    queryfs = queryf.replace("{station_clause}", station_clause)
                    queryfs = queryfs.replace("{coordinates_clause}","")

                #print(queryfs)

                db.execute(queryfs)
                if db.rowcount == 0:
                    msg = "ERROR: station data is missing for %s in that time period!" % (station)
                    print(msg)
                    continue
                rows = db.fetchall()

                for r in rows:
                    results.append(r)

                # push the data to the output file

                appendData(filename, results)

        print("Done. See file at: "+filename)

    print("All files completed")


def createOutputFile (filename, title, unit) :

    line_break = "########################################\n"

    header_line = "Time, Epoch, Fcst Length, Station, Lat, Lon, Elevation (ft), " + title + " diff (" + unit + ") \n"

    lines = [ header_line, line_break]

    file = open(filename, "w")

    file.writelines(lines)

    file.close()

def appendData (filename, data) :
    file = open(filename, "a")

    for line in data:
        # put the data into the proper format

        time_seconds = line[0]
        fcst_len = line[1]
        station_name = line[2]
        latitude = line[3]
        longitude = line[4]
        elevation = line[5]
        diff = line[6]


        date_time = time.strftime('%Y-%m-%d %H:%M', time.gmtime(int(time_seconds)))

        # output data to text file

        text_line = "%s , %s , %s , %s , %s , %s , %s , %s\n" % (
        date_time, str(time_seconds), str(fcst_len), str(station_name), str(latitude), str(longitude), str(elevation), str(diff))

        file.write(text_line)

    file.close()


if __name__ == '__main__':
    usage = 'python METAR_MODEL_util.py <xml_file>'
    utcnow = str(datetime.datetime.now())
    msg = 'METAR_MODEL_util START:' + utcnow
    print(msg)
    if len(sys.argv) != 2:
        msg = 'ERROR: incorrect number of arguments'
        print(msg)
        print(usage)
        exit(1)
    else:
        file = sys.argv[1]
        METAR_MODEL_util(file)
    utcnow = str(datetime.datetime.now())
    msg = 'METAR_MODEL_util END:' + utcnow
    print(msg)
