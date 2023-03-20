#! /bin/sh -v

 GSILIB=/lfs1/BMC/wrfruc/mhu/rapcode/gsi/build/lib
# BASEBUILD=/mnt/lfs1/projects/wrfruc/mhu/rapcode/util/GSD_UTL/tools/baselib/build
 BASEBUILD=/lfs4/BMC/amb-verif/prepbufr_raob/GSD_UTL/tools/baselib/build
 BASEINC = ${BASEBUILD}/src

# Define the fortran compiler and options
 FC  =  ifort
 CC  =  icc
 FLAGS=  -g -traceback -ftz -O3
#
 INCLD=   -I${BASEINC}
 LIBS =   -L${GSILIB} -lbufr_v
 BASELIB = ${BASEBUILD}/lib/libbase.a

#
OBJS = kinds.o module_obs_base.o module_obs_conv_pt.o \
       module_prepbufr.o prepbufr2txt.o

all: prepbufr2txt

prepbufr2txt: ${OBJS}
	${FC} -o prepbufr2txt.exe ${FLAGS} ${OBJS} ${LIBS} ${BASELIB}

.SUFFIXES : .F90 .f90 .o

.F90.o :
	${FC} ${FLAGS} ${INCLD} -c $<

.f90.o :
	${FC} ${FLAGS} ${INCLD} -c $<

clean:
	rm -f *.o *.mod *.exe
