#!/usr/bin/python

"""
create_vgtyp_column_in_table.py

Modifies tables in madis3 to have a vgtyp column, so that they will be flagged
for vgtyp verification.

Also creates new empty tables in vgtyp_sums for when vgtyp verification occurs.

Usage: create_vgtyp_column_in_table.py table_to_change temp_table

Parameters: table_to_change: The name of the table in madis3 to add a vgtyp column to.
            temp_table: A name for a temporary table to hold data from table_to_change.
                        temp_table will be deleted when the script finishes running.

Script written by Molly Smith, 23 March 2018.

"""

import sys
import MySQLdb

def create_vgtyp_column(table_to_change,temp_table):
    try:
        cnx = MySQLdb.connect(read_default_file="~/.my.cnf")
        cnx.autocommit = True
        cursor = cnx.cursor(MySQLdb.cursors.DictCursor)
    except MySQLdb.Error as e:
        print("Error: " + str(e))
        sys.exit(1)

    cursor.execute("use madis3;")

    if table_to_change[-2:] == 'qp':
        model_name = table_to_change[:-2]
        table_clean = "drop table " + temp_table + ";"
        template_table = "HRRRqp"
        table_create = "create table " + temp_table + " like " + template_table + ";"
        try:
            cursor.execute(table_clean)
            cursor.execute(table_create)
            print(temp_table + " cleaned")
        except:
            print(temp_table + " does not exist-- will create it")
            cursor.execute(table_create)

        get_fcst_lens = "select distinct fcst_len from " + table_to_change + ";"
        cursor.execute(get_fcst_lens)
        fcst_lens = []
        for row in cursor:
            val = row.values()[0]
            fcst_lens.append(int(val))
        fcst_lens.sort(key=int)
        for fcst_len in fcst_lens:
            replace_statement = "replace into " + temp_table + " (sta_id,fcst_len,time,ndiff,press,temp,dp,wd,ws,rh) select * from " + table_to_change + " where fcst_len=" + str(fcst_len) + ";"
            print(replace_statement)
            cursor.execute(replace_statement)
        table_drop_statement = "drop table " + table_to_change + ";"
        print (table_drop_statement)
        cursor.execute(table_drop_statement)
        create_new_table = "create table " + table_to_change + " like " + temp_table + ";"
        print(create_new_table)
        cursor.execute(create_new_table)
        for fcst_len in fcst_lens:
            insert_statement = "insert into " + table_to_change + " select * from " + temp_table + " where fcst_len=" + str(fcst_len) + ";"
            print(insert_statement)
            cursor.execute(insert_statement)
    elif table_to_change[-4:] == 'qp1f':
        model_name = table_to_change[:-4]
        table_clean = "drop table " + temp_table + ";"
        template_table = "HRRRqp1f"
        table_create = "create table " + temp_table + " like " + template_table + ";"
        try:
            cursor.execute(table_clean)
            cursor.execute(table_create)
            print(temp_table + " cleaned")
        except:
            print(temp_table + " does not exist-- will create it")
            cursor.execute(table_create)

        replace_statement = "replace into " + temp_table + " (sta_id,time,ndiff,press,temp,dp,wd,ws,rh) select * from " + table_to_change + ";"
        print(replace_statement)
        cursor.execute(replace_statement)
        table_drop_statement = "drop table " + table_to_change + ";"
        print (table_drop_statement)
        cursor.execute(table_drop_statement)
        create_new_table = "create table " + table_to_change + " like " + temp_table + ";"
        print(create_new_table)
        cursor.execute(create_new_table)
        insert_statement = "insert into " + table_to_change + " select * from " + temp_table + ";"
        print(insert_statement)
        cursor.execute(insert_statement)
    else:
        print("Right now only tables ending in 'qp' or 'qp1f' are supported by this script--exiting.")
        sys.exit(1)

    table_clean = "drop table " + temp_table + ";"
    cursor.execute(table_clean)

    cursor.execute("use vgtyp_sums;")
    print("creating table " + model_name + " in vgtyp_sums")
    sums_table_create = "create table " + model_name + " like template;"
    cursor.execute(sums_table_create)

#-------------------------------main driver-------------------------------

if __name__ == '__main__':

    if len(sys.argv) == 3:
        table_to_change = sys.argv[1]
        temp_table = sys.argv[2]
        print('Starting create_vgtyp_column_in_table.py')
        print('Modifying table ' + table_to_change + ' to include a vgtyp column.')
        print('Using table ' + temp_table + ' as a temporary table.')
        create_vgtyp_column(table_to_change,temp_table)
        print("Table processing complete")
    else:
        print("create_vgtyp_column_in_table.py requires two arguments: A table to modify and the name of a temporary table to be created.")