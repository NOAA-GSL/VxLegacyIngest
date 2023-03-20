C$$$   SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    GTRESIDS_sfc_tquv    CALCULATE OBSERVATION RESIDS for sfc
C                                         T/q/u/v 
C   PRGMMR:  BENJAMIN, STAN ORG: ERL/PROFS      DATE: 93-01-18
C
C ABSTRACT:  CALCULATE OBSERVATION RESIDUALS, DEFINED AS THE
C            DIFFERENCE BETWEEN THE OBSERVED VALUE AND THE BACKGROUND
C            FIELD INTERPOLATED HORIZONTALLY AND VERTICALLY (IF
C            NECESSARY) TO THE OBSERVATION LOCATION.
C
C PROGRAM HISTORY LOG:
C    85           S. BENJAMIN     ORIGINAL VERSION
C    01-28-97     S. Benjamin     3d variational version
C
C USAGE:   CALL    GTRESIDS (
C                                       ! Input
C     1  NBRSTA, OI,     OJ,     O,     OTYPE,
C     1  G3,     NX,     NY,     NZT,
C                                       ! Output
C     1  RESID,  OK)
C
C   INPUT ARGUMENT LIST:
C     NBRSTA   - INTEGER  OVERALL NUMBER OF STATIONS - ALL TYPES
C     OI       - REAL     OBSERVATION GRID-POINT LOCATION IN X-DIRECTION
C     OJ       - REAL     OBSERVATION GRID-POINT LOCATION IN Y-DIRECTION
C     O        - REAL     OBSERVATION VALUE
C     G3       - REAL     3-D BACKGROUND GRID FOR ALL VARIABLES
C     NX       - INTEGER  NO. OF GRID POINTS IN X-DIRECTION
C     NY       - INTEGER  NO. OF GRID POINTS IN Y-DIRECTION
C     NZT      - INTEGER  NO. OF GRID POINTS IN Z-DIRECTION
C   OUTPUT ARGUMENT LIST:
C     RESID    - REAL     OBSERVATION RESIDUALS
C     OK       - REAL     OBSERVATION GRID-POINT LOCATION IN K-DIMENSION
C
C REMARKS: NONE
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN-77 + EXTENSIONS
C   MACHINE: DEC - VAX, VMS
C
C$$$
        SUBROUTINE GTRESIDS_sfc_tquv (
C                                       ! Input
     1  NBRSTA, OI,     OJ,     ok,O,   OQC,    OTYPE,  oid,
     1  Gsfc,   psfc,   ulev1,  vlev1,  thvlev1, NX,     NY,     NZT,
     1  xland,  ylat,   ylon,
C                                       ! Output
     1  RESID,  resid_speed)

C      PURPOSE: CALCULATE RESIDUALS (observed value minus
C        first guess value) AT OBSERVATION SITES

C       HISTORY

        INCLUDE 'IMPLICIT'
        INCLUDE 'MAPSCON'
        INCLUDE 'METCON'

        INTEGER  NX, NY, NZT
        INTEGER  OQC(NVAR_P,MXST_P)
        INTEGER  NBRSTA                 
C Overall number of stations - all types

        INTEGER ISTA,IVAR,I,J,k,i1,i2,j1,j2,ia,ib,ja,jb,iw,jw
        INTEGER jmax,jmin
        INTEGER QCFLAG,ISTAT,ilandwater_change,ilandwater_count
        
        REAL    Psfc(NX_p,NY_p) 
        REAL    Ulev1(NX_p,NY_p) 
        REAL    Vlev1(NX_p,NY_p) 
        REAL    thVlev1(NX_p,NY_p) 
        REAL    xland(NX_p,NY_p) 
        REAL    Gsfc(NX_p,NY_p,mxvr_P) 
C Gridded field (guess and analysis)
     1  ,O (NVAR_P,MXST_P)  
C Observation values
     1  ,OI(MXST_P)             
C Observation X index
     1  ,OJ(MXST_P)             
C Observation Y index
     1  ,Ok(MXST_P)             
     1  ,RESID(NVAR_P,MXST_P) 
     1  ,RESID_speed(MXST_P)

