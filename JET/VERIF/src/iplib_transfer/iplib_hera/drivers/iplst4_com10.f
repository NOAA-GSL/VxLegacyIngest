      subroutine iplst4_com10(field3,field4,nx,ny,nx10,ny10)
      integer nx,ny,nx10,ny10
      real anx(nx,ny),fff(nx,ny),fff2(nx,ny),wmask(nx,ny)
      character*256 command
      character*9 aadate,adate
      real f(nx,ny,6) !various accumulations
      real field3(nx,ny),field4(nx10,ny10)
c
c     1 = 6h reg 2=6h update 3=12h reg 4=12h update 5=24h reg 6=24h update
c
c     the following declarations for degribbing/remapping 4km anx to 40km
c
      parameter(ji=511*491,jo=161*145,km=1)  !new stage IV grid (4km)
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
      parameter(ji15=386*293)
      real ri15(ji15,km)
      data kgdsi15/5,386,293,22813,239649,8,255000,14288,14288,0,64,
     *0,0,0,0,0,0,0,0,255,0,0/ !precip anx
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
c     ----      defines output grid   --------!common 10km
      data kgdso/3,161,145,29250,252000,8,263500,10000,10000,0,64,
     *35000,35000,0,0,0,0,0,0,255,0,0/ 
c
c     ----      defines output grid   --------!RUC 40km
c     data kgdso/3,169,153,29073,251528,8,265000,10159,10159,0,64,
c    *25000,25000,0,0,0,0,0,0,255,0,0/ 
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
      do jj = 1,ny10
      do ii = 1,nx10
      k = k + 1
      lo(k,1) = 0
      enddo
      enddo

      call ipolates(6,ipopt,kgdsi,kgdso,ji,jo,1,ibi,li,ri,
     *ko,rlat,rlon,ibo,lo,ro,iret)

      k = 0
      do jj = 1,ny10
      do ii = 1,nx10
      k = k + 1
      field4(ii,jj) =  ro(k,1)
      enddo
      enddo
c

      return
      end
