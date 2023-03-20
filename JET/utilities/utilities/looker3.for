C     this program will print out the difference between
C     the *.DAT verification scores for two directories
C     given by the links DAT1 and DAT2
C
      character*10 name
      character*80 fil1,fil2
      real data1(1000,14),date1(1000)
      real data2(1000,14),date2(1000)
      real diff(8,1000,14)
      integer date(8,1000)
      integer num(8)
      real ave(8,14),ave1(8,14),ave2(8,14)
      real sum1(8,14),sum2(8,14)
      integer ilast1(1000),ilast2(1000)
      integer cc(8,14),num1(8,14),num2(8,14)
      character*3 lev(8)
      data lev/'850','700','500','400','300','250','200','150'/
      
      write(6,25)
 25   format('YOU MUST HAVE 2 SOFTLINKS: DAT1 and DAT2',//)
 50   write(6,100) 
 100  format('enter the variable type, e.g., V,T,TM')
      read(5,'(a10)') name
      ilen=index(name,'  ') - 1

      write(6,145)
 145  format('enter the beginning dates and ending dates (i5,1x,i5)')
      read(5,'(i5.5,1x,i5.5)') ibeg,iend

      write(6,147)
 147  format('enter cycle: 00 or 12 or 99 for both')
      read(5,*) irc
c
      rbeg = ibeg*100.
      rend = iend*100.

      open(unit=30,file='compare.dat',status='unknown')

      do 500 n = 1,8
      do 125 kk=1,1000
      ilast1(kk) =1 
      ilast2(kk) =1 
 125  continue

      i = 0
      fil1 = 'DAT1' // '/' // lev(n) // name(1:ilen) // '.DAT'
      fil2 = 'DAT2' // '/' // lev(n) // name(1:ilen) // '.DAT'
      ilf1 = index(fil1,'  ' ) - 1
      ilf2 = index(fil2,'  ' ) - 1
      open(unit=10,file=fil1(1:ilf1),status='old',err=150)
      go to 160
 150  write(6,155) 
 155  format('error: cannot find your first file (check links!)')
      stop
 160  open(unit=20,file=fil2(1:ilf2),status='old',err=180)
      go to 200
 180  write(6,185)
 185  format('error: cannot find your second file (check links)')
      stop

 200  i = i + 1
      read(10,*,err=220,end=245) (data1(i,j),j=1,6),
     *date1(i),(data1(i,j),j=7,14)
      idate = date1(i) / 100
      idate = idate * 100
      if(idate.eq.date1(i)) then
                            ihr=0
                            else
                            ihr=12
                            endif
       if(irc.ne.ihr.and.irc.ne.99) then
c      if(ihr.ne.00.and.ihr.ne.12) then
                                   i = i - 1
                                   endif !wrong hour
      go to 200
 220  do 240 j=1,14
      data1(i,j) = 99.9
 240  continue
      go to 200
 245  n1=i-1
      i = 0

 250  i = i + 1
      read(20,*,err=270,end=290) (data2(i,j),j=1,6),
     *date2(i),(data2(i,j),j=7,14)
      idate = date2(i) / 100
      idate = idate * 100
      if(idate.eq.date1(i)) then
                            ihr=0
                            else
                            ihr=12
                            endif
       if(irc.ne.ihr.and.irc.ne.99) then
c      if(ihr.ne.12.and.ihr.ne.0) then
                                   i = i - 1
                                   endif !wrong hour
      go to 250
 270  do 280 j=1,14
      data2(i,j) = 99.9
 280  continue
      go to 250
 290  n2=i-1
      i=0
      close(10)
      close(20)

c     find duplicate dates......
      do 310 ii=1,n1
      if(ilast1(ii).eq.0) go to 310
      do 308 ij=ii+1,n1
      if(date1(ii).eq.date1(ij)) then
                                 ilast1(ii) = 0
                                 endif
                                 
 308  continue
 310  continue
      do 315 ii = 1,n2
      if(ilast2(ii).eq.0) go to 315
      do 313 ij = ii+1,n2
      if(date2(ii).eq.date2(ij)) then
                                 ilast2(ii) = 0
                                 endif
 313  continue
 315  continue

c     compare last occurance of date/time in each file
      k = 0
      do 350 i1=1,n1
      if(ilast1(i1).eq.0) go to 350
      do 325 i2=1,n2
      if(ilast2(i2).eq.0) go to 325      

      if(date1(i1).eq.date2(i2)) then
      if(date1(i1).ge.rbeg .and. date1(i1).le.rend) then
      k = k + 1
      date(n,k) = date1(i1)
      do 300 j = 1,14
      if(data1(i1,j).eq.99.9.or.data2(i2,j).eq.99.9) then
                    diff(n,k,j) = 99.9
                                                     else
                    diff(n,k,j) = data1(i1,j) - data2(i2,j)
                    num1(n,j) = num1(n,j) + 1
                    num2(n,j) = num2(n,j) + 1
                    sum1(n,j) = sum1(n,j) + data1(i1,j)
                    sum2(n,j) = sum2(n,j) + data2(i2,j)
                                                     endif
 300  continue
      go to 350
                                 endif
                                 endif
 325  continue ! keep searching file2 for date in file1                          
      
 350  continue !next date in file1
c
      num(n) = k
      write(30,360) lev(n),name(1:ilen)
 360  format(/,a3,a2,/)
c ! the following write added by me - BJ
      write(30,361)
 361  format(2x,'anx',2x,'36h',3x,'24h',3x,'12p',3x,'24p',
     +       3x,'12h',3x,'date',4x,'36p',3x,'03h',3x,'06h',
     +       3x,'09h',3x,'03p',3x,'06p',3x,'09p',3x,'01h')
      do 400 i = 1,k
      write(30,375) (diff(n,i,j),j=1,6),date(n,i),
     *(diff(n,i,j),j=7,14)
 375  format(f5.1,5(f5.1,1x),i7.7,8(1x,f5.1))
 400  continue
c
 500  continue !!!next level
c
c     now write out diffs by level
      do 550 i = 1,num(1)
      do 525 n = 1,8
      if(n.eq.1) write(30,505) date(n,i)
 505  format(/,i7.7,': data by level',/)
c ! the following if added by me - BJ
      if (n.eq.1) then
        write(30,362)
 362    format(6x,'anx',2x,'36h',3x,'24h',3x,'12p',3x,'24p',
     +         3x,'12h',3x,'date',4x,'36p',3x,'03h',3x,'06h',
     +         3x,'09h',3x,'03p',3x,'06p',3x,'09p',3x,'01h')
      endif
      write(30,515) lev(n),(diff(n,i,j),j=1,6),date(n,i),
     *(diff(n,i,j),j=7,14) 
 515  format(a3,':',f5.1,5(f5.1,1x),i7.7,8(1x,f5.1))

c     compute average overall days
      do 520 j=1,14
      if(diff(n,i,j).ne.99.9) then
                              ave(n,j) = ave(n,j) + diff(n,i,j)
                              cc(n,j) = cc(n,j) + 1
                              endif
 520  continue
 525  continue !next level this date
 550  continue !next matched day

      do 575 n=1,8
      do 560 j=1,14
      if(cc(n,j).eq.0) then
                       ave(n,j)=99.9
                       else
                       ave(n,j) = ave(n,j) / cc(n,j)
                       endif
      if(num1(n,j).eq.0) then
                         ave1(n,j) = 99.9
                         else
                         ave1(n,j) = sum1(n,j) / num1(n,j)
                         endif
      if(num2(n,j).eq.0) then
                         ave2(n,j) = 0
                         else
                         ave2(n,j) = sum2(n,j) / num2(n,j)
                         endif
                                          
 560  continue
 575  continue

      write(30,578)
 578  format(/'average data by level: DAT1-DAT2',/)
c ! the following write added by me - BJ
      write(30,361)
      do 595 n=1,8
      write(30,580) lev(n),(ave(n,j),j=1,14)
 580  format(a3,':',
     *f5.2,1x,5(f5.2,1x),'  ave  ',8(1x,f5.2))
 595  continue      
c
c     write out the average for DAT1 and DAT2 seperately
c
      write(30,598)
 598  format('average for DAT1/DAT2 by level',/)
c ! the following write added by me - BJ
      write(30,361)
      do 610 n = 1,8
      write(30,599) lev(n),(ave1(n,j),j=1,14)
      write(30,600) lev(n),(ave2(n,j),j=1,14)
 599  format(a3,':',f5.2,1x,5(f5.2,1x),' ave1  ',8(1x,f5.2))
 600  format(a3,':',f5.2,1x,5(f5.2,1x),' ave2  ',8(1x,f5.2))
 610  continue
            
            
            
      write(6,625)
 625  format('output (DAT1 - DAT2  is in file: compare.dat')
      call system('more compare.dat')
      stop
      end
            





