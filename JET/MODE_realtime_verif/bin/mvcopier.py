#!/usr/bin/env python
###################
#
# Name: mvcopier.py
#
# Description: script for copying MET load specs to Kirk's cron directory on Hera
#
###################

import commands
import filecmp
import fileinput
import re 
import os
import shutil
import socket 
import sys
import smtplib
import subprocess
import xml.etree.ElementTree as ET

from datetime import date, time, datetime, timedelta
from email.mime.base import MIMEBase
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText
from email.utils import COMMASPACE, formatdate
from email import encoders
from os import stat
from pwd import getpwuid

######################################################################
# Grab environmental variables

year = os.getenv("YEAR")
month = os.getenv("MONTH")
day = os.getenv("DAY")
valid_time = os.getenv("HOUR")

cycle = "%4d%02d%02d-%02d" % (int(year),int(month),int(day),int(valid_time)) 

python_path = os.getenv("PYTHON_PATH")
mvload_path = os.getenv("MVLOAD_PATH")
main_dir = os.getenv("MAIN_DIR")

model_list = os.getenv("MODEL_LIST")
model_list = model_list.split(" ")
model_list = "</val>\n      <val>".join(model_list)

data_types = os.getenv("DATA_TYPES")
data_types = data_types.split(" ")
data_types = "</val>\n      <val>".join(data_types)

cfg_dir = os.getenv("CFG_DIR")
cfg_file = os.getenv("CFG_XML")
cfg_xml = cfg_dir + "/" + cfg_file
case_cfg_xml = cfg_dir + "/case_mode_" + cfg_file

os.system("cp " + cfg_xml + " " + case_cfg_xml)
fin = open(case_cfg_xml, "rt")
fdata = fin.read()
fdata = fdata.replace("{main_dir}", main_dir)
fdata = fdata.replace("{cycle}", cycle)
fdata = fdata.replace("{model_list}", model_list)
fdata = fdata.replace("{data_types}", data_types)
fin.close()
fin = open(case_cfg_xml, "wt")
fin.write(fdata)
fin.close()

os.system(python_path + " " + mvload_path + " " + case_cfg_xml)