C Observation minus guess at obs pts
     1  ,ylat(mxst_p)
     1  ,ylon(mxst_p)

        CHARACTER OID(MXST_P)*(LSTAID_P)


        INTEGER OTYPE(MXST_P)
        integer nobs   (10)
        real resid_tot (10,2)
        real resid2_tot(10,2)
        real resid_spd,x,y,t_bkg,q_bkg,u_bkg,v_bkg,p_bkg,thv_bkg
     1     ,spd_bkg,spd_ob,u_bkg_orig, v_bkg_orig, spd_bkg_orig
        real t_bkg1,q_bkg1,u_bkg1,p_bkg1,v_bkg1,resid1,thv_bkg1, resid2
        real t_bkg2,q_bkg2,u_bkg2,v_bkg2,thv_bkg2,p_bkg2
        real xlandmax, xlandmin, totresid_landwater(nvar_p,2)
        real xlandmaxa, xlandmina


         do ivar = 3,7
           nobs(ivar) = 0.
           do k=1,2
             resid_tot (ivar,k) = 0.
             resid2_tot(ivar,k) = 0.
           end do
         end do

          write (6,*) '     '
          write(6,*) '----------------------------------------------'
          write(6,*) 'Sample sfc resids before/after 2m/10m adjust'
          write(6,*) '----------------------------------------------'
          write(6,*)
     1  '  Theta-v         ln q            u',
     1  '            v  '
          write(6,*) '----------------------------------------------'

C -- stats for resids for coastal sfc stations
         ilandwater_count = 0
         do k = 1,2
         do ivar = 3,6
           totresid_landwater(ivar,k) = 0.
         end do
         end do

         DO 1000 ISTA=1,NBRSTA
          ilandwater_change = 0
          if (int(otype(ista)/100) .ne. sfc_p ) go to 1000
          if (ok(ista).gt.1.1 ) go to 1000
           

c         if (mod(ista,100).eq.0) then
c           write(6,505) oid(ista),(resid(ivar,ista),ivar=3,6)
c         end if
505         format (a5,2x,4(f9.2,2x) )

          X = OI(ISTA)
          Y = OJ(ISTA)

          call interp_bicubic_point(x,y,gsfc(1,1,43),gsfc(1,1,44),
     1       t_bkg,q_bkg, nx_p,ny_p)
          call interp_bicubic_point(x,y,gsfc(1,1,43),psfc,
     1       t_bkg,p_bkg, nx_p,ny_p)
          call interp_bicubic_point(x,y,gsfc(1,1,45),gsfc(1,1,46),
     1       u_bkg,v_bkg, nx_p,ny_p)
          call interp_bicubic_point(x,y,ulev1,vlev1,
     1       u_bkg_orig,v_bkg_orig, nx_p,ny_p)


C --- otype-520 = buoy
C     buoy winds are at 5m, not 10 m elevation
          if (otype(ista).eq.520.or.otype(ista).eq.572
     1      .or. otype(ista).eq.571
     1      .or. otype(ista).eq.570
     1         ) then
               u_bkg = u_bkg_orig
               v_bkg = v_bkg_orig
          end if

C -- present bkg1 and bkg2 values, to be superceded below
C       if appropriate
               t_bkg1 = t_bkg
               q_bkg1 = q_bkg
               p_bkg1 = p_bkg
               u_bkg1 = u_bkg
               v_bkg1 = v_bkg

               t_bkg2 = t_bkg
               q_bkg2 = q_bkg
               p_bkg2 = p_bkg
               u_bkg2 = u_bkg
               v_bkg2 = v_bkg

C --- Use land or buoys only with all land or water background
          i1 = int(oi(ista))
          i2 = min(nx_p,i1 + 1)
          j1 = int(oj(ista))
          j2 = min(ny_p,j1 + 1)

          ia = max(i1-1,1)
          ja = max(j1-1,1)
          ib = min(i2+1,nx_p)
          jb = min(j2+1,ny_p)

C -- xlandmax(min)a is for max/min land-use
C        with extended box using not just surrounding
C        grid points from a station but one dx further
C        to a 4x4 box
          xlandmina= 10.
          xlandmaxa= -1.
          do j=ja,jb
          do i=ia,ib
            xlandmina= min(xlandmina,xland(i,j) )
            xlandmaxa= max(xlandmaxa,xland(i,j) )
          end do
          end do

          xlandmin = 
     1      min(xland(i1,j1),xland(i2,j1),xland(i1,j2),xland(i2,j2))
          xlandmax = 
     1      max(xland(i1,j1),xland(i2,j1),xland(i1,j2),xland(i2,j2))

