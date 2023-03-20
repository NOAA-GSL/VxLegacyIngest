c     this routine will verify RR (on the 13km grid) and eta
c     forecasts against ACARS observations
c
c                                                   Schwartz
c                                                   Dec 2001
c     Moninger, March 2002 - adapted
c     Moninger, Nov 2008 - adapted for RR

c     this routine expects the following links:

c     LOG_DIR : stats and individual ob/fcst files (OUTPUT)
c     OUT_DIR : partial sum directory (*.DAT files)(OUTPUT)
c
c     **note: directories for RUC and eta data are hardwired
c             see ruc_dir below and GRIBDIR link created internally
     
**************************************************************************
      parameter(rotcon = 0.70711) !sine of 45 degrees
      parameter(maxobs=200000)
      parameter(numproj=1)
      parameter(nreg=3)
c
c
c     hardwired coords for rotLL RR grid
c
      parameter(nlev=40)
      parameter(nx13=758,ny13=567)
      real lat_0_deg,lon_0_deg,dxy_km,lat_g_SW_deg,lon_g_SW_deg
      data lat_0_deg/47.5/
      data lon_0_deg/-104./
      data dxy_km/13.54508/
      data lat_g_SW_deg/2.227524/
      data lon_g_SW_deg/-140.4815/

      integer timep(maxobs),timec(maxobs),time(maxobs)
      integer iparm2(1),iparm3(5)
c     acars observed data    
      integer pindexp(maxobs),pindexc(maxobs)
      real xp(maxobs),yp(maxobs),xc(maxobs),yc(maxobs)
      real ix(maxobs),jy(maxobs)
      real pp(maxobs),tp(maxobs),rhp(maxobs),up(maxobs),vp(maxobs)
      real pc(maxobs),tc(maxobs),rhc(maxobs),uc(maxobs),vc(maxobs)
      real htp(maxobs),htc(maxobs)
      integer*4 sdg_ap_idp(maxobs),sdg_ap_idc(maxobs)
      integer*4 sdg_ap_id(maxobs)
      integer*4 up_dnp(maxobs),up_dnc(maxobs),up_dn(maxobs)
      real rh_uncp(maxobs),rh_uncc(maxobs),rh_unc(maxobs)
      real p(maxobs),ht(maxobs),t(maxobs),rh(maxobs)
      real tas(maxobs),tasp(maxobs),tasc(maxobs)
      integer dataSource(maxobs),dataSourcep(maxobs),dataSourcec(maxobs)
      real u(maxobs),v(maxobs)
      integer pi(maxobs) !index for pressure interpolation
      real latp(maxobs),latc(maxobs),lonp(maxobs),lonc(maxobs)
      real rlat(maxobs),rlon(maxobs)
      real a_hdg(maxobs),r_hdg(maxobs)
      real a_mach(maxobs),r_mach(maxobs)
      real*8 r_secs(maxobs),cal_secs(maxobs)
      real tdif(maxobs,numproj),vdif(maxobs,numproj)
      integer status(numproj)
      character*3 aregion(3)
      character*160 output_file
      character*160 grib_file

      data aregion/'nat','eas','wes'/

c  indices of fields desired from agrib
      parameter(n_g3_fields = 5)
      integer g3_fields(n_g3_fields)
      data g3_fields/7,11,52,33,34/
      real g3(nx13,ny13,nlev,n_g3_fields) 
c g2 is a dummy, because we don't want any sfc fields here.
      parameter(n_g2_fields = 0)
      integer g2_fields(1)
      data g2_fields/1/
      real g2(1,1,1)
      integer ret
      character null
      integer ilend

      real fht(nx13,ny13,nlev,numproj) !5 forecast projections for model fcsts
      real ft(nx13,ny13,nlev,numproj) !5 forecast projections for model fcsts
      real frh(nx13,ny13,nlev,numproj) !5 forecast projections for model fcsts
      real fu(nx13,ny13,nlev,numproj)
      real fv(nx13,ny13,nlev,numproj)

      real htf(maxobs,numproj)  !forecast values at ACARS pressure/location
      real tf(maxobs,numproj)  !forecast values at ACARS pressure/location
      real rhf(maxobs,numproj)  !forecast values at ACARS pressure/location
      real uf(maxobs,numproj)
      real vf(maxobs,numproj)
c
c     statistics
c

c
      parameter(numbin=8)
      integer pint(numbin)
      data pint/1050,750,600,450,350,275,225,50/ !pressure binning
c
      integer numt(numproj,nreg,numbin),numw(numproj,nreg,numbin)
      real sumt(numproj,nreg,numbin),asumt(numproj,nreg,numbin)
      real sumsqt(numproj,nreg,numbin)
c      real tbias(numproj,nreg,numbin),tmae(numproj,nreg,numbin)
c      real trms(numproj,nreg,numbin)

      real sums(numproj,nreg,numbin),asums(numproj,nreg,numbin)
      real vsum(numproj,nreg,numbin)
c      real sbias(numproj,nreg,numbin) ! ,srms(numproj,nreg,numbin)
c      real vrms(numproj,nreg,numbin)
      real sumsqs(numproj,nreg,numbin) !,smae(numproj,nreg,numbin)
c      
      character*9 adate,adatep,adte
      character*9 tailnumc(maxobs),tailnump(maxobs),tn(maxobs)
      character*4 aproj
      character*10 model
      character*13 fdates(10)

      character*80 ruc_dir,eta_dir,nmc_dir
c      character*80 command

      data ruc_dir/ '' /  !20km RUC isobaric data
      data eta_dir/ '' /   !eta 212
      data nmc_dir/ '' / !ncep 20-km RUC

      character*5 grib
      data grib/''/

      integer istatus
c
      integer plev(nlev)
      data plev/1013,1000,975,950,925,900,875,850,825,800,
     *               775,750,725,700,675,650,625,600,
     *               575,550,525,500,475,450,425,400,
     *               375,350,325,300,275,250,225,200,
     *               175,150,125,100,75,50/

c****************************************************************************
      call getarg(1,adate)

      call getarg(2,model)

      call getarg(3,output_file)

      do i = 1,maxobs
      do j = 1,numproj
      tdif(i,j) = -9.9
      vdif(i,j) = -9.9
      enddo
      enddo
      
      write(6,110) output_file
 110  format('output_file ',a80)


      ilen = index(output_file,'  ' ) - 1
      open(unit=42,file=output_file(1:ilen),status='unknown')
      write(42,'(1h.,a9)') adate
c     write header for output file of ACARS temp/wind differences
      write(42,123) 
 123  format('.',11x,'time  tail num   lat     lon  pres     ',
     *'   t - tf  ',
     *'   dir  -   dirf     s - sf      hdg     mach    vdiff',
     *'   rh   -   rhf    ht    -    htf   sdg_ap_id  up_dn  rh_unc',
     *' tas source',/,'.')

C     create previous hour date
      read(adate,'(i2,i3,i2)') iyr,jday,ihr
      ihr = ihr - 1
      ihr = ihr*100
      if(ihr.lt.0) then
                   ihr=2300
                   jday=jday - 1
                   if(jday.eq.0) then
                                 jday=365
                                 iyr=iyr - 1
                                 endif
                   endif
      write(adatep,'(i2.2,i3.3,i4.4)') iyr,jday,ihr
c
c     get ACARS observations

