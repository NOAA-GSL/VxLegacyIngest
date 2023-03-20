# SECOND of three scripts necessary to perform and plot object-based verification scores using MODE.

# script list and order:
# 1) MODE_compute.py          %%%%%%%%%%%%%%%%%%%%
# 2) aggregate_MODE_scores.py %%% THIS SCRIPT %%%%
# 3) plot_MODE_results.py     %%%%%%%%%%%%%%%%%%%%

# This code aggregates object distributions and partial sums for object-based scores from MODE from individual cases into
# the all-case distributions and all-case object-based verification scores. It also performs a small degree of plotting, much of
# which is duplicated by plot_MODE_results*py
# NOTE: MUST RUN MODE_compute.py first!

# This script expects several input arguments:
# model flavor name (e.g., HRRRv3/v4, HRRRX, HRRRdev3)
# root directory location of dumped partial sums and object attribute files from running MODE_compute.py
# starting and ending times of the forecast cases to process
# first and last forecast hours to analyze
# Some other settings are largely hard-coded

import argparse
import numpy as np
import sys
from os import path, stat, system
from datetime import datetime,timedelta
import matplotlib
matplotlib.use('agg')
from mpl_toolkits.basemap import Basemap
import matplotlib.pyplot as plt
import matplotlib.cm as mplc
from matplotlib.colors import BoundaryNorm, ListedColormap

parser = argparse.ArgumentParser(description="Aggregate partial sums and object distributions over a range of forecast cases.\nNOTE: All arguments listed below are REQUIRED, except for -diag",
                                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                 usage="aggregate_MODE_scores.py [-h] [options]",
                                 epilog="""SECOND of three scripts necessary to perform and plot object-based verification scores using MODE.

script list and order:
1) MODE_compute.py
2) aggregate_MODE_scores.py [THIS SCRIPT]
3) plot_MODE_results.py

As the file name suggests, this script reads in the partial sums and object attribute distributions calculated in
MODE_compute.py and aggregates them over all cases. It then computes final object-based verification metrics such as
the "Object-based Threat Score (OTS)", "Median of Maximum Interest (MMI)", and mean centroid distances (custom defined).
It also calculates (1-SR,POD) pairs for objects for the purpose of plotting performance diagrams in plot_MODE_results.py.

Final metrics are stored in python binary files.

NOTE: this script does perform *some* plotting of hourly object-attribute distributions.""")

parser.add_argument('-mod'     ,type=str,metavar="model name",dest="model",required=True,
                    help="Name of model flavor (e.g., HRRRv3, HRRRX, HRRRdev3)")
parser.add_argument('-start_case'    ,type=str,metavar="YYYYMMDDHH",dest="idate",required=True,
                    help="first case date (forecast initialization)")
parser.add_argument('-end_case'    ,type=str,metavar="YYYYMMDDHH",dest="edate",required=True,
                    help="end case date (forecast initialization)")
parser.add_argument('-dump',type=str,metavar="dump_root",dest="dump_root",required=True,
                    help="Root location of partial sums and object attribute files (from MODE_compute.py)")
parser.add_argument('-f'       ,type=int,metavar=("iFHR","eFHR"),required=True,nargs=2,
                    help="First and last forecast hour to be processed")
parser.add_argument('-fld',type=str,metavar="field",dest="field",required=True,choices=["compref","precip"],
                    help="Field to be processed")
parser.add_argument('-diag',type=int,metavar="diag level",required=False,choices=range(0,6),default=1,
                     help="Each setting specifies a particular type of diagnostic output (not increasingly complex)")
args = parser.parse_args()

# Apply input arguments to global settings
name = args.model
field = args.field
dump_dir = args.dump_root + '/' + name + '/' + field
img_dir = "{}/{}/{}/images/dieoff".format(args.dump_root,name,field)
iyear = int(args.idate[:4])
eyear = int(args.edate[:4])
imonth = int(args.idate[4:6])
emonth = int(args.edate[4:6])
iday = int(args.idate[6:8])
eday = int(args.edate[6:8])
ihr = int(args.idate[8:10])
ehr = int(args.edate[8:10])
ifhr = np.sort(args.f)[0] # start forecast hour to analyze
efhr = np.sort(args.f)[1] # end forecast hour to analyze

# Hard-coded constants/settings
T_start = 1
delta_hr = 1 # distance between forecast initialization times
if field == "compref":
   accum_hr = "00"
elif field == "precip":
   accum_hr = "06"
n_rad = 1
n_thresh = 4
match_int = 0.70 # threshold interest value to declare a match
agg_fhr_start = [0,6 ,12,18,0 ,12, 0]
agg_fhr_end =   [6,12,18,24,12,24,24]
dx = 3.0 # grid spacing
match_int = 0.70 # threshold interest value to declare a match
# create color scheme for multiple convolution radius and threshold testing
centroid_FB_plot = True
cmp = mplc.get_cmap('coolwarm')
nq = np.linspace(0,1,n_rad*n_thresh+1)
colors = cmp(nq)
# For separation of object attributes by size, use these bins
# units should be assumed to be grid squares, so mulitply by dx^2 for physical size
small_area_thresh = 250
large_area_thresh = 2222

###################### END SETTINGS #######################################

def calc_CRPS(F,O,data_bins):
   delta = data_bins[1:] - data_bins[:-1]
   f_hist,bins = np.histogram(F,bins=data_bins)
   o_hist,bins = np.histogram(O,bins=data_bins)
   f_hist = f_hist / float(len(F))
   o_hist = o_hist / float(len(O))
   score = np.sum(delta*(np.cumsum(f_hist) - np.cumsum(o_hist))**2)
   return score

start_time = datetime(year=iyear,month=imonth,day=iday,hour=ihr)
end_time = datetime(year=eyear,month=emonth,day=eday,hour=ehr)

# For map projections
if True:
   clat = 39.0
   clon = -95.0
   proj_wid = 5.25e6
   proj_hgt = 3.25e6
   min_area = 500
   res = 'h'
   lbl_off_x = 30000
   lbl_off_y = 20000
   figsize = (12,8)
else:
# Eastern 2/3ds US
   clat = 39.0
   clon = -90.0
   proj_wid = 3.05e6
   proj_hgt = 2.45e6
   min_area = 250
   res = 'h'
   lbl_off_y = 10000
   lbl_off_x = 15000
   figsize = (12,9.5)

# set lat and lon bins for centroid binning
lon_bins = np.arange(-110.0,-65.1,1.0)
lat_bins = np.arange(25.0,51.1,1.0)
lats_2d,lons_2d = np.meshgrid(lat_bins,lon_bins)
# set x-/y- centroid error bins [km...raw data is in m...need to convert]
x_bins = np.arange(-150.0,150.1,10.0)
y_bins = np.arange(-150.0,150.1,10.0)
cy2d,cx2d = np.meshgrid(y_bins,x_bins)

# Bin settings for CRPS calculations
area_bins = np.array([144,200,300,400,500,600,800,1000,1250,1500,2000,2500,3000,4000,5000,10000,20000,50000])
if field == "precip":
   pXX_bins = np.array([0,1,3,5,10,15,20,25,30,40,50,100])
   mass_bins = np.array([0.0,0.1,1,2,4,8,16,32,64,100,200,500,1000,1500,2000,3000,5000])
elif field == "compref":
   pXX_bins = np.arange(20.,75.1,5.0)
   mass_bins = np.array([0,500,600,700,800,900,1000,1250,1500,1750,2000,3000,4000,5000,6000,7500,10000,15000,20000,30000,40000,50000,75000,100000,200000])
curvature_bins = np.arange(700.,3500.1,100.)

