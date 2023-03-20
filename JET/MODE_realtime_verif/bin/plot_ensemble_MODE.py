import numpy as np
import matplotlib
matplotlib.use('agg')
import matplotlib.pyplot as plt
import matplotlib.cm as mplc
import matplotlib.patheffects as pe
import argparse

parser = argparse.ArgumentParser(description="Plot results from ensemble_aggregate_MODE_scores.py.\nNOTE: All arguments listed below are REQUIRED",
                                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                 usage="plot_ensemble_MODE.py [-h] [options]",
                                 epilog="""THIRD of three scripts necessary to perform and plot object-based verification scores using MODE.

script list and order:
1) MODE_compute.py
2) ensemble_aggregate_MODE_scores.py
3) plot_MODE_results.py [THIS SCRIPT]
""")

parser.add_argument('-mods',nargs='+',type=str,metavar="model names [list]",dest="models",required=True,
                    help="Names of models")
parser.add_argument('-dump',type=str,metavar="dump_root",dest="dump_root",required=True,
                    help="Root location of partial sums and object attribute files (from MODE_compute.py)")
parser.add_argument('-f'       ,type=int,metavar=("iFHR","eFHR"),required=True,nargs=2,
                    help="First and last forecast hour to be processed")
parser.add_argument('-fld',type=str,metavar="field",dest="field",required=True,choices=["compref","precip"],
                    help="Field to be processed")
args = parser.parse_args()

# Defaults
names = args.models
field = args.field
data_root = "{}/all/{}".format(args.dump_root,field)
img_dir = "{}/all/{}/images/dieoff".format(args.dump_root,field)
ifhr = np.sort(args.f)[0] # start forecast hour to analyze
efhr = np.sort(args.f)[1] # end forecast hour to analyze
nfhrs = efhr - ifhr + 1
nmems = len(names)
n_rad = 1
n_thresh = 4
thresh_mag = [25,30,35,40]
units = 'dBZ'
dx = 3.0 # grid spacing
# create color scheme for multiple convolution radius and threshold testing
cmp = mplc.get_cmap('tab10')
nq = np.linspace(0,1,nmems+1)
colors = cmp(nq)
whiter_colors = np.zeros_like(colors)
for i in range(0,len(nq)):
   whiter_colors[i,:] = 0.5*(colors[i,:] + 1.0)
marks = ['o','^','D','s']
lines = ['-','--','-.',':','']

POD = np.zeros((nmems,n_rad,n_thresh,nfhrs),dtype=np.float)
SR = np.zeros((nmems,n_rad,n_thresh,nfhrs),dtype=np.float)
N_F = np.zeros(POD.shape,dtype=np.int)
N_O = np.zeros(POD.shape,dtype=np.int)
# The number of forecast cases is not (or should not, at least, be) a function of the convolution radius or threshold
n_cases = np.zeros((nmems,nfhrs),dtype=np.int)
number_of_cases_data = np.load('{}/mode_metrics_r1t1_all.npz'.format(data_root))
n_cases = number_of_cases_data['ncases']

