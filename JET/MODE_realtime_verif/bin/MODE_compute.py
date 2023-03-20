# FIRST of three scripts necessary to perform and plot object-based verification scores using MODE.

# script list and order:            %%%%%%%%%%%%%%%%%%%
# 1) MODE_compute.py                %%% THIS SCRIPT %%%
# 2) aggregate_MODE_scores(_TOD).py %%%%%%%%%%%%%%%%%%%
# 3) plot_MODE_results(_TOD).py

# This script reads from MODE text file outputs and then mostly does TWO things with those data. It operates in a looping structure
# with the following order:
#  -convolution radius
#  -convolution threshold
#  -forecast hour
#  -forecast case (although it will probably work best for a real-time workflow to only operate on one case at a time)
# The two things done with the input data are:
#   1: build object attribute distributions by filling arrays for each attribute type (for both forecasts and observation objects)
#   2: compute individual case partial sums for score such as OTS and mean centroid distance

# This script then dumps the attribute arrays and partial sums for each forecast case into Python Numpy arrays.
# This action is the most important and final action performed by this script.

# NOTE: This script performs NO plotting.

# This script expects several input arguments:
# model flavor name (e.g., HRRRv3/v4, HRRRX, RRFS, RRFSdev1)
# root directory location of MODE output (text) files
# root directory location to dump object attribute and partial sums arrays
# starting and ending times of the forecast cases to process
#    Discussion on this: while the code is built to be able to operate over a range of forecast cases, it will probably ultimately be
#    easiest for a real-time system to just process one forecast case at a time. Therefore, the start and end dates will probably just
#    be set to the same thing and thus only one date input will be needed
# first and last forecast hours to analyze (we will probably just assume a range...it may not need to be inserted)
# Some other settings are largely hard-coded

import argparse
import numpy as np
import sys
from os import path, stat, system
import subprocess
from datetime import datetime,timedelta
from pandas import read_csv

parser = argparse.ArgumentParser(description="Compute partial sums and build object attribute arrays.\nNOTE: All arguments listed below are REQUIRED, except for -diag",
                                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                 usage="MODE_compute.py [-h] [options]",
                                 epilog="""FIRST of three scripts necessary to perform and plot object-based verification scores using MODE.

script list and order:
1) MODE_compute(_TOD).py (this script)
2) aggregate_MODE_scores(_TOD).py
3) plot_MODE_results(_TOD).py

This script reads from MODE text file outputs and then mostly does TWO things with those data. It operates in a looping structure
with the following order:
  -convolution radius
  -convolution threshold
  -forecast hour
  -forecast case (although it will probably work best for a real-time workflow to only operate on one case at a time)
The two things done with the input data are:
   1: build object attribute distributions by filling arrays for each attribute type (for both forecasts and observation objects)
   2: compute individual case partial sums for score such as OTS and mean centroid distance

This script then dumps the attribute arrays and partial sums for each forecast case into Python Numpy arrays.
This action is the most important and final action performed by this script.

NOTE: This script performs NO plotting.""")

parser.add_argument('-mod'     ,type=str,metavar="model",dest="model",required=True,
                    help="Name of model flavor (e.g., HRRRv3, HRRRX, HRRRdev3)")
parser.add_argument('-case'    ,type=str,metavar="date",required=True,
                    help="Case date (forecast initialization) in YYYYMMDDHH format")
parser.add_argument('-MODE_out',type=str,metavar="MODE_out_dir",dest="mode_out",required=True,
                    help="Root directory of MODE output files")
parser.add_argument('-dump',type=str,metavar="dump_root",dest="dump_root",required=True,
                    help="Location to dump partial sums and object attribute files")
parser.add_argument('-f'       ,type=int,metavar=("start_fhr","end_fhr"),required=True,nargs=2,
                    help="First and last forecast hour to be processed")
parser.add_argument('-fld',type=str,metavar="field",dest="field",required=True,choices=["compref","precip"],
                    help="Field to be processed")
parser.add_argument('-diag',type=int,metavar="diag_print_switch",required=False,choices=range(0,6),default=1,
                     help="Each setting specifies a particular type of diagnostic output (not increasingly complex)")
