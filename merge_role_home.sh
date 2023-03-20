#!/bin/bash --login

# This script copies scripts, source, code, and makefiles for the amb-verif project
# Author: Jeff Hamilton GSL/ASCEND/VAB
# Initial version: 20230302

# Deploy or Save?

action=$1

if [ "$action" != "deploy" ] && [ "$action" != "save" ]; then
   echo "ERROR! Unknown argument passed. Please enter either deploy or save. Exiting"
   exit
fi

echo "########"
echo "Running $0 script to $action $HOME directory"
echo "########"
date=$(date '+%Y-%m-%d %H:%M:%S')
echo "Start Time: $date"

# Determine the machine we are working on (Jet and Hera only)

machine_name=$(hostname)

if [[ $machine_name == h* ]]; then
   machine="Hera"
elif [[ $machine_name == f* ]]; then
   machine="Jet"
   home_dir=/whome/$USER
   repo_dir=/lfs4/BMC/amb-verif/verif_repos/VxLegacyIngest/JET
else
   echo "ERROR! Unkown machine! Exiting"
   exit
fi

echo "HPC: Running on $machine"

# Array of all possible file suffixes to move

suffixes=("pl" "py" "c" "sh" "h" "tcsh" "java" "class" "f" "ncl" "f90" "xml")

# crontab and home directory configuration archive

echo "SECTION: crontab and home directory configuration"

if [ "$action" == "deploy" ]; then
   cp -uf $repo_dir/cron.save $home_dir/
   find -H $repo_dir -maxdepth 1 -name '.??*' -a \( -type d -o -type f \) -exec cp '{}' -R $home_dir \; 
elif [ "$action" == "save" ]; then
   cp -uf $home_dir/cron.save $repo_dir/.
   find -H $home_dir -maxdepth 1 -name '.??*' -a \( -type d -o -type f \) -exec cp '{}' -R $repo_dir \; 
fi

echo "Done"

# libraries and utilities

echo "SECTION: libraries and utilities"

dirs=("utilities" "java8" "intel" "MySQL-python-1.2.3" "metviewer" "netcdf-perl-1.2.3" "javalibs") 

for dir in "${dirs[@]}"
do
   echo "Working on $dir"
   if [ "$action" == "deploy" ]; then
      if [ ! -d "$repo_dir/$dir" ]; then
        echo "ERROR: $repo_dir/$dir does not exist! Not deploying"
      else
        cp -ruf $repo_dir/$dir $home_dir/$dir
      fi
   elif [ "$action" == "save" ]; then
      if [ ! -d "$home_dir/$dir" ]; then
        echo "ERROR: $home_dir/$dir does not exist! Not saving"
      else
        cp -ruf $home_dir/$dir $repo_dir/$dir
      fi
   fi  
done

echo "Done"

# prepbufr_raobs

echo "SECTION: prepbufr_raobs"

dir=prepbufr_raob

echo "Working on $dir"

if [ "$action" == "deploy" ]; then
   if [ ! -d "$repo_dir/$dir" ]; then
     echo "ERROR: $repo_dir/$dir does not exist! Not deploying"
   else
     cp -ruf $repo_dir/$dir $home_dir/$dir
   fi
elif [ "$action" == "save" ]; then
   if [ ! -d "$home_dir/$dir" ]; then
     echo "ERROR: $home_dir/$dir does not exist! Not saving"
   else
     cp -ruf $home_dir/$dir $repo_dir/$dir
   fi
fi

echo "Done"

# grid-to-obs

echo "SECTION: grid-to-obs"

dirs=("ptype2" "RR_uaverif" "ruc_madis_surface" "visibility" "ceiling" "acars_RR" "surfrad3" "surfrad" "ruc_uaverif" "acars_TAM" "vis_1min" "vis_5min" "ceiling/5min" "precip_mesonets2" "precip_mesonets" "precip_1min" "airnow" "mysql_backup" "acars_bias")


