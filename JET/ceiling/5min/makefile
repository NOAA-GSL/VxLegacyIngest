CC = gcc -ansi -c #-m32 
CL = gcc -ansi #-m32

INCS = -I/usr/include/mysql
LIBS = -L/usr/lib64/mysql -lmysqlclient
#LIBS = /usr/lib64/mysql/libmysqlclient.so.15

OBJS = my_mysql_util.o w3fb06.o w3fb08.o w3fb11.o get_stations.o get_stations_retro.o write_ceils.o 


#define the rule for compiling .c files
.c.o:		
	${CC} $*.c $(INCS)

ceil:	$(OBJS) ceil_driver.o fill_ceil_values.o  agrib_ceil.o
	$(CL) $(OBJS) ceil_driver.o fill_ceil_values.o agrib_ceil.o -lm -o ceil.x $(INCS) $(LIBS)

ceil_test:	$(OBJS) ceil_driver.o fill_ceil_values.o  agrib_ceil.o
	$(CL) $(OBJS) ceil_driver.o fill_ceil_values.o agrib_ceil.o -lm -o ceil_test.x $(INCS) $(LIBS)

ceil_retro:	$(OBJS) ceil_driver_retro.o fill_ceil_values.o  agrib_ceil.o
	$(CL) $(OBJS) ceil_driver_retro.o fill_ceil_values.o agrib_ceil.o -lm -o ceil_retro.x $(INCS) $(LIBS)

ceil_rotLL:	$(OBJS) ceil_rotLL_driver.o fill_rotLL_ceil_values.o  agrib_ceil.o rotLL_geo.o
	$(CL) $(OBJS) ceil_rotLL_driver.o fill_rotLL_ceil_values.o agrib_ceil.o rotLL_geo.o -lm -o rotLL_ceil.x $(INCS) $(LIBS)

ceil_rotLL_retro:	$(OBJS) ceil_rotLL_driver_retro.o fill_rotLL_ceil_values.o  agrib_ceil.o rotLL_geo.o
	$(CL) $(OBJS) ceil_rotLL_driver_retro.o fill_rotLL_ceil_values.o agrib_ceil.o rotLL_geo.o -lm -o rotLL_ceil_retro.x $(INCS) $(LIBS)

col_wgrib.x:	col_wgrib.o
	$(CL) col_wgrib.o -lm -o col_wgrib.x
