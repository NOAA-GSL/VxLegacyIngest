# PrepBUFR RAOB

The PrepBUFR RAOB code extracts radiosonde observations from NCEP PrepBUFR/BUFR files.

## What's PrepBUFR/BUFR?

BUFR is a format maintained by the World Meteorlogical Organization. (WMO) PrepBUFR was devised by NOAA's NCEP to indicate a BUFR file that contains observational data which has been "Prepared" or quality controlled. (At least per [Guoqing Ge, et al, 2017](https://dtcenter.ucar.edu/com-GSI/users/docs/presentations/2017_tutorial/D2-L09_GSI_Fundamentals5_BUFR_Ge.pdf)) Both formats can be decoded using NCEP's "bufrlib"

## Code Structure

According to the crontab on Jet, the entrypoints for prepBUFR RAOB are `do_prepbufr_raobs.pl`, `gen_persis.pl`, and `agen_raob_sites.pl`.

They call out to other scripts as follows:

### `do_prepbufr_raobs2.pl`

This script handles parsing the PrepBUFR RAOB files and loading them into the MySQL/MariaDB database.

Calls out to:

* `get_prepbufr_raobs2.py`
  * `prepbufr2txt.ian.exe` (fortran - in the `compile2/` subdir (see the makefile therein), with links to the BUFR lib (libbufr) -- see below) -- to pull RAOBs from prepBUFR files into a text file, which get_prepbufr_raobs2.py puts into the soundings_pb database.  You can ignore the 'compile/' subdirectory; it's no longer used.
* `get_cal_secs.py`
* `Verify3.java` -- Takes the pbRAOBs in the soundings_pb database, generates interpolated RAOB soundings and stores them in the ruc_ua_pb database. This is NOT the same as Verify3.java in the verification done using Mark Govett's RAOBs. This code is shared by the jobs that load the models. Verify3.java uses other java code, including code possibly in the subdirectories 'lib' and 'sdg'.
* `update_metadata2.py`-- compares the pbRAOBs to Mark Govett's RAOBs. Useful for comparing the two kinds of RAOBs, but probably not useful once we lay down Mark's RAOBs.

Requires:
* namelist.{prepbufr_type}.template, where {prepbufr_type} is one of 'gfs' or 'gdas'. We use the latter in our production processing.

### `gen_persis.pl`

not needed for ingest of pbRAOBS, but since this involves only RAOB data, it should probably be factored into the RAOB load section. It generates persistence forecasts. Unrelated to `do_prepbufr_raobs2.pl`. Generates the ["persistence"](https://forecast.weather.gov/glossary.php?word=persistence%20forecast) variables for comparison to the developmental model.

Calls out to:

* `get_RR_file.pl`
* `jy2mdy.pl`
* `get_grid.pl`
* `VerifyPersis.java` 
* 'SumUpdaterPersis.java'
* 'SoundingLoader3.java'
* (and possibly other java code in lib/ and sdg/ subdirectories.)

### `agen_raob_sites.pl`

NOT NEEDED for ingest of pbRAOBs. This scripts matches the various models with the PrepBUFR RAOB observations.

Calls out to:

* `set_connection.pl`
* `get_RR_file.pl`
* `jy2mdy.pl`
* `get_grid.pl`
* `create_raob_file.pl`
* `new_wrgsi_soundings.x`
* `iso_wrgsi_soundings.x`
* `rotLL_soundings_iso.x`
* `rotLL_soundings.x`
* `iso_wrgsi_soundings_global.x`
* `Verify3.java`

These appear to call out to various other shell, perl, python, Java, C, and fortran executables in the repo. They all also use `mysql-connector-java-5.1.6-bin.jar`.

Main makefile for prepBUFR RAOB fortran code is in `prepbufr_raob/compile2/makefile`. `prepbufr_raob/makefile` targets the C/C++ in the `prepbufr_raob/` directory.

## Getting started

The java code here is compiled with `javac *.java`. The fortran in `.../compile2` should be compilable with the included `makefile`. You may need to update it based on the location you put the libbufr dependency. More on libbufr in [the dependencies section below](#dependencies). Otherwise, for the C dependencies, you should be able to reference the makefile in this directory.

## Dependencies

To recompile libbufr for prepbufr_raob you can do the following on Jet. Note you will want to be logged in as your personal user and not as `amb-verif`.

Load the HPC modules according to the [HPC-Stack docs](https://github.com/NOAA-EMC/hpc-stack/wiki/Official-Installations) for the system you're on. The below instructions are for Jet.

```console
# Create a space to compile libbufr
mkdir -p /lfs4/BMC/amb-verif/`whoami`/ && cd /lfs4/BMC/amb-verif/`whoami`/
# Activate the HPC Stack
module use /lfs4/HFIP/hfv3gfs/nwprod/hpc-stack/libs/modulefiles/stack
# Load a recent version of the HPC stack
module load hpc/1.2.0
# Load a recent compiler
module load intel/2022.1.2
# Load a recent version of cmake
module load cmake/3.20.1
# checkout code at the needed tag, configure and build
git clone --branch bufr_v11.7.0 https://github.com/NOAA-EMC/NCEPLIBS-bufr.git
mkdir bufr-{build,install}
cd bufr-build
# Configure the build and make sure the compiler is picked up
# You may need to use the full path in -DCMAKE_INSTALL_PREFIX instead of pwd to get the correct path
CC=`which icc` FC=`which ifort` cmake -DCMAKE_INSTALL_PREFIX=`pwd`/../bufr-install -DENABLE_TESTS=OFF ../NCEPLIBS-bufr/
make -j4
ctest # This probably won't work on Jet
make install
```

And there should be a libbufr located at `/home/path/to/bufr-install/usr/local/lib64/libbufr_d.a`.

Note - the initial `cmake` configuration should attempt to download a `bufr` test data file and fail. It will give you a message that it won't build the tests. This is desirable as Jet can't download the EMC test data file. (See - [NOAA-EMC/NCEPLIBS-bufr#150 (comment)](https://github.com/NOAA-EMC/NCEPLIBS-bufr/issues/150#issuecomment-900458971)) If this process errors out, I've had better luck building in `/lfs4` as my user than as the amb-verif user for some reason.
