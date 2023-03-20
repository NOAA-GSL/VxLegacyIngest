       PROGRAM test_w3fb06
       implicit none
       real*4 alat,alon,alat1,alon1,dx,alonv,xi,xj

       ! try to get the 1,1 point , this is input lat
       alat = 38.290
       alon = 245.144

!       alat = 30.00
!       alon = -173.0

!       alat = 35.1821
!       alon = -171.454

       alat = 0
       alon = 360 -143.59  !-143.59


       alat = 53.67
       alon = 360 -113.47!-113.47
!       alon = -113.47

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 
       alat1 = 30
       alon1 = 187
!       alon1 = 187-360
       dx = 11250.0   !meters
!       alonv = 225
       alonv = 225-360

       write(*,*) 'input lat,lon is',alat,alon

       call w3fb06(ALAT,ALON,ALAT1,ALON1,DX,ALONV,XI,XJ)
       write(*,*) 'result is ',xi,xj

       ! do it backwards
       call w3fb07(xi,xj,ALAT1,ALON1,DX,ALONV,alat,alon)
       write(*,*) 'and the recalculated  lat/lon  is', 
     + alat,alon

       stop
       end
