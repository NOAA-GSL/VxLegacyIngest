#! /bin/sh -v

# Define the fortran compiler and options
 FC  =  gfortran
 CC  =  icc
 #FLAGS=  -g -traceback -ftz -O3 -no-wrap-margin
 FLAGS = -g -fbacktrace
#
 INCLD=  
 BASELIB = 
#LIBS =  /lfs4/HFIP/hfv3gfs/nwprod/hpc-stack/libs/intel-18.0.5.274/bufr/11.4.0/lib/libbufr_d_DA.a
 LIBS = /lfs4/BMC/amb-verif/mcginnis/bufr-install/lib64/libbufr_d.a 
#
OBJS = kinds.o module_time.o module_obs_base.o module_fix_raob_heights.o module_obs_conv_pt.o \
       module_prepbufr.o prepbufr2txt.o

all: prepbufr2txt

.SUFFIXES : .F90 .f90 .o

.F90.o :
	${FC} ${FLAGS} ${INCLD} -c $<

%.o:	%.f90
	${FC} ${FLAGS} ${INCLD} -c $<

prepbufr2txt:	${OBJS} 
	      ${FC} -o prepbufr2txt.ian.exe ${FLAGS} ${OBJS} ${LIBS} ${BASELIB}

 clean:
	rm -f *.o *.mod *.exe