c     we get all obs after 30 mins pasr previous hr and those
c     up to 29 mins after current hour
c
c     note: we are grabbing only the ACARS data for previous 30 min
c           although we can get those 30 min after also by uncommenting
c           second call to getacars

      itimes=1
      istatus1 = -1
      call getacars(itimes,adatep,nump,timep,xp,yp,pp,htp,tp,
     *rhp,up,vp,pindexp,
     *latp,lonp,tailnump,a_hdg,a_mach,cal_secs,istatus1,sdg_ap_idp,
     *up_dnp,rh_uncp,tasp,dataSourcep)
      write (*,*) 'return from first call to getacars'
      if(istatus1.ne.0) then
         write(6,115) adatep
 115     format('no acars data for: ',a9)
         stop
      endif
c     combine all obs into single arrays
      n = 0
      if(istatus1.eq.0) then
      do 120 i = 1,nump
         n = n + 1
         time(n) = timep(i)
         ix(n)   = xp(i)
         jy(n)   = yp(i)
         p(n)   = pp(i)
         ht(n)  = htp(i)
         t(n)   = tp(i)
         rh(n)  = rhp(i)
         u(n)   = up(i)
         v(n)   = vp(i)
         sdg_ap_id(n) = sdg_ap_idp(i)
         up_dn(n) = up_dnp(i)
         rh_unc(n) = rh_uncp(i)
         tas(n) = tasp(i)
         dataSource(n) = dataSourcep(i)
c      index for interpolation beween index and index - 1
         pi(n)   = pindexp(i)  
         rlat(n) = latp(i)
         rlon(n) = lonp(i)
         tn(n)   = tailnump(i)
         r_hdg(n) = a_hdg(i)
         r_mach(n) = a_mach(i)
         r_secs(n) = cal_secs(i)
 120  continue
      numacars = n

      endif
c     second hour
      itimes=2     
      istatus2=-1
      call getacars(itimes,adate, numc,timec,xc,yc,pc,htc,tc,
     *rhc,uc,vc,pindexc,
     *latc,lonc,tailnumc,a_hdg,a_mach,cal_secs,istatus2,sdg_ap_idc,
     *up_dnc,rh_uncc,tasc,dataSourcec)

      write (*,*) 'return from second call to getacars'
      if(istatus2.eq.0) then
         do 140 i = 1,numc
            n = n + 1
            time(n) = timec(i)
            ix(n)   = xc(i)
            jy(n)   = yc(i)
            p(n)   = pc(i)
            ht(n)  = htc(i)
            t(n)   = tc(i)
            rh(n)  = rhc(i)
            u(n)   = uc(i)
            v(n)   = vc(i)
            sdg_ap_id(n) = sdg_ap_idc(i)
            up_dn(n) = up_dnc(i)
            rh_unc(n) = rh_uncc(i)
            tas(n) = tasc(i)
            dataSource(n) = dataSourcec(i)
            pi(n)   = pindexc(i)
            rlat(n) = latc(i)
            rlon(n) = lonc(i)
            tn(n)   = tailnumc(i)
            r_hdg(n) = a_hdg(i)
            r_mach(n) = a_mach(i)
            r_secs(n) = cal_secs(i)
 140     continue
         numacars = n
      endif

c
c
c     get all the adates for each fcst projection
c 
C      call times(adate,fdates)
c

c preset g3
      do 15 i=1,nx13
      do 14 j=1,ny13
      do 13 k=1,nlev
      do 12 l=1,n_g3_fields
         g3(i,j,k,l) = 1e20
 12   continue
 13   continue
 14   continue
 15   continue
      
c     get model (RUC or ETA) forecasts

c     we must determine if file exists; there is no soft return in unpkgrb1

      do 300 l=1,numproj
      call get_environment_variable("grib_file",grib_file)
      write (*,*) 'degribbing ',trim(grib_file)
      ret = agrib(nlev,n_g3_fields,g3_fields,
     * n_g2_fields,g2_fields,g3,g2,-1,-1,
     * grib_file,istatus)
      print*,'return status from agrib is',istatus
      if (istatus.ne.0) then
         stop
      endif

c
c     save data for each fcst projection
c  
      status(l) = 0
      do 250 i=1,nx13
      do 225 j=1,ny13
      do 220 k=1,nlev
      fht(i,j,k,l) = g3(i,j,k,1)  ! geopotential height
      ft(i,j,k,l) = g3(i,j,k,2) - 273.15
      frh(i,j,k,l) = g3(i,j,k,3)
      fu(i,j,k,l) = g3(i,j,k,4)
      fv(i,j,k,l) = g3(i,j,k,5)
      if(i .lt.2 .and. j .lt. 2) then
c       write(6,219) i,j,k,g3(i,j,k,1)
 219     format('g3 for ',3(i,1x)' is ',f10.2)
      endif
 220  continue
 225  continue
 250  continue
c
 300  continue !next fcst projection
c
c_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ 
c
c     now do bilinear interpolation and log-p interpolation
c   
      do 500 n = 1, numacars
         do ik=1,numbin-1
            if(p(n).le.pint(ik).and.p(n).gt.pint(ik+1)) then
               ip=ik
               go to 325
            endif
         enddo
c         write(42,3240) n, p(n)
 3240    format('.skipping interpolation for acars ',i4,1x,f10.1)
         go to 500

 325  k = pi(n)                 !level to start interpolation

      do 375 l = 1,numproj !!get values at all fcst projections

      htf(n,l) = -99999.9
      tf(n,l) =  -99999.9
      rhf(n,l) = -99999.9
      uf(n,l) = -99999.9
      vf(n,l) = -99999.9
      if(status(l).ne.0) go to 375
c
c     height interplation
c

      call bilin_maps_sfc(nx13,ny13,fht(1,1,k,l),
     *ix(n),jy(n),result1)
c
      call bilin_maps_sfc(nx13,ny13,fht(1,1,k-1,l),
     *ix(n),jy(n),result2)
c
c     now do the linear interpolation in log-p for result1 and result2
c
      if(result1.eq.-99999.9.or.result2.eq.-99999.9) then
           htf(n,l) = 99999
                                                     else
           htf(n,l) = result2 + 
     *     ((result1 - result2)*(log(p(n)/plev(k-1))/
     *     log(float(plev(k))/float(plev(k-1)))))
                                                     endif
c
c     temperature interpolation
c
      call bilin_maps_sfc(nx13,ny13,ft(1,1,k,l),
     *ix(n),jy(n),result1)


      call bilin_maps_sfc(nx13,ny13,ft(1,1,k-1,l),
     *ix(n),jy(n),result2)

c      write(42,3253) result1,result2, k,p(n)
 3253 format('. temperature1,2 ',f8.3,' ',f8.3,' k = ',i5,' press = ',
     * f8.3)

c
c     now do the linear interpolation in log-p for result1 and result2
c
      if(result1.eq.-99999.9.or.result2.eq.-99999.9) then
           tf(n,l) = 99999
                                                     else
           tf(n,l) = result2 + 
     *     ((result1 - result2)*(log(p(n)/plev(k-1))/
     *     log(float(plev(k))/float(plev(k-1)))))
                                                     endif
c
c     humidity interplation
c

      call bilin_maps_sfc(nx13,ny13,frh(1,1,k,l),
     *ix(n),jy(n),result1)
c
      call bilin_maps_sfc(nx13,ny13,frh(1,1,k-1,l),
     *ix(n),jy(n),result2)
c
c     now do the linear interpolation in log-p for result1 and result2
c
      if(result1.eq.-99999.9.or.result2.eq.-99999.9) then
           rhf(n,l) = 99999
                                                     else
           rhf(n,l) = result2 + 
     *     ((result1 - result2)*(log(p(n)/plev(k-1))/
     *     log(float(plev(k))/float(plev(k-1)))))
                                                     endif