for R in range(1,n_rad+1):
   for fig in range(0,20):
      plt.figure(fig,figsize=(6,6))
      plt.subplots_adjust(left=0.1,right=0.98,bottom=0.075,top=0.98,wspace=0.225,hspace=0.15)

   for T in range(1,n_thresh+1):

      CSI = np.full((nmems,nfhrs),np.nan,dtype=np.float)
      FAR = np.full(CSI.shape,np.nan,dtype=np.float)
      MMI = np.full(CSI.shape,np.nan,dtype=np.float)
      OTS = np.full(CSI.shape,np.nan,dtype=np.float)
      area_CRPS = np.full(CSI.shape,np.nan,dtype=np.float)
      aspect_CRPS = np.full(CSI.shape,np.nan,dtype=np.float)
      complex_CRPS = np.full(CSI.shape,np.nan,dtype=np.float)
      length_CRPS = np.full(CSI.shape,np.nan,dtype=np.float)
      width_CRPS = np.full(CSI.shape,np.nan,dtype=np.float)
      pXX_CRPS = np.full(CSI.shape,np.nan,dtype=np.float)
      lat_CRPS = np.full(CSI.shape,np.nan,dtype=np.float)
      lon_CRPS = np.full(CSI.shape,np.nan,dtype=np.float)
      obj_fbias = np.full(CSI.shape,np.nan,dtype=np.float)
      mean_dist_stm = np.full(CSI.shape,np.nan,dtype=np.float)
      med_dist_stm = np.full(CSI.shape,np.nan,dtype=np.float)
      std_dist_stm = np.full(CSI.shape,np.nan,dtype=np.float)
      mean_dist_all = np.full(CSI.shape,np.nan,dtype=np.float)
      med_dist_all = np.full(CSI.shape,np.nan,dtype=np.float)
      std_dist_all = np.full(CSI.shape,np.nan,dtype=np.float)
      mean_dist_gen = np.full(CSI.shape,np.nan,dtype=np.float)
      med_dist_gen = np.full(CSI.shape,np.nan,dtype=np.float)
      std_dist_gen = np.full(CSI.shape,np.nan,dtype=np.float)

      data = np.load('{}/mode_metrics_r{}t{}_all.npz'.format(data_root,R,T))

      CSI = data['CSI']
      FAR = data['FAR']
      MMI = data['MMI']
      OTS = data['OTS']
      area_CRPS = data['area_crps']
      width_CRPS = data['width_crps']
      length_CRPS = data['length_crps']
      aspect_CRPS = data['aspect_crps']
      complex_CRPS = data['complex_crps']
      pXX_CRPS = data['pXX_crps']
      lat_CRPS = data['lat_crps']
      lon_CRPS = data['lon_crps']
      mean_dist_stm = data['stm_mean_dist']
      med_dist_stm = data['stm_med_dist']
      std_dist_stm = data['stm_std_dist']
      mean_dist_all = data['all_mean_dist']
      med_dist_all = data['all_med_dist']
      std_dist_all = data['all_std_dist']
      mean_dist_gen = data['gen_mean_dist']
      med_dist_gen = data['gen_med_dist']
      std_dist_gen = data['gen_std_dist']
      POD_data = data['POD']
      SR_data = data['SR']
      N_F_data = data['n_f_objs']
      N_O_data = data['n_o_objs']
      for e in range(0,nmems):
         POD[e,R-1,T-1,:] = POD_data[e,:]
         SR[e,R-1,T-1,:] = SR_data[e,:]
         N_F[e,R-1,T-1,:] = N_F_data[e,:]
         N_O[e,R-1,T-1,:] = N_O_data[e,:]
         obj_fbias[e,:] = np.where(N_O[e,R-1,T-1,:] == 0,np.nan,1.0*N_F[e,R-1,T-1,:]/N_O[e,R-1,T-1,:])
      
      plt.figure(1)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),OTS[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(2)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),MMI[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(6)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),area_CRPS[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(7)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),width_CRPS[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(8)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),length_CRPS[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(9)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),aspect_CRPS[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(10)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),complex_CRPS[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(11)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),pXX_CRPS[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(12)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),lon_CRPS[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(13)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),lat_CRPS[e,:],'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(14)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),obj_fbias[e,:],'-',markersize=4,color=colors[e,:],label=names[e])
   #   plt.fill_between([ifhr,efhr],np.ones(2),[10.,10.],facecolor=[1.0,1.0,0.33,0.05],linestyle='None')
   #   plt.fill_between([ifhr,efhr],[0.0,0.0],np.ones(2),facecolor=[0.75,0.37,1.0,0.05],linestyle='None')
   #   t1 = plt.text(3,3.25,"OVERFORECAST",ha='left',va='top',color=[1.0,1.0,0.33],fontsize=12,fontweight=700,bbox=dict(facecolor='white',linewidth=2,edgecolor=[0.75,0.75,0.25],boxstyle='round,pad=0.5'))
   #   t2 = plt.text(12,0.50,"UNDERFORECAST",ha='center',va='center',color=[0.75,0.37,1.0],fontsize=12,fontweight=700,bbox=dict(facecolor='white',linewidth=2,edgecolor=[0.56,0.278,0.75],boxstyle='round,pad=0.5'))
   #   t1.set_path_effects([pe.Stroke(linewidth=2,foreground='0.25'),pe.Normal()])
   #   t2.set_path_effects([pe.Stroke(linewidth=2,foreground='0.1'),pe.Normal()])
      plt.plot([ifhr,efhr],[1.0,1.0],'k-',linewidth=2)

      mean_dist_stm[mean_dist_stm == -999.] = np.nan
      med_dist_stm[mean_dist_stm == -999.] = np.nan
      std_dist_stm[mean_dist_stm == -999.] = np.nan
      mean_dist_all[mean_dist_all == -999.] = np.nan
      med_dist_all[mean_dist_all == -999.] = np.nan
      std_dist_all[mean_dist_all == -999.] = np.nan
      mean_dist_gen[mean_dist_gen == -999.] = np.nan
      med_dist_gen[mean_dist_gen == -999.] = np.nan
      std_dist_gen[mean_dist_gen == -999.] = np.nan
      plt.figure(15,figsize=(6,5))
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),mean_dist_stm[e,:],'-',markersize=4,linewidth=2,color=colors[e,:],label=names[e])
   #      plt.errorbar(range(0,24),mean_dist_stm,std_dist_stm,fmt='-',color=colors[e,:],label=names[e])

      plt.figure(16,figsize=(6,5))
      plt.subplot(2,2,T)
      for e in range(0,nmems):
   #      plt.plot(range(ifhr,efhr+1),mean_dist_all[e,:],'-',markersize=4,linewidth=2,color=colors[e,:],label=names[e])
         plt.errorbar(range(ifhr,efhr+1),mean_dist_all[e,:],yerr=std_dist_all[e,:],fmt='-',color=colors[e,:],label=names[e])

      plt.figure(17,figsize=(6,5))
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),mean_dist_gen[e,:],'-',markersize=4,linewidth=2,color=colors[e,:],label=names[e])
         plt.plot(range(ifhr,efhr+1),med_dist_gen[e,:],linestyle=lines[R-1],markersize=4,linewidth=1,color=whiter_colors[e,:])
   #      plt.errorbar(range(0,24),mean_dist_gen[e,:],std_dist_gen[e,:],fmt='-',color=colors[e,:],label=names[e])

      plt.figure(18)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),np.where(N_F[e,R-1,T-1,:] == 0,np.nan,1.*N_F[e,R-1,T-1,:]/n_cases[e,:]),'-',markersize=4,color=colors[e,:],label=names[e])

      plt.figure(19)
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),np.where(N_O[e,R-1,T-1,:] == 0,np.nan,1.*N_O[e,R-1,T-1,:]/n_cases[e,:]),'-',markersize=4,color=colors[e,:],label=names[e])

   # End convolution theshold loop
