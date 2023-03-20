##############################################################################
#									     #
# FSL/FRD wide "$HOME/.cshrc" file					     #
# Updated 12/02/97 -- DSB						     #
#									     #
##############################################################################
#									     #
# PLEASE NOTE:								     #
#									     #
#	This new "~/.cshrc" file is designed to incorporate and/or do	     #
#	  everything your old "~/.cshrc", "~/.cshrc.additions" and	     #
#	  "~/.alias" files did.  However, please take note of the following: #
#									     #
#	Aliases CAN BE included in here or supplied in ".alias" if you	     #
#	  already have this file and would like to continue using it.	     #
#									     #
#	Additions to "~/.cshrc" such as variables, limits, etc, CAN BE	     #
#	  included in here or supplied in "~/.cshrc.additions" if you	     #
#	  already  have this file and would like to continue using it.	     #
#									     #
#	Both files ( "~/.alias" and "~/.cshrc.additions" ) get sourced	     #
#	  AUTOMATICALLY from the master "Cshrc" file IF they exist AND PRIOR #
#	  TO any changes or additions made in THIS file.		     #
#									     #
#	The file "/usr/local/share/lib/login/Cshrc" is sourced at the	     #
#	  begining of this file to allow your Systems Administrator to	     #
#	  add/edit FRD-wide shell settings without you having to add/edit    #
#	  them yourself.						     #
#									     #
# ALSO NOTE:								     #
#									     #
#	Use your "~/.login" file for initiallizing remote terminals and for  #
#	  all environment variables rather than setting them here.  Your     #
#	  "~/.login" file is read only once when you initially log in, not   #
#	  for subsequent shells and you only need to set environment	     #
#	  variables once.						     #
#									     #
##############################################################################
##############################################################################
#									     #
# WARNING:								     #
# --------								     #
# DO NOT CHANGE ANY OF THESE NEXT FEW ITEMS UNLESS YOU ARE WILLING TO	     #
# TAKE CARE OF THESE SETTINGS IN YOUR OWN LOGIN ENVIRONMENT!		     #
#									     #
##############################################################################

if ($?OSNAME == 0) then
        setenv OSNAME `uname -s`
        setenv OSREL `uname -r`
endif

if (-f /usr/local/lib/login/localpath.csh) then
        source /usr/local/lib/login/localpath.csh
else
        set localpath=''
endif

if (-f /usr/local/lib/login/cshrc.csh) then
        source /usr/local/lib/login/cshrc.csh
endif
#____________________________________________________________________________#
# ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^#
# DO _NOT_ CHANGE ANYTHING ABOVE THIS LINE				     #
#----------------------------------------------------------------------------#
# YOU _MAY_ CHANGE OR ADD ANYTHING BELOW THIS LINE EXCEPT WHERE NOTED	     #
# v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v#
#____________________________________________________________________________#

#
# Setup your path variable here.  Add to your path by modifying "mypath" below.
# Example: set mypath = ( $HOME/foo/bin /usr/local/foo/bin )
#
#module load newdefaults
module purge
module load intel/2022.1.2
module load ncl/6.6.2
module load szip/2.1
module load hdf5/1.8.9
module load netcdf/4.2.1.1
module load wgrib2/0.1.9.6a
#module use /lfs1/projects/dtc-hurr/MET/MET_releases/modulefiles
#module load met/6.1
#module load mvapich2

#set mypath = (/lfs1/projects/fim/whitaker/bin /home/whitaker/bin /opt/xxdiff/3.2/bin /opt/grads/2.0.a2/bin /usr/local/esrl/bin $HOME/utilities /opt/netcdf/3.6.3-lahey/bin $NCARG_ROOT/bin /opt/java/jdk1.6.0_04/bin /usr/bsd /usr/local/bin /bin )


#set mypath = (/lfs1/projects/fim/whitaker/bin /home/whitaker/bin /opt/xxdiff/3.2/bin /opt/grads/2.0.a2/bin /usr/local/esrl/bin $HOME/utilities $NETCDF/bin $NCARG_ROOT/bin /opt/java/jdk1.6.0_04/bin /usr/bsd /usr/local/bin /bin )

set mypath = (/opt/xxdiff/3.2/bin /opt/grads/2.0.a2/bin /usr/local/esrl/bin $HOME/utilities $NETCDF/bin $NCARG_ROOT/bin /opt/java/jdk1.6.0_04/bin /usr/bsd /usr/local/bin /bin /usr/bin .)

##############################################
# DO NOT CHANGE - USE "mypath" SETTING ABOVE #
set path = ( $mypath $path )		     #
##############################################

#
# Add to or modify this section for your favorite tcsh settings
#

#####
##### Set python environment
#####
##### This must be done after setting the genric paths listed above, otherwise the environment
##### gets confused and references the generic /bin/python installation by mistake.
##### This results in the proper packages not being found (MySQLdb, pygrib, etc.)
##### - Hamilton 6/5/20 
#####
#setenv PATH /contrib/miniconda3/4.5.12/envs/avid_verify/bin:/contrib/miniconda3/4.5.12/bin:${PATH}
module use -a /contrib/miniconda3/modulefiles
#bash /contrib/miniconda3/4.5.12/etc/profile.d/conda.sh
module load miniconda3/4.5.12
#conda activate
conda activate avid_verify
#####
#####


source ~/.alias

