CREATE TABLE `Template_Areg0` (
  `date` date NOT NULL DEFAULT '0000-00-00',
  `hour` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `fcst_len` mediumint(9) NOT NULL DEFAULT '0',
  `mb10` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `N_dt` smallint(5) unsigned NOT NULL DEFAULT '0',
  `sum_ob_t` float DEFAULT NULL COMMENT 'ob, in celsius',
  `sum_dt` float DEFAULT NULL COMMENT 'ob minus model, in celsius',
  `sum2_dt` float DEFAULT NULL COMMENT 'in celsius**2',
  `N_dw` smallint(6) NOT NULL DEFAULT '0',
  `sum_ob_ws` float DEFAULT NULL COMMENT 'ob wind speed, in m/s',
  `sum_model_ws` float DEFAULT NULL COMMENT 'model wind speed, in m/s',
  `sum_du` float DEFAULT NULL COMMENT 'u comp of vect. wind diff., ob minus model, in m/s',
  `sum_dv` float DEFAULT NULL COMMENT 'v component',
  `sum2_dw` float DEFAULT NULL COMMENT 'sum of squares of vector wind diff., in (m/s)**2',
  `N_dR` smallint(6) NOT NULL DEFAULT '0',
  `sum_ob_R` float DEFAULT NULL COMMENT 'ob RH, in celsius',
  `sum_dR` float DEFAULT NULL COMMENT '(ob minus model) RH, in percent',
  `sum2_dR` float DEFAULT NULL COMMENT 'RH**2 in %**2',
  `N_dRoT` smallint(6) DEFAULT NULL COMMENT 'N RH wrt observed T, in percent',
  `sum_dRoT` float DEFAULT NULL COMMENT 'sum RH wrt observed T, in percent',
  `sum2_dRoT` float DEFAULT NULL COMMENT 'sum squared RH wrt obs. T, in percent',
   `N_dH` smallint(6) NOT NULL DEFAULT '0',
  `sum_dH` float DEFAULT NULL comment 'ob minus model, in meters',
  `sum2_dH` float DEFAULT NULL comment 'in meters**2',
  UNIQUE KEY `u` (`date`,`hour`,`fcst_len`,`mb10`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1
;