# End convolution radii loop

print("Data range verified (YYYYMMDDHH of initialization): {} to {}".format(data['agg_start_date'],data['agg_end_date']))

# Make sure these lists correspond to each other and to the order of the plotting above
if data['MMI_flag']:
   MMI_title = "MMI_std"
   MMI_name = "standard MMI"
   print("Plotting standard MMI calculation")
else:
   MMI_title = "MMI_alt"
   MMI_name = "alternate MMI"
   print("Plotting alternative MMI calculation")
fig_titles = ["OTS",MMI_title,"","","","CRPS_area","CRPS_width","CRPS_length","CRPS_aspect","CRPS_complex","CRPS_pXX","CRPS_lon","CRPS_lat","object_fbias",
              "mean_distance_stm","mean_distance_all","mean_distance_gen","fcst_object_count","obs_object_count"]
fig_y_axis = ["OTS",MMI_name,"","","",
              "area distribution CRPS","width distribution CRPS","length distribution CRPS","aspect-ratio distribution CRPS","complexity CRPS","95th pct. distribution CRPS","centroid longitude CRPS","centroid latitude CRPS",
              r"object frequency bias ($N_f/N_o$)","mean distance between matched storm objects","mean distance between all matched objects","generalized mean distance between objects","average forecast object count per case","average observation object count per case"]
