#!/bin/sh --login

#setup environmnet for METplus
#source /apps/lmod/lmod/init/sh
module use -a ${EXEC_DIR}
module purge
module load intel/2022.1.2
module load intelpython/3.6.5
module load netcdf/4.6.1
module load hdf5/1.10.4
module load contrib
module load nco/4.9.1
module load wgrib2/2.0.8
module use /contrib/met/modulefiles
module load met/10.0.0

export JLOGFILE=${WF_LOG_DIR}/metplus_jlogfile
export PYTHONPATH=${METPLUS_PATH}/ush:${METPLUS_PATH}/parm
export PATH="${PATH}:${METPLUS_PATH}/ush"

${METPLUS_PATH}/ush/run_metplus.py -c ${METPLUS_CFG}
