CREATE TABLE `bad_winds` (
 valid_time int(11) NOT NULL COMMENT 'VALID time secs since 1/1/70',
 wmoid mediumint(8) unsigned NOT NULL DEFAULT '0',
 press mediumint not null comment 'pressure in mb',
 dir smallint not null comment 'wind direction, true',
 spd smallint not null comment 'wind speed in kts',
 unique key u (valid_time,wmoid)
 ) ENGINE=MyISAM DEFAULT CHARSET=latin1
 ;
 