for R in range(1,n_rad+1):
   for T in range(T_start,n_thresh+1):
      print("WORKING ON THRESHOLD {}".format(T))

      # to set color index in later plots
      color_number = n_thresh*(R-1) + T - 1 # to force 0-base

      # Output metrics as a function of forecast lead time
      # aggregated across all cases
      num_fcst_objs = np.zeros(efhr-ifhr+1,dtype=np.int)
      num_obs_objs = np.zeros(num_fcst_objs.shape,dtype=np.int)
      OTS = np.full(num_fcst_objs.shape,-999.,dtype=np.float)
      MMI = np.full(num_fcst_objs.shape,-999.,dtype=np.float)
      total_pod = np.full(num_fcst_objs.shape,-999.,dtype=np.float)
      total_sr = np.full(num_fcst_objs.shape,-999.,dtype=np.float)
      total_far = np.full(num_fcst_objs.shape,-999.,dtype=np.float)
      total_csi = np.full(num_fcst_objs.shape,-999.,dtype=np.float)
      mean_centroid_dist = np.full((efhr-ifhr+1,5),-999.,dtype=np.float)
      median_centroid_dist = np.full(mean_centroid_dist.shape,-999.,dtype=np.float)
      std_centroid_dist = np.zeros(mean_centroid_dist.shape,dtype=np.float)
      fbias = -999.

      # All-forecast-hour aggregated object attribute distributions
      all_f_area = np.empty(0,dtype=np.int)
      all_f_aspect = np.empty(0,dtype=np.float)
      all_f_complexity = np.empty(0,dtype=np.float)
      all_f_pXX = np.empty(0,dtype=np.float)
      all_f_mass = np.empty(0,dtype=np.float)
      all_f_cent_lon = np.empty(0,dtype=np.float)
      all_f_cent_lat = np.empty(0,dtype=np.float)
      all_o_area = np.empty(0,dtype=np.int)
      all_o_aspect = np.empty(0,dtype=np.float)
      all_o_complexity = np.empty(0,dtype=np.float)
      all_o_pXX = np.empty(0,dtype=np.float)
      all_o_mass = np.empty(0,dtype=np.float)
      all_o_cent_lon = np.empty(0,dtype=np.float)
      all_o_cent_lat = np.empty(0,dtype=np.float)

      # Based on this array dimensionality, aggregated scores cannot be plotted in this code and must instead be plotted in the "plot_MODE_results" script
      # Final time-aggregated scores
      agg_OTS = np.full((len(agg_fhr_start)),-999.,dtype=np.float)
      agg_MMI = np.full(agg_OTS.shape,-999.,dtype=np.float)
      agg_pod = np.full(agg_OTS.shape,-999.,dtype=np.float)
      agg_far = np.full(agg_OTS.shape,-999.,dtype=np.float)
      agg_sr = np.full(agg_OTS.shape,-999.,dtype=np.float)
      agg_csi = np.full(agg_OTS.shape,-999.,dtype=np.float)
      agg_mean_dist = np.full(agg_OTS.shape,-999.,dtype=np.float) # ONLY ALL MATCHED objects (not JUST STORMS)
      agg_gen_dist = np.full(agg_OTS.shape,-999.,dtype=np.float) # for generalized distance
      agg_fcst_count = np.zeros(agg_OTS.shape,dtype=np.int)
      agg_obs_count = np.zeros(agg_OTS.shape,dtype=np.int)
      agg_fbias = np.zeros(agg_OTS.shape,dtype=np.float)

      # Time-aggregated score components
      agg_ots_sum = np.zeros((len(agg_fhr_start),2),dtype=np.float)
      # One agg_max_int array for each possible set of aggregated time periods (need to add more if len(agg_fhr_start > 15))
      for d in range(0,len(agg_fhr_start)):
         exec("agg_max_int_{:02d} = np.empty(0,dtype=np.float)".format(d))
         exec("agg_gen_dist_{:02d} = np.empty(0,dtype=np.float)".format(d))
      agg_hit = np.zeros(len(agg_fhr_start),dtype=np.int)
      agg_fa = np.zeros(len(agg_fhr_start),dtype=np.int)
      agg_miss = np.zeros(len(agg_fhr_start),dtype=np.int)
      agg_dist_sum = np.zeros(len(agg_fhr_start),dtype=np.float)
      agg_dist_count = np.zeros(len(agg_fhr_start),dtype=np.int)

      ff = 0
      for fhr in range(ifhr,efhr+1):
         lead = "{:02d}".format(fhr)
         print("WORKING ON FORECAST HOUR {}".format(lead))

         ots_sum = np.zeros(2,dtype=np.float)
         max_int_array = np.empty(0,dtype=np.float)

         # initialize empty arrays for all-case distribution. Since we don't know the number of forecast and observation objects
         # at the moment we first perform the data read, we will start with empty arrays and build them up as we go.
         ### individual object qualities
         f_cent_lat = np.empty(0,dtype=np.float)
         f_cent_lon = np.empty(0,dtype=np.float)
         f_angle = np.empty(0,dtype=np.float)
         f_length = np.empty(0,dtype=np.float)
         f_width = np.empty(0,dtype=np.float)
         f_aspect = np.empty(0,dtype=np.float)
         f_area = np.empty(0,dtype=np.float)
         f_curvature = np.empty(0,dtype=np.float)
         f_complexity = np.empty(0,dtype=np.float)
         f_p10 = np.empty(0,dtype=np.float)
         f_p25 = np.empty(0,dtype=np.float)
         f_p50 = np.empty(0,dtype=np.float)
         f_p75 = np.empty(0,dtype=np.float)
         f_p90 = np.empty(0,dtype=np.float)
         f_pXX = np.empty(0,dtype=np.float)
         f_mass = np.empty(0,dtype=np.float)
       	 o_cent_x = np.empty(0,dtype=np.float)
       	 o_cent_y = np.empty(0,dtype=np.float)
         o_cent_lat = np.empty(0,dtype=np.float)
         o_cent_lon = np.empty(0,dtype=np.float)
         o_angle = np.empty(0,dtype=np.float)
         o_length = np.empty(0,dtype=np.float)
         o_width = np.empty(0,dtype=np.float)
         o_aspect = np.empty(0,dtype=np.float)
         o_area = np.empty(0,dtype=np.float)
         o_area_t = np.empty(0,dtype=np.float)
         o_curvature = np.empty(0,dtype=np.float)
         o_complexity = np.empty(0,dtype=np.float)
         o_p10 = np.empty(0,dtype=np.float)
         o_p25 = np.empty(0,dtype=np.float)
         o_p50 = np.empty(0,dtype=np.float)
         o_p75 = np.empty(0,dtype=np.float)
         o_p90 = np.empty(0,dtype=np.float)
         o_pXX = np.empty(0,dtype=np.float)
         o_mass = np.empty(0,dtype=np.float)
         # object pair attributes
         pair_dcentroid = np.empty(0,dtype=np.float)
         pair_dangle = np.empty(0,dtype=np.float)
         pair_daspect = np.empty(0,dtype=np.float)
         pair_area_ratio = np.empty(0,dtype=np.float)
         pair_int_area = np.empty(0,dtype=np.float)
         pair_union_area = np.empty(0,dtype=np.float)
         pair_sym_diff_area = np.empty(0,dtype=np.float)
         pair_consum_ratio = np.empty(0,dtype=np.float)
         pair_curv_ratio = np.empty(0,dtype=np.float)
         pair_complex_ratio = np.empty(0,dtype=np.float)
         pair_pct_intense_ratio = np.empty(0,dtype=np.float)
         pair_interest = np.empty(0,dtype=np.float)
         # other
         gen_x_match_dist = np.empty(0,dtype=np.float)
         gen_y_match_dist = np.empty(0,dtype=np.float)
         # Note: not including clusters, whether matched or not
         # contingency table statistics
         hit = 0
         miss = 0
         false_alarm = 0
         storm_match_dist_array = np.empty(0,dtype=np.float)
         all_match_dist_array = np.empty(0,dtype=np.float)
         gen_match_dist_array = np.empty(0,dtype=np.float)

         n_cases = 0
         # time is the time at the start of each forecast case
         time = start_time
         # LOOP BY CASES (indicated by initialization time)
         while time <= end_time:
            # set the initialization time of the case
            cyear = str(time.year)
            cmonth = "{:02d}".format(time.month)
            cday = "{:02d}".format(time.day)
            chour = "{:02d}".format(time.hour)
            casedir = cyear + cmonth + cday + chour
            # set up the valid time
            vtime = time + timedelta(hours=fhr)
            vyear = vtime.year
            vmonth = "{:02d}".format(vtime.month)
            vday = "{:02d}".format(vtime.day)
            vhour = "{:02d}".format(vtime.hour)

            if args.diag >= 2:
               print("WORKING ON FORECAST CASE {}{}{} {}Z".format(cyear,cmonth,cday,chour))
            psum_filename = "{}/partial_sums/{}/partial_sums_r{}t{}_{}_f{}.npz".format(dump_dir,casedir,R,T,casedir,lead)
            attr_filename = "{}/object_attributes/{}/attributes_r{}t{}_{}_f{}.npz".format(dump_dir,casedir,R,T,casedir,lead)
            if path.isfile(psum_filename) and path.isfile(attr_filename):
               data_psum = np.load(psum_filename)
               data_attr = np.load(attr_filename)
               n_cases += 1
            else:
               print("Data for case {}{}{} {}Z not present...skipping loop. n_cases = {}".format(cyear,cmonth,cday,chour,n_cases))
               # Increment time and move to next case
               time += timedelta(hours=delta_hr)
               continue

            # Construct all-case sum from partial sums
            ots_sum[0] += data_psum['ots_sum_numer']
            ots_sum[1] += data_psum['ots_sum_denom']
            num_fcst_objs[ff] += data_psum['n_f_objs']
            num_obs_objs[ff] += data_psum['n_o_objs']
            hit += data_psum['n_hit']
            miss += data_psum['n_miss']
            false_alarm += data_psum['n_fa']

            # Construct large arrays to make final calculations
            max_int_array = np.append(max_int_array,data_attr['max_interest'])
            standard_MMI = data_attr['MMI_flag']
            all_match_dist_array = np.append(all_match_dist_array,data_attr['all_match_dist'])
            storm_match_dist_array = np.append(storm_match_dist_array,data_attr['storm_match_dist'])
            gen_match_dist_array = np.append(gen_match_dist_array,data_attr['gen_match_dist'])

            # Append storm attribute file arrays to all-case arrays
            f_cent_lat = np.append(f_cent_lat,data_attr['file_f_cent_lat'])
            f_cent_lon = np.append(f_cent_lon,data_attr['file_f_cent_lon'])
            f_angle = np.append(f_angle,data_attr['file_f_angle'])
            f_length = np.append(f_length,data_attr['file_f_length'])
            f_width = np.append(f_width,data_attr['file_f_width'])
            f_aspect = np.append(f_aspect,data_attr['file_f_aspect'])
            f_area = np.append(f_area,data_attr['file_f_area'])
            f_curvature = np.append(f_curvature,data_attr['file_f_curvature'])
            f_complexity = np.append(f_complexity,data_attr['file_f_complexity'])
     #       f_p10 = np.append(f_p10,data_attr['file_f_p10'])
     #       f_p25 = np.append(f_p25,data_attr['file_f_p25'])
     #       f_p50 = np.append(f_p50,data_attr['file_f_p50'])
     #       f_p75 = np.append(f_p75,data_attr['file_f_p75'])
     #       f_p90 = np.append(f_p90,data_attr['file_f_p90'])
            f_pXX = np.append(f_pXX,data_attr['file_f_p95'])
            f_mass = np.append(f_mass,data_attr['file_f_mass'])
            o_cent_lat = np.append(o_cent_lat,data_attr['file_o_cent_lat'])
            o_cent_lon = np.append(o_cent_lon,data_attr['file_o_cent_lon'])
            o_angle = np.append(o_angle,data_attr['file_o_angle'])
            o_length = np.append(o_length,data_attr['file_o_length'])
            o_width = np.append(o_width,data_attr['file_o_width'])
            o_aspect = np.append(o_aspect,data_attr['file_o_aspect'])
            o_area = np.append(o_area,data_attr['file_o_area'])
            o_curvature = np.append(o_curvature,data_attr['file_o_curvature'])
            o_complexity = np.append(o_complexity,data_attr['file_o_complexity'])
            o_p10 = np.append(o_p10,data_attr['file_o_p10'])
    #        o_p25 = np.append(o_p25,data_attr['file_o_p25'])
    #        o_p50 = np.append(o_p50,data_attr['file_o_p50'])
    #        o_p75 = np.append(o_p75,data_attr['file_o_p75'])
    #        o_p90 = np.append(o_p90,data_attr['file_o_p90'])
            o_pXX = np.append(o_pXX,data_attr['file_o_p95'])
            o_mass = np.append(o_mass,data_attr['file_o_mass'])
            pair_dcentroid = np.append(pair_dcentroid,data_attr['file_pair_dcentroid'])
    #        pair_dangle = np.append(pair_dangle,data_attr['file_pair_dangle'])
    #        pair_daspect = np.append(pair_daspect,data_attr['file_pair_daspect'])
    #        pair_area_ratio = np.append(pair_area_ratio,data_attr['file_pair_area_ratio'])
    #        pair_int_area = np.append(pair_int_area,data_attr['file_pair_int_area'])
    #        pair_union_area = np.append(pair_union_area,data_attr['file_pair_union_area'])
    #        pair_sym_diff_area = np.append(pair_sym_diff_area,data_attr['file_pair_sym_diff_area'])
    #        pair_consum_ratio = np.append(pair_consum_ratio,data_attr['file_pair_consum_ratio'])
    #        pair_curv_ratio = np.append(pair_curv_ratio,data_attr['file_pair_curv_ratio'])
    #        pair_complex_ratio = np.append(pair_complex_ratio,data_attr['file_pair_complex_ratio'])
    #        pair_pct_intense_ratio = np.append(pair_pct_intense_ratio,data_attr['file_pair_pct_intense_ratio'])
            pair_interest = np.append(pair_interest,data_attr['file_pair_interest'])
            gen_x_match_dist = np.append(gen_x_match_dist,data_attr['gen_match_x_error'])
            gen_y_match_dist = np.append(gen_y_match_dist,data_attr['gen_match_y_error'])
            if args.diag >= 3:
               print("There were {} forecast objects, {} observation objects, and {} pairs to evaluate in this file".format(n_f,n_o,n_pairs))

            # Increment time loop to next forecast cycle
            time += timedelta(hours=delta_hr)

         # END case loop (forecast init/cycle time)

         if args.diag >= 3:
            print("There were {} matched object pairs representing the shape of a single intense thunderstorm evaluated at f{:02d}".format(len(storm_match_dist_array),fhr))
            print("There are a total of {} forecast objects and {} observation objects to evaluate at forecast hour {:02d} over {} cases".format(num_fcst_objs[ff],num_obs_objs[ff],fhr,n_cases))

         # Aggregate object attributes over all forecast hours
         all_f_area = np.append(all_f_area,f_area)
         all_f_aspect = np.append(all_f_aspect,f_aspect)
         all_f_complexity = np.append(all_f_complexity,f_complexity)
         all_f_pXX = np.append(all_f_pXX,f_pXX)
         all_f_mass = np.append(all_f_mass,f_mass)
         all_f_cent_lon = np.append(all_f_cent_lon,f_cent_lon)
         all_f_cent_lat = np.append(all_f_cent_lat,f_cent_lat)
         all_o_area = np.append(all_o_area,o_area)
         all_o_aspect = np.append(all_o_aspect,o_aspect)
         all_o_complexity = np.append(all_o_complexity,o_complexity)
         all_o_pXX = np.append(all_o_pXX,o_pXX)
         all_o_mass = np.append(all_o_mass,o_mass)
         all_o_cent_lon = np.append(all_o_cent_lon,o_cent_lon)
         all_o_cent_lat = np.append(all_o_cent_lat,o_cent_lat)

         if len(storm_match_dist_array) > 0:
            mean_centroid_dist[ff,0] = np.mean(storm_match_dist_array)
            median_centroid_dist[ff,0] = np.median(storm_match_dist_array)
            std_centroid_dist[ff,0] = np.std(storm_match_dist_array)
         if len(all_match_dist_array) > 0:
            mean_centroid_dist[ff,1] = np.mean(all_match_dist_array)
            median_centroid_dist[ff,1] = np.median(all_match_dist_array)
            std_centroid_dist[ff,1] = np.std(all_match_dist_array)
       	 if len(gen_match_dist_array)	> 0:
            mean_centroid_dist[ff,2] = np.mean(gen_match_dist_array)
            median_centroid_dist[ff,2] = np.median(gen_match_dist_array)
            std_centroid_dist[ff,2] = np.std(gen_match_dist_array)

         # Add time-aggregated score components to arrays
         # (The final calculation of time-aggregated scores must occur outside of the forecast-hour loop...so...in other words...outside of THIS loop)
         for d in range(0,len(agg_fhr_start)):
            if fhr >= agg_fhr_start[d] and fhr <= agg_fhr_end[d]:
               agg_ots_sum[d,0] += ots_sum[0]
               agg_ots_sum[d,1] += ots_sum[1]
               exec("agg_max_int_{:02d} = np.append(agg_max_int_{:02d},max_int_array)".format(d,d))
               exec("agg_gen_dist_{:02d} = np.append(agg_gen_dist_{:02d},gen_match_dist_array)".format(d,d))
               agg_dist_sum[d] += np.sum(all_match_dist_array)
               agg_dist_count[d] += len(all_match_dist_array)
               agg_hit[d] += hit
               agg_miss[d] += miss
               agg_fa[d] += false_alarm
               agg_fcst_count[d] += num_fcst_objs[ff]
               agg_obs_count[d] += num_obs_objs[ff]
         for d in range(0,len(agg_fhr_start)):
            exec("agg_gen_dist[{}] = np.mean(agg_gen_dist_{:02d})".format(d,d))
            if agg_obs_count[d] > 0:
               agg_fbias[d] = float(agg_fcst_count[d]) / agg_obs_count[d]

         if num_fcst_objs[ff] > 0 and num_obs_objs[ff] > 0:

            # Compute single-forecast-hour scores
            if hit + miss > 0:
               total_pod[ff] = float(hit) / (hit + miss)
            if hit + false_alarm > 0:
               total_sr[ff] = float(hit) / (hit + false_alarm)
               total_far[ff] = float(false_alarm) / (hit + false_alarm)
            if hit + miss + false_alarm > 0:
               total_csi[ff] = float(hit) / (hit + miss + false_alarm)

            OTS[ff] = ots_sum[0] / ots_sum[1]
            MMI[ff] = np.median(max_int_array)

            # Calculate object attribute distribution CRPSs
            cent_lon_crps = calc_CRPS(f_cent_lon,o_cent_lon,np.arange(-108.0,75.01,0.1))
            cent_lat_crps = calc_CRPS(f_cent_lat,o_cent_lat,np.arange(25.0,51.01,0.1))
            area_crps = calc_CRPS(f_area,o_area,area_bins)
            length_crps = calc_CRPS(f_length,o_length,np.arange(2,751.,5.0))
            width_crps = calc_CRPS(f_width,o_width,np.arange(1,301,1.0))
            aspect_crps = calc_CRPS(f_aspect,o_aspect,np.arange(0.0,1.01,0.01))
            complex_crps = calc_CRPS(f_complexity,o_complexity,np.arange(0.0,1.01,0.01))
            pXX_crps = calc_CRPS(f_pXX,o_pXX,pXX_bins)
            curv_crps = calc_CRPS(f_curvature,o_curvature,curvature_bins)

            if False:
               # What is the typical area of objects with a given curvature?
               curvature_area_sum = np.zeros_like(curvature_bins,dtype=np.float)
               curvature_num = np.zeros_like(curvature_bins,dtype=np.int)
               mean_area_curv = np.zeros_like(curvature_bins,dtype=np.float)
               curvature_ar_sum = np.zeros_like(curvature_bins,dtype=np.float)
               mean_AR_curv = np.zeros_like(curvature_bins,dtype=np.float)
               for a in range(0,num_fcst_objs[ff]):
                  for b in range(0,len(curvature_bins)-1):
                     if f_curvature[a] > curvature_bins[b] and f_curvature[a] <= curvature_bins[b+1]:
                        curvature_area_sum[b] += f_area[a]
                        curvature_num[b] += 1
       	                curvature_ar_sum[b] += f_aspect[a]
       	                break
               mean_area_curv = curvature_area_sum / curvature_num
               mean_AR_curv = curvature_ar_sum / curvature_num
               f = plt.figure(figsize=(5,5))
               ax1 = f.add_axes([0.125,0.1,0.775,0.88])
               ax1.set_xlim(curvature_bins[0],curvature_bins[-1])
               ax1.set_xticks(curvature_bins[::2])
               ax1.set_xlabel('Curvature value',fontsize=8)
               ax2 = plt.twinx(ax1)
               h1 = ax1.plot(0.5*(curvature_bins[:-1] + curvature_bins[1:]),mean_area_curv[:-1],'r-x',linewidth=2,label="area")
               h2 = ax2.plot(0.5*(curvature_bins[:-1] + curvature_bins[1:]),mean_AR_curv[:-1],'b-x',linewidth=2,label="aspect ratio")
               for a in range(0,len(curvature_bins)-1):
                  if curvature_num[a] > 0:
                     ax1.text(0.5*(curvature_bins[a] + curvature_bins[a+1]),mean_area_curv[a]+25,"{:4d}".format(curvature_num[a]),ha='center',va='bottom',fontsize=6,fontweight=100,rotation=45)
               ax1.grid(linestyle=":",color="0.75")
               ax2.set_xlim(curvature_bins[0],curvature_bins[-1])
               ax2.set_ylim(0,1)
               ax2.set_yticks(np.arange(0.,1.01,0.1))
               ax2.set_ylabel("aspect ratio",fontsize=8)
               ax1.set_ylabel(r"object area [$km^2$]",fontsize=8)
               ax1.tick_params(axis='both',labelsize=6)
               ax2.tick_params(axis='y',labelsize=6)
               lns = h1 + h2
               lbls = [l.get_label() for l in lns]
               ax1.legend(lns,lbls,loc=0,fontsize=8)
               image_file = "{}/{}_curvature_parameters_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               f.savefig(image_file)
               plt.close()

            if True:
               # Determine object count bias as a function of object size
               f_hist,bin = np.histogram(dx**2*f_area,bins=area_bins)
               o_hist,bin = np.histogram(dx**2*o_area,bins=area_bins)
               bias_by_size = 1.0*f_hist / o_hist
               # Also corroborate frequency (coverage) bias from MATS by calculating total area
               fbias = np.sum(f_area) / np.sum(o_area)
               plt.figure(figsize=(5,5))
               plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
               plt.bar(0.5*(bin[:-1]+bin[1:]),bias_by_size,align='center',width=1.0*(bin[1:]-bin[:-1]),color='red',edgecolor='black',linewidth=1,label=name)
               plt.xscale('log')
               plt.grid(linestyle=":",color='0.75')
               if T <= 2:
                  plt.ylim(0.5,2.25)
               else:
                  plt.ylim(0.9,30)
                  plt.yscale('log')
               plt.xlabel(r"Object area bin [km$^{2}$]",size=8)
               plt.ylabel("object count bias (F/O)",size=8)
               plt.tick_params(axis='both',labelsize=6)
               plt.legend(loc=1,prop={'size':8})
               image_file = "{}/{}_object_bias_by_size_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

            if False:
               # Geographical location of objects
               # first one is gridded location of objects
               plt.figure(figsize=(9,5))
               plt.subplots_adjust(left=0.075,bottom=0.075,top=0.98,right=0.98,wspace=0.2)
               plt.subplot(1,2,1)
               f_hist,bin = np.histogram(f_cent_lon,bins=np.arange(-107.5,-79.51,1.0))
               o_hist,bin = np.histogram(o_cent_lon,bins=np.arange(-107.5,-79.51,1.0))
               plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[ff]),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
               plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(num_obs_objs[ff]),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
               plt.grid(linestyle=":",color='0.75')
               plt.xlabel("Object centroid longitude (deg.)",size=8)
               plt.ylabel("relative frequency",size=8)
               plt.tick_params(axis='both',labelsize=6)
               plt.legend(loc=1,prop={'size':8})
               mu_f = np.mean(f_cent_lon)
               mu_o = np.mean(o_cent_lon)
               std_f = np.std(f_cent_lon)
               std_o = np.std(o_cent_lon)
               med_f = np.median(f_cent_lon)
               med_o = np.median(o_cent_lon)
               plt.figtext(0.10,0.96,r"$\mu_f$={:5.1f};  $\mu_o$={:5.1f}".format(mu_f,mu_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.10,0.91,r"median$_f$={:5.1f};  median$_o$={:5.1f}".format(med_f,med_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.10,0.86,r"$\sigma_f$={:4.1f};  $\sigma_o$={:4.1f}".format(std_f,std_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.10,0.81,r"N$_f$={};  N$_o$={}".format(num_fcst_objs[ff],num_obs_objs[ff]),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.10,0.76,"CRPS={:5.3f}".format(cent_lon_crps),ha='left',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
               plt.subplot(1,2,2)
               f_hist,bin = np.histogram(f_cent_lat,bins=np.arange(27.5,49.51,1.0))
               o_hist,bin = np.histogram(o_cent_lat,bins=np.arange(27.5,49.51,1.0))
               plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[ff]),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
               plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(num_obs_objs[ff]),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
               plt.grid(linestyle=":",color='0.75')
               plt.xlabel("Object centroid latitude (deg.)",size=8)
               plt.ylabel("relative frequency",size=8)
               plt.tick_params(axis='both',labelsize=6)
               mu_f = np.mean(f_cent_lat)
               mu_o = np.mean(o_cent_lat)
               std_f = np.std(f_cent_lat)
               std_o = np.std(o_cent_lat)
               med_f = np.median(f_cent_lat)
               med_o = np.median(o_cent_lat)
               plt.figtext(0.97,0.96,r"$\mu_f$={:3.1f};  $\mu_o$={:3.1f}".format(mu_f,mu_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.91,r"median$_f$={:3.1f};  median$_o$={:3.1f}".format(med_f,med_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.86,r"$\sigma_f$={:3.1f};  $\sigma_o$={:3.1f}".format(std_f,std_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.81,r"N$_f$={};  N$_o$={}".format(num_fcst_objs[ff],num_obs_objs[ff]),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.76,"CRPS={:5.3f}".format(cent_lat_crps),ha='right',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
               image_file = "{}/{}_object_centroid_loc_hist_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

            if True:
               # map of east-west and south-north components of centroid error
               plt.figure(figsize=(5,5))
               plt.subplots_adjust(left=0.125,bottom=0.1,top=0.9,right=0.875)
               centroid_error_hist2d,binx,biny = np.histogram2d(gen_x_match_dist/1000.,gen_y_match_dist/1000.,bins=[x_bins,y_bins]) # division is to convert from m to km
               hist = centroid_error_hist2d / len(gen_match_dist_array)
               clevs = [1e-5,1e-4,2.5e-4,5e-4,7.5e-4,1e-3,2.5e-3,5e-3,7.5e-3,1e-2,2.5e-2,5e-2,7.5e-2,1e-1,2e-1]
               ccs = mplc.get_cmap('BuPu',len(clevs))
               plt.contourf(0.5*(cx2d[:-1,:-1]+cx2d[1:,1:]),0.5*(cy2d[:-1,:-1]+cy2d[1:,1:]),hist,clevs,colors=ccs(range(len(clevs))),extend='both')
               plt.grid(linestyle=":",color='0.75')
               plt.xlim(x_bins[0],x_bins[-1])
               plt.ylim(y_bins[0],y_bins[-1])
               plt.xlabel("west-east centroid error [km]",size=8)
               plt.ylabel("south-north centroid error [km]",size=8)
               plt.tick_params(axis='both',labelsize=6)
               cb = plt.colorbar(orientation='vertical',fraction=0.05,aspect=20,pad=0.03,shrink=0.5,extend='max',format="%2.1e")
               cb.set_ticks(clevs)
               cb.set_label("relative frequency",fontsize=10)
               cb.ax.tick_params(labelsize=6)
               plt.plot(np.nanmean(gen_x_match_dist)/1000.,np.nanmean(gen_y_match_dist)/1000.,'xk',ms=6,mew=2,label="mean error location")
               plt.plot(np.nanmedian(gen_x_match_dist)/1000.,np.nanmedian(gen_y_match_dist)/1000.,'ok',ms=6,mew=2,label="median error location")
               plt.legend(loc='upper right',prop={'size':8})
               image_file = "{}/{}_object_centroid_error_map_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

            if True:
               # Projected map plots of object centroids
               # We will keep this code so that any of the following three types of plots can be made just by commenting or setting flags (rather than replacing the code altogether)
               # - forecast-object centroid density
               # - observation-object centroid density
               # - frequency bias of object centroid density
               f_hist2d,binx,biny = np.histogram2d(f_cent_lon,f_cent_lat,bins=[lon_bins,lat_bins])
               o_hist2d,binx,biny = np.histogram2d(o_cent_lon,o_cent_lat,bins=[lon_bins,lat_bins])
               if centroid_FB_plot:
                fbias_hist2d = np.ma.masked_where(o_hist2d == 0,f_hist2d/o_hist2d)
               else:
                hist2d = f_hist2d / (1.0*num_fcst_objs[ff])
                #hist2d = o_hist2d / (1.0*num_obs_objs[ff])
                hist_max = 10**np.ceil(np.log10(np.amax(hist2d)))
               fig = plt.figure(figsize=figsize)
               ax = plt.subplots_adjust(left=0.01,right=0.95,bottom=0.05,top=0.99)
               m = Basemap(projection='lcc',width=proj_wid,height=proj_hgt,lat_0=clat,lon_0=clon,lat_1=38.5,resolution=res,area_thresh=min_area)
               m.drawlsmask(land_color='0.9',ocean_color='powderblue')
               m.drawcountries(linewidth=1,color='0.1')
               if True:
                  m.drawcoastlines(linewidth=0.5,color='0.4')
               else:
                  m.drawcounties(linewidth=0.5,color='0.6',linestyle='-')
               m.drawstates(linewidth=0.5,color='0.5')
               m.drawmapboundary(color=[0.25,0.01,0.02],linewidth=3)
               m.drawmeridians(np.arange(-130.0,-50.1,10.0),linewidth=0.1,labels=[0,0,0,1],labelstyle='E/W',yoffset=lbl_off_y,fontsize=8,dashes=[2,2])
               m.drawparallels(np.arange(20.0,55.1,5.0),linewidth=0.1,labels=[0,1,0,0],labelstyle='E/W',xoffset=lbl_off_x,fontsize=8,dashes=[2,2])
               x2d,y2d = m(lons_2d,lats_2d)
               # Frequency bias plot
               if centroid_FB_plot:
                fb_clevs_low = np.array([0,0.25,0.5,0.75,0.9])
                fb_clevs_high = np.array([1.1,1.25,1.5,2,2.5,3,3.5,4])
                fb_clevs = np.append(fb_clevs_low,fb_clevs_high)
                cm_low = mplc.get_cmap('Oranges_r',len(fb_clevs_low))
                cm_high = mplc.get_cmap('Purples',len(fb_clevs_high))
                cmap = np.vstack((cm_low(np.linspace(0,1,len(fb_clevs_low)-1)),np.array([0.9,1.0,0.9,1.0]),cm_high(np.linspace(0,1,len(fb_clevs_high)))))
                final_colors = ListedColormap(cmap)
                norm = BoundaryNorm(boundaries=fb_clevs,ncolors=len(fb_clevs),clip=True)
                plt.pcolormesh(x2d[:-1,:-1],y2d[:-1,:-1],fbias_hist2d,norm=norm,cmap=final_colors)
                cb = plt.colorbar(orientation='horizontal',fraction=0.05,aspect=50,pad=0.03,shrink=0.5,extend='max')
                cb.set_ticks(fb_clevs) # Frequency bias plot
                cb.set_label(r'Frequency bias ($N_f / N_o$)',fontsize=10)
               else:
                # Linear color scaling
               # plt.pcolormesh(x2d[:-1,:-1],y2d[:-1,:-1],hist2d,vmin=1,vmax=5000),cmap=mplc.get_cmap('PuRd'))
                # Logarithmic color scaling
                plt.pcolormesh(x2d[:-1,:-1],y2d[:-1,:-1],hist2d,norm=matplotlib.colors.LogNorm(vmin=1e-4,vmax=0.01),cmap=mplc.get_cmap('PuRd'))
                cb = plt.colorbar(orientation='horizontal',fraction=0.05,aspect=50,pad=0.03,shrink=0.5,extend='both')
                cb.set_ticks([1e-4,5e-4,1e-3,5e-3,0.01,0.05,0.1]) # For log-based normalization of this plot
                #cb.set_ticks([1,5,10,25,50,75,100,250,500,750,1000,5000])  # For linear scaling of this plot
                cb.set_label("relative frequency",fontsize=10)
               cb.ax.tick_params(labelsize=8)
               if centroid_FB_plot:
                image_file = "{}/{}_centroid_fbias_heatmap_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               else:
                image_file = "{}/{}_centroid_heatmap_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

            # Straight-up object attributes
            if True:
               # Object area
               plt.figure(figsize=(5,5))
               plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
               f_hist,bin = np.histogram(dx**2*f_area,bins=[144,180,270,360,450,540,630,720,810,900,1000,1200,1400,1600,1800,2000])
               o_hist,bin = np.histogram(dx**2*o_area,bins=[144,180,270,360,450,540,630,720,810,900,1000,1200,1400,1600,1800,2000])
               plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[ff]),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
               plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(num_obs_objs[ff]),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
               plt.grid(linestyle=":",color='0.75')
               plt.xlabel(r"Object area [km$^{2}$]",size=8)
               plt.ylabel("relative frequency",size=8)
               plt.tick_params(axis='both',labelsize=6)
               plt.legend(loc=1,prop={'size':8})
               mu_f = dx**2*np.mean(f_area)
               mu_o = dx**2*np.mean(o_area)
               std_f = np.std(dx**2*f_area)
               std_o = np.std(dx**2*o_area)
               med_f = dx**2*np.median(f_area)
               med_o = dx**2*np.median(o_area)
               plt.figtext(0.93,0.83,r"$\mu_f$={:4.0f};  $\mu_o$={:4.0f}".format(mu_f,mu_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.78,r"median$_f$={:4.0f};  median$_o$={:4.0f}".format(med_f,med_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.73,r"$\sigma_f$={:4.0f};  $\sigma_o$={:4.0f}".format(std_f,std_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.68,r"N$_f$={};  N$_o$={}".format(num_fcst_objs[ff],num_obs_objs[ff]),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.63,"CRPS={:5.3f}".format(area_crps),ha='right',va='top',fontweight='bold',fontsize=9,bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
               image_file = "{}/{}_object_area_hist_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

               # Object length & width
               plt.figure(figsize=(9,5))
               plt.subplots_adjust(left=0.075,bottom=0.075,top=0.98,right=0.98,wspace=0.2)
               plt.subplot(1,2,1)
               f_hist,bin = np.histogram(dx*f_length,bins=[6,25,50,75,100,125,150,175,200,250,300,400,500,600,750,1000])
       	       o_hist,bin = np.histogram(dx*o_length,bins=[6,25,50,75,100,125,150,175,200,250,300,400,500,600,750,1000])
               plt.semilogy(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[ff]),'s-r',linewidth=2,label=name)
               plt.semilogy(0.5*(bin[:-1]+bin[1:]),o_hist/float(num_obs_objs[ff]),'s-k',linewidth=2,label="MRMS")
               plt.grid(linestyle=":",color='0.75')
               plt.xlabel("Object length [km]",size=8)
               plt.ylabel("relative frequency",size=8)
               plt.tick_params(axis='both',labelsize=6)
               plt.legend(loc=1,prop={'size':8})
               mu_f = dx*np.mean(f_length)
               mu_o = dx*np.mean(o_length)
               std_f = np.std(dx*f_length)
               std_o = np.std(dx*o_length)
               med_f = dx*np.median(f_length)
               med_o = dx*np.median(o_length)
               plt.figtext(0.48,0.83,r"$\mu_f$={:4.0f};  $\mu_o$={:4.0f}".format(mu_f,mu_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.48,0.78,r"median$_f$={:4.0f};  median$_o$={:4.0f}".format(med_f,med_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.48,0.73,r"$\sigma_f$={:4.0f};  $\sigma_o$={:4.0f}".format(std_f,std_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.48,0.68,r"N$_f$={};  N$_o$={}".format(num_fcst_objs[ff],num_obs_objs[ff]),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.48,0.63,"CRPS={:5.3f}".format(length_crps),ha='right',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
               plt.subplot(1,2,2)
               f_hist,bin = np.histogram(dx*f_width,bins=[6,20,30,40,50,60,75,100,125,150,175,200,250,300])
       	       o_hist,bin = np.histogram(dx*o_width,bins=[6,20,30,40,50,60,75,100,125,150,175,200,250,300])
               plt.semilogy(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[ff]),'s-r',linewidth=2,label=name)
               plt.semilogy(0.5*(bin[:-1]+bin[1:]),o_hist/float(num_obs_objs[ff]),'s-k',linewidth=2,label="MRMS")
               plt.grid(linestyle=":",color='0.75')
               plt.xlabel("Object width [km]",size=8)
               plt.ylabel("relative frequency",size=8)
               plt.tick_params(axis='both',labelsize=6)
               mu_f = dx*np.mean(f_width)
               mu_o = dx*np.mean(o_width)
               std_f = np.std(dx*f_width)
               std_o = np.std(dx*o_width)
               med_f = dx*np.median(f_width)
               med_o = dx*np.median(o_width)
               plt.figtext(0.97,0.96,r"$\mu_f$={:3.0f};  $\mu_o$={:3.0f}".format(mu_f,mu_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.91,r"median$_f$={:3.0f};  median$_o$={:3.0f}".format(med_f,med_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.86,r"$\sigma_f$={:3.0f};  $\sigma_o$={:3.0f}".format(std_f,std_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.81,r"N$_f$={};  N$_o$={}".format(num_fcst_objs[ff],num_obs_objs[ff]),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.76,"CRPS={:5.3f}".format(width_crps),ha='right',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
               image_file = "{}/{}_object_wid_len_hist_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

               # aspect ratio
               plt.figure(figsize=(5,5))
               plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
               f_hist,bin=np.histogram(f_aspect,bins=np.arange(0.0,1.01,0.1))
       	       o_hist,bin=np.histogram(o_aspect,bins=np.arange(0.0,1.01,0.1))
               plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[ff]),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
               plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(num_obs_objs[ff]),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
               plt.grid(linestyle=":",color='0.75')
               plt.xlim(0,1)
               plt.xlabel("Object aspect ratio [width/length]",size=8)
               plt.ylabel("relative frequency",size=8)
               plt.tick_params(axis='both',labelsize=6)
               plt.legend(loc=1,prop={'size':8})
               mu_f = np.mean(f_aspect)
               mu_o = np.mean(o_aspect)
               std_f = np.std(f_aspect)
               std_o = np.std(o_aspect)
               med_f = np.median(f_aspect)
               med_o = np.median(o_aspect)
               plt.figtext(0.14,0.97,r"$\mu_f$={:5.3f};  $\mu_o$={:5.3f}".format(mu_f,mu_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.92,r"median$_f$={:5.3f};  median$_o$={:5.3f}".format(med_f,med_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.87,r"$\sigma_f$={:5.3f};  $\sigma_o$={:5.3f}".format(std_f,std_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.82,r"N$_f$={};  N$_o$={}".format(num_fcst_objs[ff],num_obs_objs[ff]),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.77,"CRPS={:5.3f}".format(aspect_crps),ha='left',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
               image_file = "{}/{}_object_aspect_hist_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

               # complexity
               plt.figure(figsize=(5,5))
               plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
               f_hist,bin=np.histogram(f_complexity,bins=np.arange(0.0,1.01,0.1))
       	       o_hist,bin=np.histogram(o_complexity,bins=np.arange(0.0,1.01,0.1))
               plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[ff]),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
               plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(num_obs_objs[ff]),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
               plt.grid(linestyle=":",color='0.75')
               plt.xlim(0,1)
               plt.xlabel("Object complexity [-]",size=8)
               plt.ylabel("relative frequency",size=8)
               plt.tick_params(axis='both',labelsize=6)
               plt.legend(loc=1,prop={'size':8})
               mu_f = np.mean(f_complexity)
               mu_o = np.mean(o_complexity)
               std_f = np.std(f_complexity)
               std_o = np.std(o_complexity)
               med_f = np.median(f_complexity)
               med_o = np.median(o_complexity)
               plt.figtext(0.97,0.83,r"$\mu_f$={:5.3f};  $\mu_o$={:5.3f}".format(mu_f,mu_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.78,r"median$_f$={:5.3f};  median$_o$={:5.3f}".format(med_f,med_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.73,r"$\sigma_f$={:5.3f};  $\sigma_o$={:5.3f}".format(std_f,std_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.68,r"N$_f$={};  N$_o$={}".format(num_fcst_objs[ff],num_obs_objs[ff]),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.97,0.63,"CRPS={:5.3f}".format(complex_crps),ha='right',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
               image_file = "{}/{}_object_complex_hist_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

               # percentile intensity values
               plt.figure(figsize=(5,5))
               plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
               if True in np.isnan(f_pXX):
                  print("Yeah, there are NaNs in f_pXX for some odd reason")
                  print(np.where(np.isnan(f_pXX)))
               f_hist,bin=np.histogram(f_pXX,bins=np.arange(25.0,70.1,5.0))
               if True in np.isnan(o_pXX):
                  print("Yeah, there are NaNs in o_pXX for some odd reason")
                  print(np.where(np.isnan(o_pXX)))
       	       o_hist,bin=np.histogram(o_pXX,bins=np.arange(25.0,70.1,5.0))
               plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[ff]),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
               plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(num_obs_objs[ff]),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
               plt.grid(linestyle=":",color='0.75')
               plt.xlabel("Object 95th percentile value",size=8)
               plt.ylabel("relative frequency",size=8)
               plt.tick_params(axis='both',labelsize=6)
               plt.legend(loc=1,prop={'size':8})
               mu_f = np.mean(f_pXX)
               mu_o = np.mean(o_pXX)
               std_f = np.std(f_pXX)
               std_o = np.std(o_pXX)
               med_f = np.median(f_pXX)
               med_o = np.median(o_pXX)
               plt.figtext(0.14,0.97,r"$\mu_f$={:4.1f};  $\mu_o$={:4.1f}".format(mu_f,mu_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.92,r"median$_f$={:4.1f};  median$_o$={:4.1f}".format(med_f,med_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.87,r"$\sigma_f$={:4.1f};  $\sigma_o$={:4.1f}".format(std_f,std_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.82,r"N$_f$={};  N$_o$={}".format(num_fcst_objs[ff],num_obs_objs[ff]),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.77,"CRPS={:5.3f}".format(pXX_crps),ha='left',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
               image_file = "{}/{}_object_pXX_hist_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

            if False:
               # Curvature
               plt.figure(figsize=(5,5))
               plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
               f_hist,bin=np.histogram(f_curvature,bins=np.arange(0,3000.1,100.0))
               o_hist,bin=np.histogram(o_curvature,bins=np.arange(0,3000.1,100.0))
               plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[ff]),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
               plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(num_obs_objs[ff]),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
               plt.grid(linestyle=":",color='0.75')
               plt.xlabel("Object curvature",size=8)
               plt.ylabel("relative frequency",size=8)
               plt.tick_params(axis='both',labelsize=6)
               plt.legend(loc=1,prop={'size':8})
               mu_f = np.mean(f_curvature)
               mu_o = np.mean(o_curvature)
               std_f = np.std(f_curvature)
               std_o = np.std(o_curvature)
               med_f = np.median(f_curvature)
               med_o = np.median(o_curvature)
               plt.figtext(0.14,0.97,r"$\mu_f$={:4.1f};  $\mu_o$={:4.1f}".format(mu_f,mu_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.92,r"median$_f$={:4.1f};  median$_o$={:4.1f}".format(med_f,med_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.87,r"$\sigma_f$={:4.1f};  $\sigma_o$={:4.1f}".format(std_f,std_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.82,r"N$_f$={};  N$_o$={}".format(num_fcst_objs[ff],num_obs_objs[ff]),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.14,0.77,"CRPS={:5.3f}".format(curv_crps),ha='left',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
               image_file = "{}/{}_object_curve_hist_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

            # Pair interest
            if False:
               plt.figure(figsize=(5,5))
               plt.subplots_adjust(left=0.125,right=0.98,bottom=0.1,top=0.98)
               hist,bins = np.histogram(pair_interest,bins=np.arange(0.0,1.01,0.05))
               plt.bar(bins[:-1],hist/float(len(pair_interest)),edgecolor='black',facecolor='red',width=0.05)
               plt.xticks(np.arange(0.0,1.01,0.1))
               plt.xlim(0,1)
               plt.grid(linestyle=":",color='0.75')
               plt.xlabel("Pair interest",fontsize=8)
               plt.ylabel("Relative frequency",fontsize=8)
               plt.tick_params(axis='both',labelsize=6)
               mu_f = np.mean(pair_interest)
               std_f = np.std(pair_interest)
               med_f = np.median(pair_interest)
               plt.figtext(0.93,0.88,r"$\mu$={:5.3f}".format(mu_f),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.83,"median={:5.3f}".format(med_f),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.78,r"$\sigma$={:5.3f}".format(std_f),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.73,"N={}".format(len(pair_interest)),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               image_file = "{}/{}_pair_interest_dist_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

           # Centroid distances (all matched)
            if True:
               plt.figure(figsize=(5,5))
               plt.subplots_adjust(left=0.125,right=0.98,bottom=0.1,top=0.98)
               hist,bins = np.histogram(all_match_dist_array,bins=np.arange(0.0,301.,10.))
               plt.bar(0.5*(bins[:-1]+bins[1:]),hist/float(len(all_match_dist_array)),edgecolor='black',facecolor='red')
               plt.grid(linestyle=":",color='0.75')
               plt.xlabel("centroid distance between matched objects",fontsize=8)
               plt.ylabel("Relative frequency",fontsize=8)
               plt.tick_params(axis='both',labelsize=6)
               mu_f = np.mean(all_match_dist_array)
               std_f = np.std(all_match_dist_array)
               med_f = np.median(all_match_dist_array)
               plt.figtext(0.93,0.88,r"$\mu$={:5.3f}".format(mu_f),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.83,"median={:5.3f}".format(med_f),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.78,r"$\sigma$={:5.3f}".format(std_f),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               plt.figtext(0.93,0.73,"N={}".format(len(all_match_dist_array)),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
               image_file = "{}/{}_centroid_dist_match_dist_r{}t{}_f{:02d}.png".format(img_dir,name,R,T,fhr)
               plt.savefig(image_file,dpi=120)
               plt.close()

         # save intermediate calculations to npz files for later re-use
         np.savez("{}/mode_metrics_r{}t{}_f{:02d}".format(dump_dir,R,T,fhr),OTS=OTS[ff],MMI=MMI[ff],POD=total_pod[ff],FAR=total_far[ff],SR=total_sr[ff],CSI=total_csi[ff],
                  n_f_objs=num_fcst_objs[ff],n_o_objs=num_obs_objs[ff],area_crps=area_crps,length_crps=length_crps,width_crps=width_crps,aspect_crps=aspect_crps,
                  complex_crps=complex_crps,pXX_crps=pXX_crps,lon_crps=cent_lon_crps,lat_crps=cent_lat_crps,ncases=n_cases,
                  stm_mean_dist=mean_centroid_dist[ff,0],stm_med_dist=median_centroid_dist[ff,0],stm_std_dist=std_centroid_dist[ff,0],
                  all_mean_dist=mean_centroid_dist[ff,1],all_med_dist=median_centroid_dist[ff,1],all_std_dist=std_centroid_dist[ff,1],fbias=fbias,
                  gen_mean_dist=mean_centroid_dist[ff,2],gen_med_dist=median_centroid_dist[ff,2],gen_std_dist=std_centroid_dist[ff,2],
                  MMI_flag=standard_MMI,agg_start_date=args.idate,agg_end_date=args.edate)

         ff+=1 #increment forecast hour counter so that numpy arrays can still be 0-indexed even if ifhr /= 0

      # END forecast hour time loop

      # Calculate final time-aggregated scores
      for d in range(0,len(agg_fhr_start)):
         if agg_hit[d] + agg_miss[d] > 0:
            agg_pod[d] = float(agg_hit[d]) / (agg_hit[d] + agg_miss[d])
         if agg_hit[d] + agg_fa[d] > 0:
            agg_sr[d] = float(agg_hit[d]) / (agg_hit[d] + agg_fa[d])
            agg_far[d] = float(agg_fa[d]) / (agg_hit[d] + agg_fa[d])
         if agg_hit[d] + agg_fa[d] + agg_miss[d] > 0:
            agg_csi[d] = float(agg_hit[d]) / (agg_hit[d] + agg_fa[d] + agg_miss[d])
         agg_mean_dist[d] = agg_dist_sum[d] / agg_dist_count[d]
         agg_OTS[d] = agg_ots_sum[d,0] / agg_ots_sum[d,1]
         exec("agg_MMI[{:d}] = np.median(agg_max_int_{:02d})".format(d,d))
         # Save scores to file for later plotting
         np.savez("{}/agg_scores_r{}t{}_f{:02d}-f{:02d}".format(dump_dir,R,T,agg_fhr_start[d],agg_fhr_end[d]),
                  OTS=agg_OTS[d],MMI=agg_MMI[d],MMI_flag=standard_MMI,POD=agg_pod[d],FAR=agg_far[d],SR=agg_sr[d],CSI=agg_csi[d],
                  NF=agg_fcst_count[d],NO=agg_obs_count[d],mean_dist=agg_mean_dist[d],gen_dist=agg_gen_dist[d],obj_fbias=agg_fbias[d])

      #### done handling time-aggregated output #####

      # Make plots of all-forecast hour object attributes
      if True:
         total_fcst_objs = np.sum(num_fcst_objs)
         total_obs_objs = np.sum(num_obs_objs)
         mass_crps = calc_CRPS(f_mass,o_mass,mass_bins)
         area_crps = calc_CRPS(f_area,o_area,area_bins)
         aspect_crps = calc_CRPS(f_aspect,o_aspect,np.arange(0.0,1.01,0.01))
         complex_crps = calc_CRPS(f_complexity,o_complexity,np.arange(0.0,1.01,0.01))
         pXX_crps = calc_CRPS(f_pXX,o_pXX,pXX_bins)

         # Object area
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
         f_hist,bin = np.histogram(dx**2*all_f_area,bins=area_bins)
         o_hist,bin = np.histogram(dx**2*all_o_area,bins=area_bins)
         plt.semilogx(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs),'r-x',markersize=6,label=name)
         plt.semilogx(0.5*(bin[:-1]+bin[1:]),o_hist/float(total_obs_objs),'k-x',markersize=6,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel(r"Object area [km$^{2}$]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         mu_f = dx**2*np.mean(all_f_area)
         mu_o = dx**2*np.mean(all_o_area)
         std_f = np.std(dx**2*all_f_area)
         std_o = np.std(dx**2*all_o_area)
         med_f = dx**2*np.median(all_f_area)
         med_o = dx**2*np.median(all_o_area)
         plt.figtext(0.93,0.83,r"$\mu_f$={:4.0f};  $\mu_o$={:4.0f}".format(mu_f,mu_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.93,0.78,r"median$_f$={:4.0f};  median$_o$={:4.0f}".format(med_f,med_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.93,0.73,r"$\sigma_f$={:4.0f};  $\sigma_o$={:4.0f}".format(std_f,std_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.93,0.68,r"N$_f$={};  N$_o$={}".format(total_fcst_objs,total_obs_objs),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.93,0.63,"CRPS={:5.3f}".format(area_crps),ha='right',va='top',fontweight='bold',fontsize=9,bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
         image_file = "{}/{}_object_area_hist_r{}t{}_all.png".format(img_dir,name,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # aspect ratio
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
         f_hist,bin=np.histogram(all_f_aspect,bins=np.arange(0.0,1.01,0.05))
         o_hist,bin=np.histogram(all_o_aspect,bins=np.arange(0.0,1.01,0.05))
         plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
         plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(total_obs_objs),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlim(0,1)
         plt.xlabel("Object aspect ratio [width/length]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         mu_f = np.mean(all_f_aspect)
         mu_o = np.mean(all_o_aspect)
         std_f = np.std(all_f_aspect)
         std_o = np.std(all_o_aspect)
         med_f = np.median(all_f_aspect)
         med_o = np.median(all_o_aspect)
         plt.figtext(0.14,0.97,r"$\mu_f$={:5.3f};  $\mu_o$={:5.3f}".format(mu_f,mu_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.14,0.92,r"median$_f$={:5.3f};  median$_o$={:5.3f}".format(med_f,med_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.14,0.87,r"$\sigma_f$={:5.3f};  $\sigma_o$={:5.3f}".format(std_f,std_o),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.14,0.82,r"N$_f$={};  N$_o$={}".format(total_fcst_objs,total_obs_objs),ha='left',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.14,0.77,"CRPS={:5.3f}".format(aspect_crps),ha='left',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
         image_file = "{}/{}_object_aspect_hist_r{}t{}_all.png".format(img_dir,name,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # complexity
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
         f_hist,bin=np.histogram(all_f_complexity,bins=np.arange(0.0,1.01,0.05))
         o_hist,bin=np.histogram(all_o_complexity,bins=np.arange(0.0,1.01,0.05))
         plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
         plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(total_obs_objs),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlim(0,1)
         plt.xlabel("Object complexity [-]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         mu_f = np.mean(all_f_complexity)
         mu_o = np.mean(all_o_complexity)
         std_f = np.std(all_f_complexity)
         std_o = np.std(all_o_complexity)
         med_f = np.median(all_f_complexity)
         med_o = np.median(all_o_complexity)
         plt.figtext(0.97,0.83,r"$\mu_f$={:5.3f};  $\mu_o$={:5.3f}".format(mu_f,mu_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.97,0.78,r"median$_f$={:5.3f};  median$_o$={:5.3f}".format(med_f,med_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.97,0.73,r"$\sigma_f$={:5.3f};  $\sigma_o$={:5.3f}".format(std_f,std_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.97,0.68,r"N$_f$={};  N$_o$={}".format(total_fcst_objs,total_obs_objs),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.97,0.63,"CRPS={:5.3f}".format(complex_crps),ha='right',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
         image_file = "{}/{}_object_complex_hist_r{}t{}_all.png".format(img_dir,name,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # percentile intensity values
         pbins = np.arange(0.0,100.1,5.0)
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
         f_hist,bin=np.histogram(all_f_pXX,bins=pXX_bins)
         o_hist,bin=np.histogram(all_o_pXX,bins=pXX_bins)
         plt.bar(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs),width=bin[1:]-bin[:-1],align='center',color='red',edgecolor='white',linewidth=1,label=name)
         plt.bar(0.5*(bin[:-1]+bin[1:]),o_hist/float(total_obs_objs),width=1.0*(bin[1:]-bin[:-1]),align='center',color='None',edgecolor='black',linewidth=1,label="MRMS")
         plt.yscale('log')
         plt.grid(linestyle=":",color='0.75')
         if field == 'compref':
            plt.xlabel("Object 95th percentile value",size=8)
         elif field == 'precip':
            plt.xlabel("Object 99th percentile value",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         mu_f = np.mean(all_f_pXX)
         mu_o = np.mean(all_o_pXX)
         std_f = np.std(all_f_pXX)
         std_o = np.std(all_o_pXX)
         med_f = np.median(all_f_pXX)
         med_o = np.median(all_o_pXX)
         plt.figtext(0.97,0.83,r"$\mu_f$={:4.1f};  $\mu_o$={:4.1f}".format(mu_f,mu_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.97,0.78,r"median$_f$={:4.1f};  median$_o$={:4.1f}".format(med_f,med_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.97,0.73,r"$\sigma_f$={:4.1f};  $\sigma_o$={:4.1f}".format(std_f,std_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.97,0.68,r"N$_f$={};  N$_o$={}".format(total_fcst_objs,total_obs_objs),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.97,0.63,"CRPS={:5.3f}".format(pXX_crps),ha='right',va='top',fontsize=9,fontweight='bold',bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
         image_file = "{}/{}_object_pXX_hist_r{}t{}_all.png".format(img_dir,name,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # Object total mass
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
         f_hist,bin = np.histogram(all_f_mass,bins=mass_bins)
         o_hist,bin = np.histogram(all_o_mass,bins=mass_bins)
         plt.semilogx(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs),'r-x',ms=6,label=name)
         plt.semilogx(0.5*(bin[:-1]+bin[1:]),o_hist/float(total_obs_objs),'k-x',ms=6,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel(r"Object total mass (mm)",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         mu_f = dx**2*np.mean(all_f_mass)
         mu_o = dx**2*np.mean(all_o_mass)
         std_f = np.std(dx**2*all_f_mass)
         std_o = np.std(dx**2*all_o_mass)
         med_f = dx**2*np.median(all_f_mass)
         med_o = dx**2*np.median(all_o_mass)
         plt.figtext(0.93,0.83,r"$\mu_f$={:4.0f};  $\mu_o$={:4.0f}".format(mu_f,mu_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.93,0.78,r"median$_f$={:4.0f};  median$_o$={:4.0f}".format(med_f,med_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.93,0.73,r"$\sigma_f$={:4.0f};  $\sigma_o$={:4.0f}".format(std_f,std_o),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.93,0.68,r"N$_f$={};  N$_o$={}".format(total_fcst_objs,total_obs_objs),ha='right',va='top',fontsize=7,bbox=dict(facecolor='white',edgecolor='black',linewidth=0.5))
         plt.figtext(0.93,0.63,"CRPS={:5.3f}".format(mass_crps),ha='right',va='top',fontweight='bold',fontsize=9,bbox=dict(facecolor='white',edgecolor='black',linewidth=1))
         image_file = "{}/{}_object_mass_hist_r{}t{}_all.png".format(img_dir,name,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

      if True:
         # Determine object count bias as a function of object size
         f_hist,bin = np.histogram(dx**2*all_f_area,bins=area_bins)
         o_hist,bin = np.histogram(dx**2*all_o_area,bins=area_bins)
         bias_by_size = 1.0*f_hist / o_hist
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
         plt.bar(0.5*(bin[:-1]+bin[1:]),bias_by_size,align='center',width=1.0*(bin[1:]-bin[:-1]),color='red',edgecolor='black',linewidth=1,label=name)
         plt.xscale('log')
         plt.grid(linestyle=":",color='0.75')
         if field == 'compref':
            if T <= 2:
               plt.ylim(0.6,1.9)
            elif T == 3:
               plt.ylim(0.0,4.0)
            else:
               plt.ylim(0.5,20)
               plt.yscale('log')
         if field == 'precip':
            if T <= 2:
               plt.ylim(0.5,1.51)
            elif T >= 3:
               plt.ylim(0.25,1.9)
         plt.xlabel(r"Object area bin [km$^{2}$]",size=8)
         plt.ylabel("object count bias (F/O)",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/{}_object_bias_by_size_r{}t{}_all.png".format(img_dir,name,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

      # Geographic frequency bias distribution as a function of object size
      if True:
         f_cent_lon_small = all_f_cent_lon[all_f_area <= small_area_thresh]
         f_cent_lat_small = all_f_cent_lat[all_f_area <= small_area_thresh]
         o_cent_lon_small = all_o_cent_lon[all_o_area <= small_area_thresh]
         o_cent_lat_small = all_o_cent_lat[all_o_area <= small_area_thresh]
         f_cent_lon_medium = all_f_cent_lon[(all_f_area > small_area_thresh) & (all_f_area <= large_area_thresh)]
         f_cent_lat_medium = all_f_cent_lat[(all_f_area > small_area_thresh) & (all_f_area <= large_area_thresh)]
         o_cent_lon_medium = all_o_cent_lon[(all_o_area > small_area_thresh) & (all_o_area <= large_area_thresh)]
         o_cent_lat_medium = all_o_cent_lat[(all_o_area > small_area_thresh) & (all_o_area <= large_area_thresh)]
         f_cent_lon_large = all_f_cent_lon[all_f_area > large_area_thresh]
         f_cent_lat_large = all_f_cent_lat[all_f_area > large_area_thresh]
         o_cent_lon_large = all_o_cent_lon[all_o_area > large_area_thresh]
         o_cent_lat_large = all_o_cent_lat[all_o_area > large_area_thresh]
         for a in range(0,3):
            if a == 0:
               f_hist2d,binx,biny = np.histogram2d(f_cent_lon_small,f_cent_lat_small,bins=[lon_bins,lat_bins])
               o_hist2d,binx,biny = np.histogram2d(o_cent_lon_small,o_cent_lat_small,bins=[lon_bins,lat_bins])
            elif a == 1:
               if R <= 2:
                  f_hist2d,binx,biny = np.histogram2d(f_cent_lon_medium,f_cent_lat_medium,bins=[lon_bins[::2],lat_bins[::2]])
                  o_hist2d,binx,biny = np.histogram2d(o_cent_lon_medium,o_cent_lat_medium,bins=[lon_bins[::2],lat_bins[::2]])
               else:
                  f_hist2d,binx,biny = np.histogram2d(f_cent_lon_medium,f_cent_lat_medium,bins=[lon_bins[::4],lat_bins[::4]])
                  o_hist2d,binx,biny = np.histogram2d(o_cent_lon_medium,o_cent_lat_medium,bins=[lon_bins[::4],lat_bins[::4]])
            elif a == 2:
               if R >= 3:
                  f_hist2d,binx,biny = np.histogram2d(f_cent_lon_large,f_cent_lat_large,bins=[lon_bins[::8],lat_bins[::8]])
                  o_hist2d,binx,biny = np.histogram2d(o_cent_lon_large,o_cent_lat_large,bins=[lon_bins[::8],lat_bins[::8]])
               else:
                  f_hist2d,binx,biny = np.histogram2d(f_cent_lon_large,f_cent_lat_large,bins=[lon_bins[::4],lat_bins[::4]])
                  o_hist2d,binx,biny = np.histogram2d(o_cent_lon_large,o_cent_lat_large,bins=[lon_bins[::4],lat_bins[::4]])
            fbias_hist2d = np.ma.masked_where(o_hist2d == 0,f_hist2d/o_hist2d)
            fig = plt.figure(figsize=figsize)
            ax = plt.subplots_adjust(left=0.01,right=0.95,bottom=0.05,top=0.97)
            m = Basemap(projection='lcc',width=proj_wid,height=proj_hgt,lat_0=clat,lon_0=clon,lat_1=38.5,resolution=res,area_thresh=min_area)
            m.drawlsmask(land_color='0.9',ocean_color='powderblue')
            m.drawcountries(linewidth=1,color='0.1')
            m.drawcoastlines(linewidth=0.5,color='0.4')
            m.drawstates(linewidth=0.5,color='0.5')
            m.drawmapboundary(color=[0.25,0.01,0.02],linewidth=3)
            m.drawmeridians(np.arange(-130.0,-50.1,5.0),linewidth=0.1,labels=[0,0,0,1],labelstyle='E/W',yoffset=lbl_off_y,fontsize=8,dashes=[2,2])
            m.drawparallels(np.arange(20.0,55.1,5.0),linewidth=0.1,labels=[0,1,0,0],labelstyle='E/W',xoffset=lbl_off_x,fontsize=8,dashes=[2,2])
            if a == 0:
               x2d,y2d = m(lons_2d,lats_2d)
            elif a == 1:
               if R <= 2:
                  x2d,y2d = m(lons_2d[::2,::2],lats_2d[::2,::2])
               else:
                  x2d,y2d = m(lons_2d[::4,::4],lats_2d[::4,::4])
            elif a == 2:
               if R <= 2:
                  x2d,y2d = m(lons_2d[::4,::4],lats_2d[::4,::4])
               else:
                  x2d,y2d = m(lons_2d[::8,::8],lats_2d[::8,::8])
            fb_clevs_low = np.array([0,0.25,0.5,0.75,0.9])
            fb_clevs_high = np.array([1.1,1.25,1.5,2,2.5,3,3.5,4])
            fb_clevs = np.append(fb_clevs_low,fb_clevs_high)
            cm_low = mplc.get_cmap('Oranges_r',len(fb_clevs_low))
            cm_high = mplc.get_cmap('Purples',len(fb_clevs_high))
            cmap = np.vstack((cm_low(np.linspace(0,1,len(fb_clevs_low)-1)),np.array([0.9,1.0,0.9,1.0]),cm_high(np.linspace(0,1,len(fb_clevs_high)))))
            final_colors = ListedColormap(cmap)
            norm = BoundaryNorm(boundaries=fb_clevs,ncolors=len(fb_clevs),clip=True)
        #  plt.pcolormesh(x2d[:-1,:-1],y2d[:-1,:-1],fbias_hist2d,norm=norm,cmap=final_colors)
            plt.contourf(x2d[:-1,:-1],y2d[:-1,:-1],fbias_hist2d,levels=fb_clevs,colors=cmap,extend='max')
            cb = plt.colorbar(orientation='horizontal',fraction=0.05,aspect=50,pad=0.03,shrink=0.5,extend='max')
            cb.set_ticks(fb_clevs) # Frequency bias plot
            if a == 0:
               cb.set_label(r'Frequency bias of small objects ($N_f / N_o$)',fontsize=10)
               _nf_ = len(f_cent_lon_small)
               _no_ = len(o_cent_lon_small)
               image_file = "{}/{}_centroid_fbias_heatmap_r{}t{}_all_small.png".format(img_dir,name,R,T)
            elif a == 1:
               cb.set_label(r'Frequency bias of medium objects ($N_f / N_o$)',fontsize=10)
               _nf_ = len(f_cent_lat_medium)
               _no_ = len(o_cent_lat_medium)
               image_file = "{}/{}_centroid_fbias_heatmap_r{}t{}_all_medium.png".format(img_dir,name,R,T)
            elif a == 2:
               cb.set_label(r'Frequency bias of large objects ($N_f / N_o$)',fontsize=10)
               _nf_ = len(f_cent_lon_large)
               _no_ = len(o_cent_lat_large)
               image_file = "{}/{}_centroid_fbias_heatmap_r{}t{}_all_large.png".format(img_dir,name,R,T)
            cb.ax.tick_params(labelsize=8)
            min_sample = np.amin(o_hist2d)
            med_sample = np.median(o_hist2d)
            plt.figtext(0.75,0.22,r"$N_f$={}".format(_nf_) + "\n" + r"$N_o$={}".format(_no_) + "\n" + r"median obs bin count = {:.0f}".format(med_sample),
                        ha='left',va='top',fontsize=10,fontweight=500,bbox=dict(facecolor='white',edgecolor='black',boxstyle='round,pad=0.3',linewidth=1.5))
            fig.savefig(image_file,dpi=120)
            plt.close(fig)

   # End convolution theshold loop
# End convolution radii loop
