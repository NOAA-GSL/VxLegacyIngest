import os
import sys
import math
from numpy import isnan

def add_or_null(prev_sum,data_field,j,i):
    if type(data_field) == type(None):
        return(None)
    else:
        try:
            val = prev_sum+data_field[j,i]
            return(val)
        except:
            # index out of range (too near edge)
            return(None)

def divide_or_null(value,multiplier,divisor):
    if value == None:
        return('\\N')
    else:
        result = "%.0f" % ((value*multiplier)/divisor)
        return(result)
    
def write_station_values(model,run_time,fcst_len,proj,stations,scales,\
                             MODEL_pm2p5,lats,lons):
    # (lats,lons in arg list are ONLY needed for DEGUGGING
    tmp_file = "tmp/%d.%d.%s.%d.pm2p5_data.writing3" % \
        (os.getpid(),run_time,model,fcst_len)
    pid = os.getpid()
    print( "tmp_file",tmp_file)
    tmp_stream = open(tmp_file,"w",0)       # no buffering
    out_str = ""
    valid_time = run_time + fcst_len*3600

    max_pm2p5=0
    for s in stations:
        #print s.id,s.lat,s.lon,s.elev
        # limit to the RAP130 domain
        if s.lon > -57 or s.lon < -141 or \
           s.lat > 59 or s.lat < 15:
            continue
        #print "id,lat,lon is",s.id,s.lat,s.lon,
        [xi,yj] = proj.latlon2ij(s.lat,s.lon)
        if not isnan(xi) and not isnan(yj):
         i_ctr = int(round(xi))
         j_ctr = int(round(yj))
         #print 'i_ctr',i_ctr,'j_ctr',j_ctr,'lat',lats[j_ctr,i_ctr],'lon',lons[j_ctr,i_ctr]
         #print "center is",i_ctr,j_ctr
         #print 'lat,lon is',s.lat,s.lon
         for scale in scales:
             #print "scale is",scale,'proj.dx is',proj.dx
             # get number of grid points to include in the average
             n_ij = int(round(scale*1000/proj.dx))
             min_i = i_ctr - int((n_ij-1)/2)
             min_j = j_ctr - int((n_ij-1)/2)
             #print 'n_ij',n_ij,min_i,min_j
             i_cells = range(min_i,min_i+n_ij)
             j_cells = range(min_j,min_j+n_ij)
             #print 'i,j range',i_cells,j_cells
             sum_pm2p5= 0
             n_sum = 0
             for i in i_cells:
                 for j in j_cells:
                     sum_pm2p5= add_or_null(sum_pm2p5,MODEL_pm2p5,j,i)
                     n_sum += 1
             avg_pm2p5 = divide_or_null(sum_pm2p5,10,n_sum)
             try:
                 if float(avg_pm2p5) > float(max_pm2p5):
                     max_pm2p5 = avg_pm2p5
             except:
                 # get here is avg_pm2p5 is '\N'
                 pass
             this_str = "%s,%d,%d,%d," %  (s.id,valid_time,fcst_len,scale)
             if model == 'HRRR_GSD':
                 this_str += "%s" % (avg_pm2p5)

             this_str += "\n"
             #print 'station',s.id,this_str,
             out_str += this_str

    print 'max_pm2p5',float(max_pm2p5)/10
    tmp_stream.write(out_str)
    tmp_stream.close()
    done_file = tmp_file.replace(".writing3",".written3")
    os.rename(tmp_file,done_file)
     
        
        
