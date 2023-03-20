def get_grid (file,thisDir,DEBUG):

    import os
    import sys
    import MySQLdb
#    import StringIO
    from string import *
    import random
    import datetime
    import time
#    import math
    import re
    import calendar
    

    la1=    lo1=    lov =    latin1 =0
    nx=ny=dx=0
    grid_type =0
    grib_type = 0
    # first, let's see if its grib(1)
    arg = strip(thisDir)+"/col_wgrib.x -V "+file
    # clean it for the taint flag
#    $unsafe_arg =~ /([-\w. \/\>\|\:\']+)/;

    a= os.popen(arg)
    allrecs= a.read()
    result = re.split('\n\n',allrecs)
    
#    for i in range(0, len(result)):
    for i in range(0, 1):
        record= result[i]
        print "record=",record
        print re.search("date (\d+) .*anl",record)

	#print;
        if re.search("date (\d+) .*anl",record):
           out= re.findall("date (\d+)",record)
	   run_date=out[0]
	   fcst_proj=0;
	   grib_type = 1
        elif re.search("date (\d+) .* (\d+)hr fcst",record): 
#           print "ok2",record
           out= re.findall("date (\d+) .* (\d+)hr fcst",record)
	   run_date= out[0][0]
	   fcst_proj=int(out[0][1])
	   grib_type = 1

        elif re.search("Lambert Conf: Lat1 ([\-\.\d]+) Lon1 ([\-\.\d]+) Lov ([\-\.\d]+)",record):
	    #print "got lambert\n";
            print "ok3",record
            out = re.findall("Lambert Conf: Lat1 ([\-\.\d]+) Lon1 ([\-\.\d]+) Lov ([\-\.\d]+)")
	    la1 = out[0]
	    lo1 = out[1]
	    lov = out[2]
	    grid_type = 1		# Lambert conformal conic with 1 std parallel

            out= re.findall("Latin1 ([\.\d]+)")
	    latin1 = out[0]

	    out= re.findall("North Pole \((\d+) x (\d+)\) Dx ([\.\d]+)",record)
	    nx = out[0]
	    ny = out[1]
	    dx = out[2]
            if dx <= 1000:
                dx = dx * 1000


	elif re.search("latlon: lat  ([\-\.\d]+) to ([\-\.\d]+) by ([\.\d]+)",record) :
            print "ok4",record
            out= re.findall("latlon: lat  ([\-\.\d]+) to ([\-\.\d]+) by ([\.\d]+)") 
	    la1 = out[0]			# lat1
	    lo1 = out[1]			# lat2
 	    dx = out[2] + 0		# make sure its a number


	    grib_type = 1

	    out = re.finall("long ([\-\.\d]+) to ([\-\.\d]+) by ([\.\d]+), \((\d+) x (\d+)")
	    lov = out[0]			# lon1
	    latin1 = out[1]		# lon2
            if latin1 < lov :
		latin1 =  latin1+ 360

	    dy = out[2] + 0;		# make sure its a number
	    nx = out[3]
	    ny = out[4]
            if dx ==  dy :
                if la1 <  lo1:
		    grid_type = 10	# 10 = lat-lon grid, S to N
		else: 
		    grid_type = 11        # 11 = lat-lon grid, N to S

	    else :
		grid_type = 0

	    if DEBUG :
		print "lat: ",la1+" to "+lo1+" by "+dx
		print "lon: "+lov+" to "+latin1+" by "+dy




    if grib_type != 1:
	# its not grib(1). Must be grib2
	arg = strip(thisDir)+"/wgrib2.x -grid "+strip(file)

        if DEBUG :
	    print "NUMBER 2 arg is "+arg
        try:
            a= os.popen(arg)
            allrecs= a.read()
        except :
            sys.exit(0)
    
        if re.search("Lambert Conformal",allrecs):
	    grib_type = 2

	    out = re.findall("Lat1 ([\-\.\d]+) Lon1 ([\-\.\d]+) Lov ([\-\.\d]+)")
	    la1 = out[0]	
	    lo1 = out[1]	
	    lov = out[2]


	    out= re.findall("Latin1 ([\.\d]+)")
	    latin1 = out[0]

	    #print;
	    out = re.findall("North Pole \((\d+) x (\d+)\) Dx ([\.\d]+) (.) Dy ([\.\d]+)")
	    nx = out[0]
	    ny = out[1]
	    dx = out[2]
	    mkm = out[3]	# "m" or (maybe) "km"
	    dy = out[4]
            if mkm != "m":
		dx = dx *1000  # send it out in meters
	        dy = dy *1000

	    #print "dx |$dx|, dy |$dy|\n";
            if dx == dy: 
		grid_type = 1	# 1 = Lamb. Conf with 1 std parallel
	    else: 
		grid_type = 0	# unknown grid type
	    
	elif re.search("lat-lon grid:\((\d+) x (\d+)",allrecs):
	    grib_type = 2
            out = re.findall("lat-lon grid:\((\d+) x (\d+)")
	    nx = out[0]
	    ny = out[1]
	    out = re.findall("lat (.+) to (.+) by (.+)")
	    la1 = out[0]			# lat1
	    lo1 = out[1]		# lat2
	    dx = out[2] + 0		# make sure its a number

	    out  =  re.findall("lon (.+) to (.+) by (.+)")
	    lov = out[0]			# lon1
	    latin1 = out[1]		# lon2
	    dy = out[2] + 0		# make sure its a number
            if dx == dy:
                if la1 < lo1:
		    grid_type = 10	# 10 = lat-lon grid, S to N
		else:
		    grid_type = 11        # 11 = lat-lon grid, N to S
		
	    else:
		grid_type = 0
	    
	else :
	    grid_type = 0

	# get run date
#	arg = strip(thisDir)+"/wgrib2 "+file
#        a= os.popen(arg)
#        line= a.read()
        print "I am here in grib2"
        out = re.findall("d=(\d*)",allrecs)
        run_date = out[0]
        out = re.findall("(\d*) hour fcst",allrecs)
        fcst_proj= out[0]

   
    print "run_date is "+run_date
    year = int(run_date[0:4])
    mon  = int(run_date[4:6])
    day = int(run_date[6:8])
    hour= int(run_date[8:10])
    min=0
    sec=0

    t1 = datetime.datetime(year,mon,day,hour,min,sec)
    t2 = t1 + datetime.timedelta(seconds=3600*fcst_proj)


#    valid_date = "%4d"%(t2.year)+  "%02d"%(t2.month)+"%02d"%(t2.day)+"%02d"%(t2.hour)

    valid_date = t2
    
    print la1, lo1,lov,latin1,nx,ny,dx,grib_type,grid_type,valid_date,fcst_proj
    return la1, lo1,lov,latin1,nx,ny,dx,grib_type,grid_type,valid_date,fcst_proj