args = parser.parse_args()

# Apply input arguments to global settings
name = args.model
field = args.field
dump_dir = args.dump_root + '/python_data/' + name + '/' + field
data_root = args.mode_out + '/' + name + '/' + field
iyear = int(args.case[:4])
eyear = iyear
imonth = int(args.case[4:6])
emonth = imonth
iday = int(args.case[6:8])
eday = iday
ihr = int(args.case[8:10])
ehr = ihr
ifhr = np.sort(args.f)[0] # start forecast hour to analyze
efhr = np.sort(args.f)[1] # end forecast hour to analyze

# Hard-coded constants/settings
delta_hr = 1 # distance between forecast initialization times
dx = 3.0 # grid spacing of input data
intensity_percentile_number = 99
if field == "compref":
   accum_hr = "00"
elif field == "precip":
   accum_hr = "06"
n_rad = 1
n_thresh = 4
match_int = 0.70 # threshold interest value to declare a match
###################### END SETTINGS #######################################

if args.diag == 1:
   print("Processing field " + field)
   print("Processing {} forecast initialized at {}".format(args.model,args.case))
   print("Processing forecast hour range of f{:02d}-f{:02d}".format(ifhr,efhr))
   print("Pulling in MODE output from " + data_root)
   print("Partial sums and attribute arrays will be stored in " + dump_dir)

def gc_dist(lon1,lat1,lon2,lat2):
   R_E = 6.371e6 # [m]
   # Convert to radians
   lon1 = np.deg2rad(lon1)
   lon2 = np.deg2rad(lon2)
   lat1 = np.deg2rad(lat1)
   lat2 = np.deg2rad(lat2)
   theta = np.arccos(np.sin(lat1)*np.sin(lat2) + np.cos(lat1)*np.cos(lat2)*np.cos(lon1 - lon2))
   distance = R_E * theta
   return distance

start_time = datetime(year=iyear,month=imonth,day=iday,hour=ihr)
end_time = datetime(year=eyear,month=emonth,day=eday,hour=ehr)

