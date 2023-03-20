FC = ifort -c -heap-arrays -extend-source 132 -g -traceback
FL = ifort -heap-arrays -g
CC = gcc -c -ansi  -g

NETCDF = /apps/netcdf/3.6.3-intel
INCS = -I./ -I$(NETCDF)/include
LIBS = -L$(NETCDF)/lib -lnetcdf -lm

#define a rule for compiling .f files
.f.o:		
	${FC} $*.f $(INCS)
.c.o:
	${CC} $*.c $(INCS)

5:	verif5.o agrib.o agrib2.o  rotLL_geo.o
	$(FL) verif5.o agrib.o agrib2.o  rotLL_geo.o -o verif5.x $(INCS) $(LIBS)

backfill:	verif5_backfill.o agrib.o agrib2.o  rotLL_geo.o
	$(FL) verif5_backfill.o agrib.o agrib2.o  rotLL_geo.o -o verif5_backfill.x $(INCS) $(LIBS)

6:	verif5.o agrib.o agrib2.o  rotLL_geo.o
	$(FL) verif5.o agrib.o agrib2.o  rotLL_geo.o -o verif6.x $(INCS) $(LIBS)

retro:	verif_retro.o agrib.o agrib2.o  rotLL_geo.o
	$(FL) verif_retro.o agrib.o agrib2.o  rotLL_geo.o -o verif_retro.x $(INCS) $(LIBS)

rotLL:	verif_rotLL.o agrib.o rotLL_geo.o
	$(FL) verif_rotLL.o agrib.o rotLL_geo.o -o verif_rotLL.x $(INCS) $(LIBS)

new: 	verif_rotLL_new.o agrib.o rotLL_geo.o
	$(FL) verif_rotLL_new.o agrib.o rotLL_geo.o -o verif_rotLL_new.x $(INCS) $(LIBS)


gfs:	verif_gfs.o read_gfs_netcdf.o
	$(FL) verif_gfs.o read_gfs_netcdf.o -lm -o verif_gfs.x $(INCS) $(LIBS)

fim:	verif_fim.o read_gfs_netcdf.o
	$(FL) verif_fim.o read_gfs_netcdf.o -lm -o verif_fim.x $(INCS) $(LIBS)

