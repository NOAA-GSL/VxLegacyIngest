import os
import math

def write_station_values(model,run_time,fcst_len_mins,proj,stations,scales,\
                             CRAIN,CFRZR,CICEP,CSNOW):
    tmp_file = "tmp/%d.%d.%s.%d.dswrf_data.writing" % \
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
        if not math.isnan(xi):
          i_ctr = int(round(xi))
          j_ctr = int(round(yj))
          #print "center is",i_ctr,j_ctr
          for scale in scales:
            #print "scale is",scale,'proj.dx is',proj.dx
            # get number of grid points to include in the average
            n_ij = int(math.ceil(scale*1000/proj.dx))
            min_i = i_ctr - int((n_ij-1)/2)
            min_j = j_ctr - int((n_ij-1)/2)
            #print 'n_ij',n_ij,min_i,min_j
            i_cells = range(min_i,min_i+n_ij)
            j_cells = range(min_j,min_j+n_ij)
            #print 'i,j range',i_cells,j_cells
            sum_CRAIN = 0
            sum_CFRZR = 0
            sum_CICEP = 0
            sum_CSNOW = 0
            n_sum = 0
            edge = 0
            for i in i_cells:
                for j in j_cells:
                    if i >= proj.nx or j >= proj.ny:
                        edge = 1
                        break
                    sum_CRAIN += CRAIN[j,i]*100
                    sum_CFRZR += CFRZR[j,i]*100
                    sum_CICEP += CICEP[j,i]*100
                    sum_CSNOW += CSNOW[j,i]*100
                    n_sum += 1
            if edge == 0:
                avg_CRAIN = round(sum_CRAIN/n_sum)
                avg_CFRZR = round(sum_CFRZR/n_sum)
                avg_CICEP = round(sum_CICEP/n_sum)
                avg_CSNOW = round(sum_CSNOW/n_sum)
                this_str = "%s,%d,%d,%d,%.0f,%.0f,%.0f,%.0f\n" % \
                    (s.id,valid_time,fcst_len_mins,scale,\
                         avg_CRAIN,avg_CFRZR,avg_CICEP,avg_CSNOW )
               #print 'station',s.id,this_str,
                out_str += this_str
            else:
                #print "station",s.id,"on edge for scale",scale
                pass
 
    tmp_stream.write(out_str)
    tmp_stream.close()
    done_file = tmp_file.replace(".writing",".2written")
    os.rename(tmp_file,done_file)
     
        
        