for n in range(1,20):
 if n <= 2 or n >= 6:
  plt.figure(n)
  for T in range(1,n_thresh+1):
   plt.subplot(2,2,T)
   plt.grid(linestyle=':',color='0.75')
   plt.xticks(range(0,37,3))
   plt.xlim(ifhr-1,efhr+1)
   if n <= 14:
    if "bias" in fig_titles[n-1]:
     plt.yticks([0.0,0.5,0.75,0.9,1.0,1.1,1.25,1.5,2,2.5,3,3.5,4])
     if T < 4:
      plt.ylim(0.95,2.5)
     else:
      plt.ylim(0.99,4.0)
    elif "MMI" in fig_titles[n-1]:
     plt.yticks(np.arange(0.,1.01,0.1))
     plt.ylim(0.0,0.95)
    elif "OTS" in fig_titles[n-1]:
     plt.yticks(np.arange(0.,1.01,0.1))
     plt.ylim(0.3,0.95)
   elif n >= 15 and n <= 17:
    if n == 15:
     plt.ylim(10,35)
    elif n == 16:
     plt.ylim(0,46)
    elif n == 17:
     plt.ylim(0,55)
   plt.xlabel("Forecast hour",size=8)
   plt.ylabel(fig_y_axis[n-1],size=8)
   plt.tick_params(axis='both',labelsize=6)
   bot,top = plt.ylim()
   if n == 16:
    plt.text(0.5*(ifhr+efhr),bot+0.02*(top-bot),"Threshold: {} {}".format(thresh_mag[T-1],units),ha='center',va='bottom',fontsize=8,fontweight=300,bbox=dict(facecolor='white',edgecolor='black',pad=2,linewidth=0.5))
   else:
    plt.text(0.5*(ifhr+efhr),top-0.02*(top-bot),"Threshold: {} {}".format(thresh_mag[T-1],units),ha='center',va='top',fontsize=8,fontweight=300,bbox=dict(facecolor='white',edgecolor='black',pad=2,linewidth=0.5))
  plt.subplot(2,2,1)
  plt.figtext(0.025,0.01,'max # of cases: {}'.format(np.amax(n_cases)),va='bottom',ha='left',fontsize=8,fontweight=300,bbox=dict(facecolor='white',edgecolor='black',pad=2,linewidth=0.5))
  plt.legend(loc=0,prop={'size':6},ncol=1)
  image_file = "{}/all_{}.png".format(img_dir,fig_titles[n-1])
  plt.savefig(image_file,dpi=120)
  plt.close(n)

def performance_diagram_window(flag):
   # Settings to control the window of the performance diagram to be displayed
   if flag:
      plt.xlim(0,1)
      plt.ylim(0,1)
      plt.xticks(np.arange(0.0,1.01,0.1))
      plt.yticks(np.arange(0.0,1.01,0.1))
   else:
      plt.xticks(np.arange(0.0,1.01,0.05))
      plt.yticks(np.arange(0.0,1.01,0.05))
      plt.xlim(0.1,0.9)
      plt.ylim(0.45,1.0)