C --- if otype is NOT buoy (land)  [otype-520 = buoy]
          if (otype(ista).ne.520) then
            if (xlandmaxa.eq.0.) then
               if (o(h_p,ista).lt.13.) go to 600
               write(6,506) oid(ista),ylat(ista),ylon(ista),o(h_p,ista)
506            format 
     1          ('Land station surrounded by model water - ',a9, 3f8.2)
            write(6,*)i1,j1,i2,j2,oi(ista),oj(ista)
            jmax=min(j2+2,nx_p)
            jmin=max(1,j1-2)
            do j=jmax,jmin,-1
            write(6,13)j,xland(i1-2,j),xland(i1-1,j),xland(i1,j),
     1          xland(i2,j),xland(i2+1,j),xland(i2+2,j)
            end do

C --- Key threshold in next line -- use land obs (METARs) over water
C       as long as elevation is less than 35 m
C       (i.e., not 'too far' above sea level)
            if (o(h_p,ista).lt.35.) then

               write(6,*)'OK, over ocean'
c              write(6,506) oid(ista),ylat(ista),ylon(ista),o(h_p,ista)
              go to 1000
            end if
            if (o(h_p,ista).gt.150. .and. o(h_p,ista).lt.250.
     1            .and. ylat(ista).gt.41.4
     1            .and. ylat(ista).lt.49.
     1            .and. ylon(ista).gt.-92.
     1            .and. ylon(ista).lt.-72.
     1              ) then
               write(6,*)'OK, over Great Lakes'
              go to 1000
            end if

C        flag out any obs for land station surrounded by model water
               do ivar = 1,7
                 resid(ivar,ista) = spval_p 
               end do

               go to 1000
            end if
            if (xlandmin.eq.0.) then
c              write(6,507) oid(ista),oi(ista),oj(ista)
507            format 
     1          ('Land station w/ water point nearby     - ',a9, 2f7.2)
c              write(6,5061) oid(ista),ylat(ista),ylon(ista),o(h_p,ista)
5061            format 
     1          ('Land station w/ water point nearby - ',a9, 3f8.2)
c           write(6,*)i1,j1,i2,j2,oi(ista),oj(ista)
c           do j=j2+2,j1-2,-1
c           write(6,13)j,xland(i1-2,j),xland(i1-1,j),xland(i1,j),
c    1          xland(i2,j),xland(i2+1,j),xland(i2+2,j)
c           end do
c           do j=j2+2,j1-2,-1
c           write(6,13)j,psfc(i1-2,j),psfc(i1-1,j),psfc(i1,j),
c    1          psfc(i2,j),psfc(i2+1,j),psfc(i2+2,j)
c           end do
               do j=j1,j2
               do i=i1,i2
                 if (xland(i,j).ne.0.) go to 5071
               end do
               end do
               i=i-1
               j=j-1
5071           continue

C  --- Now, let's look for the nearest fully water point, which may
C        fit the METAR/land ob much better than the interpolated value
C        from a combination of land and water points
               do jw=j1,j2
               do iw=i1,i2
                 if (xland(iw,jw).lt.0.5) go to 5072
               end do
               end do
               iw = i
               jw = j
5072           continue
               ilandwater_change = 1
c              write(6,*)t_bkg,q_bkg,u_bkg,v_bkg
               t_bkg1 = gsfc(i,j,43)
               q_bkg1 = gsfc(i,j,44)
C -- take original interpolated pressure value so as to not make
C        theta-v from bkg any more inconsistent than is necessary
               p_bkg1 = psfc(i,j)
               u_bkg1 = gsfc(i,j,45)
               v_bkg1 = gsfc(i,j,46)
c              write(6,*)t_bkg1,q_bkg1,u_bkg1,v_bkg1

               p_bkg2 = psfc(iw,jw)
               t_bkg2 = gsfc(iw,jw,43)
               q_bkg2 = gsfc(iw,jw,44)
               u_bkg2 = gsfc(iw,jw,45)
               v_bkg2 = gsfc(iw,jw,46)
            end if
          end if
            
