#!/bin/sh --login

#setup environmnet for METplus
#source /apps/lmod/lmod/init/sh
module purge
module load intel/2022.1.2
module load intelpython/3.6.5
module load netcdf/4.6.1
module load hdf5/1.10.4
module load nco/4.9.1
module load wgrib/1.8.1.0b
module load wgrib2/2.0.8
module load R/4.0.2
module load contrib
module use /contrib/met/modulefiles
module load met/9.1
module use /contrib/met/METplus/modulefiles
module load metplus/3.1.1

export JLOGFILE=/mnt/lfs1/BMC/amb-verif/tcmet/output/logs/metplus_jlogfile
export PYTHONPATH=${METPLUS_PATH}/ush:${METPLUS_PATH}/parm
export PATH="${PATH}:${METPLUS_PATH}/ush"

${METPLUS_PATH}/ush/master_metplus.py -c ${METPLUS_CFG1} -c ${METPLUS_CFG2}
