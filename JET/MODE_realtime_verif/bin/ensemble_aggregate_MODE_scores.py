# SECOND of three scripts necessary to perform and plot object-based verification scores using MODE.
# This script handles multiple forecast systems

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
2) ensemble_aggregate_MODE_scores.py [THIS SCRIPT]
3) plot_MODE_results.py

As the file name suggests, this script reads in the partial sums and object attribute distributions calculated in
MODE_compute.py and aggregates them over all cases. It then computes final object-based verification metrics such as
the "Object-based Threat Score (OTS)", "Median of Maximum Interest (MMI)", and mean centroid distances (custom defined).
It also calculates (1-SR,POD) pairs for objects for the purpose of plotting performance diagrams in plot_MODE_results.py.

Final metrics are stored in python binary files.

NOTE: this script does perform *some* plotting of hourly object-attribute distributions.""")

parser.add_argument('-mods',nargs='+',type=str,metavar="model names [list]",dest="models",required=True,
                    help="Names of models")
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

names = args.models
nmems = len(names)
field = args.field
img_dir = "{}/{}/{}/images/dieoff".format(args.dump_root,"all",field)
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
cmp = mplc.get_cmap('jet')
nq = np.linspace(0,1,2*nmems+1)
colors_membs = cmp(nq)
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
   mass_bins = np.array([0,500,600,700,800,900,1000,1500,2000,3000,4000,5000,6000,7500,10000,15000,20000,30000,40000,50000,75000,100000,200000])
curvature_bins = np.arange(700.,3500.1,100.)

for R in range(1,n_rad+1):
   for T in range(T_start,n_thresh+1):
      print("WORKING ON THRESHOLD {}".format(T))

      # Output metrics as a function of forecast lead time
      # aggregated across all cases
      num_fcst_objs = np.zeros((nmems,efhr-ifhr+1),dtype=np.int)
      num_obs_objs = np.zeros_like(num_fcst_objs,dtype=np.int)
      OTS = np.full((nmems,efhr-ifhr+1),-999.,dtype=np.float)
      MMI = np.full(OTS.shape,-999.,dtype=np.float)
      total_pod = np.full(OTS.shape,-999.,dtype=np.float)
      total_sr = np.full(OTS.shape,-999.,dtype=np.float)
      total_far = np.full(OTS.shape,-999.,dtype=np.float)
      total_csi = np.full(OTS.shape,-999.,dtype=np.float)
      mean_centroid_dist = np.full((nmems,efhr-ifhr+1,5),-999.,dtype=np.float)
      median_centroid_dist = np.full(mean_centroid_dist.shape,-999.,dtype=np.float)
      std_centroid_dist = np.zeros(mean_centroid_dist.shape,dtype=np.float)
      cent_lon_crps = np.zeros((nmems,efhr-ifhr+1),dtype=np.float)
      cent_lat_crps = np.zeros_like(cent_lon_crps)
      area_crps = np.zeros_like(cent_lon_crps)
      length_crps = np.zeros_like(cent_lon_crps)
      width_crps = np.zeros_like(cent_lon_crps)
      aspect_crps = np.zeros_like(cent_lon_crps)
      complex_crps = np.zeros_like(cent_lon_crps)
      pXX_crps = np.zeros_like(cent_lon_crps)
      curv_crps = np.zeros_like(cent_lon_crps)
      n_cases = np.zeros_like(num_fcst_objs,dtype=np.int)

      for e in range(0,nmems):
         # All-forecast-hour aggregated object attribute distributions
         exec("all_f_area_{:02d} = np.empty(0,dtype=np.int)".format(e))
         exec("all_f_aspect_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_f_complexity_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_f_pXX_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_f_mass_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_f_cent_lon_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_f_cent_lat_{:02d} = np.empty(0,dtype=np.float)".format(e))
             # This seems off, but it has to be done because different models/forecasting systems may be valid 
             # on different sets of cases, which impacts how many observation objects there are for a given model.
         exec("all_o_area_{:02d} = np.empty(0,dtype=np.int)".format(e))
         exec("all_o_aspect_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_o_complexity_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_o_pXX_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_o_mass_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_o_cent_lon_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_o_cent_lat_{:02d} = np.empty(0,dtype=np.float)".format(e))
         exec("all_interest_{:02d} = np.empty(0,dtype=np.int)".format(e))
         exec("all_distance_{:02d} = np.empty(0,dtype=np.float)".format(e))

      # Based on this array dimensionality, aggregated scores cannot be plotted in this code and must instead be plotted in the "plot_MODE_results" script
      # Final time-aggregated scores
      agg_OTS = np.full((nmems,len(agg_fhr_start)),-999.,dtype=np.float)
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
      agg_ots_sum = np.zeros((nmems,len(agg_fhr_start),2),dtype=np.float)
      # One agg_max_int array for each possible set of aggregated time periods (need to add more if len(agg_fhr_start > 15))
      for d in range(0,len(agg_fhr_start)):
         for e in range(0,nmems):
            exec("agg_max_int_{:02d}_{:02d} = np.empty(0,dtype=np.float)".format(d,e))
            exec("agg_gen_dist_{:02d}_{:02d} = np.empty(0,dtype=np.float)".format(d,e))
      agg_hit = np.zeros((nmems,len(agg_fhr_start)),dtype=np.int)
      agg_fa = np.zeros((nmems,len(agg_fhr_start)),dtype=np.int)
      agg_miss = np.zeros((nmems,len(agg_fhr_start)),dtype=np.int)
      agg_dist_sum = np.zeros((nmems,len(agg_fhr_start)),dtype=np.float)
      agg_dist_count = np.zeros((nmems,len(agg_fhr_start)),dtype=np.int)

      ff = 0
      for fhr in range(ifhr,efhr+1):
         lead = "{:02d}".format(fhr)
         print("WORKING ON FORECAST HOUR {}".format(lead))

         for e in range(0,nmems):
            print("WORKING ON FORECAST MEMBER " + names[e])

            plt.figure(1,figsize=(5,5))
            plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
            plt.figure(2,figsize=(5,5))
            plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
            plt.figure(3,figsize=(9,5))
            plt.subplots_adjust(left=0.075,bottom=0.075,top=0.98,right=0.98,wspace=0.2)
            plt.figure(4,figsize=(5,5))
            plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
            plt.figure(5,figsize=(5,5))
            plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
            plt.figure(6,figsize=(5,5))
            plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
            plt.figure(7,figsize=(5,5))
            plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
            plt.figure(8,figsize=(5,5))
            plt.subplots_adjust(left=0.125,right=0.98,bottom=0.1,top=0.98)
            plt.figure(9,figsize=(5,5))
            plt.subplots_adjust(left=0.125,right=0.98,bottom=0.1,top=0.98)

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
            exec("o_cent_lat_{:02d} = np.empty(0,dtype=np.float)".format(e))
            exec("o_cent_lon_{:02d} = np.empty(0,dtype=np.float)".format(e))
            exec("o_length_{:02d} = np.empty(0,dtype=np.float)".format(e))
            exec("o_width_{:02d} = np.empty(0,dtype=np.float)".format(e))
            exec("o_aspect_{:02d} = np.empty(0,dtype=np.float)".format(e))
            exec("o_area_{:02d} = np.empty(0,dtype=np.float)".format(e))
            exec("o_curvature_{:02d} = np.empty(0,dtype=np.float)".format(e))
            exec("o_complexity_{:02d} = np.empty(0,dtype=np.float)".format(e))
            exec("o_pXX_{:02d} = np.empty(0,dtype=np.float)".format(e))
            exec("o_mass_{:02d} = np.empty(0,dtype=np.float)".format(e))
            o_cent_x = np.empty(0,dtype=np.float)
            o_cent_y = np.empty(0,dtype=np.float)
            o_angle = np.empty(0,dtype=np.float)
            o_area_t = np.empty(0,dtype=np.float)
            o_p10 = np.empty(0,dtype=np.float)
            o_p25 = np.empty(0,dtype=np.float)
            o_p50 = np.empty(0,dtype=np.float)
            o_p75 = np.empty(0,dtype=np.float)
            o_p90 = np.empty(0,dtype=np.float)
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

               if args.diag >= 5:
                  print("WORKING ON FORECAST CASE {}{}{} {}Z".format(cyear,cmonth,cday,chour))
               psum_filename = "{}/{}/{}/partial_sums/{}/partial_sums_r{}t{}_{}_f{}.npz".format(args.dump_root,names[e],field,casedir,R,T,casedir,lead)
               attr_filename = "{}/{}/{}/object_attributes/{}/attributes_r{}t{}_{}_f{}.npz".format(args.dump_root,names[e],field,casedir,R,T,casedir,lead)
               if path.isfile(psum_filename) and path.isfile(attr_filename):
                  data_psum = np.load(psum_filename)
                  data_attr = np.load(attr_filename)
                  n_cases[e,ff] += 1
               else:
                  if args.diag >= 5:
                     print("Data for case {}{}{} {}Z not present...skipping loop. n_cases = {}".format(cyear,cmonth,cday,chour,n_cases[e,ff]))
                  # Increment time and move to next case
                  time += timedelta(hours=delta_hr)
                  continue

               # Construct all-case sum from partial sums
               ots_sum[0] += data_psum['ots_sum_numer']
               ots_sum[1] += data_psum['ots_sum_denom']
               num_fcst_objs[e,ff] += data_psum['n_f_objs']
               num_obs_objs[e,ff] += data_psum['n_o_objs']
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
               f_p10 = np.append(f_p10,data_attr['file_f_p10'])
               f_p25 = np.append(f_p25,data_attr['file_f_p25'])
               f_p50 = np.append(f_p50,data_attr['file_f_p50'])
               f_p75 = np.append(f_p75,data_attr['file_f_p75'])
               f_p90 = np.append(f_p90,data_attr['file_f_p90'])
               f_pXX = np.append(f_pXX,data_attr['file_f_p95'])
               f_mass = np.append(f_mass,data_attr['file_f_mass'])
               exec("o_cent_lat_{:02d} = np.append(o_cent_lat_{:02d},data_attr['file_o_cent_lat'])".format(e,e))
               exec("o_cent_lon_{:02d} = np.append(o_cent_lon_{:02d},data_attr['file_o_cent_lon'])".format(e,e))
               o_angle = np.append(o_angle,data_attr['file_o_angle'])
               exec("o_length_{:02d} = np.append(o_length_{:02d},data_attr['file_o_length'])".format(e,e))
               exec("o_width_{:02d} = np.append(o_width_{:02d},data_attr['file_o_width'])".format(e,e))
               exec("o_aspect_{:02d} = np.append(o_aspect_{:02d},data_attr['file_o_aspect'])".format(e,e))
               exec("o_area_{:02d} = np.append(o_area_{:02d},data_attr['file_o_area'])".format(e,e))
               exec("o_curvature_{:02d} = np.append(o_curvature_{:02d},data_attr['file_o_curvature'])".format(e,e))
               exec("o_complexity_{:02d} = np.append(o_complexity_{:02d},data_attr['file_o_complexity'])".format(e,e))
               o_p10 = np.append(o_p10,data_attr['file_o_p10'])
               o_p25 = np.append(o_p25,data_attr['file_o_p25'])
               o_p50 = np.append(o_p50,data_attr['file_o_p50'])
               o_p75 = np.append(o_p75,data_attr['file_o_p75'])
               o_p90 = np.append(o_p90,data_attr['file_o_p90'])
               exec("o_pXX_{:02d} = np.append(o_pXX_{:02d},data_attr['file_o_p95'])".format(e,e))
               exec("o_mass_{:02d} = np.append(o_mass_{:02d},data_attr['file_o_mass'])".format(e,e))
               pair_dcentroid = np.append(pair_dcentroid,data_attr['file_pair_dcentroid'])
               pair_dangle = np.append(pair_dangle,data_attr['file_pair_dangle'])
               pair_daspect = np.append(pair_daspect,data_attr['file_pair_daspect'])
               pair_area_ratio = np.append(pair_area_ratio,data_attr['file_pair_area_ratio'])
               pair_int_area = np.append(pair_int_area,data_attr['file_pair_int_area'])
               pair_union_area = np.append(pair_union_area,data_attr['file_pair_union_area'])
               pair_sym_diff_area = np.append(pair_sym_diff_area,data_attr['file_pair_sym_diff_area'])
               pair_consum_ratio = np.append(pair_consum_ratio,data_attr['file_pair_consum_ratio'])
               pair_curv_ratio = np.append(pair_curv_ratio,data_attr['file_pair_curv_ratio'])
               pair_complex_ratio = np.append(pair_complex_ratio,data_attr['file_pair_complex_ratio'])
               pair_pct_intense_ratio = np.append(pair_pct_intense_ratio,data_attr['file_pair_pct_intense_ratio'])
               pair_interest = np.append(pair_interest,data_attr['file_pair_interest'])
               gen_x_match_dist = np.append(gen_x_match_dist,data_attr['gen_match_x_error'])
               gen_y_match_dist = np.append(gen_y_match_dist,data_attr['gen_match_y_error'])
               if args.diag >= 4:
                  print("There were {} forecast objects, {} observation objects, and {} pairs to evaluate in this file".format(len(data_attr['file_f_cent_lat']),len(data_attr['file_o_cent_lat']),len(data_attr['file_pair_dcentroid'])))

               # Increment time loop to next forecast cycle
               time += timedelta(hours=delta_hr)

            # END case loop (forecast init/cycle time)

            if args.diag >= 2:
               print("There were {} matched object pairs representing the shape of a single intense thunderstorm evaluated at f{:02d}".format(len(storm_match_dist_array),fhr))
               print("There are a total of {} forecast objects and {} observation objects to evaluate at forecast hour {:02d} over {} cases".format(num_fcst_objs[e,ff],num_obs_objs[e,ff],fhr,n_cases[e,ff]))

            # Aggregate object attributes over all forecast hours
            exec("all_f_area_{:02d} = np.append(all_f_area_{:02d},f_area)".format(e,e))
            exec("all_f_aspect_{:02d} = np.append(all_f_aspect_{:02d},f_aspect)".format(e,e))
            exec("all_f_complexity_{:02d} = np.append(all_f_complexity_{:02d},f_complexity)".format(e,e))
            exec("all_f_pXX_{:02d} = np.append(all_f_pXX_{:02d},f_pXX)".format(e,e))
            exec("all_f_mass_{:02d} = np.append(all_f_mass_{:02d},f_mass)".format(e,e))
            exec("all_f_cent_lon_{:02d} = np.append(all_f_cent_lon_{:02d},f_cent_lon)".format(e,e))
            exec("all_f_cent_lat_{:02d} = np.append(all_f_cent_lat_{:02d},f_cent_lat)".format(e,e))
            exec("all_distance_{:02d} = np.append(all_distance_{:02d},all_match_dist_array)".format(e,e))
            exec("all_interest_{:02d} = np.append(all_interest_{:02d},pair_interest)".format(e,e))
            exec("all_o_area_{:02d} = np.append(all_o_area_{:02d},o_area_{:02d})".format(e,e,e))
            exec("all_o_aspect_{:02d} = np.append(all_o_aspect_{:02d},o_aspect_{:02d})".format(e,e,e))
            exec("all_o_complexity_{:02d} = np.append(all_o_complexity_{:02d},o_complexity_{:02d})".format(e,e,e))
            exec("all_o_pXX_{:02d} = np.append(all_o_pXX_{:02d},o_pXX_{:02d})".format(e,e,e))
            exec("all_o_mass_{:02d} = np.append(all_o_mass_{:02d},o_mass_{:02d})".format(e,e,e))
            exec("all_o_cent_lon_{:02d} = np.append(all_o_cent_lon_{:02d},o_cent_lon_{:02d})".format(e,e,e))
            exec("all_o_cent_lat_{:02d} = np.append(all_o_cent_lat_{:02d},o_cent_lat_{:02d})".format(e,e,e))

            if len(storm_match_dist_array) > 0:
               mean_centroid_dist[e,ff,0] = np.mean(storm_match_dist_array)
               median_centroid_dist[e,ff,0] = np.median(storm_match_dist_array)
               std_centroid_dist[e,ff,0] = np.std(storm_match_dist_array)
            if len(all_match_dist_array) > 0:
               mean_centroid_dist[e,ff,1] = np.mean(all_match_dist_array)
               median_centroid_dist[e,ff,1] = np.median(all_match_dist_array)
               std_centroid_dist[e,ff,1] = np.std(all_match_dist_array)
            if len(gen_match_dist_array) > 0:
               mean_centroid_dist[e,ff,2] = np.mean(gen_match_dist_array)
               median_centroid_dist[e,ff,2] = np.median(gen_match_dist_array)
               std_centroid_dist[e,ff,2] = np.std(gen_match_dist_array)

            # Add time-aggregated score components to arrays
            # (The final calculation of time-aggregated scores must occur outside of the forecast-hour loop...so...in other words...outside of THIS loop)
            for d in range(0,len(agg_fhr_start)):
               if fhr >= agg_fhr_start[d] and fhr <= agg_fhr_end[d]:
                  agg_ots_sum[e,d,0] += ots_sum[0]
                  agg_ots_sum[e,d,1] += ots_sum[1]
                  exec("agg_max_int_{:02d}_{:02d} = np.append(agg_max_int_{:02d}_{:02d},max_int_array)".format(d,d,e,e))
                  exec("agg_gen_dist_{:02d}_{:02d} = np.append(agg_gen_dist_{:02d}_{:02d},gen_match_dist_array)".format(d,d,e,e))
                  agg_dist_sum[e,d] += np.sum(all_match_dist_array)
                  agg_dist_count[e,d] += len(all_match_dist_array)
                  agg_hit[e,d] += hit
                  agg_miss[e,d] += miss
                  agg_fa[e,d] += false_alarm
                  agg_fcst_count[e,d] += num_fcst_objs[e,ff]
                  agg_obs_count[e,d] += num_obs_objs[e,ff]
            for d in range(0,len(agg_fhr_start)):
               exec("agg_gen_dist[{},{}] = np.mean(agg_gen_dist_{:02d}_{:02d})".format(e,d,d,e))
               if agg_obs_count[e,d] > 0:
                  agg_fbias[e,d] = float(agg_fcst_count[e,d]) / agg_obs_count[e,d]

            if num_fcst_objs[e,ff] > 0 and num_obs_objs[e,ff] > 0:

               # Compute single-forecast-hour scores
               if hit + miss > 0:
                  total_pod[e,ff] = float(hit) / (hit + miss)
               if hit + false_alarm > 0:
                  total_sr[e,ff] = float(hit) / (hit + false_alarm)
                  total_far[e,ff] = float(false_alarm) / (hit + false_alarm)
               if hit + miss + false_alarm > 0:
                  total_csi[e,ff] = float(hit) / (hit + miss + false_alarm)

               OTS[e,ff] = ots_sum[0] / ots_sum[1]
               MMI[e,ff] = np.median(max_int_array)

               # Calculate object attribute distribution CRPSs
               exec("cent_lon_crps[e,ff] = calc_CRPS(f_cent_lon,o_cent_lon_{:02d},np.arange(-108.0,75.01,0.1))".format(e))
               exec("cent_lat_crps[e,ff] = calc_CRPS(f_cent_lat,o_cent_lat_{:02d},np.arange(25.0,51.01,0.1))".format(e))
               exec("area_crps[e,ff] = calc_CRPS(f_area,o_area_{:02d},area_bins)".format(e))
               exec("length_crps[e,ff] = calc_CRPS(f_length,o_length_{:02d},np.arange(2,751.,5.0))".format(e))
               exec("width_crps[e,ff] = calc_CRPS(f_width,o_width_{:02d},np.arange(1,301,1.0))".format(e))
               exec("aspect_crps[e,ff] = calc_CRPS(f_aspect,o_aspect_{:02d},np.arange(0.0,1.01,0.01))".format(e))
               exec("complex_crps[e,ff] = calc_CRPS(f_complexity,o_complexity_{:02d},np.arange(0.0,1.01,0.01))".format(e))
               exec("pXX_crps[e,ff] = calc_CRPS(f_pXX,o_pXX_{:02d},pXX_bins)".format(e))
               exec("curv_crps[e,ff] = calc_CRPS(f_curvature,o_curvature_{:02d},curvature_bins)".format(e))

               # One plot for each forecast hour
               if True:
                  # Determine object count bias as a function of object size
                  f_hist,bin = np.histogram(dx**2*f_area,bins=area_bins)
                  exec("o_hist,bin = np.histogram(dx**2*o_area_{:02d},bins=area_bins)".format(e))
                  bias_by_size = 1.0*f_hist / o_hist
                  plt.figure(1)
                  plt.plot(0.5*(bin[:-1]+bin[1:]),bias_by_size,'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])

               # Straight-up object attributes
               if True:
                  # Object area
                  plt.figure(2)
                  f_hist,bin = np.histogram(dx**2*f_area,bins=area_bins)
                  plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[e,ff]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])

                  # Object length & width
                  plt.figure(3)
                  plt.subplot(1,2,1)
                  f_hist,bin = np.histogram(dx*f_length,bins=[6,25,50,75,100,125,150,175,200,250,300,400,500,600,750,1000])
                  plt.semilogy(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[e,ff]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])
                  plt.subplot(1,2,2)
                  f_hist,bin = np.histogram(dx*f_width,bins=[6,20,30,40,50,60,75,100,125,150,175,200,250,300])
                  plt.semilogy(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[e,ff]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])

                  # aspect ratio
                  plt.figure(4)
                  f_hist,bin=np.histogram(f_aspect,bins=np.arange(0.0,1.01,0.1))
                  plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[e,ff]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])

                  # complexity
                  plt.figure(5)
                  f_hist,bin=np.histogram(f_complexity,bins=np.arange(0.0,1.01,0.1))
                  plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[e,ff]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])

                  # percentile intensity values
                  plt.figure(6)
              #    if True in np.isnan(f_pXX):
              #       print("Yeah, there are NaNs in f_pXX for some odd reason")
              #       print(np.where(np.isnan(f_pXX)))
                  print("computing histogram and plotting for f_pXX at fhr={:02d}".format(ff))
                  f_hist,bin=np.histogram(f_pXX,bins=pXX_bins)
                  print(f_hist)
                  print(bin)
                  plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[e,ff]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])

               if False:
                  # Curvature
                  plt.figure(7)
                  f_hist,bin=np.histogram(f_curvature,bins=curvature_bins)
                  plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(num_fcst_objs[e,ff]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])

               # Pair interest
               if True:
                  plt.figure(8)
                  hist,bins = np.histogram(pair_interest,bins=np.arange(0.0,1.01,0.05))
                  plt.plot(bins[:-1],hist/float(len(pair_interest)),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])

               # Centroid distances (all matched)
               if True:
                  plt.figure(9)
                  hist,bins = np.histogram(all_match_dist_array,bins=np.arange(0.0,126.,5.))
                  plt.plot(0.5*(bins[:-1]+bins[1:]),hist/float(len(all_match_dist_array)),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])

         # END member loop

         biggest_obs_ind = np.argmax(num_obs_objs[:,ff])
         max_obs_size = num_obs_objs[biggest_obs_ind,ff]

         plt.figure(1)
         plt.plot([area_bins[0],area_bins[-1]],[1,1],'-k',linewidth=3)
         plt.xscale('log')
         plt.grid(linestyle=":",color='0.75')
         if T <= 2:
            plt.ylim(0.25,3)
         elif T == 3:
            plt.ylim(0.9,10)
         elif T == 4:
            plt.ylim(0.75,40)
            plt.yscale('log')
         plt.xlabel(r"Object area bin [km$^{2}$]",size=8)
         plt.ylabel("object count bias (F/O)",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/object_bias_by_size_r{}t{}_f{:02d}.png".format(img_dir,R,T,fhr)
         plt.savefig(image_file,dpi=120)
         plt.close(1)

         plt.figure(2)
         exec("o_hist,bin = np.histogram(dx**2*o_area_{:02d},bins=area_bins)".format(biggest_obs_ind))
         plt.plot(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),color='black',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel(r"Object area [km$^{2}$]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/object_area_hist_r{}t{}_f{:02d}.png".format(img_dir,R,T,fhr)
         plt.savefig(image_file,dpi=120)
         plt.close(2)

         plt.figure(3)
         plt.subplot(1,2,1)
         exec("o_hist,bin = np.histogram(dx*o_length_{:02d},bins=[6,25,50,75,100,125,150,175,200,250,300,400,500,600,750,1000])".format(biggest_obs_ind))
         plt.semilogy(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'-k',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel("Object length [km]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         plt.subplot(1,2,2)
         exec("o_hist,bin = np.histogram(dx*o_width_{:02d},bins=[6,20,30,40,50,60,75,100,125,150,175,200,250,300])".format(biggest_obs_ind))
         plt.semilogy(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'-k',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel("Object width [km]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         image_file = "{}/object_wid_len_hist_r{}t{}_f{:02d}.png".format(img_dir,R,T,fhr)
         plt.savefig(image_file,dpi=120)
         plt.close(3)

         plt.figure(4)
         exec("o_hist,bin=np.histogram(o_aspect_{:02d},bins=np.arange(0.0,1.01,0.1))".format(biggest_obs_ind))
         plt.plot(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'k-',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlim(0,1)
         plt.xlabel("Object aspect ratio [width/length]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc='upper left',prop={'size':8})
         image_file = "{}/object_aspect_hist_r{}t{}_f{:02d}.png".format(img_dir,R,T,fhr)
         plt.savefig(image_file,dpi=120)
         plt.close(4)

         plt.figure(5)
         exec("o_hist,bin=np.histogram(o_complexity_{:02d},bins=np.arange(0.0,1.01,0.1))".format(biggest_obs_ind))
         plt.plot(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'-k',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlim(0,1)
         plt.xlabel("Object complexity [-]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/object_complex_hist_r{}t{}_f{:02d}.png".format(img_dir,R,T,fhr)
         plt.savefig(image_file,dpi=120)
         plt.close(5)

         plt.figure(6)
         print("Plotting observation distribution, o_pXX, at fhr={:02d}".format(ff))
         exec('blah=o_pXX_{:02d}'.format(biggest_obs_ind))
         print(blah)
         exec("o_hist,bin=np.histogram(o_pXX_{:02d},bins=pXX_bins)".format(biggest_obs_ind))
         plt.plot(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'-k',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel("Object 95th percentile value",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/object_pXX_hist_r{}t{}_f{:02d}.png".format(img_dir,R,T,fhr)
         plt.savefig(image_file,dpi=120)
         plt.close(6)

         if False:
            plt.figure(7)
            exec("o_hist,bin=np.histogram(o_curvature_{:02d},bins=curvature_bins)".format(biggest_obs_ind))
            plt.plot(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'-k',linewidth=3,label="MRMS")
            plt.grid(linestyle=":",color='0.75')
            plt.xlabel("Object curvature",size=8)
            plt.ylabel("relative frequency",size=8)
            plt.tick_params(axis='both',labelsize=6)
            plt.legend(loc=1,prop={'size':8})
            image_file = "{}/object_curve_hist_r{}t{}_f{:02d}.png".format(img_dir,R,T,fhr)
            plt.savefig(image_file,dpi=120)
            plt.close(7)

         if True:
            plt.figure(8)
            plt.xticks(np.arange(0.0,1.01,0.1))
            plt.xlim(0,1)
            plt.grid(linestyle=":",color='0.75')
            plt.xlabel("Pair interest",fontsize=8)
            plt.ylabel("Relative frequency",fontsize=8)
            plt.tick_params(axis='both',labelsize=6)
            plt.legend(loc=0,prop={'size':8})
            if fhr == 0 or fhr == 1:
               image_file = "{}/pair_interest_dist_r{}t{}_f{:02d}.png".format(img_dir,R,T,fhr)
            plt.savefig(image_file,dpi=120)
            plt.close(8)

         if True:
            plt.figure(9)
            plt.grid(linestyle=":",color='0.75')
            plt.xlabel("centroid distance between matched objects",fontsize=8)
            plt.ylabel("Relative frequency",fontsize=8)
            plt.tick_params(axis='both',labelsize=6)
            plt.legend(loc=0,prop={'size':8})
            image_file = "{}/centroid_dist_match_hist_r{}t{}_f{:02d}.png".format(img_dir,R,T,fhr)
            plt.savefig(image_file,dpi=120)
            plt.close(9)

         ff+=1 #increment forecast hour counter so that numpy arrays can still be 0-indexed even if ifhr /= 0

      # END forecast hour time loop

      # save intermediate calculations to npz files for later re-use
      np.savez('{}/all/{}/mode_metrics_r{}t{}_all'.format(args.dump_root,field,R,T),OTS=OTS,MMI=MMI,POD=total_pod,FAR=total_far,SR=total_sr,CSI=total_csi,
         n_f_objs=num_fcst_objs,n_o_objs=num_obs_objs,area_crps=area_crps,length_crps=length_crps,width_crps=width_crps,aspect_crps=aspect_crps,
         complex_crps=complex_crps,pXX_crps=pXX_crps,lon_crps=cent_lon_crps,lat_crps=cent_lat_crps,ncases=n_cases,
         stm_mean_dist=mean_centroid_dist[:,:,0],stm_med_dist=median_centroid_dist[:,:,0],stm_std_dist=std_centroid_dist[:,:,0],
         all_mean_dist=mean_centroid_dist[:,:,1],all_med_dist=median_centroid_dist[:,:,1],all_std_dist=std_centroid_dist[:,:,1],
         gen_mean_dist=mean_centroid_dist[:,:,2],gen_med_dist=median_centroid_dist[:,:,2],gen_std_dist=std_centroid_dist[:,:,2],
         MMI_flag=standard_MMI,agg_start_date=args.idate,agg_end_date=args.edate,names=args.models)

      # Calculate final time-aggregated scores
      for d in range(0,len(agg_fhr_start)):
         for e in range(0,nmems):
            if agg_hit[e,d] + agg_miss[e,d] > 0:
               agg_pod[e,d] = float(agg_hit[e,d]) / (agg_hit[e,d] + agg_miss[e,d])
            if agg_hit[e,d] + agg_fa[e,d] > 0:
               agg_sr[e,d] = float(agg_hit[e,d]) / (agg_hit[e,d] + agg_fa[e,d])
               agg_far[e,d] = float(agg_fa[e,d]) / (agg_hit[e,d] + agg_fa[e,d])
            if agg_hit[e,d] + agg_fa[e,d] + agg_miss[e,d] > 0:
               agg_csi[e,d] = float(agg_hit[e,d]) / (agg_hit[e,d] + agg_fa[e,d] + agg_miss[e,d])
            agg_mean_dist[e,d] = agg_dist_sum[e,d] / agg_dist_count[e,d]
            agg_OTS[e,d] = agg_ots_sum[e,d,0] / agg_ots_sum[e,d,1]
            exec("agg_MMI[{},{}] = np.median(agg_max_int_{:02d}_{:02d})".format(e,d,d,e))
         # Save scores to file for later plotting
         np.savez("{}/all/{}/agg_scores_r{}t{}_f{:02d}-f{:02d}".format(args.dump_root,field,R,T,agg_fhr_start[d],agg_fhr_end[d]),
                  OTS=agg_OTS[:,d],MMI=agg_MMI[:,d],MMI_flag=standard_MMI,POD=agg_pod[:,d],FAR=agg_far[:,d],SR=agg_sr[:,d],CSI=agg_csi[:,d],
                  NF=agg_fcst_count[:,d],NO=agg_obs_count[:,d],mean_dist=agg_mean_dist[:,d],gen_dist=agg_gen_dist[:,d],obj_fbias=agg_fbias[:,d])

      #### done handling time-aggregated output #####

      # Make plots of all-forecast hour object attributes
      if True:
         total_fcst_objs = np.sum(num_fcst_objs,axis=1)
         biggest_obs_ind = np.argmax(np.sum(num_obs_objs,axis=1))
         max_obs_size = np.sum(num_obs_objs[biggest_obs_ind,:])
  #       mass_crps = calc_CRPS(f_mass,o_mass,mass_bins)
  #       area_crps = calc_CRPS(f_area,o_area,area_bins)
  #       aspect_crps = calc_CRPS(f_aspect,o_aspect,np.arange(0.0,1.01,0.01))
  #       complex_crps = calc_CRPS(f_complexity,o_complexity,np.arange(0.0,1.01,0.01))
  #       pXX_crps = calc_CRPS(f_pXX,o_pXX,pXX_bins)

         # Object area
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
         for e in range(0,nmems):
            exec("f_hist,bin = np.histogram(dx**2*all_f_area_{:02d},bins=area_bins)".format(e))
            plt.semilogx(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs[e]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])
         exec("o_hist,bin = np.histogram(dx**2*all_o_area_{:02d},bins=area_bins)".format(biggest_obs_ind))
         plt.semilogx(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'k-',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel(r"Object area [km$^{2}$]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/object_area_hist_r{}t{}_all.png".format(img_dir,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # aspect ratio
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
         for e in range(0,nmems):
            exec("f_hist,bin=np.histogram(all_f_aspect_{:02d},bins=np.arange(0.0,1.01,0.05))".format(e))
            plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs[e]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])
         exec("o_hist,bin=np.histogram(all_o_aspect_{:02d},bins=np.arange(0.0,1.01,0.05))".format(biggest_obs_ind))
         plt.plot(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'-k',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xticks(np.arange(0.,1.01,0.10))
         plt.xlim(0,1)
         plt.xlabel("Object aspect ratio [width/length]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/object_aspect_hist_r{}t{}_all.png".format(img_dir,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # complexity
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
         for e in range(0,nmems):
            exec("f_hist,bin=np.histogram(all_f_complexity_{:02d},bins=np.arange(0.0,1.01,0.05))".format(e))
            plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs[e]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])
         exec("o_hist,bin=np.histogram(all_o_complexity_{:02d},bins=np.arange(0.0,1.01,0.05))".format(biggest_obs_ind))
         plt.plot(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'-k',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xticks(np.arange(0.,1.01,0.10))
         plt.xlim(0,1)
         plt.xlabel("Object complexity [-]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/object_complex_hist_r{}t{}_all.png".format(img_dir,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # percentile intensity values
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.98)
         for e in range(0,nmems):
            exec("f_hist,bin=np.histogram(all_f_pXX_{:02d},bins=pXX_bins)".format(e))
            plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs[e]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])
         exec("o_hist,bin=np.histogram(all_o_pXX_{:02d},bins=pXX_bins)".format(biggest_obs_ind))
         plt.plot(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'-k',linewidth=3,label="MRMS")
        # plt.yscale('log')
         plt.grid(linestyle=":",color='0.75')
         if field == 'compref':
            plt.xlabel("Object 95th percentile value",size=8)
         elif field == 'precip':
            plt.xlabel("Object 99th percentile value",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/object_pXX_hist_r{}t{}_all.png".format(img_dir,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # Object total mass
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
         for e in range(0,nmems):
            exec("f_hist,bin = np.histogram(all_f_mass_{:02d},bins=mass_bins)".format(e))
            plt.semilogx(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs[e]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])
         exec("o_hist,bin = np.histogram(all_o_mass_{:02d},bins=mass_bins)".format(biggest_obs_ind))
         plt.semilogx(0.5*(bin[:-1]+bin[1:]),o_hist/float(max_obs_size),'k-',linewidth=3,label="MRMS")
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel(r"Object total mass (dBZ)",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/object_mass_hist_r{}t{}_all.png".format(img_dir,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # Pair interest
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
         for e in range(0,nmems):
            exec("f_hist,bin = np.histogram(all_interest_{:02d},bins=np.arange(0.0,1.01,0.05))".format(e))
            plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(total_fcst_objs[e]),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel("Object pair interest [-]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/pair_interest_hist_r{}t{}_all.png".format(img_dir,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

         # Centroid distance
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
         for e in range(0,nmems):
            exec("f_hist,bin = np.histogram(dx*all_distance_{:02d},bins=np.arange(0.0,300.1,10.))".format(e))
            plt.plot(0.5*(bin[:-1]+bin[1:]),f_hist/float(np.sum(f_hist)),'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])
         plt.grid(linestyle=":",color='0.75')
         plt.xlabel("Centroid distance [km]",size=8)
         plt.ylabel("relative frequency",size=8)
         plt.tick_params(axis='both',labelsize=6)
         plt.legend(loc=1,prop={'size':8})
         image_file = "{}/centroid_dist_hist_r{}t{}_all.png".format(img_dir,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

      if True:
         # Determine object count bias as a function of object size
         plt.figure(figsize=(5,5))
         plt.subplots_adjust(left=0.125,bottom=0.1,top=0.98,right=0.95)
         for e in range(0,nmems):
            exec("o_hist,bin = np.histogram(dx**2*all_o_area_{:02d},bins=area_bins)".format(e))
            exec("f_hist,bin = np.histogram(dx**2*all_f_area_{:02d},bins=area_bins)".format(e))
            bias_by_size = 1.0*f_hist / o_hist
            plt.plot(0.5*(bin[:-1]+bin[1:]),bias_by_size,'-',color=colors_membs[nmems-1+e,:],linewidth=1,label=names[e])
         plt.plot([area_bins[0],area_bins[-1]],[1,1],'-k',linewidth=3)
         plt.xscale('log')
         plt.grid(linestyle=":",color='0.75')
         if field == 'compref':
            if T <= 3:
               plt.ylim(0.01,1.5)
            else:
               plt.ylim(0.05,11)
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
         image_file = "{}/object_bias_by_size_r{}t{}_all.png".format(img_dir,R,T)
         plt.savefig(image_file,dpi=120)
         plt.close()

   # End convolution theshold loop
# End convolution radii loop
