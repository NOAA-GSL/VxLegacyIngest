      subroutine iplst4_eta12(field3,field4,nx,ny,nx12,ny12)
      integer nx,ny,nx12,ny12
      real anx(nx,ny),fff(nx,ny),fff2(nx,ny),wmask(nx,ny)
      character*256 command
      character*9 aadate,adate
      real f(nx,ny,6) !various accumulations
      real field3(nx,ny),field4(nx12,ny12)
c
c     1 = 6h reg 2=6h update 3=12h reg 4=12h update 5=24h reg 6=24h update
c
c     the following declarations for degribbing/remapping 4km anx to 40km
c
      parameter(ji=511*491,jo=141*128,km=1)  !new stage IV grid (4km)
      real rlat(jo),rlon(jo)
      integer ibi(km),ibo(km)
      logical*1 li(ji,km),lo(jo,km)  !!input/output mask field
      real ri(ji,km),ro(jo,km)       !!input/output precip data
      integer ipopt(20)
      data ipopt/20*-1/
      integer kgdsi(22),kgdsi15(22),kgdso(22)
      integer kpds(100)
c
c
c     the following declarations for degribbing/remapping 15km anx
c
c     parameter(ji15=386*293)
c     real ri15(ji15,km)
c     data kgdsi15/5,386,293,22813,239649,8,255000,14288,14288,0,64,
c    *0,0,0,0,0,0,0,0,255,0,0/ !precip anx
c
c
c    -----      defines input grid    --------!new stage4 4km polarstereo
c     data kgdsi/5,1121,881,23117,240977,8,255000,4763,4763,0,64,
c    *0,0,0,0,0,0,0,0,255,0,0/
c
c
c    -----      defines input grid    --------!cut stage4 4km polarstereo
      data kgdsi/5,511,491,27973,250204,8,255000,4763,4763,0,64,
     *0,0,0,0,0,0,0,0,255,0,0/
c
c
c     ----      defines output grid   --------!cut ETA 12km
      data kgdso/3,141,128,29089,251505,8,265000,12191,12191,0,64,
     *25000,25000,0,0,0,0,0,0,255,0,0/ 
c
c
c     ----      defines output grid   --------!RUC 40km
c     data kgdso/3,76,57,16281,233862,8,265000,81268,81268,0,64,
c    *25000,25000,0,0,0,0,0,0,255,0,0/ 
c
c
c****************************************************************************
c 
c     now call ncep routine to remap this to the RUC grid
c
      ibi(1)=mod(kpds(4)/64,2)
c
c     IPLOLATES INTERPOLATES RAW STAGE4 data to grid defined in declarations
c
      k = 0
      do jj = 1,ny
      do ii = 1,nx
      k = k + 1
      ri(k,1) = field3(ii,jj)
      li(k,1) = 1
      enddo
      enddo

      k = 0
      do jj = 1,ny12
      do ii = 1,nx12
      k = k + 1
      lo(k,1) = 0
      enddo
      enddo

      call ipolates(6,ipopt,kgdsi,kgdso,ji,jo,1,ibi,li,ri,
     *ko,rlat,rlon,ibo,lo,ro,iret)

      k = 0
      do jj = 1,ny12
      do ii = 1,nx12
      k = k + 1
      field4(ii,jj) =  ro(k,1)
      enddo
      enddo
c

      return
      end
