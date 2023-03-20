CC = gcc -ansi -c #-m32 
CL = gcc -ansi #-m32

INCS = -I/usr/include/mysql
LIBS = -L/usr/lib64/mysql -lmysqlclient
#LIBS = /usr/lib64/mysql/libmysqlclient.so.15

OBJS = my_mysql_util.o w3fb06.o w3fb11.o w3fb08.o get_vis_stations.o write_vis.o


#define the rule for compiling .c files
.c.o:		
	${CC} $*.c $(INCS)

vis:	$(OBJS) vis_driver.o fill_vis_values.o  agrib_vis.o rotLL_geo.o
	$(CL) $(OBJS) vis_driver.o fill_vis_values.o agrib_vis.o rotLL_geo.o -lm -o vis.x $(INCS) $(LIBS)

