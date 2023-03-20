import numpy as np
import matplotlib
matplotlib.use('agg')
import matplotlib.pyplot as plt
import matplotlib.cm as mplc
import matplotlib.patheffects as pe

# Defaults
name = "HRRRX"
field = "compref"
img_dir = "/mnt/lfs4/BMC/amb-verif/RT_MODE/python_data/" + name + "/" + field + "/images"
data_root = "/mnt/lfs4/BMC/amb-verif/RT_MODE/python_data/" + name + "/" + field
ifhr = 0
efhr = 18
nfhrs = efhr - ifhr + 1
n_rad = 1
n_thresh = 4
thresh_mag = [25,30,35,40]
units = 'dBZ'
dx = 3.0 # grid spacing
# create color scheme for multiple convolution radius and threshold testing
cmp = mplc.get_cmap('coolwarm')
nq = np.linspace(0,1,n_rad*n_thresh)
colors = cmp(nq)
whiter_colors = np.zeros_like(colors)
for i in range(0,len(nq)):
   whiter_colors[i,:] = 0.5*(colors[i,:] + 1.0)
marks = ['o','^','D','s']
lines = ['-','--','-.',':','']

POD = np.zeros((n_rad,n_thresh,nfhrs),dtype=np.float)
SR = np.zeros((n_rad,n_thresh,nfhrs),dtype=np.float)
N_F = np.zeros(POD.shape,dtype=np.int)
N_O = np.zeros(POD.shape,dtype=np.int)
# The number of forecast cases is not (or should not, at least, be) a function of the convolution radius or threshold
n_cases = np.zeros(nfhrs,dtype=np.int)
for fhr in range(ifhr,efhr+1):
   number_of_cases_data = np.load('{}/mode_metrics_r1t1_f{:02d}.npz'.format(data_root,fhr))
   f = fhr - ifhr
   n_cases[f] = number_of_cases_data['ncases']

