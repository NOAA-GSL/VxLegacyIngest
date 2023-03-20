import os
import sys
import math

def add_or_null(prev_sum,data_field,j,i):
    if type(data_field) == type(None):
        return(None)
    else:
        return(prev_sum+data_field[j,i])

def divide_or_null(value,divisor):
    if value == None:
        return('\\N')
    else:
        result = "%.2f" % (value/divisor)
        return(result)
    
def write_station_values(model,run_time,fcst_len_mins,proj,stations,scales,\
                             MODEL_DSWRF    ,MODEL_DIRECT,    MODEL_DIFFUSE,\
                             MODEL_DSWRF15,MODEL_DIRECT15,MODEL_DIFFUSE15):
    tmp_file = "tmp/%d.%d.%s.%d.dswrf_data.writing3" % \
        (os.getpid(),run_time,model,fcst_len_mins)
    pid = os.getpid()
    print( "tmp_file",tmp_file)
    tmp_stream = open(tmp_file,"w",0)       # no buffering
    out_str = ""
    valid_time = run_time + fcst_len_mins*60

    for s in stations:
        #print s.id,s.lat,s.lon,s.elev
        # limit to the RAP130 domain
        if s.lon > -57 or s.lon < -141 or \
           s.lat > 59 or s.lat < 15:
            continue
        [xi,yj] = proj.latlon2ij(s.lat,s.lon)
        i_ctr = int(round(xi))
        j_ctr = int(round(yj))
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
            sum_DSWRF = 0
            sum_DIRECT = 0
            sum_DIFFUSE = 0
            sum_DSWRF15 = 0
            sum_DIRECT15 = 0
            sum_DIFFUSE15 = 0
            n_sum = 0
            for i in i_cells:
                for j in j_cells:
                    sum_DSWRF = add_or_null(sum_DSWRF,MODEL_DSWRF,j,i)
                    sum_DSWRF15 = add_or_null(sum_DSWRF15,MODEL_DSWRF15,j,i)
                    sum_DIRECT = add_or_null(sum_DIRECT,MODEL_DIRECT,j,i)
                    sum_DIRECT15 = add_or_null(sum_DIRECT15,MODEL_DIRECT15,j,i)
                    sum_DIFFUSE = add_or_null(sum_DIFFUSE,MODEL_DIFFUSE,j,i)
                    sum_DIFFUSE15 = add_or_null(sum_DIFFUSE15,MODEL_DIFFUSE15,j,i)
                    n_sum += 1
            avg_DSWRF = divide_or_null(sum_DSWRF,n_sum)
            avg_DSWRF15 = divide_or_null(sum_DSWRF15,n_sum)
            avg_DIRECT = divide_or_null(sum_DIRECT,n_sum)
            avg_DIRECT15 = divide_or_null(sum_DIRECT15,n_sum)
            avg_DIFFUSE = divide_or_null(sum_DIFFUSE,n_sum)
            avg_DIFFUSE15 = divide_or_null(sum_DIFFUSE15,n_sum)
            #print "scale,n, avg DSWRF, avg DSWRF15", scale,n_sum,avg_DSWRF,avg_DSWRF15
            this_str = "%s,%d,%d,%d," %  (s.id,valid_time,fcst_len_mins,scale)
            if model == 'HRRR':
                this_str += "%s,%s,%s,%s,%s,%s" %  \
                    (avg_DSWRF,avg_DSWRF15,avg_DIRECT,avg_DIRECT15,avg_DIFFUSE,avg_DIFFUSE15)
            else:
                this_str += "%s" % (avg_DSWRF)
            
            this_str += "\n"
            #print 'station',s.id,this_str,
            out_str += this_str

    tmp_stream.write(out_str)
    tmp_stream.close()
    done_file = tmp_file.replace(".writing3",".written3")
    os.rename(tmp_file,done_file)
     
        
        
