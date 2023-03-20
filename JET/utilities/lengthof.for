	function lengthof(line)
c  routines index of the right-most non-blank character in line
	character line*(*)
	last = len(line)
	do 20 i=1,last
	if(line(last-i+1:last-i+1).eq.' ') go to 20	
	lengthof=last-i+1
	go to 30
20	continue
	lengthof=0
30	continue
	return
	end

	