c
c     u wind interpolation
c
      call bilin_maps_sfc(nx13,ny13,fu(1,1,k,l),
     *ix(n),jy(n),result1)
c
      call bilin_maps_sfc(nx13,ny13,fu(1,1,k-1,l),
     *ix(n),jy(n),result2)
c
      if(result1.eq.-99999.9.or.result2.eq.-99999.9) then
         uf(n,l) = -99999.9
        else

c     log-p interpolation
           uf(n,l) = result2 + 
     *          ((result1 - result2)*(log(p(n)/plev(k-1))/
     *          log(float(plev(k))/float(plev(k-1)))))
        endif
c
c     v wind interpolation
c
      call bilin_maps_sfc(nx13,ny13,fv(1,1,k,l),
     *ix(n),jy(n),result1)
c
      call bilin_maps_sfc(nx13,ny13,fv(1,1,k-1,l),
     *ix(n),jy(n),result2)
c
      if(result1.eq.-99999.9.or.result2.eq.-99999.9) then
           vf(n,l) = -99999.9
        else

c     log-p interpolation
           vf(n,l) = result2 + 
     *          ((result1 - result2)*(log(p(n)/plev(k-1))/
     *          log(float(plev(k))/float(plev(k-1)))))
        endif
c     
        if(uf(n,l).eq.-99999.9) vf(n,l) = -99999.9
        if(vf(n,l).eq.-99999.9) uf(n,l) = -99999.9
        
c     rotate wind fcst into ACARS observation plane
c     
        if(uf(n,l).ne.-99999.9.and.vf(n,l).ne.-99999.9) then
           call rotll_wind2true_deg(rlat(n),rlon(n),
     *                         lat_0_deg,lon_0_deg,
     *                         theta)
c      write(*,3254) rlat(n),rlon(n),theta
 3254 format('. lat,lon,theta ',f8.3,' ',f8.3,' ',f8.3)

           theta = -theta
           if(theta.lt.-180) theta = theta + 360.
           if(theta.gt.180) theta = theta - 360.
           theta = theta * 0.017453
           uorig = uf(n,l)
           vorig = vf(n,l)
           uf(n,l) = uorig * cos(theta) - vorig * sin(theta)
           vf(n,l) = uorig * sin(theta) + vorig * cos(theta)
        endif
c
c     now compute stats
c
      if(numacars.lt.100) go to 510 
      if(t(n).ne.-99999.9.and.tf(n,l).ne.-99999.9) then
      tdif(n,l) = tf(n,l) - t(n)
      numt(l,1,ip) = numt(l,1,ip) + 1
      sumt(l,1,ip) = sumt(l,1,ip) + tdif(n,l)
      asumt(l,1,ip) = asumt(l,1,ip) + abs(tdif(n,l))
      sumsqt(l,1,ip) = sumsqt(l,1,ip) + ( tdif(n,l) ** 2 )
c     numbin(last) group are over all pressures for each region
      numt(l,1,numbin) = numt(l,1,numbin) + 1
      sumt(l,1,numbin) = sumt(l,1,numbin) + tdif(n,l)
      asumt(l,1,numbin) = asumt(l,1,numbin) + abs(tdif(n,l))
      sumsqt(l,1,numbin) = sumsqt(l,1,numbin) + ( tdif(n,l) ** 2 )

      if(rlon(n).ge.-105.0) then !east
      numt(l,2,ip) = numt(l,2,ip) + 1
      sumt(l,2,ip) = sumt(l,2,ip) + tdif(n,l)
      asumt(l,2,ip) = asumt(l,2,ip) + abs(tdif(n,l))
      sumsqt(l,2,ip) = sumsqt(l,2,ip) + (tdif(n,l) ** 2)
      numt(l,2,numbin) = numt(l,2,numbin) + 1
      sumt(l,2,numbin) = sumt(l,2,numbin) + tdif(n,l)
      asumt(l,2,numbin) = asumt(l,2,numbin) + abs(tdif(n,l))
      sumsqt(l,2,numbin) = sumsqt(l,2,numbin) + (tdif(n,l) ** 2)

      else                      !west
      numt(l,3,ip) = numt(l,3,ip) + 1
      sumt(l,3,ip) = sumt(l,3,ip) + tdif(n,l)
      asumt(l,3,ip) = asumt(l,3,ip) + abs(tdif(n,l))
      sumsqt(l,3,ip) = sumsqt(l,3,ip) + ( tdif(n,l) ** 2 )
      numt(l,3,numbin) = numt(l,3,numbin) + 1
      sumt(l,3,numbin) = sumt(l,3,numbin) + tdif(n,l)
      asumt(l,3,numbin) = asumt(l,3,numbin) + abs(tdif(n,l))
      sumsqt(l,3,numbin) = sumsqt(l,3,numbin) + ( tdif(n,l) ** 2 )
      endif
      endif
      
      ibad = 0
      if(u(n).eq.-99999.9.or.v(n).eq.-99999.9) then 
         ibad = 1
         dir = 999.
         s = 999.
      else
         call uvtodirspd(u(n),v(n),dir,s)
      endif

      if(uf(n,l).eq.-99999.9.or.vf(n,l).eq.-99999) then 
         ibad = 1
         dirf = 999.
         sfl = 999.
       else
         call uvtodirspd(uf(n,l),vf(n,l),dirf,sfl)
      endif

      if(ibad.ne.1)                                then
        
         vdif(n,l) = ((u(n)-uf(n,l))** 2 +(v(n)-vf(n,l))** 2) ** 0.5

         numw(l,1,ip) = numw(l,1,ip) + 1
         sums(l,1,ip) = sums(l,1,ip) + ( sfl - s )
         asums(l,1,ip) = asums(l,1,ip) + abs ( sfl - s )
         sumsqs(l,1,ip) = sumsqs(l,1,ip) + ( sfl - s ) ** 2
         vsum(l,1,ip) = vsum(l,1,ip) + vdif(n,l) ** 2
         
         numw(l,1,numbin) = numw(l,1,numbin) + 1
         sums(l,1,numbin) = sums(l,1,numbin) + ( sfl - s )
         asums(l,1,numbin) = asums(l,1,numbin) + abs ( sfl - s )
         sumsqs(l,1,numbin) = sumsqs(l,1,numbin) + ( sfl - s ) ** 2
         vsum(l,1,numbin) = vsum(l,1,numbin) + vdif(n,l) ** 2 
         
         
         if(rlon(n).ge.-105.0) then !east
            numw(l,2,ip) = numw(l,2,ip) + 1
            sums(l,2,ip) = sums(l,2,ip) + ( sfl - s )
            asums(l,2,ip) = asums(l,2,ip) + abs ( sfl - s )
            sumsqs(l,2,ip) = sumsqs(l,2,ip) + ( sfl - s ) ** 2
            vsum(l,2,ip) = vsum(l,2,ip) + vdif(n,l)**2
            
            numw(l,2,numbin) = numw(l,2,numbin) + 1
            sums(l,2,numbin) = sums(l,2,numbin) + ( sfl - s )
            asums(l,2,numbin) = asums(l,2,numbin) + abs ( sfl - s )
            sumsqs(l,2,numbin) = sumsqs(l,2,numbin) + ( sfl - s ) ** 2
            vsum(l,2,numbin) = vsum(l,2,numbin) + vdif(n,l) **2 
            
         else                   !west
            
            numw(l,3,ip) = numw(l,3,ip) + 1
            sums(l,3,ip) = sums(l,3,ip) + ( sfl - s )
            asums(l,3,ip) = asums(l,3,ip) + abs ( sfl - s )
            sumsqs(l,3,ip) = sumsqs(l,3,ip) + ( sfl - s ) ** 2
            vsum(l,3,ip) = vsum(l,3,ip) + vdif(n,l) **2
            
            numw(l,3,numbin) = numw(l,3,numbin) + 1
            sums(l,3,numbin) = sums(l,3,numbin) + ( sfl - s )
            asums(l,3,numbin) = asums(l,3,numbin) + abs ( sfl - s )
            sumsqs(l,3,numbin) = sumsqs(l,3,numbin) + ( sfl - s ) ** 2
            vsum(l,3,numbin) = vsum(l,3,numbin) + vdif(n,l) **2 
            
            
         endif
      endif

 375  continue !next forecast projection (l)