# Roebber performance diagram containing ALL data points
if False:
 plt.figure(figsize=(6,6))
 plt.subplots_adjust(left=0.1,right=0.94,bottom=0.1,top=0.97)
 for csi in np.arange(0.1,0.91,0.1):
   x = np.linspace(0.01,1.0,100)
   y = np.zeros(x.shape,dtype=np.float)
   for i in range(0,len(x)):
      y[i] = 1.0 / (1/csi - 1/x[i] + 1)
      if y[i] < 0.0 or y[i] > y[np.maximum(i-1,0)]:
         y[i] = 1.0
   plt.plot(x,y,'--',linewidth=0.5,color='0.7')
   plt.text(x[95],y[95],"{:3.1f}".format(csi),fontsize=6,color='0.7',ha='center',va='center',bbox=dict(facecolor='white',edgecolor='None',pad=1))
 performance_diagram_window(False)
 for bias in [0.25,0.5,0.75,0.9,1.0,1.1,1.25,1.5,2,3,4,5]:
   plt.plot([0,1],[0,bias],'-',linewidth=0.5,color='0.7')
   if bias < 1.0:
      plt.text(1.0,bias," {:4.2f}".format(bias),fontsize=6,color='0.7',ha='left')
   else:
      plt.text(1.0/bias,1.0,"{:4.2f}".format(bias),fontsize=6,color='0.7',va='bottom')
 plt.plot([0,1],[0,1],'-',linewidth=1.5,color='0.3')
 for R in range(1,n_rad+1):
   for T in range(1,n_thresh+1):
      if n_rad > 1:
         plot_label = "R{}-T{} {}".format(R,thresh_mag[T-1],units)
      else:
         plot_label = "{} {}".format(thresh_mag[T-1],units)
      color_number = n_thresh*(R-1) + T - 1
      plt.plot(SR[R-1,T-1,:],POD[R-1,T-1,:],marker=marks[T-1],markersize=4,mfc=colors[color_number],color=colors[color_number,:],label=plot_label)
 for R in range(1,n_rad+1):
   for T in range(1,n_thresh+1):
      color_number = n_thresh*(R-1) + T - 1
      plt.plot(SR[R-1,T-1,0],POD[R-1,T-1,0],marker=marks[T-1],markersize=5,mfc='yellow',mew=0.5,mec='k')
      if ifhr <= 12 and efhr >= 12:
         plt.plot(SR[R-1,T-1,12-ifhr],POD[R-1,T-1,12-ifhr],marker=marks[T-1],markersize=5,mfc='orange',mew=0.5,mec='k')
      plt.plot(SR[R-1,T-1,efhr],POD[R-1,T-1,efhr],marker=marks[T-1],markersize=5,mfc='sienna',mew=0.5,mec='k')
 plt.xlabel("success ratio (1-FAR)",size=8)
 plt.ylabel("POD",size=8)
 plt.tick_params(axis='both',labelsize=6)
 plt.legend(loc='lower right',prop={'size':8},ncol=1,fancybox=True)
 image_file = "{}/{}_object_performance_diagram_all.png".format(img_dir,name)
 plt.savefig(image_file,dpi=120)
 plt.close()

