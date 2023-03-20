import glob
import subprocess
from datetime import datetime as dt
from numpy import abs
from sys import exit
from os import system, path
import argparse

parser = argparse.ArgumentParser(description="Finds the nearest-in-time MRMS reflectivity file to the nominal time")
parser.add_argument('MRMS_dir',type=str)
parser.add_argument('target_time',type=str)
parser.add_argument('out_dir',type=str,metavar="out_directory")
args = parser.parse_args()

target_time = dt.strptime(args.target_time,"%Y%m%d%H%M")

results = subprocess.Popen("ls {}/*MRMS_MergedReflectivityQCComposite*".format(args.out_dir),shell=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
results = glob.glob(f"{args.out_dir}/*MRMS_MergedReflectivityQCComposite*")
print(results)
#stdout,stderr = results.communicate()
#print(stdout)
#print(stderr)

min_time_diff = 99999 # seconds
for file in results:
# for file in stdout.split():
   file_pieces = str(file).split('/')
   print(file_pieces)
   MRMS_file = file_pieces[9]
   MRMS_date_str = MRMS_file.split('.')[0]
   MRMS_date = dt.strptime(MRMS_date_str,"%Y%m%d-%H%M%S")
   time_diff = (MRMS_date - target_time).total_seconds()
   if abs(time_diff) < min_time_diff:
      min_time_diff = abs(time_diff)
      target_MRMS_file = str(MRMS_file)

print("The closest-in-time MRMS file to the target time is {}".format(target_MRMS_file))
time_str = dt.strftime(target_time,"%Y%m%d_%H%M")
out_file = "MRMS_compref_{}.grib2".format(time_str)
command = "cp -v {}/{} {}/{}".format(args.out_dir,target_MRMS_file,args.out_dir,out_file)
print("The Python command to run is {}".format(command))
#print(dt.strftime(dt.now(),"%Y%m%d %H%M%S"))
cmp_prs = system(command)
print("the result from the 'copy' command in the Python script is {}".format(cmp_prs))
#cmp_prs = subprocess.call(["cp","{}/{}".format(args.MRMS_dir,target_MRMS_file),"{}/{}".format(args.out_dir,out_file)])
