import os
import sys
import math

def write_station_values3(proj,stations,model,run_time,fcst_len,PCP,accum=0):
    pid = int(os.getpid())
    tmp_file = "tmp/%d.%s.%03d.%d.PCP_%sh_data.writing" % \
        (run_time,model,fcst_len,pid,accum)
    print( "tmp_file",tmp_file)
    tmp_stream = open(tmp_file,"w",0)       # no buffering
    out_str = ""
    n_out_of_range=0
    n_in_range=0
    sum_precip_in=0
    n_with_precip_in=0
    n_with_precip_out=0
    for s in stations:
        #print s.id,s.lat,s.lon,s.elev
        [xi,yj] = proj.latlon2ij(s.lat,s.lon)
        if math.isnan(xi) or math.isnan(yj):
            #print s.id,s.lat,s.lon,'is out of range'
            n_out_of_range += 1
            if i_pcp > 0:
             n_with_precip_out +=1
             continue
        else:
            n_in_range += 1
            i_ctr = int(round(xi))
            j_ctr = int(round(yj))
            #print "station ",s.id,"center is",i_ctr,j_ctr,xi,yj
            #print 'lat,lon is',s.lat,s.lon
            i_pcp = int(round(PCP[j_ctr,i_ctr]))
            if i_pcp > 0:
                n_with_precip_in +=1
                #print s.id,s.lat,s.lon,s.elev,i_ctr,j_ctr,i_pcp,PCP[j_ctr,i_ctr]
                sum_precip_in += i_pcp
            this_str = "%s,%d,%d,%d\n" % \
                (s.id,run_time+3600*fcst_len,fcst_len,i_pcp)
            out_str += this_str
    print n_out_of_range,"stations out of range"
    print n_with_precip_out,"stations out of range with precip"
    print n_in_range,"stations in range"
    print n_with_precip_in,"stations in range with precip"
    print sum_precip_in,"is sum of all precip in range"
    tmp_stream.write(out_str)
    tmp_stream.close()
    done_file = tmp_file.replace(".writing",".written")
    os.rename(tmp_file,done_file)
     
        
        