c
c     write each ACARS and f-o difference for each projection to a file
      if(t(n).lt.-100) t(n) = 99999.
      write(42,475) r_secs(n),time(n),tn(n),rlat(n),rlon(n),p(n),
     *t(n),tf(n,1),
     *dir,dirf,
     *s,sfl,
     *r_hdg(n),r_mach(n),vdif(n,1),rh(n),rhf(n,1),ht(n),htf(n,1),
     *sdg_ap_id(n),up_dn(n),rh_unc(n),tas(n),dataSource(n)

 475  format(f11.0,1x, i4.4,1x,a9,1x,f5.2,1x,f7.2,1x,f7.2,1x,
     *f8.2,' - ',f8.2,1x,
     *f4.0,' - ',f8.2,1x,f6.2,' - ',f8.2,1x,
     *f6.0,1x,f9.3,1x,f6.2,1x,f6.0,' - ',f8.0,1x,f6.0,' - ',f8.0,
     *i5,i4,1x,f7.1,1x,f7.1,1x,i2.2)

 500  continue !next acars observation (n)
c
      close(42)
c     now compute stats using sums above
c
 510  continue

c  LEAVE OUT CALCULATING STATS

 550  continue !next pressure bin                   
 600  continue !next region
 700  continue !next projection

c
c      stop
      end
c********************************************************************
C     this subroutine computes the fcst file times that match
C     the obs time
C
c                                                   Schwartz Dec 2001
      subroutine times(adate,fcst_dates)
c
      parameter( nproj = 1)
      character*7 date
      character*9 adate 
      character*13 fcst_dates(nproj)
      integer proj(nproj)
      data proj/1/ !,1,3,6,9,12/
      character*4 aproj(nproj)
      data aproj/'0001'/ !,'0001','0003','0006','0009','0012'/

c
c      write(6,100)
c 100  format('input the observation time')
c      read(5,'(a9)') adate
c     compute yesterday's adate
      read(adate,'(i2,i3,i2)') iyr,jday,ihr
      jyday = jday - 1
      iyyr = iyr
      if(jyday.eq.0) then
                     jyday = 365
                     iyyr = iyr - 1
                     ily = iyyr / 4
                     rly = iyyr / 4.
                     if(ily.eq.rly) jyday = 366
                     endif 
      
      do 200 i = 1,1

      nhr = ihr - proj(i)
      print*, 'proj is ',proj,' nrh is ',nhr,' i ia ',i
      if(nhr.lt.0) then
                   nhr = nhr + 24
                   write(date,'(i2.2,i3.3,i2.2)') iyyr,jyday,nhr
                   else
                   write(date,'(i2.2,i3.3,i2.2)') iyr,jday,nhr
                   endif

      fcst_dates(i) = date // '00' // aproj(i)

 200  continue
c
c      write(6,300) adate,(aproj(i),fcst_dates(i),i=1,nproj)
 300  format('obs time = ',a9,/,' ',a4,' fcst file = ',a13,/
     *,a4,' fcst file = ',a13)

      return
      end
        
c***********************************************************
C     subroutine getacrs 
c
c     this routine returns ACARS data given the adate(a9)  
c     it returns the 13km i,j as well as p,t,u,v, and obs time
c
      subroutine getacars(itimes,adate,num,time,x,y,p,ht,t,rh,u,v,
     *pi,
     *lat,lon,tn,a_hdg,a_mach,cal_secs,istatus,sdg_ap_id,
     *up_dn,rh_unc,tas,data_source)
c
      include 'netcdf.inc'
      INTEGER NCID, STATUS 


      PARAMETER (NREC= 200000)   !CHANGE THIS TO GENERALIZE
C     VARIABLE IDS RUN SEQUENTIALLY FROM 1 TO NVARS= 47
      INTEGER*4 RCODE
      INTEGER*4 RECDIM
C     ****VARIABLES FOR THIS NETCDF FILE****
C
      INTEGER*4   missingInputMinutes            
      CHARACTER*1 minDate                        (   30)
      CHARACTER*1 maxDate                        (   30)
      REAL*8      minSecs                        
      REAL*8      maxSecs                        
      REAL*4      latitude                       (NREC)
      REAL*4      longitude                      (NREC)
      REAL*4      altitude                       (NREC)
      REAL*4      GPSaltitude                    (NREC)
      REAL*8      timeObs                        (NREC)
      REAL*4      temperature                    (NREC)
      REAL*4      windDir                        (NREC)
      REAL*4      windSpeed                      (NREC)
      REAL*4      heading                        (NREC)
      REAL*4      mach                           (NREC)
      REAL*4      trueAirSpeed                   (NREC)
      REAL*4      waterVaporMR                   (NREC)
      REAL*4      correctedWVMR                  (NREC)
      REAL*4      downlinkedRH                   (NREC)
      real*4      RHfromWVMR                     (NREC)
      real*4      rhUncertainty                          (NREC)
      REAL*4      dewpoint                       (NREC)
      REAL*4      rh_probe                       (NREC)
      REAL*4      medTurbulence                  (NREC)
      REAL*4      maxTurbulence                  (NREC)
      REAL*4      vertAccel                      (NREC)
      REAL*4      vertGust                       (NREC)
      CHARACTER*1 tailNumber                     (    9,NREC)
      INTEGER*4   en_tailnumber                  (NREC)
      INTEGER*4   dataType                       (NREC)
      integer     dataSource                     (NREC)
      LOGICAL*1   airline                        (NREC)
      LOGICAL*1   dataDescriptor                 (NREC)
      LOGICAL*1   errorType                      (NREC)
      LOGICAL*1   rollFlag                       (NREC)
      LOGICAL*1   waterVaporQC                   (NREC)
      LOGICAL*1   interpolatedTime               (NREC)
      LOGICAL*1   interpolatedLL                 (NREC)
      LOGICAL*1   tempError                      (NREC)
      LOGICAL*1   windDirError                   (NREC)
      LOGICAL*1   windSpeedError                 (NREC)
      LOGICAL*1   speedError                     (NREC)
      LOGICAL*1   bounceError                    (NREC)
      LOGICAL*1   correctedFlag                  (NREC)
      CHARACTER*1 flight                         (   13,NREC)
      CHARACTER*1 rptStation                     (    4,NREC)
      REAL*8      timeReceived                   (NREC)
      CHARACTER*1 origAirport                    (    6,NREC)
      INTEGER*4   orig_airport_id                (NREC)
      CHARACTER*1 destAirport                    (    6,NREC)
      INTEGER*4   dest_airport_id                (NREC)
      CHARACTER*1 format                         (    9,NREC)
      integer*4 sounding_airport_id              (NREC)
      integer*4 sounding_flag                    (NREC)
      integer nf_fid, nf_vid, nf_status  ! from Tracy

