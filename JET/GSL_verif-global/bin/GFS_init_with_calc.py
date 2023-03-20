#!/usr/bin/env python
###################
#
# Name: GFS_init.py
#
# Description: script for moving GFS grib2 files
#
#
# History:
#   INITIAL VERSION - Jeff Hamilton GSD/ADB, 20180406
#   Modified by Molly Smith, GSL/AVID/VAB, 20210125
#
###################
import sys
import os
import resource
from datetime import datetime
from datetime import timedelta
import pygrib

def main():
    # Environmental options
    Year = os.getenv("YEAR")
    Month = os.getenv("MONTH")
    Day = os.getenv("DAY")
    Hour = os.getenv("HOUR")

    exec_dir = os.getenv("EXECDIR")
    script_dir = os.getenv("SCRIPTDIR")
    rt_dir = os.getenv("REALTIMEDIR")
    model_dir = os.getenv("MODELDIR")
    model = os.getenv("MODEL")

    # Looping variables

    variables = (os.getenv("VARIABLE")).split(",")
    forecast_leads = (os.getenv("FCSTLEADS")).split()

    # Interpolation options

    #pcp_mask = os.getenv("PCPMASK")


    # Move files

    time = datetime(int(Year), int(Month), int(Day), int(Hour))

    date_str = '%4d%02d%02d%02d' % (time.year, time.month, time.day, time.hour)

    # Create realtime directory

    valid_dir = time.strftime('%Y%m%d-%Hz')
    print(valid_dir)
    os.system('mkdir -p %s/%s' % (rt_dir, valid_dir))
    os.chdir('%s/%s' % (rt_dir, valid_dir))

    for fcst_len in forecast_leads:
        src_file_str = time.strftime('%y%j%H')
        src_file = '%s000%s' % (src_file_str,fcst_len)

        temp_file = '%s_%s_%s_temp.grib2' % (model,date_str,fcst_len)
        new_file = '%s_%s_%s.grib2' % (model,date_str,fcst_len)
        file_created = False

        # Move files

        fcst_file = '%s/%s' % (model_dir,src_file)

        if (os.path.isfile('%s' % fcst_file)):

            print('Source file: ', src_file)

            for var in variables:
               # Grab only the variable desired
               if var == 'RH':
                  c = [0.611583699E03, 0.444606896E02, 0.143177157E01, 0.264224321E-1, 0.299291081E-3, 0.203154182E-5, 0.702620698E-8, 0.379534310E-11, -0.321582393E-13]
                  grbs2 = pygrib.open(fcst_file)
                  grbs2.seek(0)
                  all_tmp = grbs2.select(parameterName="Temperature",typeOfLevel='isobaricInhPa')
                  all_rh = grbs2.select(parameterName="Relative humidity",typeOfLevel='isobaricInhPa')
                  all_spfh = grbs2.select(parameterName="Specific humidity",typeOfLevel='isobaricInhPa')
                  grbs2.close()
                  for i in range(0, len(all_tmp)):
                     tmp_array = all_tmp[i].values
                     tmp_level_mb = all_tmp[i].level
                     i_rh = 0
                     i_spfh = 0
                     for j in range(0, len(all_rh)):
                        rh_level_mb = all_rh[j].level
                        if tmp_level_mb == rh_level_mb:
                           i_rh = j
                     for j in range(0, len(all_spfh)):
                        spfh_level_mb = all_spfh[j].level
                        if tmp_level_mb == spfh_level_mb:
                           i_spfh = j
                     if i == i_rh and i == i_spfh and tmp_level_mb >= 100:
                        spfh_array = all_spfh[i_spfh].values
                        tmp_array = tmp_array - 273.15
                        esat = c[0]+tmp_array*(c[1]+tmp_array*(c[2]+tmp_array*(c[3]+tmp_array*(c[4]+tmp_array*(c[5]+tmp_array*(c[6]+tmp_array*(c[7]+tmp_array*c[8])))))))
                        ws = (0.622 * esat) / (tmp_level_mb * 100 - esat)
                        new_rh = spfh_array / ((1 - spfh_array) * ws) * 100
                        new_rh[new_rh < 0] = 0
                        try:
                           all_rh[i_rh].values = new_rh
                           grbout = open(temp_file,'wb')
                           grbout.write(all_rh[i_rh].tostring())
                           grbout.close()
                           if (os.path.isfile('%s' % new_file) and file_created is True):
                              cmd = 'wgrib2 %s | wgrib2 -i %s -append -GRIB %s' % (temp_file,temp_file,new_file)
                           else:
                              cmd = 'wgrib2 %s | wgrib2 -i %s -GRIB %s' % (temp_file,temp_file,new_file)
                              file_created = True
                           print(cmd)
                           os.system(cmd)
                           cmd = 'rm -f %s' % (temp_file)
                           print(cmd)
                           os.system(cmd)
                        except RuntimeError:
                           print('Error writing RH to grib file for level '+str(tmp_level_mb)+'mb')
                  ## include Z2 variables
                  #grbs2 = pygrib.open(fcst_file)
                  #grbs2.seek(0)
                  #z2_tmp = grbs2.select(parameterName="Temperature",typeOfLevel='heightAboveGround', level=2)
                  #z2_rh = grbs2.select(parameterName="Relative humidity",typeOfLevel='heightAboveGround', level=2)
                  #z2_spfh = grbs2.select(parameterName="Specific humidity",typeOfLevel='heightAboveGround', level=2)
                  #z2_pres = grbs2.select(parameterName="Pressure",typeOfLevel='surface')
                  #grbs2.close()
                  #for i in range(0, len(z2_tmp)):
                  #   tmp_array = z2_tmp[i].values
                  #   tmp_level_mb = z2_pres[i].values/100
                  #   spfh_array = z2_spfh[i].values
                  #   tmp_array = tmp_array - 273.15
                  #   esat = c[0]+tmp_array*(c[1]+tmp_array*(c[2]+tmp_array*(c[3]+tmp_array*(c[4]+tmp_array*(c[5]+tmp_array*(c[6]+tmp_array*(c[7]+tmp_array*c[8])))))))
                  #   ws = (0.622 * esat) / (tmp_level_mb * 100 - esat)
                  #   new_rh = spfh_array / ((1 - spfh_array) * ws) * 100
                  #   new_rh[new_rh < 0] = 0
                  #   try:
                  #      z2_rh[i].values = new_rh
                  #      grbout = open(temp_file,'wb')
                  #      grbout.write(z2_rh[i].tostring())
                  #      grbout.close()
                  #      if (os.path.isfile('%s' % new_file) and file_created is True):
                  #         cmd = 'wgrib2 %s | wgrib2 -i %s -append -GRIB %s' % (temp_file,temp_file,new_file)
                  #      else:
                  #         cmd = 'wgrib2 %s | wgrib2 -i %s -GRIB %s' % (temp_file,temp_file,new_file)
                  #         file_created = True
                  #      print(cmd)
                  #      os.system(cmd)
                  #      cmd = 'rm -f %s' % (temp_file)
                  #      print(cmd)
                  #      os.system(cmd)
                  #   except RuntimeError:
                  #      print('Error writing RH to grib file for level Z2')
               elif var == 'WIND':
                  cmd = 'wgrib2 %s -wind_speed %s -match "(UGRD|VGRD)"'  % (fcst_file,temp_file)
                  print(cmd)
                  os.system(cmd)
                  if (os.path.isfile('%s' % new_file) and file_created is True):
                     cmd = 'wgrib2 %s | wgrib2 -i %s -append -GRIB %s' % (temp_file,temp_file,new_file)
                  else:
                     cmd = 'wgrib2 %s | wgrib2 -i %s -GRIB %s' % (temp_file,temp_file,new_file)
                     file_created = True
                  print(cmd)
                  os.system(cmd)
                  cmd = 'rm -f %s' % (temp_file)
                  print(cmd)
                  os.system(cmd)
               else:
                  if (os.path.isfile('%s' % new_file) and file_created is True):
                     cmd = 'wgrib2 %s | egrep "(%s)" | wgrib2 -i %s -append -GRIB %s' % (fcst_file,var,fcst_file,new_file)
                  else:
                     cmd = 'wgrib2 %s | egrep "(%s)" | wgrib2 -i %s -GRIB %s' % (fcst_file,var,fcst_file,new_file)
                     file_created = True
                  print(cmd)
                  os.system(cmd)

            if (os.path.isfile('%s' % new_file)):
                print('%s file moved to %s/%s/%s' % (fcst_file,rt_dir,valid_dir,new_file))
            else:
                print('%s file missing' % (new_file))

        else:
            print('%s file missing' % (fcst_file))

####### main ##########

if __name__ == "__main__":
    main()
