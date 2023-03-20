use soundings;
load data local infile 'tmp/mysql_202111010000.tmp'
replace into table hypsometric_summary
fields terminated by ',' 
lines terminated by ',\n'
(wmoid,time,
mean_h_diff_500,  max_h_diff_500,  n_h_diff_500,  n_added_500,
mean_h_diff,  max_h_diff,  n_h_diff,  n_added);