C*************************************
      INTEGER*4 START(10)
      INTEGER*4 COUNT(10)
      INTEGER VDIMS(10) !ALLOW UP TO 10 DIMENSIONS
      CHARACTER*31 DUMMY
      character*9 adate
      character*80 acars_file,output_file
      character*9 tailnum(nrec),tn(nrec)
      real pressure,uobs,vobs
      real rix,rjy
      real x(nrec),y(nrec)
      integer time(nrec)
      real u(nrec),v(nrec),t(nrec),p(nrec),rh(nrec),ht(nrec)
      integer pindex,pi(nrec),sdg_ap_id(nrec),up_dn(nrec)
      real rh_unc(nrec),a_hdg(nrec),a_mach(nrec)
      real lat(nrec),lon(nrec)
      real tas(nrec)
      real*8 cal_secs(nrec)
      integer data_source(nrec)
c
c
c     hardwired coords for rotLL RR grid
c
      parameter(nlev=40)
      parameter(nx13=758,ny13=567)
      real lat_0_deg,lon_0_deg,dxy_km,lat_g_SW_deg,lon_g_SW_deg
      data lat_0_deg/47.5/
      data lon_0_deg/-104./
      data dxy_km/13.54508/
      data lat_g_SW_deg/2.227524/
      data lon_g_SW_deg/-140.4815/
      integer plev(nlev)
      data plev/1013,1000,975,950,925,900,875,850,825,800,
     *               775,750,725,700,675,650,625,600,
     *               575,550,525,500,475,450,425,400,
     *               375,350,325,300,275,250,225,200,
     *               175,150,125,100,70,50/

       call ncpopt(ncverbose)
      acars_file = 'ACARS_DIR' // '/' // adate // 'q.cdf'
      ilenf = index(acars_file,'   ') - 1
      status = nf_open(acars_file(1:ilenf),NF_NOWRITE,ncid)
      IF (STATUS .NE. NF_NOERR) then
         istatus=-1
         write(6,8) acars_file(1:ilenf),ncid,status
 8    format('acars data not found for ',a50,' ',i5,' ',i5)
      num=0
      return
      endif
c              
      CALL NCINQ(NCID,NDIMS,NVARS,NGATTS,RECDIM,RCODE)
      CALL NCDINQ(NCID,RECDIM,DUMMY,NRECS,RCODE)
C     !NRECS! NOW CONTAINS NUM RECORDS FOR THIS FILE
C
C    statements to fill latitude                       
C
      ivarid = ncvid(ncid,'latitude                       ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO  60 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
  60  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +latitude                       ,RCODE)
C
C    statements to fill longitude                      
C
      ivarid = ncvid(ncid,'longitude                      ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO  70 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
  70  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +longitude                      ,RCODE)
C
C    statements to fill altitude                       
C
      ivarid = ncvid(ncid,'altitude                       ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO  80 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
  80  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +altitude                       ,RCODE)
