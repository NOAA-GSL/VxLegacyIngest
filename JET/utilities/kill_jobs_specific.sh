#!/bin/ksh
function is_number {
expr $1 + 0 >/dev/null 2>&1
if [ $? -ne 0 ]; then
ISNUMBER="FALSE"
else
ISNUMBER="TRUE"
fi
}

#list=$(showq -b -u $USER | cut -d" " -f1| tail -500)
list=$(showq -n -u $USER | grep vis | cut -d" " -f1| tail -500)

print ${list}

for id in ${list} ; do
# is_number $id
# if  [ $ISNUMBER == "TRUE" ] && [[ $id -gt "10000000" ]] ; then 
 if  [ $id -gt "1000" ] ; then 
         qdel $id
         print $id
 fi 
done

