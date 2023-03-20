CC = gcc -ansi -c #-fnonstd -C -g 
CL = gcc -ansi #-fnonstd  -C -g 

#define the rule for compiling .c files
.c.o:		
	${CC} $*.c $(INCS)

agrib_soundings.x:        agrib_soundings.o w3fb11.o w3fb12.o  agrib.o read_airports.o
	$(CL) agrib_soundings.o w3fb11.o w3fb12.o agrib.o read_airports.o -lm -o agrib_soundings.x

col_wgrib.x:	col_wgrib.o
	$(CL) col_wgrib.o -lm -o col_wgrib.x

iso:	iso_agrib_soundings.o w3fb11.o w3fb12.o  agrib.o read_airports.o
	$(CL) iso_agrib_soundings.o w3fb11.o w3fb12.o agrib.o read_airports.o -lm -o iso_agrib_soundings.x

iso2:	iso_agrib2_soundings.o w3fb11.o w3fb12.o  read_airports.o
	$(CL) iso_agrib2_soundings.o w3fb11.o w3fb12.o read_airports.o -lm -o iso_agrib2_soundings.x