C
C    statements to fill GPSaltitude                       
C
      ivarid = ncvid(ncid,'GPSaltitude                       ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO  85 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 85   CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +GPSaltitude                    ,RCODE)
C
C    statements to fill timeObs                        
C
      ivarid = ncvid(ncid,'timeObs                        ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO  90 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
  90  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +timeObs                        ,RCODE)
C
C    statements to fill temperature                    
C
      ivarid = ncvid(ncid,'temperature                    ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 100 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 100  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +temperature                    ,RCODE)
C
C    statements to fill windDir                        
C
      ivarid = ncvid(ncid,'windDir                        ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 110 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 110  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +windDir                        ,RCODE)
C
C    statements to fill windSpeed                      
C
      ivarid = ncvid(ncid,'windSpeed                      ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 120 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 120  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +windSpeed                      ,RCODE)
C
C    statements to fill heading                        
C
      ivarid = ncvid(ncid,'heading                        ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 130 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 130  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +heading                        ,RCODE)
C
C    statements to fill mach                           
C
      ivarid = ncvid(ncid,'mach                           ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 140 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 140  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +mach                           ,RCODE)
C
C    statements to fill true airspeed                           
C
      ivarid = ncvid(ncid,'trueAirSpeed                   ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 145 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 145  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +trueAirSpeed                          ,RCODE)
C
C    statements to fill waterVaporMR                   
C
      ivarid = ncvid(ncid,'waterVaporMR                   ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 150 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 150  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +waterVaporMR                   ,RCODE)
C
C    statements to fill ruUncertainty                  
C
      ivarid = ncvid(ncid,'rhUncertainty                ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 165 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 165  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +rhUncertainty                          ,RCODE)
C
C    statements to fill downlinkedRH                   
C
      ivarid = ncvid(ncid,'downlinkedRH                   ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 170 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 170  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +downlinkedRH                   ,RCODE)
C
C    statements to fill RHfromWVMR                 
C
      ivarid = ncvid(ncid,'RHfromWVMR                   ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 175 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 175  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +RHfromWVMR                   ,RCODE)
C
C    statements to fill dewpoint                       
C
      ivarid = ncvid(ncid,'dewpoint                       ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 180 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 180  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +dewpoint                       ,RCODE)
C
C    statements to fill medTurbulence                  
C
      ivarid = ncvid(ncid,'medTurbulence                  ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 200 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 200  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +medTurbulence                  ,RCODE)
C
C    statements to fill maxTurbulence                  
C
      ivarid = ncvid(ncid,'maxTurbulence                  ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 210 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 210  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +maxTurbulence                  ,RCODE)
C
C    statements to fill tailNumber                     
C
      ivarid = ncvid(ncid,'tailNumber                     ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 240 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 240  CONTINUE
      CALL NCVGTC(NCID,ivarid,START,COUNT,
     +tailNumber                     ,LENSTR,RCODE)
C
C    statements to fill dataType                       
C
      ivarid = ncvid(ncid,'dataType                       ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 260 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 260  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +dataType                       ,RCODE)
C
C    statements to fill dataSource, using Tracy's method                        
C
      status = NF_INQ_VARID(ncid,'dataSource',ivarid)
      if(status.ne.NF_NOERR) then
        print *, NF_STRERROR(status)
        print *,'in var dataSource'
      endif
      status = NF_GET_VAR_INT(ncid,ivarid,dataSource)
      if(status.ne.NF_NOERR) then
        print *, NF_STRERROR(status)
        print *,'in NF_GET_VAR_ dataSource '
      endif

C    statements to fill airline                        
C
      ivarid = ncvid(ncid,'airline                        ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 270 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 270  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +airline                        ,RCODE)
C
C    statements to fill dataDescriptor                 
C
      ivarid = ncvid(ncid,'dataDescriptor                 ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 280 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 280  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +dataDescriptor                 ,RCODE)
C
C    statements to fill errorType                      
C
      ivarid = ncvid(ncid,'errorType                      ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 290 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 290  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +errorType                      ,RCODE)
C
C    statements to fill waterVaporQC                   
C
      ivarid = ncvid(ncid,'waterVaporQC                   ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 310 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 310  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +waterVaporQC                   ,RCODE)
C
C    statements to fill flight                         
C
      ivarid = ncvid(ncid,'flight                         ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 400 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 400  CONTINUE
      CALL NCVGTC(NCID,ivarid,START,COUNT,
     +flight                         ,LENSTR,RCODE)
C
C    statements to fill orig_airport_id                
C
      ivarid = ncvid(ncid,'orig_airport_id                ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 440 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE
 440  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +orig_airport_id                ,RCODE)
C
C    statements to fill dest_airport_id                
C
      ivarid = ncvid(ncid,'dest_airport_id                ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 460 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE  
 460  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +dest_airport_id                ,RCODE)
C
C    statements to fill sounding_airport_id                
C
      ivarid = ncvid(ncid,'sounding_airport_id                ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 475 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE  
 475  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +sounding_airport_id                ,RCODE)
C
C    statements to fill sounding_flag               
C
      ivarid = ncvid(ncid,'sounding_flag                ',rcode)
      CALL NCVINQ(NCID,ivarid,DUMMY,NTP,NVDIM,VDIMS,NVS,RCODE)
      LENSTR=1
      DO 477 J=1,NVDIM
      CALL NCDINQ(NCID,VDIMS(J),DUMMY,NDSIZE,RCODE)
      LENSTR=LENSTR*NDSIZE
      START(J)=1
      COUNT(J)=NDSIZE  
 477  CONTINUE
      CALL NCVGT(NCID,ivarid,START,COUNT,
     +sounding_flag                ,RCODE)
C
      CALL NCCLOS(NCID,RCODE)
C
C
C     HERE IS WHERE YOU WRITE STATEMENTS TO USE THE DATA
C
C
C
      nn = 0
      output_file= adate // '.acars'
      ilenf=index(output_file,'   ') - 1

      print*,'acars records found:',nrecs
      if(nrecs .ge. NREC) then
         print*,'TOO MANY ACARS RECORDS. INCREASE NREC!'
         stop
      endif
c      open(unit=25,file=output_file(1:ilenf),status='unknown')
c
      do 700 i = 1,nrecs

         if(timeobs(i).ne.0) then
            call i4time_to_adate(timeobs(i),iyr,imo,iday,ihr,imin,isec)
            
         else
            
            iyr=-99
            imo=99
            idy=99
            ihrs=99
            imin=99
            isec=99
            
         endif
c
         do 500 n=1,9
            ival=ichar(tailnumber(n,i))
            if(ival.lt.32) then
               tailnum(i)(n:n)=' '
            else
               tailnum(i)(n:n) = tailnumber(n,i)
            endif
 500     continue

         if(imin.eq.99) go to 700

         if(itimes.eq.1.and.imin.lt.30) go to 700
         if(itimes.eq.2.and.imin.ge.30) go to 700

c         write(25,550) ihr,imin,isec,
c     *        tailnum(i),latitude(i),longitude(i),altitude(i),
c     *        temperature(i),winddir(i),windspeed(i),
c     *        heading(i),mach(i),errortype(i),
c     *        correctedflag(i),rollflag(i),temperror(i),winddirerror(i),
c     *        windspeederror(i),speederror(i),bounceerror(i)
 550     format(i2.2,i2.2,i2.2,1x,a9,1x,f6.2,1x,f9.2,1x,
     *        f7.1,1x,f5.1,1x,f5.1,1x,
     *        f5.1,1x,f6.0,1x,f9.3,2x,8(a1,1x))

         
         if(altitude(i).ne.99999.and.altitude(i).ge.-150) then
            pressure = ztopsa(altitude(i))
         else
            pressure  = -99999.9
         endif
         if(pressure.gt.1013.or.pressure.lt.50) then
c            write(25,4792)
 4792       format('bad pressure')
            go to 700
         endif
c     

c     find pressure index for interpolation
c
         do 480 nnn=2,nlev
            if(pressure.le.plev(nnn-1).and.pressure.gt.plev(nnn)) then 
               pindex  = nnn    !interpolation done between level nnn-1 and nnn
               go to 485
            endif
 480     continue
         pindex = -99
         write(6,481) tn(i),ihr,imin
 481     format('bad pressure for ',a9,1x,i2.2,i2.2)

         go to 700

 485     ibad=0

 
c  changed 14-Mar-2005 to process obs with bad wind but good temperature
c        if wind dir or speed bad or errorType = "W"
         if(winddir(i).lt.0.or.winddir(i).gt.360)     ibad=1
         if(windspeed(i).lt.0.or.windspeed(i).gt.200) ibad=1
c     if errtype is 87 ('W') or 66 ('B')...
         if(errortype(i).eq.87.or.errortype(i).eq.66) ibad = 1

         if(errortype(i).eq.87) then
c            write(6,4855) timeObs(i),tailnum(i),temperature(i),
c     *           errortype(i),winddir(i),windspeed(i)
 4855       format("bad W but good T: ",  
     *           f11.0,1x,a9,1x,f6.1,1x,i5,1x,f9.1,1x,f9.1)   
         endif

         if(ibad.eq.0) then 
            call dirspdtouv(winddir(i),windspeed(i),uobs,vobs)
c            write(25,4852) winddir(i),windspeed(i),uobs,vobs
 4852       format(4(f6.2,1x))
         else
            uobs = -99999.9
            vobs = -99999.9
            winddir(i)=-99999.9
            windspeed(i) = -99999.9
         endif

c        if bad temperature or errorType = "T"
         if(temperature(i).gt.400.or.temperature(i).lt.0.or.
     *      errortype(i).eq.84.or.errorType(i).eq.66) then
            temperature(i) = -99999.9
         endif
         
c
c
         rlon = longitude(i);
         if(rlon.lt.0) rlon = rlon + 360. 
         call rotll_geo_to_ij(latitude(i),rlon,lat_0_deg,lon_0_deg,
     *                        lat_g_SW_deg, lon_g_SW_deg,dxy_km,
     *                        rjy,rix)
c            write(*,4850) latitude(i),longitude(i),rix,rjy
 4850       format('.lat,lon,i,j',4(f8.2,1x))
c restrict to one less than max because bilin interp looks at
c i+1 and j+1
         if(rix.lt.0.or.rix.gt.nx13-1) rix = 99.9
         if(rjy.lt.0.or.rjy.gt.ny13-1) rjy = 99.9
c     
c     
         if(rix.eq.99.9.or.rjy.eq.99.9) go to 700

c        if errorType = "B' (both wind and temp)
         if(errortype(i).eq.66) go to 700
c
       
         if(errortype(i).eq.84) then
            write(6,4854) timeObs(i),tailnum(i),temperature(i),
     *           errortype(i),uobs
 4854       format("bad T but good W: ",
     *           f11.0,1x,a9,1x,f6.1,1x,i5,1x,f11.0)   
         endif
c     
c     save this acars data to be passed back
c     
         nn = nn + 1
         time(nn) = (ihr*100) + imin
         x(nn) = rix
         y(nn) = rjy
         p(nn) = pressure
         ht(nn) = GPSaltitude(i)
         u(nn) = uobs
         v(nn) = vobs
         cal_secs(nn) = timeObs(i)
         lat(nn) = latitude(i)
         lon(nn) = longitude(i)
         pi(nn) = pindex
         tn(nn) = tailnum(i)
         a_hdg(nn) = heading(i)
         a_mach(nn) = mach(i)
         tas(nn) = trueAirSpeed(i)
         data_source(nn) = dataSource(i)
         sdg_ap_id(nn) = sounding_airport_id(i)
         up_dn(nn) = sounding_flag(i)
         if(temperature(i).gt.0) then
            t(nn) = temperature(i) - 273.15
         else
            t(nn) = -99999.9
         endif
         if(downlinkedRH(i).lt.99998) then
            rh(nn) = downlinkedRH(i) * 100
         else
c  pick up rh from WVSS-2
            if(RHfromWVMR(i).lt.99998) then
               rh(nn) = RHfromWVMR(i) * 100
            else
              rh(nn) = 99999.
           endif
        endif 

c pick up rhUncertainty
        if(rhUncertainty(i).lt.99998) then
           rh_unc(nn) = rhUncertainty(i) * 100
        else
           rh_unc(nn) = 99999.
        endif
        if(cal_secs(i) .gt. 1136295854 .and. 
     .     cal_secs(i) .lt.1136295854+60)  then
           print *, tailnum(i),' ',cal_secs(i), latitude(i)
        endif
 700  continue
      num = nn
      istatus=0
c      close(25)
      write(6,679) nn,adate
 679  format(i4, ' acars in range for date = ',a9)
      istatus=0
      return
      end
c      
c************************************************************************
      subroutine i4time_to_adate(i4time,year,month,day,hours,minutes,
     1           seconds)
C
C This subroutine accepts as input the i4time (# of seconds since Jan
C 1, 1970) and outputs the elements of the date.
C
C Brian Jamison 18-Nov-1993
C
        real*8 i4time
        integer*4 year,month,day,hours,minutes,seconds,count,
     1            nmonth(12),nmonth_ly(12),daycount
        logical ly
        data nmonth/31,28,31,30,31,30,31,31,30,31,30,31/
        data nmonth_ly/31,29,31,30,31,30,31,31,30,31,30,31/
C
c        write(6,9) 
c 9      format(' input the i4time')
c        read(5,10) i4time
c 10     format(i9)
        count = 0
        year = 1970
        do while (i4time.ge.count)
          ly = .false.
          call leapyear_tf(year,ly)
          if (ly) then 
            count = count + 31622400
            lastcount = 31622400
          else
            count = count + 31536000
            lastcount = 31536000
          endif
          year = year + 1
        enddo
        count = count - lastcount
        year = year - 1
c
        daycount = 0
        do while (i4time.ge.count)
          daycount = daycount + 1
          count = count + 86400
        enddo
        daycount = daycount - 1
        count = count - 86400
c
        month = 0
        call leapyear_tf(year,ly)
        do while (daycount.ge.0)
          month = month + 1
          if (ly) then
            daycount = daycount - nmonth_ly(month)
            if (daycount.le.0) day = (nmonth_ly(month) + daycount) + 1
          else
            daycount = daycount - nmonth(month)
            if (daycount.le.0) day = (nmonth(month) + daycount) + 1
          endif
        enddo
c
        hours = 0
        do while (i4time.ge.count)
          count = count + 3600
          hours = hours + 1
        enddo
        count = count - 3600
        hours = hours - 1
c
        minutes = 0
        do while (i4time.ge.count)
          count = count + 60
          minutes = minutes + 1
        enddo
        count = count - 60
        minutes = minutes - 1
c
        seconds = i4time - count
c
c        write(6,100) i4time,year,month,day,hours,minutes,seconds
 100    format('i4time = ',i9,/,'year = ',i3,/,'month = ',i3,
     1  /,' day = ',i3,/,' hour = ',i3,/,' min = ',i4,/,'sec =',i4)
        return
        end
c
	subroutine leapyear_tf(iyear,ly)
c
c This subroutine will accept as input the day, month, and year and
c output the logical variable "ly" which will be true for leap year
C and false for other years. (Brian Jamison)
c
c Notes on input:
c
c   iyear  -  must be 4 digit integer (i.e. 1992 instead of 92)
c
c
        integer iyear
        logical yeardiv4,yeardiv100,yeardiv400,ly
c
c Initialize the logical variables
c
        yeardiv4 = .false.
        yeardiv100 = .false.
        yeardiv400 = .false.
c
c Test to see if the year is a leap year
c Leap year definition: If the year is evenly divisible by 4, it is a
c leap year unless it is a centenary year (i.e. 1800,1900, etc.).  However
c centenary years evenly divisible by 400 are leap years (e.g. 2000).
c
        if (mod(iyear,4).eq.0) yeardiv4 = .true.
        if (mod(iyear,100).eq.0) yeardiv100 = .true.
        if (mod(iyear,400).eq.0) yeardiv400 = .true.
c
        ly = .false.
        if (yeardiv4) then
          if ((yeardiv100).and.(.not.yeardiv400)) return
          ly = .true.
        endif
c
        return
        end
c************************************************************************
      REAL FUNCTION ZTOPSA(Z)

C*  This routine converts a height in meters into a pressure in a stand
Crd
C*  atmosphere in millibars.
C

      REAL T0,GAMMA,P0,P11,Z11,C1,C2,Z,FLAG,FLG

      DATA FLAG,FLG/99999.,99998./
      DATA T0,GAMMA,P0/288.,.0065,1013.2/
      DATA C1,C2/5.256,14600./
      DATA Z11,P11/11000.,226.0971/

      IF (Z.GT.FLG) THEN
          ZTOPSA=FLAG
        ELSE IF (Z.LT.Z11) THEN
          ZTOPSA=P0*((T0-GAMMA*Z)/T0)**C1
        ELSE
          ZTOPSA=P11*10.**((Z11-Z)/C2)
       END IF

      RETURN
      END
c**************************************************************************
c  
	SUBROUTINE DIRSPDTOUV(DIR,SPD,U,V)
C 
C**** CONVERTS ARRAYS OF DIRECTION AND SPEED DIMENSIONED TO JCOUNT
C**** ELEMENTS IN EACH ARRAY TO ARRAYS OF U AND V COORDINATES
C
        REAL*4 DIR,SPD,U,V
        REAL*4 THETA
C
C
          THETA=270.0-DIR
          IF (DIR.GE.0.0.AND.DIR.LE.90.0) THEN
            THETA=(DIR+90.0)*(-1.0)
          ENDIF
          U=COSD(THETA)*SPD
          V=SIND(THETA)*SPD
C
C
        RETURN
        END
C
      SUBROUTINE UVTODIRSPD(U,V,DIR,SPD)
C
      REAL U,V,DIR,SPD
C
C
        DIR = 270.0 - (ATAN2(V,U)) * 180.0/3.1415926
        IF (DIR.GT.360.0) THEN
          DIR = DIR - 360.0
        ELSE IF (DIR.LT.0.0) THEN
          DIR = DIR + 360.0
        ENDIF
        SPD = SQRT(U*U + V*V)
C
C
      RETURN
      END
c**************************************************
c*****************************************************
       SUBROUTINE W3FB11(ALAT,ELON,ALAT1,ELON1,DX,ELONV,ALATAN,XI,XJ)
C$$$   SUBPROGRAM  DOCUMENTATION  BLOCK
C
C SUBPROGRAM:  W3FB11        LAT/LON TO LAMBERT(I,J) FOR GRIB
C   PRGMMR: STACKPOLE        ORG: NMC42       DATE: 90-06-04
C
C ABSTRACT: CONVERTS THE COORDINATES OF A LOCATION ON EARTH GIVEN IN
C   THE NATURAL COORDINATE SYSTEM OF LATITUDE/LONGITUDE TO A GRID
C   COORDINATE SYSTEM OVERLAID ON A LAMBERT CONFORMAL TANGENT CONE
C   PROJECTION TRUE AT A GIVEN N OR S LATITUDE. W3FB11 IS THE REVERSE
C   OF W3FB12. USES GRIB SPECIFICATION OF THE LOCATION OF THE GRID
C
C PROGRAM HISTORY LOG:
C   88-11-25  ORIGINAL AUTHOR:  STACKPOLE, W/NMC42
C   88-12-05  R.E.JONES   CHANGE TO MICROSOFT FORTRAN 4.10
C   90-06-04  R.E.JONES   CHANGE TO SUN FORTRAN 1.3
C   91-03-29  R.E.JONES   CONVERT TO SiliconGraphics FORTRAN
C   93-03-29  R.E.JONES   ADD SAVE STATEMENT
C
C USAGE:  CALL W3FB11 (ALAT,ELON,ALAT1,ELON1,DX,ELONV,ALATAN,XI,XJ)
C   INPUT ARGUMENT LIST:
C     ALAT     - LATITUDE IN DEGREES (NEGATIVE IN SOUTHERN HEMIS)
C     ELON     - EAST LONGITUDE IN DEGREES, REAL*4
C     ALAT1    - LATITUDE  OF LOWER LEFT POINT OF GRID (POINT (1,1))
C     ELON1    - LONGITUDE OF LOWER LEFT POINT OF GRID (POINT (1,1))
C                ALL REAL*4
C     DX       - MESH LENGTH OF GRID IN METERS AT TANGENT LATITUDE
C     ELONV    - THE ORIENTATION OF THE GRID.  I.E.,
C                THE EAST LONGITUDE VALUE OF THE VERTICAL MERIDIAN
C                WHICH IS PARALLEL TO THE Y-AXIS (OR COLUMNS OF
C                OF THE GRID) ALONG WHICH LATITUDE INCREASES AS
C                THE Y-COORDINATE INCREASES.  REAL*4
C                THIS IS ALSO THE MERIDIAN (ON THE BACK SIDE OF THE
C                TANGENT CONE) ALONG WHICH THE CUT IS MADE TO LAY
C                THE CONE FLAT.
C     ALATAN   - THE LATITUDE AT WHICH THE LAMBERT CONE IS TANGENT TO
C                (TOUCHING) THE SPHERICAL EARTH.
C                 SET NEGATIVE TO INDICATE A
C                 SOUTHERN HEMISPHERE PROJECTION.
C
C   OUTPUT ARGUMENT LIST:
C     XI       - I COORDINATE OF THE POINT SPECIFIED BY ALAT, ELON
C     XJ       - J COORDINATE OF THE POINT; BOTH REAL*4
C
C   REMARKS: FORMULAE AND NOTATION LOOSELY BASED ON HOKE, HAYES,
C     AND RENNINGER'S "MAP PROJECTIONS AND GRID SYSTEMS...", MARCH 1981
C     AFGWC/TN-79/003
C
C ATTRIBUTES:
C   LANGUAGE: SiliconGraphics 3.5 FORTRAN 77
C   MACHINE:  SiliconGraphics IRIS-4D/25, 35, INDIGO
C
C$$$
C
         SAVE
C
         DATA  RERTH /6.3712E+6/, PI/3.14159/
C
C        PRELIMINARY VARIABLES AND REDIFINITIONS
C
C        H = 1 FOR NORTHERN HEMISPHERE; = -1 FOR SOUTHERN
C
         IF (ALATAN.GT.0) THEN
           H =  1.0
         ELSE
           H = -1.0
         ENDIF
C
         RADPD  = PI / 180.0
         REBYDX = RERTH / DX
         ALATN1 = ALATAN * RADPD
         AN     = H * SIN(ALATN1)
         COSLTN = COS(ALATN1)
C
C        MAKE SURE THAT INPUT LONGITUDES DO NOT PASS THROUGH
C        THE CUT ZONE (FORBIDDEN TERRITORY) OF THE FLAT MAP
C        AS MEASURED FROM THE VERTICAL (REFERENCE) LONGITUDE.
C
         ELON1L = ELON1
         IF ((ELON1 - ELONV).GT.180.)
     &     ELON1L = ELON1 - 360.
         IF ((ELON1 - ELONV).LT.(-180.))
     &     ELON1L = ELON1 + 360.
C
         ELONL = ELON
         IF ((ELON  - ELONV).GT.180.)
     &     ELONL  = ELON  - 360.
         IF ((ELON - ELONV).LT.(-180.))
     &     ELONL = ELON + 360.
C
         ELONVR = ELONV * RADPD
C
C        RADIUS TO LOWER LEFT HAND (LL) CORNER
C
         ALA1 =  ALAT1 * RADPD
         RMLL = REBYDX * (((COSLTN)**(1.-AN))*(1.+AN)**AN) *
     &           (((COS(ALA1))/(1.+H*SIN(ALA1)))**AN)/AN
C
C        USE LL POINT INFO TO LOCATE POLE POINT
C
         ELO1  = ELON1L * RADPD
         ARG   = AN * (ELO1-ELONVR)
         POLEI = 1. - H * RMLL * SIN(ARG)
         POLEJ = 1. + RMLL * COS(ARG)
C
C        RADIUS TO DESIRED POINT AND THE I J TOO
C
         ALA =  ALAT * RADPD
         RM  = REBYDX * ((COSLTN**(1.-AN))*(1.+AN)**AN) *
     &           (((COS(ALA))/(1.+H*SIN(ALA)))**AN)/AN
C
         ELO = ELONL * RADPD
         ARG = AN * (ELO-ELONVR)
         XI  = POLEI + H * RM * SIN(ARG)
         XJ  = POLEJ - RM * COS(ARG)
C
C        IF COORDINATE LESS THAN 1
C        COMPENSATE FOR ORIGIN AT (1,1)
C
         IF (XI.LT.1.)  XI = XI - 1.
         IF (XJ.LT.1.)  XJ = XJ - 1.
C
      RETURN
      END


c***********************************************************
	subroutine bilin_maps_sfc(nx,ny,z,ix,jy,result)
c
c	z	input	real array	2-d grid to interpolate from
c	ix,jy   input	real            MAPS i,j to interpolate to
c	result	output	real    	interpolated data
c
        parameter (rmsg = -9999.9)
        parameter (boundscheck = 1.0e+10)
c        parameter (lx60 = 26, ly60 = 21)
c        parameter (lx40 = 36, ly40 = 34)
c
c       integer*4 lx,ly,lrec
        real*4 dx,dy,z(nx,ny),ix,jy,result
c
c Local Variables
c
	integer*4 i,j
c        real*4 rmsg
c
c Find out the grid point southwest of the user-supplied point.
c
        i = int(ix)
        j = int(jy)
        if(i.lt.1 .or. j.lt.1 .or. i.gt.nx-1 .or. j.gt.ny-1) then
           result =  -99999.9
          go to 111
        endif

c        write(42,1001) i,j,z(i,j)+273.15
 1001   format('.interp SW ',i3,1x,i3,1x,f9.3)

c Figure out some constants needed for the bi-linear interpolation.
c
        xfrac = (ix - float(i)) 
        yfrac = (jy - float(j))
        
c
	z1 = z(i,j)            			! SW of desired point
	z2 = z(i+1,j)      			! SE  "    "      "
	z3 = z(i+1,j+1)	        		! NE  "    "      "
	z4 = z(i,j+1)         			! NW  "    "      "
c
	if (z1.gt.boundscheck .or. z2.gt.boundscheck .or.
     1      z3.gt.boundscheck .or. z4.gt.boundscheck) then
          result = -99999.9
          go to 111
        endif
c
c Do the interpolation
c
	za=z1+(z2-z1)*xfrac 				! za is S of desired pt
	zb=z4+(z3-z4)*xfrac 				! zb is N of desired pt
	result=za+(zb-za)*yfrac
c
  111   continue	
	return
	end
c**************************************************************
