CC = gcc -ansi -c -g #-fnonstd -C -g 
CL = gcc -ansi -g #-fnonstd  -C -g 

# Replace this with the path to your netCDF installation. 
NETCDF_BASE = /usr/local/apps/netcdf

INCS = -I./ -I$(NETCDF_BASE)/include
LIBS = -L$(NETCDF_BASE)/lib -lnetcdf 


#define the rule for compiling .c files
.c.o:           
	${CC} $*.c $(INCS)

ncdump2:	ncdump2.o
	$(CL) ncdump2.o -lm -o ncdump2.x $(INCS) $(LIBS)

ncdump3:	ncdump3.o
	$(CL) ncdump3.o -lm -o ncdump3.x $(INCS) $(LIBS)

