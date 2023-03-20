#! /contrib/miniconda3/4.5.12/bin/python3
#############################################################
#
# init_met_tc.py
#
# Initializes the MET TC ingest workflow for completed storms
#
# Script by Molly B Smith, 2021 Aug 3
#
############################################################

from datetime import datetime,timedelta
from pathlib import Path
import os
import sys
import glob

today_no_tz = datetime.utcnow()
today = datetime.strptime(today_no_tz.strftime("%Y%m%d%H") + "-+0000", "%Y%m%d%H-%z")
print("Running MET TC ingest init - ", today.strftime("%Y-%m-%d %HZ"))
year = today.strftime("%Y")
month = today.strftime("%m")
day = today.strftime("%d")
hour = today.strftime("%H")

adeck_dir = os.getenv('ADECK_DIR_ORIG')
bdeck_dir = os.getenv('BDECK_DIR_ORIG')
edeck_dir = os.getenv('EDECK_DIR_ORIG')

adeck_verif_dir = os.getenv('ADECK_DIR')
bdeck_verif_dir = os.getenv('BDECK_DIR')
edeck_verif_dir = os.getenv('EDECK_DIR')

metplus_conf_template_dir = os.getenv('CFGDIR') + "/metplus/backfill_auto_generated"
metplus_conf_template = os.getenv('CFGTMP')

script_dir = os.getenv('SCRIPT_DIR')

models = os.getenv('MODEL').split(' ')

all_storms = {}

print("Navigating to bdeck directory: ", bdeck_dir)
os.chdir(bdeck_dir)

for basin in ["al","ep","cp"]:
    all_storms[basin] = []
    print("========================================================")
    print("Getting list of storms in basin: ", basin, " for year: ", year)
    filematch = (bdeck_dir + "/*.b" + basin + "*" + year + ".dat")
    print("    Searching for bdeck files that match the string: ", filematch)
    all_files = glob.glob(filematch)
    print("    ", len(all_files), " files found. Parsing storm ids from them")
    for name in all_files:
        storm_id = name.split(".")[1][3:5]
        if storm_id not in all_storms[basin]:
            all_storms[basin].append(storm_id)
    all_storms[basin].sort()
    print(len(all_storms[basin]), " storms found for basin: ", basin, " and year: ", year, ". They are: ", all_storms[basin])
    
    print("========================================================")
    for storm in all_storms[basin]:
        print("Processing storm ", storm)
        filematch = (bdeck_dir + "/*.b" + basin + storm + year + ".dat")
        print("    Searching for bdeck files that match the string: ", filematch)
        all_files = glob.glob(filematch)
        all_files = sorted(all_files, key = lambda x:x.split('.')[0].split('/')[-1])
        print("    ", len(all_files), " files found. Parsing start and end dates from them")
        startdate_str = all_files[0].split('.')[0].split('/')[-1]
        enddate_str = all_files[-1].split('.')[0].split('/')[-1]
        enddate_str_rec = enddate_str
        print("    Start date is ", startdate_str, " end date is ", enddate_str)
        
        verif_adeck = "a" + basin + storm + year + ".dat"
        verif_bdeck = "b" + basin + storm + year + ".dat"
        verif_edeck = "e" + basin + storm + year + ".dat"
        
        enddate = datetime.strptime(enddate_str+"-+0000", "%Y%m%d%H-%z")
        if today < enddate + timedelta(days=1):
            print("    Storm end date is within 24 hours of now. Not processing yet.")
        elif os.path.isfile(bdeck_verif_dir + "/" + verif_bdeck):
            print("    Storm was already processed with ", bdeck_verif_dir + "/" + verif_bdeck, ". Skipping.")
            Path(bdeck_verif_dir + "/" + verif_bdeck).touch()
        else:
            print("    Storm end date is more than 24 hours ago. Processing.")
            print("        Copying final bdeck file to working dir: ", bdeck_verif_dir)
            os.system("cp " + bdeck_dir + "/" + enddate_str + "." + verif_bdeck + " " +  bdeck_verif_dir + "/" + verif_bdeck)
            
            print("        Determining final edeck file")
            filematch = (edeck_dir + "/*.e" + basin + storm + year + ".dat")
            all_files = glob.glob(filematch)
            all_files = sorted(all_files, key = lambda x:x.split('.')[0].split('/')[-1])
            enddate_str = all_files[-1].split('.')[0].split('/')[-1]
            print("        Final edeck file issued on ", enddate_str)
            print("        Copying final edeck file to working dir: ", edeck_verif_dir)
            os.system("cp " + edeck_dir + "/" + enddate_str + "." + verif_edeck + " " +  edeck_verif_dir + "/" + verif_edeck)
            
            for model in models:
                print("        Creating METplus template for ", basin, " storm ", storm, " model ", model)
                metplus_conf_file = metplus_conf_template + "_" + model + "_" + basin + storm + year + ".conf"
                os.system("cp " + metplus_conf_template_dir + "/" + metplus_conf_template + "template.conf" + " " + metplus_conf_template_dir + "/" + metplus_conf_file)
                fin = open(metplus_conf_template_dir + "/" + metplus_conf_file, "rt")
                fdata = fin.read()
                fdata = fdata.replace("REPLACE_WITH_STARTTIME", startdate_str)
                fdata = fdata.replace("REPLACE_WITH_ENDTIME", enddate_str_rec)
                fdata = fdata.replace("REPLACE_WITH_MODEL_LOWER", model.lower())
                fdata = fdata.replace("REPLACE_WITH_MODEL", model)
                fdata = fdata.replace("REPLACE_WITH_BASIN", basin.upper())
                fdata = fdata.replace("REPLACE_WITH_STORM_ID", storm)
                fin.close()
                fin = open(metplus_conf_template_dir + "/" + metplus_conf_file, "wt")
                fin.write(fdata)
                fin.close()
                
                print("        Submitting METplus job for ", basin, " storm ", storm, " model ", model)
                os.system(script_dir + "/metplus_wrapper_backfill.sh " + metplus_conf_template_dir + "/" + metplus_conf_file)