##### Old, but keeping around for reference. - Hamilton
#
#setenv PYTHONHOME /lfs1/projects/amb-verif/anaconda/bin/python
#setenv PYTHONPATH /lfs1/projects/amb-verif/anaconda/
#setenv PYTHONHOME /usr/bin/python
#setenv PYTHONPATH /usr/lib64/python2.7/
#setenv PYTHONPATH ${PYTHONPATH}:/lfs3/projects/amb-verif/anaconda/lib64/python/
#setenv PYTHONPATH /lfs1/projects/amb-verif/anaconda/pkgs
#setenv PYTHONPATH /lfs1/projects/amb-verif/anaconda/pkgs/proj4-5.0.1-h14c3975_0/lib/
#setenv PYTHONPATH ${PYTHONPATH}:/lfs1/projects/amb-verif/anaconda/pkgs/eccodes-2.8.2-ha8b302a_0/lib/
#setenv PYTHONPATH ${PYTHONPATH}:/lfs1/projects/amb-verif/anaconda/pkgs/pygrib-2.0.3-py27h5688137_0/lib/python2.7/site-packages/
##setenv PYTHONPATH /lfs4/BMC/amb-verif/anaconda/pkgs/proj4-5.0.1-h14c3975_0/lib/
##setenv PYTHONPATH ${PYTHONPATH}:/lfs4/BMC/amb-verif/anaconda/pkgs/eccodes-2.8.2-ha8b302a_0/lib/
##setenv PYTHONPATH ${PYTHONPATH}:/lfs4/BMC/amb-verif/anaconda/pkgs/pygrib-2.0.3-py27h5688137_0/lib/python2.7/site-packages/
#setenv PYTHONPATH ${PYTHONPATH}:/usr/lib/python2.7/site-packages/
##setenv PYTHONHOME /contrib/miniconda3/4.5.12/envs/avid_verify/bin/python
#####

if ( $?tcsh ) then
    set history= ( 1000 "%h %W/%D/%Y %T %R\n" )
   if($USER == "moninger" ) then
        set prompt="%B%h %{\033[1;34m%}%n%{\033[1;39m%}@%m:%~%#%b ";
    else
       set prompt="%B%h %{\033[1;31m%}%n%{\033[1;39m%}@%m:%~%#%b ";
    endif 
	
	setenv LESS "-e -m -s"
#	mesg -y
	setenv PRINTER bugs_2  #prints both ascii and postscript

# The following sets line editing behaviour to vi emulation.
# Change to "bindkey -e" for emacs emulation instead.

	bindkey -e

endif

setenv XAPPLRESDIR ~/app-defaults # added 29-Nov-2011 WRM
set savehist=
#setenv GRIB_DEFINITION_PATH /lfs1/projects/fim/whitaker/share/grib_api/definitions/
#setenv GRIB_DEFINITION_PATH /lfs3/projects/amb-verif/anaconda/python/grib_api-1.11.0/definitions/
#setenv GRIB_DEFINITION_PATH /mnt/lfs3/projects/nrtrr/HRRR_TLE/apps/grib_api/1.13.1/share/grib_api/definitions
#setenv PYTHONPATH /lfs3/projects/nrtrr/HRRR_TLE/apps/anaconda/lib/python2.7/:/lfs3/projects/amb-verif/anaconda/lib64/python/
#set firstentry=`echo $LD_LIBRARY_PATH | cut -f1 -d":"`
#if ($firstentry != '/lfs3/projects/nrtrr/HRRR_TLE/apps/anaconda/lib/') then
#   setenv LD_LIBRARY_PATH "/lfs3/projects/nrtrr/HRRR_TLE/apps/anaconda/lib/:${LD_LIBRARY_PATH}"
#endif

setenv CC icc
setenv FC ifort
setenv ESMF_DIR /whome/amb-verif/LVT/esmf
setenv ESMF_COMM mpiuni
setenv ESMF_COMPILER intel
setenv ESMF_INSTALL_PREFIX /whome/amb-verif/LVT/esmf

setenv LVT_ARCH linux_ifc
setenv LVT_SRC /whome/amb-verif/LVT/src
setenv LVT_FC ifort
setenv LVT_CC icc
setenv LVT_GRIBAPI /lfs3/BMC/nrtrr/amb-verif/grib_api_dir
#setenv LD_LIBRARY_PATH "/apps/szip/2.1/lib:${LVT_GRIBAPI}/lib:${LD_LIBRARY_PATH}"
setenv LVT_HDF4 /apps/hdf4/4.2.7-intel
setenv LVT_HDF5 /apps/hdf5/1.8.9-intel
#setenv LVT_HDF5 /lfs1/projects/dtc-hurr/MET/MET_releases/external_libs/
#setenv LVT_HDFEOS /scratch4/NCEPDEV/land/noscrub/James.V.Geiger/lib/hdfeos2/2.19v1.00_intel-15.1.133
setenv LVT_JASPER /lfs3/BMC/nrtrr/amb-verif/jasper
setenv LVT_LIBESMF /whome/amb-verif/LVT/esmf/lib/libO/Linux.intel.64.mpiuni.default
setenv LVT_MODESMF /whome/amb-verif/LVT/esmf/mod/modO/Linux.intel.64.mpiuni.default
setenv LVT_NETCDF /apps/netcdf/4.2.1.1-intel

##setenv LD_LIBRARY_PATH "/usr/lib64/mysql:${LD_LIBRARY_PATH}:/lfs4/BMC/amb-verif/anaconda/lib"
setenv LD_LIBRARY_PATH "/usr/lib64/mysql:${LD_LIBRARY_PATH}"
#setenv CLASSPATH "${CLASSPATH}:."