	program printerror
c  reads f77 error messages and prints corresponding lines+/- 2.
	character line*80, errmsg*132, filename*100, oldfilename*100

	nfile=0
	lastlinenumber=0
10	continue
	read(5,20,END=1000) errmsg
20	format(a132)
c  look for two blanks to get length of errmsg.
	lengtherr=lengthof(errmsg)
	if(lengtherr.eq.0) lengtherr=132
        write(6,30) " "
	write(6,30) errmsg(1:lengtherr)
30	format(a)
c  find line number, if any
	lineidx1=index(errmsg,'line ')
	if(lineidx1.eq.0) go to 10 	!no line number
	lineidx1=lineidx1+5
	lineidx2=index(errmsg(lineidx1:),':')-2+lineidx1
	read(errmsg(lineidx1:lineidx2),40, ERR=10) linenumber
40	format(i5)
	if (linenumber.eq.0) go to 10
c  a real linenumber.  print it out (once)
	line1=linenumber-2
	if(line1.lt.1) line1=1
	line2=linenumber+2

c  we have a line number, now get the program name
	pindex1=index(errmsg,'"')+1
	pindex2=index(errmsg(2:),'"')
	if(pindex2-pindex1 .gt. 100) then
	   print *, 'f78: FILENAMES TOO LONG!'
	   call exit(1)
	end if
	filename=errmsg(pindex1:pindex2)
	if(filename.ne.oldfilename) then
c  a new file
		nfile=nfile+1
		LUNopen=10+mod(nfile,2)
		LUNclose=11-mod(nfile,2)
		if(nfile.gt.1) close(LUNclose)
		open(LUNopen,FILE=filename,STATUS='OLD')
		oldfilename=filename
		lastlinenumber=0
	endif

c  don't print out if we've already done so
	if(linenumber.eq.lastlinenumber) go to 10
	lastlinenumber=linenumber
	rewind(LUNopen)
	do 100 i=1,9000		!won't work for pgms longer than 9000 lines!
	read(LUNopen,50,END=110) line
50	format(a)
	if(i.ge.line1.and.i.le.line2) then
		l=lengthof(line)
		if(l.lt.1) l=1
		if(l.gt.79) l=79
		if(i.eq.linenumber) then
			print*,'>',line(1:l)
		else
			print*,'_', line(1:l)
		endif
	endif
100	continue
110	continue
	go to 10
1000	continue
	STOP
	end