C --- If buoy station...
          if (otype(ista).eq.520) then
            if (xlandmin.gt.0.) then
               write(6,508) oid(ista),ylat(ista),ylon(ista)
508            format 
     1          ('Buoy station surrounded by model land  - ',a9, 2f7.2)
C        flag out any obs for buoy station surrounded by model land
            write(6,*)i1,j1,i2,j2, oi(ista),oj(ista)
            jmax=min(j2+2,nx_p)
            jmin=max(1,j1-2)
            do j=jmax,jmin,-1
            write(6,13)j,xland(i1-2,j),xland(i1-1,j),xland(i1,j),
     1          xland(i2,j),xland(i2+1,j),xland(i2+2,j)
13          format (i5, 6f6.0)
            end do
               do ivar = 1,7
                 resid(ivar,ista) = spval_p 
               end do

               go to 1000
            end if
            if (xlandmax.gt.0.) then
c              write(6,509) oid(ista),oi(ista),oj(ista)
509            format 
     1          ('Buoy station w/ land  point nearby     - ',a9, 2f7.2)
               do j=j1,j2
               do i=i1,i2
                 if (xland(i,j).eq.0.) go to 5091
               end do
               end do
5091           continue
c              write(6,*)t_bkg,q_bkg,u_bkg,v_bkg
               ilandwater_change = 1
               t_bkg1 = gsfc(i,j,43)
               q_bkg1 = gsfc(i,j,44)
               p_bkg1 = psfc(i,j)

C -- For buoys:
C -- use 5m wind from ulev1,vlev1, not 10m wind in gsfc(45/46)
               u_bkg1 = ulev1(i,j)
               v_bkg1 = vlev1(i,j)
c              write(6,*)t_bkg1,q_bkg1,u_bkg1,v_bkg1
            end if
          end if

600       continue
            

          if (ilandwater_change.eq.1) then
c           write(6,505) oid(ista),(resid(ivar,ista),ivar=3,6)
            ilandwater_count = ilandwater_count + 1
            do ivar=3,6
              if (abs(resid(ivar,ista)).lt.90000.) 
     1        totresid_landwater(ivar,1) = totresid_landwater(ivar,1)
     1          + abs(resid(ivar,ista) )
            end do
          end if

          thv_bkg = t_bkg*(1000./p_bkg)**rovcp_p
     1       * (1. + 0.6078*q_bkg)
          thv_bkg1 = t_bkg1*(1000./p_bkg1)**rovcp_p
     1       * (1. + 0.6078*q_bkg1)
          thv_bkg2 = t_bkg2*(1000./p_bkg2)**rovcp_p
     1       * (1. + 0.6078*q_bkg2)
          q_bkg = alog(max(0.00005,q_bkg))
          q_bkg1 = alog(max(0.00005,q_bkg1))
          q_bkg2 = alog(max(0.00005,q_bkg2))

          do ivar = 3,6
           CALL CHCKQC (OQC(IVAR,ISTA), MSTRBAD_P,
     1                   QCFLAG, ISTAT)
           IF (O(IVAR,ISTA).LE.99990.  .AND.
     1                 QCFLAG .EQ. 0) THEN

           nobs(ivar) = nobs(ivar) + 1
           resid_tot(ivar,1) = resid_tot(ivar,1) + resid(ivar,ista)
           resid2_tot(ivar,1) = resid2_tot(ivar,1) + resid(ivar,ista)**2
          

            if (ivar.eq.theta_p) then
            if (oid(ista)(1:4).eq.'KSBA')
     1        write (6,*)'KSBA',o(theta_p,ista),thv_bkg,thv_bkg1,
     1           thv_bkg2,thvlev1(i,j),thvlev1(iw,jw),resid(theta_p,ista)
     1           ,psfc(i,j),psfc(iw,jw)
             if (xland(i1,j1).ne.0.) then
              resid(theta_p,ista) = o(theta_p,ista) - thv_bkg
             end if
              resid1 = o(theta_p,ista) - thv_bkg1
              resid2 = o(theta_p,ista) - thv_bkg2
              if (abs(resid(theta_p,ista)) .gt. abs(resid1) ) then
                resid(theta_p,ista) = resid1
                q_bkg = q_bkg1
                u_bkg = u_bkg1
                v_bkg = v_bkg1
              end if
              if (abs(resid(theta_p,ista)) .gt. abs(resid2) ) then
                resid(theta_p,ista) = resid2
                q_bkg = q_bkg2
                u_bkg = u_bkg2
                v_bkg = v_bkg2
              end if
            end if