for R in range(1,n_rad+1):
   for T in range(1,n_thresh+1):

      if n_rad > 1:
         plot_label = "R{}-T{} {}".format(R,thresh_mag[T-1],units)
      else:
         plot_label = "{} {}".format(thresh_mag[T-1],units)

      color_number = n_thresh*(R-1) + T - 1
      CSI = np.zeros(nfhrs,dtype=np.float)
      FAR = np.zeros(nfhrs,dtype=np.float)
      MMI = np.zeros(nfhrs,dtype=np.float)
      OTS = np.zeros(nfhrs,dtype=np.float)
      area_CRPS = np.zeros(nfhrs,dtype=np.float)
      aspect_CRPS = np.zeros(nfhrs,dtype=np.float)
      complex_CRPS = np.zeros(nfhrs,dtype=np.float)
      length_CRPS = np.zeros(nfhrs,dtype=np.float)
      width_CRPS = np.zeros(nfhrs,dtype=np.float)
      pXX_CRPS = np.zeros(nfhrs,dtype=np.float)
      lat_CRPS = np.zeros(nfhrs,dtype=np.float)
      lon_CRPS = np.zeros(nfhrs,dtype=np.float)
      obj_fbias = np.zeros(nfhrs,dtype=np.float)
      mean_dist_stm = np.zeros(nfhrs,dtype=np.float)
      med_dist_stm = np.zeros(nfhrs,dtype=np.float)
      std_dist_stm = np.zeros(nfhrs,dtype=np.float)
      mean_dist_all = np.zeros(nfhrs,dtype=np.float)
      med_dist_all = np.zeros(nfhrs,dtype=np.float)
      std_dist_all = np.zeros(nfhrs,dtype=np.float)
      mean_dist_gen = np.zeros(nfhrs,dtype=np.float)
      med_dist_gen = np.zeros(nfhrs,dtype=np.float)
      std_dist_gen = np.zeros(nfhrs,dtype=np.float)

      for fhr in range(ifhr,efhr+1):
         f = fhr - ifhr
         data = np.load('{}/mode_metrics_r{}t{}_f{:02d}.npz'.format(data_root,R,T,fhr))

         CSI[f] = data['CSI']
       	 POD[R-1,T-1,f] = data['POD']
       	 FAR[f] = data['FAR']
       	 SR[R-1,T-1,f] = data['SR']
       	 MMI[f] = data['MMI']
       	 OTS[f] = data['OTS']
         N_F[R-1,T-1,f] = data['n_f_objs']
         N_O[R-1,T-1,f] = data['n_o_objs']
         area_CRPS[f] = data['area_crps']
       	 width_CRPS[f] = data['width_crps']
       	 length_CRPS[f] = data['length_crps']
       	 aspect_CRPS[f] = data['aspect_crps']
       	 complex_CRPS[f] = data['complex_crps']
       	 pXX_CRPS[f] = data['pXX_crps']
         lat_CRPS[f] = data['lat_crps']
         lon_CRPS[f] = data['lon_crps']
         obj_fbias[f] = data['fbias']
         mean_dist_stm[f] = data['stm_mean_dist']
         med_dist_stm[f] = data['stm_med_dist']
         std_dist_stm[f] = data['stm_std_dist']
         mean_dist_all[f] = data['all_mean_dist']
         med_dist_all[f] = data['all_med_dist']
         std_dist_all[f] = data['all_std_dist']
         mean_dist_gen[f] = data['gen_mean_dist']
         med_dist_gen[f] = data['gen_med_dist']
         std_dist_gen[f] = data['gen_std_dist']
         obj_fbias[f] = np.where(N_O[R-1,T-1,f] == 0,np.nan,1.0*N_F[R-1,T-1,f]/N_O[R-1,T-1,f])

      plt.figure(1,figsize=(5,5))
      plt.subplots_adjust(left=0.1,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),OTS,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(2,figsize=(5,5))
      plt.subplots_adjust(left=0.1,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),MMI,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(6,figsize=(5,5))
      plt.subplots_adjust(left=0.15,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),area_CRPS,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(7,figsize=(5,5))
      plt.subplots_adjust(left=0.15,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),width_CRPS,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(8,figsize=(5,5))
      plt.subplots_adjust(left=0.15,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),length_CRPS,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(9,figsize=(5,5))
      plt.subplots_adjust(left=0.15,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),aspect_CRPS,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(10,figsize=(5,5))
      plt.subplots_adjust(left=0.15,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),complex_CRPS,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(11,figsize=(5,5))
      plt.subplots_adjust(left=0.15,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),pXX_CRPS,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(12,figsize=(5,5))
      plt.subplots_adjust(left=0.15,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),lon_CRPS,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(13,figsize=(5,5))
      plt.subplots_adjust(left=0.15,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),lat_CRPS,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(14,figsize=(5,5))
      plt.subplots_adjust(left=0.125,right=0.98,bottom=0.1,top=0.98)
      plt.fill_between([ifhr,efhr],np.ones(2),[10.,10.],facecolor=[1.0,1.0,0.33,0.05],linestyle='None')
      plt.fill_between([ifhr,efhr],[0.0,0.0],np.ones(2),facecolor=[0.75,0.37,1.0,0.05],linestyle='None')
      t1 = plt.text(3,3.25,"OVERFORECAST",ha='left',va='top',color=[1.0,1.0,0.33],fontsize=12,fontweight=700,bbox=dict(facecolor='white',linewidth=2,edgecolor=[0.75,0.75,0.25],boxstyle='round,pad=0.5'))
      t2 = plt.text(12,0.50,"UNDERFORECAST",ha='center',va='center',color=[0.75,0.37,1.0],fontsize=12,fontweight=700,bbox=dict(facecolor='white',linewidth=2,edgecolor=[0.56,0.278,0.75],boxstyle='round,pad=0.5'))
      t1.set_path_effects([pe.Stroke(linewidth=2,foreground='0.25'),pe.Normal()])
      t2.set_path_effects([pe.Stroke(linewidth=2,foreground='0.1'),pe.Normal()])
      plt.plot([ifhr,efhr],[1.0,1.0],'k-',linewidth=2)
      plt.plot(range(ifhr,efhr+1),obj_fbias,linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

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
      plt.subplots_adjust(left=0.125,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),mean_dist_stm,linestyle=lines[R-1],marker=marks[T-1],markersize=4,linewidth=2,color=colors[color_number,:],label=plot_label)
#      plt.errorbar(range(0,24),mean_dist_stm,std_dist_stm,fmt='-',color=colors[color_number,:],label=plot_label)

      plt.figure(16,figsize=(6,5))
      plt.subplots_adjust(left=0.125,right=0.98,bottom=0.1,top=0.98)