for dir in "${dirs[@]}"; do
   echo "Working on $dir"
   if [ "$action" == "deploy" ]; then
      if [ ! -d "$repo_dir/$dir" ]; then
        echo "ERROR: $repo_dir/$dir does not exist! Not deploying"
      else
        if [ ! -d "$home_dir/$dir" ]; then
           mkdir -p $home_dir/$dir
        fi
        if [ ! -d "$home_dir/$dir/beta" ] && [ -d "$repo_dir/$dir/beta" ]; then
           mkdir -p $home_dir/$dir/beta
        fi
        cp -ruf $repo_dir/$dir/*makefile* $home_dir/$dir/
        for suffix in "${suffixes[@]}"; do
           cp -ruf $repo_dir/$dir/*.$suffix $home_dir/$dir/
           cp -ruf $repo_dir/$dir/beta/*.$suffix $home_dir/$dir/beta/
        done
      fi
   elif [ "$action" == "save" ]; then
      if [ ! -d "$home_dir/$dir" ]; then
        echo "ERROR: $home_dir/$dir does not exist! Not saving"
      else
        if [ ! -d "$repo_dir/$dir" ]; then
           mkdir -p $repo_dir/$dir
        fi
        if [ ! -d "$repo_dir/$dir/beta" ] && [ -d "$home_dir/$dir/beta" ]; then
           mkdir -p $repo_dir/$dir/beta
        fi
        cp -ruf $home_dir/$dir/*makefile* $repo_dir/$dir/
        for suffix in "${suffixes[@]}"; do
           cp -ruf $home_dir/$dir/*.$suffix $repo_dir/$dir/
           cp -ruf $home_dir/$dir/beta/*.$suffix $repo_dir/$dir/beta/
        done
      fi
   fi
done

echo "Done"

# grid-to-grid

echo "SECTION: grid-to-grid"

dir=plot_fim

echo "Working on $dir"

if [ "$action" == "deploy" ]; then
   if [ ! -d "$repo_dir/$dir" ]; then
     echo "ERROR: $repo_dir/$dir does not exist! Not deploying"
   else
     for suffix in "${suffixes[@]}"; do
        cp -ruf $repo_dir/$dir/*.$suffix $home_dir/$dir/
     done
   fi
elif [ "$action" == "save" ]; then
   if [ ! -d "$home_dir/$dir" ]; then
     echo "ERROR: $home_dir/$dir does not exist! Not saving"
   else
     for suffix in "${suffixes[@]}"; do
        cp -ruf $home_dir/$dir/*.$suffix $repo_dir/$dir/
     done
   fi
fi

echo "Done"


dirs=("VERIF" "VERIF_2.0")

for dir in "${dirs[@]}"; do
   echo "Working on $dir"
   if [ "$action" == "deploy" ]; then
      if [ ! -d "$repo_dir/$dir" ]; then
        echo "ERROR: $repo_dir/$dir does not exist! Not deploying"
      else
        if [ ! -d "$home_dir/$dir" ]; then
           mkdir -p $home_dir/$dir
        fi
        if [ ! -d "$home_dir/$dir/exec" ] && [ -d "$repo_dir/$dir/exec" ]; then
           mkdir -p $home_dir/$dir/exec
        fi
        if [ ! -d "$home_dir/$dir/xml" ] && [ -d "$repo_dir/$dir/xml" ]; then
           mkdir -p $home_dir/$dir/xml
        fi
        if [ ! -d "$home_dir/$dir/bin" ] && [ -d "$repo_dir/$dir/bin" ]; then
           mkdir -p $home_dir/$dir/bin
        fi
        if [ ! -d "$home_dir/$dir/src" ] && [ -d "$repo_dir/$dir/src" ]; then
           mkdir -p $home_dir/$dir/src
        fi
        cp -ruf $repo_dir/$dir/*makefile* $home_dir/$dir/
        cp -ruf $repo_dir/$dir/exec/*makefile* $home_dir/$dir/exec/
        cp -ruf $repo_dir/$dir/exec/*Makefile* $home_dir/$dir/exec/
        cp -ruf $repo_dir/$dir/xml/submit* $home_dir/$dir/xml/
        for suffix in "${suffixes[@]}"; do
           cp -ruf $repo_dir/$dir/*.$suffix $home_dir/$dir/
           cp -ruf $repo_dir/$dir/xml/*.$suffix $home_dir/$dir/xml/
           cp -ruf $repo_dir/$dir/src/*.$suffix $home_dir/$dir/src/
           cp -ruf $repo_dir/$dir/src/*iplib* $home_dir/$dir/src/
           cp -ruf $repo_dir/$dir/bin/*.$suffix $home_dir/$dir/bin/
        done
      fi
   elif [ "$action" == "save" ]; then
      if [ ! -d "$home_dir/$dir" ]; then
        echo "ERROR: $home_dir/$dir does not exist! Not saving"
      else
        if [ ! -d "$repo_dir/$dir" ]; then
           mkdir -p $repo_dir/$dir
        fi
        if [ ! -d "$repo_dir/$dir/exec" ] && [ -d "$home_dir/$dir/exec" ]; then
           mkdir -p $repo_dir/$dir/exec
        fi
        if [ ! -d "$repo_dir/$dir/xml" ] && [ -d "$home_dir/$dir/xml" ]; then
           mkdir -p $repo_dir/$dir/xml
        fi
        if [ ! -d "$repo_dir/$dir/bin" ] && [ -d "$home_dir/$dir/bin" ]; then
           mkdir -p $repo_dir/$dir/bin
        fi
        if [ ! -d "$repo_dir/$dir/src" ] && [ -d "$home_dir/$dir/src" ]; then
           mkdir -p $repo_dir/$dir/src
        fi
        cp -ruf $home_dir/$dir/*makefile* $repo_dir/$dir/
        cp -ruf $home_dir/$dir/exec/*makefile* $repo_dir/$dir/exec/
        cp -ruf $home_dir/$dir/exec/*Makefile* $repo_dir/$dir/exec/
        cp -ruf $home_dir/$dir/xml/submit* $repo_dir/$dir/xml/
        for suffix in "${suffixes[@]}"; do
           cp -ruf $home_dir/$dir/*.$suffix $repo_dir/$dir/
           cp -ruf $home_dir/$dir/xml/*.$suffix $repo_dir/$dir/xml/
           cp -ruf $home_dir/$dir/src/*.$suffix $repo_dir/$dir/src/
           cp -ruf $home_dir/$dir/src/*iplib* $repo_dir/$dir/src/
           cp -ruf $home_dir/$dir/bin/*.$suffix $repo_dir/$dir/bin/
        done
      fi
   fi
done

echo "Done"

# METplus workflows

echo "SECTION: METplus worflows"

dirs=("MODE_realtime_verif" "tcmet" "GSL_verif-global" "ensemble")

for dir in "${dirs[@]}"; do
   echo "Working on $dir"
   if [ "$action" == "deploy" ]; then
      if [ ! -d "$repo_dir/$dir" ]; then
        echo "ERROR: $repo_dir/$dir does not exist! Not deploying"
      else
        if [ ! -d "$home_dir/$dir" ]; then
           mkdir -p $home_dir/$dir
        fi
        if [ ! -d "$home_dir/$dir/xml" ] && [ -d "$repo_dir/$dir/xml" ]; then
           mkdir -p $home_dir/$dir/xml
           mkdir -p $home_dir/$dir/xml/submit
           mkdir -p $home_dir/$dir/xml/retro
        fi
        if [ ! -d "$home_dir/$dir/bin" ] && [ -d "$repo_dir/$dir/bin" ]; then
           mkdir -p $home_dir/$dir/bin
        fi
        if [ ! -d "$home_dir/$dir/config" ] && [ -d "$repo_dir/$dir/config" ]; then
           mkdir -p $home_dir/$dir/config
        fi
        cp -ruf $repo_dir/$dir/config $home_dir/$dir/config
        cp -ruf $repo_dir/$dir/xml/submit $home_dir/$dir/config/submit
        cp -ruf $repo_dir/$dir/xml/retro $home_dir/$dir/config/retro
        for suffix in "${suffixes[@]}"; do
           cp -ruf $repo_dir/$dir/*.$suffix $home_dir/$dir/
           cp -ruf $repo_dir/$dir/xml/*.$suffix $home_dir/$dir/xml/
           cp -ruf $repo_dir/$dir/bin/*.$suffix $home_dir/$dir/bin/
        done
      fi
   elif [ "$action" == "save" ]; then
      if [ ! -d "$home_dir/$dir" ]; then
        echo "ERROR: $home_dir/$dir does not exist! Not saving"
      else
        if [ ! -d "$repo_dir/$dir" ]; then
           mkdir -p $repo_dir/$dir
        fi
        if [ ! -d "$repo_dir/$dir/xml" ] && [ -d "$home_dir/$dir/xml" ]; then
           mkdir -p $repo_dir/$dir/xml
           mkdir -p $repo_dir/$dir/xml/submit
           mkdir -p $repo_dir/$dir/xml/retro
        fi
        if [ ! -d "$repo_dir/$dir/bin" ] && [ -d "$home_dir/$dir/bin" ]; then
           mkdir -p $repo_dir/$dir/bin
        fi
        if [ ! -d "$repo_dir/$dir/config" ] && [ -d "$home_dir/$dir/config" ]; then
           mkdir -p $repo_dir/$dir/config
        fi
        cp -ruf $home_dir/$dir/config $repo_dir/$dir/config
        cp -ruf $home_dir/$dir/xml/submit $repo_dir/$dir/xml/submit
        cp -ruf $home_dir/$dir/xml/retro $repo_dir/$dir/xml/retro
        for suffix in "${suffixes[@]}"; do
           cp -ruf $home_dir/$dir/*.$suffix $repo_dir/$dir/
           cp -ruf $home_dir/$dir/xml/*.$suffix $repo_dir/$dir/xml/
           cp -ruf $home_dir/$dir/bin/*.$suffix $repo_dir/$dir/bin/
        done
      fi
   fi
done

echo "Done"

echo "########"
echo "$HOME $action COMPLETE!"
date=$(date '+%Y-%m-%d %H:%M:%S')
echo "End Time: $date"
