#!/usr/bin/python
import MySQLdb as SQL
import os.path
print 'started'
my_db = SQL.connect(host='wolphin', user='wcron0_user',passwd='cohen_lee', db='files_on_jet')
print 'opened db'

c = my_db.cursor()
c.execute("""SELECT dirname from files_avail_new""")

x = c.fetchone()
while x <> None:
#	print x[0]
        if os.path.isdir(x[0]) :
#		print x[0]+ 'exists\n'
		pass
	else:
	    try:
		print x[0]+ ' no longer there\n'
                ex_str   = """DELETE from files_avail_new WHERE dirname=%s"""%(x[0])
                print ex_str
		#c.execute(ex_str)
                #my_db.commit()
	    except:
		print 'error processing',x[0]
	x = c.fetchone()
my_db.close()
        