#      plt.plot(range(ifhr,efhr+1),mean_dist_all,linestyle=lines[R-1],marker=marks[T-1],markersize=4,linewidth=2,color=colors[color_number,:],label=plot_label)
      plt.errorbar(range(ifhr,efhr+1),mean_dist_all,yerr=std_dist_all,fmt='-',color=colors[color_number,:],label=plot_label)

      plt.figure(17,figsize=(6,5))
      plt.subplots_adjust(left=0.125,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),mean_dist_gen,linestyle=lines[R-1],marker=marks[T-1],markersize=4,linewidth=2,color=colors[color_number,:],label=plot_label)
      plt.plot(range(ifhr,efhr+1),med_dist_gen,linestyle=lines[R-1],markersize=4,linewidth=1,color=whiter_colors[color_number,:])
#      plt.errorbar(range(0,24),mean_dist_gen,std_dist_gen,fmt='-',color=colors[color_number,:],label=plot_label)

      plt.figure(18,figsize=(5,5))
      plt.subplots_adjust(left=0.1,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),np.where(N_F[R-1,T-1,:] == 0,np.nan,1.*N_F[R-1,T-1,:]/n_cases),linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

      plt.figure(19,figsize=(5,5))
      plt.subplots_adjust(left=0.1,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),np.where(N_O[R-1,T-1,:] == 0,np.nan,1.*N_O[R-1,T-1,:]/n_cases),linestyle=lines[R-1],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)

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
  plt.grid(linestyle=':',color='0.75')
  plt.xticks(range(0,37,3))
  plt.xlim(ifhr-1,efhr+1)
  if n <= 14:
   if "bias" in fig_titles[n-1]:
    plt.yticks([0.0,0.5,0.75,0.9,1.0,1.1,1.25,1.5,2,2.5,3,3.5,4])
    plt.ylim(0,3.5)
   elif "MMI" in fig_titles[n-1]:
    plt.yticks(np.arange(0.,1.01,0.05))
    plt.ylim(0.0,0.95)
   elif "OTS" in fig_titles[n-1]:
    plt.yticks(np.arange(0.,1.01,0.05))
    plt.ylim(0.35,0.90)
  elif n >= 15 and n <= 17:
   plt.ylim(0,55)
  plt.xlabel("Forecast hour",size=8)
  plt.ylabel(fig_y_axis[n-1],size=8)
  plt.tick_params(axis='both',labelsize=6)
  plt.figtext(0.1,0.025,'max # of cases: {}'.format(np.amax(n_cases)),va='bottom',ha='left',fontsize=10,fontweight=500,bbox=dict(facecolor='white',edgecolor='black',pad=1))
  plt.legend(loc=0,prop={'size':8},ncol=n_rad)
  image_file = "{}/{}_{}.png".format(img_dir,name,fig_titles[n-1])
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
      plt.xlim(0.2,0.9)
      plt.ylim(0.6,1.0)

# Roebber performance diagram containing ALL data points
plt.figure(figsize=(5,5))
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
performance_diagram_window(True)
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

# Roebber performance diagram by forecast hour
for fhr in range(ifhr,efhr+1):
   f = fhr - ifhr
   plt.figure(6,figsize=(4,4))
   plt.subplots_adjust(left=0.12,right=0.94,bottom=0.1,top=0.97)
   for csi in np.arange(0.1,0.91,0.1):
      x = np.linspace(0.01,1.0,100)
      y = np.zeros(x.shape,dtype=np.float)
      for i in range(0,len(x)):
         y[i] = 1.0 / (1/csi - 1/x[i] + 1)
         if y[i] < 0.0 or y[i] > y[np.maximum(i-1,0)]:
            y[i] = 1.0
      plt.plot(x,y,'--',linewidth=0.5,color='0.7')
      plt.text(x[95],y[95],"{:3.1f}".format(csi),fontsize=6,color='0.7',ha='center',va='center',bbox=dict(facecolor='white',edgecolor='None',pad=1))
   performance_diagram_window(True)
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
         plt.plot(SR[R-1,T-1,f],POD[R-1,T-1,f],marker=marks[T-1],markersize=4,color=colors[color_number,:],label=plot_label)
   plt.xlabel("success ratio (1-FAR)",size=8)
   plt.ylabel("POD",size=8)
   plt.tick_params(axis='both',labelsize=6)
   plt.legend(loc='lower right',prop={'size':8},ncol=1,fancybox=True)
   image_file = "{}/{}_object_performance_diagram_f{:02d}.png".format(img_dir,name,fhr)
   plt.savefig(image_file,dpi=120)
   plt.close(6)