for R in range(1,n_rad+1):
   for T in range(1,n_thresh+1):
      if args.diag >= 1:
         print("WORKING ON THRESHOLD {}".format(T))

      ff = 0
      for fhr in range(ifhr,efhr+1):
         lead = "{:02d}".format(fhr)
         if args.diag >= 1:
            print("WORKING ON FORECAST HOUR {}".format(lead))

         # contingency table statistics
         hit = 0
         miss = 0
         false_alarm = 0
         n_matches = 0

         n_files = 0
         # time is the time at the start of each forecast case
         time = start_time
         # LOOP BY CASES (indicated by initialization time)
         while time <= end_time:
            # set the initialization time of the case
            cyear = time.year
            cmonth = "{:02d}".format(time.month)
            cday = "{:02d}".format(time.day)
            chour = "{:02d}".format(time.hour)
            # set up the valid time
            vtime = time + timedelta(hours=fhr)
            vyear = vtime.year
            vmonth = "{:02d}".format(vtime.month)
            vday = "{:02d}".format(vtime.day)
            vhour = "{:02d}".format(vtime.hour)

            if args.diag == 2:
               print("WORKING ON FORECAST CASE {}{}{} {}Z".format(cyear,cmonth,cday,chour))

            # Set file name to read
            if n_rad > 0 or n_thresh > 0:
               file = "{}/{}{}{}{}/mode_{}_{}0000L_{}{}{}_{}0000V_{}0000A_R{}_T{}_obj.txt".format(data_root,cyear,cmonth,cday,chour,field,lead,vyear,vmonth,vday,vhour,accum_hr,R,T)
            else:
               file = "{}/{}{}{}{}/mode_{}_{}0000L_{}{}{}_{}0000V_{}0000A_obj.txt".format(data_root,cyear,cmonth,cday,chour,field,lead,vyear,vmonth,vday,vhour,accum_hr)
            # Checks for file existence and size - skip if file does not exist or does not have data in it
            if not path.isfile(file):
               if args.diag == 2:
                  print(file + " does not exist!")
               time += timedelta(hours=delta_hr)
               continue
            # This block of code performs the Linux command "wc -l file" and checks if it has more than 1 line. If it doesn't, don't read the file.
            out = subprocess.Popen(['wc','-l',file],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
            stdout,stderr = out.communicate()
            nline = int(stdout.split()[0])
            fsize = stat(file).st_size
            if nline == 1:
               print("Data file " + file + " has no objects in it. Skipping file.")
               time += timedelta(hours=delta_hr)
               continue
            elif fsize == 0:
               print("Data file " + file + " has size 0 for some odd reason. Deleting it and moving on...")
               system("rm -f " + file)
               time += timedelta(hours=delta_hr)
               continue
            else:
               df = read_csv(file,sep="\s+")
               n_files += 1

            # Separate pandas dataframe into categories
            obj_ids = df['OBJECT_ID']
            cent_long = df['CENTROID_LON']
            cent_lat = df['CENTROID_LAT']
            ax_ang = df['AXIS_ANG']
            length = df['LENGTH']
            width = df['WIDTH']
            area = df['AREA']
            area_thresh = df['AREA_THRESH']
            curv = df['CURVATURE']
            complex = df['COMPLEXITY']
            p10 = df['INTENSITY_10']
            p25 = df['INTENSITY_25']
            p50 = df['INTENSITY_50']
            p75 = df['INTENSITY_75']
            p90 = df['INTENSITY_90']
            exec("pXX = df['INTENSITY_{}']".format(intensity_percentile_number))
            mass = df['INTENSITY_SUM']
            cent_dist = df['CENTROID_DIST']
            angle_diff = df['ANGLE_DIFF']
            aspect_diff = df['ASPECT_DIFF']
            area_ratio = df['AREA_RATIO']
            int_area = df['INTERSECTION_AREA']
            union_area = df['UNION_AREA']
            sym_diff_area = df["SYMMETRIC_DIFF"]
            cons_ratio = df["INTERSECTION_OVER_AREA"]
            curv_ratio = df['CURVATURE_RATIO']
            cplx_ratio = df['COMPLEXITY_RATIO']
            p_int_ratio = df['PERCENTILE_INTENSITY_RATIO']
            interest = df['INTEREST']

            # counts local to just this data file
            n_pairs = 0
            n_f = 0
            n_o = 0
            # data local to just this data file
            file_pair_fid = []
            file_pair_oid = []
            file_f_cent_lat = np.empty(0,dtype=np.float)
            file_f_cent_lon = np.empty(0,dtype=np.float)
            file_f_angle = np.empty(0,dtype=np.float)
            file_f_length = np.empty(0,dtype=np.float)
            file_f_width = np.empty(0,dtype=np.float)
            file_f_aspect = np.empty(0,dtype=np.float)
            file_f_mass = np.empty(0,dtype=np.float)
            file_f_p10 = np.empty(0,dtype=np.float)
            file_f_p25 = np.empty(0,dtype=np.float)
            file_f_p50 = np.empty(0,dtype=np.float)
            file_f_p75 = np.empty(0,dtype=np.float)
            file_f_p90 = np.empty(0,dtype=np.float)
            file_f_pXX = np.empty(0,dtype=np.float)
            file_f_area = np.empty(0,dtype=np.float)
            file_f_curvature = np.empty(0,dtype=np.float)
            file_f_complexity = np.empty(0,dtype=np.float)
            file_o_cent_lat = np.empty(0,dtype=np.float)
            file_o_cent_lon = np.empty(0,dtype=np.float)
            file_o_angle = np.empty(0,dtype=np.float)
            file_o_length = np.empty(0,dtype=np.float)
            file_o_width = np.empty(0,dtype=np.float)
            file_o_aspect = np.empty(0,dtype=np.float)
            file_o_mass = np.empty(0,dtype=np.float)
            file_o_p10 = np.empty(0,dtype=np.float)
            file_o_p25 = np.empty(0,dtype=np.float)
            file_o_p50 = np.empty(0,dtype=np.float)
            file_o_p75 = np.empty(0,dtype=np.float)
            file_o_p90 = np.empty(0,dtype=np.float)
            file_o_pXX = np.empty(0,dtype=np.float)
            file_o_area = np.empty(0,dtype=np.float)
            file_o_curvature = np.empty(0,dtype=np.float)
            file_o_complexity = np.empty(0,dtype=np.float)
            file_pair_dcentroid = np.empty(0,dtype=np.float)
            file_pair_dangle = np.empty(0,dtype=np.float)
            file_pair_daspect = np.empty(0,dtype=np.float)
            file_pair_area_ratio = np.empty(0,dtype=np.float)
            file_pair_int_area = np.empty(0,dtype=np.float)
            file_pair_union_area = np.empty(0,dtype=np.float)
            file_pair_sym_diff_area = np.empty(0,dtype=np.float)
            file_pair_consum_ratio = np.empty(0,dtype=np.float)
            file_pair_curv_ratio = np.empty(0,dtype=np.float)
            file_pair_complex_ratio = np.empty(0,dtype=np.float)
            file_pair_pct_intense_ratio = np.empty(0,dtype=np.float)
            file_pair_interest = np.empty(0,dtype=np.float)
            file_storm_match_dist = np.empty(0,dtype=np.float)
            file_all_match_dist = np.empty(0,dtype=np.float)
            file_gen_match_dist = np.empty(0,dtype=np.float)
            file_gen_match_x_error = np.empty(0,dtype=np.float)
            file_gen_match_y_error = np.empty(0,dtype=np.float)

            # Partition total input information into data columns
            # obj_ids = data[:,20]
            for i in range(0,len(obj_ids)):
               if obj_ids[i][0:1] == "F" and obj_ids[i].find("_") == -1:
                  n_f += 1
                  file_f_cent_lat = np.append(file_f_cent_lat,cent_lat[i])
                  file_f_cent_lon = np.append(file_f_cent_lon,cent_long[i])
                  file_f_angle = np.append(file_f_angle,ax_ang[i])
                  file_f_length = np.append(file_f_length,length[i])
                  file_f_width = np.append(file_f_width,width[i])
                  file_f_aspect = np.append(file_f_aspect,width[i]/length[i])
                  file_f_area = np.append(file_f_area,area[i])
                  file_f_curvature = np.append(file_f_curvature,curv[i])
                  file_f_complexity = np.append(file_f_complexity,complex[i])
                  file_f_p10 = np.append(file_f_p10,p10[i])
                  file_f_p25 = np.append(file_f_p25,p25[i])
                  file_f_p50 = np.append(file_f_p50,p50[i])
                  file_f_p75 = np.append(file_f_p75,p75[i])
                  file_f_p90 = np.append(file_f_p90,p90[i])
                  file_f_pXX = np.append(file_f_pXX,pXX[i])
                  file_f_mass = np.append(file_f_mass,mass[i])
               elif obj_ids[i][0:1] == "O" and obj_ids[i].find("_") == -1:
                  n_o += 1
                  file_o_cent_lat = np.append(file_o_cent_lat,cent_lat[i])
                  file_o_cent_lon = np.append(file_o_cent_lon,cent_long[i])
                  file_o_angle = np.append(file_o_angle,ax_ang[i])
                  file_o_length = np.append(file_o_length,length[i])
                  file_o_width = np.append(file_o_width,width[i])
                  file_o_aspect = np.append(file_o_aspect,width[i]/length[i])
                  file_o_area = np.append(file_o_area,area[i])
                  file_o_curvature = np.append(file_o_curvature,curv[i])
                  file_o_complexity = np.append(file_o_complexity,complex[i])
                  file_o_p10 = np.append(file_o_p10,p10[i])
                  file_o_p25 = np.append(file_o_p25,p25[i])
                  file_o_p50 = np.append(file_o_p50,p50[i])
                  file_o_p75 = np.append(file_o_p75,p75[i])
                  file_o_p90 = np.append(file_o_p90,p90[i])
                  file_o_pXX = np.append(file_o_pXX,pXX[i])
                  file_o_mass = np.append(file_o_mass,mass[i])
               elif obj_ids[i][0:1] == "F" and obj_ids[i].find("_") >= 0:
                  n_pairs += 1
                  fid = obj_ids[i].split("_")[0]
                  oid = obj_ids[i].split("_")[1]
                  file_pair_fid.append(int(fid[1:]))
                  file_pair_oid.append(int(oid[1:]))
                  file_pair_dcentroid = np.append(file_pair_dcentroid,cent_dist[i])
                  file_pair_dangle = np.append(file_pair_dangle,angle_diff[i])
                  file_pair_daspect = np.append(file_pair_daspect,aspect_diff[i])
                  file_pair_area_ratio = np.append(file_pair_area_ratio,area_ratio[i])
                  file_pair_int_area = np.append(file_pair_int_area,int_area[i])
                  file_pair_union_area = np.append(file_pair_union_area,union_area[i])
                  file_pair_sym_diff_area = np.append(file_pair_sym_diff_area,sym_diff_area[i])
                  file_pair_consum_ratio = np.append(file_pair_consum_ratio,cons_ratio[i])
                  file_pair_curv_ratio = np.append(file_pair_curv_ratio,curv_ratio[i])
                  file_pair_complex_ratio = np.append(file_pair_complex_ratio,cplx_ratio[i])
                  file_pair_pct_intense_ratio = np.append(file_pair_pct_intense_ratio,p_int_ratio[i])
                  file_pair_interest = np.append(file_pair_interest,interest[i])

            if args.diag == 3:
               print("There were {} forecast objects, {} observation objects, and {} pairs to evaluate in this file".format(n_f,n_o,n_pairs))

            if field == "compref":
               ##################################
               # Classify objects by morphology #
               ##################################
               f_morph_index = np.full(n_f,np.nan,dtype=np.int)
               o_morph_index = np.full(n_o,np.nan,dtype=np.int)
            
               if intensity_percentile_number == 95:
                  min_dbz = 39
               elif intensity_percentile_number == 99:
                  min_dbz = 41

               # FORECAST OBJECTS
               for i in range(n_f):
                  if file_f_pXX[i] >= min_dbz:
                     # Convective
                     if file_f_area[i]*dx**2 <= 2500 and file_f_complexity[i] <= 0.1 and file_f_aspect[i] >= 0.85:
                        f_morph_index[i] = 1 # Cellular
                     elif file_f_complexity[i] <= 0.4 and file_f_curvature[i]*dx > 2500 and file_f_length[i]*dx >= 100:
                        f_morph_index[i] = 2 # Linear, non-bow echo
                     elif file_f_complexity[i] <= 0.6 and file_f_curvature[i]*dx <= 2500:
                        f_morph_index[i] = 3 # Linear, bow-echo
                     elif file_f_area[i]*dx**2 >= 5000:
                        f_morph_index[i] = 4 # Non-linear convective
                     else:
                        f_morph_index[i] = 5 # Non-cellular convective
                  else:
                     f_morph_index[i] = 0 # non-convective

               # OBSERVATION OBJECTS
               for i in range(n_o):
                  if file_o_pXX[i] >= min_dbz:
                     # Convective
                     if file_o_area[i]*dx**2 <= 2500 and file_o_complexity[i] <= 0.1 and file_o_aspect[i] >= 0.85:
                        o_morph_index[i] = 1 # Cellular
                     elif file_o_complexity[i] <= 0.4 and file_o_curvature[i]*dx > 2500 and file_o_length[i]*dx >= 100:
                        o_morph_index[i] = 2 # Linear, non-bow echo
                     elif file_o_complexity[i] <= 0.6 and file_o_curvature[i]*dx <= 2500:
                        o_morph_index[i] = 3 # Linear, bow-echo
                     elif file_o_area[i]*dx**2 >= 5000:
                        o_morph_index[i] = 4 # Non-linear convective
                     else:
                        o_morph_index[i] = 5 # Non-cellular convective
                  else:
                     o_morph_index[i] = 0 # non-convective

            # Calculate metrics using data from the current file

            # Set-up object IDs for calculations
            file_pair_fid = np.array(file_pair_fid,dtype=np.int)
            file_pair_oid = np.array(file_pair_oid,dtype=np.int)

            ###################################
            # Object-based threat score (OTS) #
            ###################################
            # requirements:
            # -pair interest values
            # -object IDs associated with that pair (both forecast and observation)
            # -object areas (both forecast and observation)
            # We will compute the OTS over multiple cases by summing the numerator and denominator from each data file before taking the quotient
            ots_sum = 0.0
            if n_f > 0 and n_o > 0:
               # Sort the pair_interest array *from the current file only* but keep that sorted interest linked with the pair object IDs
               indices = np.argsort(file_pair_interest)
               # reverse the indices array so that it goes descending from maximum
               indices = indices[::-1]
               sorted_int = file_pair_interest[indices]
               sorted_fid = file_pair_fid[indices]
               sorted_oid = file_pair_oid[indices]

               if args.diag == 4:
                  for i in range(0,n_f):
                     print("Forecast object #{:03d} has area {}".format(i+1,file_f_area[i]))
                  for i in range(0,n_o):
                     print("Observation object #{:03d} has area {}".format(i+1,file_o_area[i]))
                  for i in range(0,n_pairs):
                     print("#{:03d}: interest of {:7.5f} corresponds to pair F{:03d}-O{:03d}".format(i,sorted_int[i],sorted_fid[i],sorted_oid[i]))

               matched_fid = []
               matched_oid = []
               for i in range(0,n_pairs):
                  if (sorted_fid[i] not in matched_fid) and (sorted_oid[i] not in matched_oid):
                     if args.diag == 4:
                        print("Object pair F{:03d}-O{:03d} with interest {} and areas {} & {} added to OTS sum".format(sorted_fid[i],sorted_oid[i],sorted_int[i],file_f_area[sorted_fid[i]-1],file_o_area[sorted_oid[i]-1]))
                     ots_sum += sorted_int[i] * (file_f_area[sorted_fid[i]-1] + file_o_area[sorted_oid[i]-1])
                     matched_fid.append(sorted_fid[i])
                     matched_oid.append(sorted_oid[i])
                  else:
                     if args.diag == 4:
                        if sorted_fid[i] in matched_fid:
                           print("forecast object {:03d} has already been used in OTS calculation. Skipping...".format(sorted_fid[i]))
                        elif sorted_oid[i] in matched_oid:
                           print("observation object {:03d} has already been used in OTS calculation. Skipping...".format(sorted_oid[i]))
               case_OTS = ots_sum / (np.sum(file_f_area) + np.sum(file_o_area))
            # END IF n_f > 0 and n_o > 0

            ###########
            #   MMI   #
            ###########
            alt_max_interest = np.empty(0,dtype=np.float)
            if n_f > 0 and n_o > 0:
               # Setup 2-dimensional interest array ( THIS IS A VERY IMPORTANT STEP )
               interest_2d = np.zeros((n_f,n_o),dtype=np.float) # This array is used in other metric calculations, so don't delete it!
               for n in range(0,n_pairs):
                  a = file_pair_fid[n] - 1
                  b = file_pair_oid[n] - 1
                  interest_2d[a,b] = file_pair_interest[n]
               # Compute standard MMI first
               max_int = np.amax(interest_2d,axis=1)
               max_interest = np.append(max_int,np.amax(interest_2d,axis=0))
               case_MMI = np.median(max_interest)

               # Next calculate alternate version, as OTS is calculated (the "generalized" method)
               matched_fid = []
               matched_oid = []
               for i in range(0,n_pairs):
                  if (sorted_fid[i] not in matched_fid) and (sorted_oid[i] not in matched_oid):
    #                 print("Object pair F{:03d}-O{:03d} with interest {} added to MMI list".format(sorted_fid[i],sorted_oid[i],sorted_int[i]))
                     alt_max_interest = np.append(alt_max_interest,sorted_int[i])
                     matched_fid.append(sorted_fid[i])
                     matched_oid.append(sorted_oid[i])
               n_zeros = np.maximum(n_f,n_o) - np.minimum(n_f,n_o)
               alt_max_interest = np.append(alt_max_interest,np.zeros(n_zeros))
            # END IF
            ############## end MMI calculation #################################

            ###########################
            # Mean centroid distances #
            ###########################
            # Mean distance between matched objects that resemble individual convective storms (i.e., omitting MCCs, MCSs, squall lines etc.)
            for p in range(0,n_pairs):
               if file_pair_interest[p] >= match_int:
                  file_all_match_dist = np.append(file_all_match_dist,file_pair_dcentroid[p])
                  if (file_f_area[file_pair_fid[p]-1] < 200. and file_o_area[file_pair_oid[p]-1] < 200.) and \
                     (file_f_pXX[file_pair_fid[p]-1] > 50. and file_o_pXX[file_pair_oid[p]-1] > 50.):
                     file_storm_match_dist = np.append(file_storm_match_dist,file_pair_dcentroid[p])
                     n_matches += 1

            # Mean distance calculated in a general sense using the same method as for OTS
            # this method does not require object "matches"
            if n_f > 0 and n_o > 0:
               file_dist = file_pair_dcentroid
               sorted_dist = file_dist[indices]
               matched_fid = []
               matched_oid = []
               for i in range(0,n_pairs):
                  if (sorted_fid[i] not in matched_fid) and (sorted_oid[i] not in matched_oid):
                     if args.diag == 5:
                        print("Object pair F{:03d}-O{:03d} with centroid distance {} added to mean distance sum".format(sorted_fid[i],sorted_oid[i],sorted_dist[i]))
                     file_gen_match_dist = np.append(file_gen_match_dist,sorted_dist[i])
                     matched_fid.append(sorted_fid[i])
                     matched_oid.append(sorted_oid[i])
                  # Compute E-W and N-S error components for generalized matches
                     x_error = np.sign(file_f_cent_lon[sorted_fid[i]-1]-file_o_cent_lon[sorted_oid[i]-1]) * \
                               gc_dist(file_f_cent_lon[sorted_fid[i]-1],file_o_cent_lat[sorted_oid[i]-1],file_o_cent_lon[sorted_oid[i]-1],file_o_cent_lat[sorted_oid[i]-1])
                     y_error = np.sign(file_f_cent_lat[sorted_fid[i]-1]-file_o_cent_lat[sorted_oid[i]-1]) * \
                               gc_dist(file_o_cent_lon[sorted_oid[i]-1],file_f_cent_lat[sorted_fid[i]-1],file_o_cent_lon[sorted_oid[i]-1],file_o_cent_lat[sorted_oid[i]-1])
                     file_gen_match_x_error = np.append(file_gen_match_x_error,x_error)
                     file_gen_match_y_error = np.append(file_gen_match_y_error,y_error)

            # Populate contingency table for matched objects
            # requires "interest_2d" array to be valid (DO NOT DELETE OR MOVE MMI calculation unless you move the interest_2d assignment somewhere!)
            n_hit = 0
            n_miss = 0
            n_fa = 0
            for o in range(0,n_o):
               found_hit = False
               for f in range(0,n_f):
                  # hit
                  if interest_2d[f,o] >= match_int:
                     n_hit += 1
                     found_hit = True
                     break # stop looking for other forecast objects that match to this observation one
               if not found_hit: # If we made it all the way through the f-loop without getting a hit, count a miss
                  n_miss += 1
            # Now search through the forecast objects to see if there were any false alarms
            for f in range(0,n_f):
               found_hit = False
               for o in range(0,n_o):
                  if interest_2d[f,o] > match_int:
                     found_hit = True
                     break
               # If, after searching through all observation objects, we didn't get a match, 
               # then the forecast object is a false alarm
               if not found_hit:
                  n_fa += 1
            if n_hit + n_miss > 0:
               case_pod = float(n_hit) / (n_hit + n_miss)
            else:
               case_pod = -999
            if n_hit + n_fa > 0:
               case_sr =  float(n_hit) / (n_hit + n_fa)
               case_far = float(n_fa) / (n_hit + n_fa)
            else:
               case_sr = -999
               case_far = -999
            if n_hit + n_miss + n_fa > 0:
               case_csi = float(n_hit) / (n_hit + n_miss + n_fa)
            else:
               case_csi = -999

            hit += n_hit
            miss += n_miss
            false_alarm += n_fa

            # Write partial sums and single-case object attribute lists to files
            # only scalar values will appear in the "partial_sums" files
            np.savez("{}/partial_sums/{}/partial_sums_r{}t{}_{}{}{}{}_f{}".format(dump_dir,args.case,R,T,cyear,cmonth,cday,chour,lead),
                    ots_sum_numer = ots_sum,
                    ots_sum_denom = np.sum(file_f_area) + np.sum(file_o_area),
                    n_f_objs = n_f,
                    n_o_objs = n_o,
                    n_hit = n_hit,
                    n_fa = n_fa,
                    n_miss = n_miss)
            # The "attributes" files will contain all vector quantities
            np.savez("{}/object_attributes/{}/attributes_r{}t{}_{}{}{}{}_f{}".format(dump_dir,args.case,R,T,cyear,cmonth,cday,chour,lead),
                    file_f_cent_lat=file_f_cent_lat,file_f_cent_lon=file_f_cent_lon,
                    file_f_angle = file_f_angle,
                    file_f_length = file_f_length,
                    file_f_width = file_f_width,
                    file_f_aspect = file_f_aspect,
                    file_f_mass = file_f_mass,
                    file_f_area = file_f_area,
                    file_f_curvature = file_f_curvature,
                    file_f_complexity = file_f_complexity,
                    file_f_p10 = file_f_p10,
                    file_f_p25 = file_f_p25,
                    file_f_p50 = file_f_p50,
                    file_f_p75 = file_f_p75,
                    file_f_p90 = file_f_p90,
                    file_f_pXX = file_f_pXX,
       	       	    file_o_cent_lat=file_o_cent_lat,file_o_cent_lon=file_o_cent_lon, 
       	       	    file_o_angle = file_o_angle,
       	       	    file_o_length = file_o_length,
       	       	    file_o_width = file_o_width,
       	       	    file_o_aspect = file_o_aspect,
       	       	    file_o_mass	= file_o_mass,
       	       	    file_o_area	= file_o_area,
       	       	    file_o_curvature = file_o_curvature,
       	       	    file_o_complexity =	file_o_complexity,
       	       	    file_o_p10 = file_o_p10,
       	       	    file_o_p25 = file_o_p25,
       	       	    file_o_p50 = file_o_p50,
       	       	    file_o_p75 = file_o_p75,
       	       	    file_o_p90 = file_o_p90,
       	       	    file_o_pXX = file_o_pXX,
                    file_pair_dcentroid = file_pair_dcentroid,
                    file_pair_dangle = file_pair_dangle,
                    file_pair_daspect = file_pair_daspect,
                    file_pair_area_ratio = file_pair_area_ratio,
                    file_pair_int_area = file_pair_int_area,
                    file_pair_union_area = file_pair_union_area,
                    file_pair_sym_diff_area = file_pair_sym_diff_area,
                    file_pair_consum_ratio = file_pair_consum_ratio,
                    file_pair_curv_ratio = file_pair_curv_ratio,
                    file_pair_complex_ratio = file_pair_complex_ratio,
                    file_pair_pct_intense_ratio = file_pair_pct_intense_ratio,
                    file_pair_interest = file_pair_interest,
                    all_match_dist = file_all_match_dist,
                    storm_match_dist = file_storm_match_dist,
                    gen_match_dist = file_gen_match_dist,
                    gen_match_x_error = file_gen_match_x_error,
                    gen_match_y_error = file_gen_match_y_error,
                    max_interest = max_interest,
                    alt_max_interest = alt_max_interest)
            # Object morphology classifications
            np.savez("{}/object_attributes/{}/morphology_index_r{}t{}_{}{}{}{}_f{}".format(dump_dir,args.case,R,T,cyear,cmonth,cday,chour,lead),
                    f_morph = f_morph_index,
                    o_morph = o_morph_index)

            # Increment time loop to next forecast cycle
            time += timedelta(hours=delta_hr)

         # END case loop (forecast init/cycle time)
      # END forecast hour time loop
   # End convolution theshold loop
# End convolution radii loop