c           if (ivar.eq.qv_p   ) resid(qv_p,ista) 
c    1           = o(qv_p,ista) - q_bkg
            if (ivar.eq.u_p    ) then
                 spd_bkg = sqrt(u_bkg**2 + v_bkg**2)
                 spd_bkg_orig = sqrt(u_bkg_orig**2 + v_bkg_orig**2)
                 spd_ob  = sqrt(o(u_p,ista)**2 + o(v_p,ista)**2)
                 resid_spd = spd_ob - spd_bkg_orig
                 resid_tot(7,1) = resid_tot(7,1)+resid_spd
                 resid2_tot(7,1) = resid2_tot(7,1)+resid_spd**2
                 resid_spd = spd_ob - spd_bkg
                 resid_tot(7,2) = resid_tot(7,2)+resid_spd
                 resid2_tot(7,2) = resid2_tot(7,2)+resid_spd**2

                 resid(u_p,ista) = o(u_p,ista) - u_bkg
                 resid_speed(ista) = spd_ob - spd_bkg
            end if
            if (ivar.eq.v_p) then
                 resid(v_p,ista) = o(v_p,ista) - v_bkg
            end if     

           resid_tot(ivar,2) = resid_tot(ivar,2) + resid(ivar,ista)
           resid2_tot(ivar,2) = resid2_tot(ivar,2) + resid(ivar,ista)**2

           end if
          end do

          if (ilandwater_change.eq.1) then
c           write(6,505) oid(ista),(resid(ivar,ista),ivar=3,6)
            do ivar=3,6
              if (abs(resid(ivar,ista)).lt.90000.) 
     1        totresid_landwater(ivar,2) = totresid_landwater(ivar,2)
     1          + abs(resid(ivar,ista) )
            end do
          end if

c         if (mod(ista,10).eq.0) then
c           write(6,505) oid(ista),(resid(ivar,ista),ivar=3,6)
c         end if

1000    continue

          write (6,*) '     '
          write (6,*) '     '
          write(6,*) '----------------------------------------------'
          write(6,*) 'Mean abs residuals for coastal sfc stations'
          write(6,*) '----------------------------------------------'
          write(6,*)' Row 1 - Before matching land/water type'
          write(6,*)' Row 2 - After  matching land/water type'
          write (6,*) '     '
          write(6,*)
     1  '  Theta-v         ln q            u',
     1  '            v     '
          do i=1,2
          write(6,1010) 
     1     (totresid_landwater(ivar,i)/max(1.,
     1          float(ilandwater_count)),ivar=3,6)
1010      format (' ',4(f9.3,6x) )
          end do

          nobs(7) = nobs(6)

          write (6,*) '     '
          write (6,*) '     '
          write(6,*) '----------------------------------------------'
          write(6,*) 'Mean/RMS residuals for sfc stations'
          write(6,*) '----------------------------------------------'
          write(6,*)' Row 1 - No. of obs for each variable'
          write(6,*)' Row 2 - Background = RUC native level 1'
          write(6,*)' Row 3 - Background = t/q at 2m, u/v at 10m'
          write (6,*) '     '
          write(6,*)
     1  '  Theta-v         RH              u',
     1  '            v             spd'
          write(6,*) '----------------------------------------------'
          write(6,1020) (nobs(ivar),ivar=3,6)
1020      format (' ',4(i9,6x) )
        do k=1,2
          do ivar=3,7
            if (nobs(ivar).gt.0) then
             resid_tot(ivar,k) = resid_tot(ivar,k)/max(1.,
     1          float(nobs(ivar)))
             resid2_tot(ivar,k)=sqrt(resid2_tot(ivar,k)/
     1               max(1.,float((nobs(ivar)-1))))
            end if
          end do
          write (6,*) '     '
          write(6,*) '----------------------------------------------'
          write (6,1050) (resid_tot(ivar,k),resid2_tot(ivar,k),ivar=3,7)
1050      format (' ',5(f5.2,1x,f5.2,4x) )
        end do
          write(6,*) '----------------------------------------------'
          write (6,*) '     '


        RETURN
        END
