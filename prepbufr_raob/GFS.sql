CREATE TABLE `GFS` (
  `wmoid` mediumint(8) unsigned NOT NULL COMMENT 'RAOB id',
  `date` date NOT NULL,
  `hour` tinyint(4) NOT NULL COMMENT 'hour of day',
  `fcst_len` smallint(6) NOT NULL COMMENT 'fcst length in hours',
  `press` smallint(5) unsigned NOT NULL COMMENT 'pressure in hPa',
  `z` smallint(5) unsigned NOT NULL COMMENT 'geopotential height in m',
  `t` mediumint(9) DEFAULT NULL COMMENT 'temperature in .01 C',
  `dp` mediumint(9) DEFAULT NULL COMMENT 'dewpoint in .01 C',
  `rh` tinyint(3) unsigned DEFAULT NULL COMMENT 'rh in percent',
  `rhot` tinyint(3) unsigned DEFAULT NULL COMMENT 'rh using observed T',
  `wd` smallint(5) unsigned DEFAULT NULL COMMENT 'wind direction, true',
  `ws` mediumint(8) unsigned DEFAULT NULL COMMENT 'wind speed, m/s',
  `version` tinyint(4) DEFAULT NULL,
  UNIQUE KEY `u` (`wmoid`,`date`,`hour`,`fcst_len`,`press`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1
/*!50100 PARTITION BY RANGE (to_days(date))
(PARTITION m202111 VALUES LESS THAN (738490) ENGINE = MyISAM,
 PARTITION m202112 VALUES LESS THAN (738521) ENGINE = MyISAM,
 PARTITION m202201 VALUES LESS THAN (738552) ENGINE = MyISAM,
 PARTITION m202202 VALUES LESS THAN (738580) ENGINE = MyISAM,
 PARTITION m202203 VALUES LESS THAN (738611) ENGINE = MyISAM,
 PARTITION m202204 VALUES LESS THAN (738641) ENGINE = MyISAM) */
