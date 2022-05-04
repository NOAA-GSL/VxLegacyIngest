CC = gcc -ansi -c #-fnonstd -C -g 
CL = gcc -ansi #-fnonstd  -C -g 

OBJS = w3fb11.o w3fb12.o w3fb06.o w3fb07.c w3fb08.c w3fb09.c read_airports.o agrib.o

#define the rule for compiling .c files
.c.o:		
	${CC} $*.c $(INCS)

wrgsi_soundings.x:   $(OBJS) wrgsi_soundings.o 
	$(CL) $(OBJS) wrgsi_soundings.o -lm -o wrgsi_soundings.x

new_wrgsi:    $(OBJS) new_wrgsi_soundings.o
	$(CL) $(OBJS) new_wrgsi_soundings.o -lm -o new_wrgsi_soundings.x

test_wrgsi:    $(OBJS) new_wrgsi_soundings_test.o
	$(CL) $(OBJS) new_wrgsi_soundings_test.o -lm -o new_wrgsi_soundings_test.x

col_wgrib.x:	col_wgrib.o
	$(CL) col_wgrib.o -lm -o col_wgrib.x

iso:	$(OBJS) iso_wrgsi_soundings.o 
	$(CL) $(OBJS) iso_wrgsi_soundings.o -lm -o iso_wrgsi_soundings.x

test_iso:	$(OBJS) iso_wrgsi_soundings_test.o 
	$(CL) $(OBJS) iso_wrgsi_soundings_test.o -lm -o iso_wrgsi_soundings_test.x

global_iso:	$(OBJS) iso_wrgsi_soundings_global.o 
	$(CL) $(OBJS) iso_wrgsi_soundings_global.o -lm -o iso_wrgsi_soundings_global.x

rotLL:	$(OBJS) rotLL_soundings.o rotLL_geo.o 
	$(CL) $(OBJS) rotLL_soundings.o rotLL_geo.o -lm -o rotLL_soundings.x

rotLL_iso:	$(OBJS) rotLL_soundings_iso.o rotLL_geo.o 
	$(CL) $(OBJS) rotLL_soundings_iso.o rotLL_geo.o -lm -o rotLL_soundings_iso.x

fv3_soundings:	read_airports.o computeFV3Sounding.o fv3SoundingLib.o fv3_soundings.o
	$(CL) read_airports.o computeFV3Sounding.o fv3SoundingLib.o fv3_soundings.o -lm -o fv3_soundings_grib2.x

mymail:	mymail.o
	$(CL) mymail.o -lm -o mymail.x


