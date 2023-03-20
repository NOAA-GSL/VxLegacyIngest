CREATE TABLE `hypsometric_summary` (
  `wmoid` varchar(10) NOT NULL COMMENT 'WMOID for each RAOB site',
  `time` int NOT NULL COMMENT 'VALID time secs since 1/1/70',
  mean_h_diff_500 int not null comment 'avg h diff below 500 mb between reported and integrated height (m*10)',
  max_h_diff_500 int not null comment 'max h diff below 500 mb between reported and integrated height (m*10)',
  n_h_diff_500 int not null comment 'number of heights changed below 500 mb',
  n_added_500 int not null comment 'number of heights added below 500 mb (that were previously missing)',
  mean_h_diff int not null comment 'avg h diff between reported and integrated height (m*10)',
  max_h_diff int not null comment 'max h diff between reported and integrated height (m*10)',
  n_h_diff int not null comment 'number of heights changed',
  n_added int not null comment 'number of heights added (that were previously missing)',
  UNIQUE KEY `u` (`wmoid`,`time`),
  KEY `time` (`time`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1
;

