use ruc_ua_pb;
load data local infile 'ruc_ua_pb.metadata.txt'
replace into table metadata
fields terminated by ','
(wmoid,name,lat,lon,elev,descript);
