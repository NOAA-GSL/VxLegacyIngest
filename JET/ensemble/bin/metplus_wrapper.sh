#!/bin/sh --login

#setup environmnet for METplus
#source /apps/lmod/lmod/init/sh
module purge
module load intel/2022.1.2
module load intelpython/3.6.5
module load netcdf/4.6.1
module load hdf5/1.10.4
module load contrib
module load met/9.0
module load nco/4.1.0
module load wgrib2/0.2.0.1

export JLOGFILE=/mnt/lfs1/BMC/amb-verif/METplus_ensemble/METplus/logs/metplus_jlogfile
export PYTHONPATH=${METPLUS_PATH}/ush:${METPLUS_PATH}/parm
export PATH="${PATH}:${METPLUS_PATH}/ush"

${METPLUS_PATH}/ush/master_metplus.py -c ${METPLUS_CFG}