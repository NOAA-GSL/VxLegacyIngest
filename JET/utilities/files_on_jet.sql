use files_on_jet;
drop table if exists files;
create table files (
one tinyint not null primary key comment 'always 1 so this table has only one line',
time_checked datetime not null,
files blob not null comment 'an ascii list of available files'
)
;
