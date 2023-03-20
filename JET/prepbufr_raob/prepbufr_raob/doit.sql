use soundings_pb;
select distinct site from RAOB_raob_soundings where time = '2022-09-26 00:00:00' order by site;
