use ruc_ua_pb;
CREATE TABLE `moving` (
  `wmoid` varchar(20)  NOT NULL,
  `latest` datetime DEFAULT NULL comment 'most recent time (re)discovered moving',
  PRIMARY KEY (`wmoid`)
) comment 'List of moving RAOBs found in prepBUFR files',
ENGINE=MyISAM DEFAULT CHARSET=latin1
;