### Plots by convolution radius/threshold configuration
for R in range(1,n_rad+1):
   for T in range(1,n_thresh+1):
      # Performance diagram
      color_number = n_thresh*(R-1) + T - 1
      plt.figure(6,figsize=(4,4))
      plt.subplots_adjust(left=0.12,right=0.94,bottom=0.1,top=0.97)
      for csi in np.arange(0.1,0.91,0.1):
         x = np.linspace(0.01,1.0,100)
         y = np.zeros(x.shape,dtype=np.float)
         for i in range(0,len(x)):
            y[i] = 1.0 / (1/csi - 1/x[i] + 1)
            if y[i] < 0.0 or y[i] > y[np.maximum(i-1,0)]:
               y[i] = 1.0
         plt.plot(x,y,'--',linewidth=0.5,color='0.7')
         plt.text(x[95],y[95],"{:3.1f}".format(csi),fontsize=6,color='0.7',ha='center',va='center',bbox=dict(facecolor='white',edgecolor='None',pad=1))
      performance_diagram_window(True)
      for bias in [0.25,0.5,0.75,0.9,1.0,1.1,1.25,1.5,2,3,4,5]:
         plt.plot([0,1],[0,bias],'-',linewidth=0.5,color='0.7')
         if bias < 1.0:
            plt.text(1.0,bias," {:4.2f}".format(bias),fontsize=6,color='0.7',ha='left')
         else:
            plt.text(1.0/bias,1.0,"{:4.2f}".format(bias),fontsize=6,color='0.7',va='bottom')
      plt.plot([0,1],[0,1],'-',linewidth=1.5,color='0.3')
      plt.plot(SR[R-1,T-1,:],POD[R-1,T-1,:],marker=marks[T-1],linestyle='-',linewidth=0.5,markersize=4,color=colors[color_number,:])
      plt.text(SR[R-1,T-1,0]+0.01,POD[R-1,T-1,0]+0.01,"f{:02d}".format(ifhr),fontsize=5,ha='left',va='baseline')
      plt.text(SR[R-1,T-1,12-ifhr]+0.01,POD[R-1,T-1,12-ifhr]+0.01,"f{:02d}".format(12),fontsize=5,ha='left',va='baseline')
      plt.text(SR[R-1,T-1,efhr-ifhr]+0.01,POD[R-1,T-1,efhr-ifhr]+0.01,"f{:02d}".format(efhr),fontsize=5,ha='left',va='baseline')
      plt.xlabel("success ratio (1-FAR)",size=8)
      plt.ylabel("POD",size=8)
      plt.tick_params(axis='both',labelsize=6)
      image_file = "{}/{}_object_performance_diagram_r{}t{}.png".format(img_dir,name,R,T)
      plt.savefig(image_file,dpi=120)
      plt.close(6)

      # Object counts
      plt.figure(10,figsize=(5,5))
      plt.subplots_adjust(left=0.125,right=0.98,bottom=0.1,top=0.98)
      plt.plot(range(ifhr,efhr+1),N_F[R-1,T-1,:]/(1.*n_cases),'-x',linewidth=2,markersize=4,color=colors[color_number,:],label=name)
      plt.plot(range(ifhr,efhr+1),N_O[R-1,T-1,:]/(1.*n_cases),'k-x',linewidth=3,markersize=4,label="MRMS")
      plt.xticks(range(0,37,3))
      plt.grid(linestyle=':',color='0.75')
      plt.xlim(ifhr-1,efhr+1)
      plt.xlabel("Forecast hour",size=8)
      plt.ylabel("Average object count per case",size=8)
      plt.tick_params(axis='both',labelsize=6)
      plt.legend(loc=0,prop={'size':6})
      image_file = "{}/{}_object_count_r{}t{}.png".format(img_dir,name,R,T)
      plt.savefig(image_file,dpi=120)
      plt.close(10)