### Plots by convolution radius/threshold configuration
for R in range(1,n_rad+1):
   plt.figure(6,figsize=(8,8))
   plt.subplots_adjust(left=0.10,right=0.975,bottom=0.075,top=0.97,hspace=0.2,wspace=0.2)
   for T in range(1,n_thresh+1):
      # Performance diagram
      color_number = n_thresh*(R-1) + T - 1
      plt.subplot(2,2,T)
      for csi in np.arange(0.1,0.91,0.1):
         x = np.linspace(0.01,1.0,100)
         y = np.zeros(x.shape,dtype=np.float)
         for i in range(0,len(x)):
            y[i] = 1.0 / (1/csi - 1/x[i] + 1)
            if y[i] < 0.0 or y[i] > y[np.maximum(i-1,0)]:
               y[i] = 1.0
         plt.plot(x,y,'--',linewidth=0.5,color='0.7')
         plt.text(x[95],y[95],"{:3.1f}".format(csi),fontsize=6,color='0.7',ha='center',va='center',bbox=dict(facecolor='white',edgecolor='None',pad=1))
      performance_diagram_window(False)
      for bias in [0.25,0.5,0.75,0.9,1.0,1.1,1.25,1.5,2,3,4,5]:
         plt.plot([0,1],[0,bias],'-',linewidth=0.5,color='0.7')
         if bias < 1.0:
            plt.text(1.0,bias," {:4.2f}".format(bias),fontsize=6,color='0.7',ha='left')
         else:
            plt.text(1.0/bias,1.0,"{:4.2f}".format(bias),fontsize=6,color='0.7',va='bottom')
      plt.plot([0,1],[0,1],'-',linewidth=1.5,color='0.3')
      for e in range(0,nmems):
         plt.plot(SR[e,R-1,T-1,:],POD[e,R-1,T-1,:],marker=marks[T-1],linestyle=':',linewidth=1,markersize=3,color=colors[e,:],label=names[e])
         plt.text(SR[e,R-1,T-1,0]+0.01,POD[e,R-1,T-1,0]+0.01,"f{:02d}".format(ifhr),fontsize=5,ha='left',va='baseline')
         plt.text(SR[e,R-1,T-1,12-ifhr]+0.01,POD[e,R-1,T-1,12-ifhr]+0.01,"f{:02d}".format(12),fontsize=5,ha='left',va='baseline')
         plt.text(SR[e,R-1,T-1,efhr-ifhr]+0.01,POD[e,R-1,T-1,efhr-ifhr]+0.01,"f{:02d}".format(efhr),fontsize=5,ha='left',va='baseline')
      plt.xlabel("success ratio (1-FAR)",size=8)
      plt.ylabel("POD",size=8)
      plt.tick_params(axis='both',labelsize=6)
      left,right = plt.xlim()
      bot,top = plt.ylim()
      plt.text(0.025*(right-left)+left,top-0.04*(top-bot),"Threshold: {} {}".format(thresh_mag[T-1],units),ha='left',va='top',fontsize=8,fontweight=400,bbox=dict(facecolor='white',edgecolor='black',pad=2))
   plt.legend(loc='lower right',prop={'size':8},ncol=1,fancybox=True)
   image_file = "{}/all_object_performance_diagram.png".format(img_dir)
   plt.savefig(image_file,dpi=120)
   plt.close(6)

   # object counts
   plt.figure(10,figsize=(6,6))
   plt.subplots_adjust(left=0.1,right=0.98,bottom=0.075,top=0.98,wspace=0.2,hspace=0.15)
   for T in range(1,n_thresh+1):
      plt.subplot(2,2,T)
      for e in range(0,nmems):
         plt.plot(range(ifhr,efhr+1),N_F[e,R-1,T-1,:]/(1.*n_cases[e,:]),'-',linewidth=2,markersize=4,color=colors[e,:],label=names[e])
     # plt.plot(range(ifhr,efhr+1),N_O[e,R-1,T-1,:]/(1.*n_cases[e,:]),'k-',linewidth=3,markersize=4,label="MRMS")
      plt.xticks(range(int(ifhr/3)*3,efhr+1,3))
      plt.grid(linestyle=':',color='0.75')
      plt.xlim(ifhr-1,efhr+1)
      plt.xlabel("Forecast hour",size=8)
      plt.ylabel("Average object count per case",size=8)
      left,right = plt.xlim()
      bot,top = plt.ylim()
      plt.text(0.025*(right-left)+left,top-0.04*(top-bot),"Threshold: {} {}".format(thresh_mag[T-1],units),ha='left',va='top',fontsize=8,fontweight=400,bbox=dict(facecolor='white',edgecolor='black',pad=2,linewidth=0.5))
      plt.tick_params(axis='both',labelsize=6)
   plt.legend(loc=0,prop={'size':6})
   image_file = "{}/all_object_count.png".format(img_dir)
   plt.savefig(image_file,dpi=120)
   plt.close(10)
