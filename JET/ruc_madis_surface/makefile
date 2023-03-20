CC = gcc -ansi -c #-m32 
CL = gcc -ansi #-m32

INCS = -I/usr/include/mysql
LIBS = -L/usr/lib64/mysql -lmysqlclient

OBJS = my_mysql_util.o agrib.o w3fb11.o  w3fb06.o w3fb08.o

#define the rule for compiling .c files
.c.o:		
	${CC} $*.c $(INCS)

RUC:	$(OBJS) agrib_madis_sites.o fill_ruc_values.o write_stations5.o get_stations.o 
	$(CL) $(OBJS) agrib_madis_sites.o fill_ruc_values.o write_stations5.o get_stations.o -lm -o agrib_madis_sites.x $(INCS) $(LIBS)

RUCq:	$(OBJS) agrib_madis_sites_q.o fill_ruc_values_q.o write_stations5q.o get_stations_q.o 
	$(CL) $(OBJS) agrib_madis_sites_q.o fill_ruc_values_q.o write_stations5q.o get_stations_q.o -lm -o agrib_madis_sites_q.x $(INCS) $(LIBS)

col_wgrib.x:	col_wgrib.o
	$(CL) col_wgrib.o -lm -o col_wgrib.x

#q:	$(OBJS) HRRR_driver_q.o fill_surface_values_q.o  fill_surface_values_q_polar.o fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o 
#	$(CL) $(OBJS) HRRR_driver_q.o fill_surface_values_q.o  fill_surface_values_q_polar.o fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o -lm -o surface_HRRR_q.x $(INCS) $(LIBS)

sta_test:	$(OBJS) HRRR_driver_q_station_test.o fill_surface_values_q_all_station_test.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q_test.o 
	$(CL) $(OBJS) HRRR_driver_q_station_test.o fill_surface_values_q_all_station_test.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q_test.o -lm -o surface_HRRR_q_station_test.x $(INCS) $(LIBS)

q:	$(OBJS) HRRR_driver_q.o fill_surface_values_q_all.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o 
	$(CL) $(OBJS) HRRR_driver_q.o fill_surface_values_q_all.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o -lm -o surface_HRRR_q.x $(INCS) $(LIBS)

test:	$(OBJS) HRRR_driver_q.o fill_surface_values_q_all_test.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o 
	$(CL) $(OBJS) HRRR_driver_q.o fill_surface_values_q_all_test.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o -lm -o surface_HRRR_q_test.x $(INCS) $(LIBS)

smartinit:	$(OBJS) HRRR_driver_q.o fill_surface_values_q_all_smartinit.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o 
	$(CL) $(OBJS) HRRR_driver_q.o fill_surface_values_q_all_smartinit.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o -lm -o surface_smartinit_q.x $(INCS) $(LIBS)

5:	$(OBJS) HRRR_driver5.o fill_surface_values5.o write_stations_old.o rotLL_geo.o get_stations.o 
	$(CL) $(OBJS) HRRR_driver5.o fill_surface_values5.o write_stations_old.o rotLL_geo.o get_stations.o -lm -o surface_HRRR5.x $(INCS) $(LIBS)

#retro:	$(OBJS) WRF_retro_driver5.o fill_surface_values5.o write_stations_old.o rotLL_geo.o get_stations_retro.o 
#	$(CL) $(OBJS) WRF_retro_driver5.o fill_surface_values5.o write_stations_old.o rotLL_geo.o get_stations_retro.o -lm -o WRF_retro.x $(INCS) $(LIBS)
#retro:	$(OBJS) WRF_retro_driver5.o fill_surface_values5.o write_stations_files.o rotLL_geo.o get_stations_retro.o 
#	$(CL) $(OBJS) WRF_retro_driver5.o fill_surface_values5.o write_stations_files.o rotLL_geo.o get_stations_retro.o -lm -o WRF_retro.x $(INCS) $(LIBS)

retro:	$(OBJS) WRF_retro_driver5.o fill_surface_values_q_all.o write_stations_files.o rotLL_geo.o get_stations_retro.o 
	$(CL) $(OBJS) WRF_retro_driver5.o fill_surface_values_q_all.o write_stations_files.o rotLL_geo.o get_stations_retro.o -lm -o WRF_retro.x $(INCS) $(LIBS)

update:	$(OBJS) HRRR_driver_update.o fill_surface_values5.o write_stations_update.o rotLL_geo.o get_stations.o 
	$(CL) $(OBJS) HRRR_driver_update.o fill_surface_values5.o write_stations_update.o rotLL_geo.o get_stations.o -lm -o surface_HRRR_update.x $(INCS) $(LIBS)

#fim:	$(OBJS) FIM_driver_q.o fill_surface_values_q_fim.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o 
#	$(CL) $(OBJS) FIM_driver_q.o fill_surface_values_q_fim.o  fill_GLMP_surface_values.o write_stations5q.o rotLL_geo.o get_stations_q.o -lm -o surface_fim_q.x $(INCS) $(LIBS)
