C$$$   SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    EXSFCOBS    EXTRAPOLATE SFC OBSERVATIONS
C
C   PRGMMR:  BENJAMIN, STAN ORG: ERL/PROFS      DATE: 93-01-18
C
C ABSTRACT:  FOR OBS WHICH HAVE A SURFACE PRESSURE WHICH IS
C       GREATER THAN THAT OF THE BACKGROUND FIELD INTERPOLATED TO THE
C       OBSERVATION LOCATION, EXTRAPOLATE SFC VALUES OF P, M, THETA,
C       AND PC BACK UP TO TO THE INTERPOLATED GRID POINT TERRAIN AT THE
C       OBSERVATION POINT.
C
C PROGRAM HISTORY LOG:
C    90-03-23       S. BENJAMIN     ORIGINAL VERSION
C
C USAGE:           CALL         EXSFCOBS (
C     1  NBRSTA, OI,     OJ,     OTYPE,  O,      OID,
C     1  OQC,    G3,     TOPO,   NX,     NY,     NZT)
C
C
C   INPUT ARGUMENT LIST:
C     NBRSTA   - INTEGER  TOTAL NO. OF OBS USED IN ANALYSIS
C     OI       - REAL     OB I COORDINATE
C     OJ       - REAL     OB J COORDINATE
C     OTYPE    - INTEGER  TYPE OF OBSERVATIONS
C     O        - REAL     OBSERVATION VALUES
C     OID      - CHAR*5   OBSERVATION IDs
C     OQC      - INTEGER  OBSERVATION QUALITY FLAG
C     G3       - REAL     GRID POINT VALUES OF ALL VARIABLES
C     TOPO     - REAL     GRID POINT ELEVATIONS
C     NX       - INTEGER  NO. OF POINTS IN X DIRECTION
C     NY       - INTEGER  NO. OF POINTS IN Y DIRECTION
C     NZT      - INTEGER  NO. OF LEVELS
C   OUTPUT ARGUMENT LIST:
C
C REMARKS: NONE
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN-77 + EXTENSIONS
C   MACHINE: DEC - VAX, VMS
C
C$$$
 
        SUBROUTINE EXSFCOBS (
     1  NBRSTA, OI,     OJ,     OTYPE,  O,      OID,
     1  OQC,    G3,     NX,     NY,     NZT)


C       PURPOSE: For obs which have a surface pressure which is
C       greater than that of the background field interpolated to the
C       observation location, extrapolate sfc values of p, M, theta,
C       and Pc back up to to the interpolated grid point terrain at the
C       observation point.

C       HISTORY
C    23 Mar 1990        S. Benjamin     Original version
C    23 Mar 1990        S. Benjamin     Extrapolated sfc data with psfc
C                                        > psfc(background) back to
C                                        interpolated grid point topo
C    14 Mar 1991        S. Benjamin     Changed so that there is no
C                                        extrapolation of sfc theta,M,P
C                                        unless SAO sfc p is within
C                                        10 mb of model background sfc p.

        INCLUDE 'IMPLICIT'
        INCLUDE 'MAPSCON'
        INCLUDE 'METCON'
        INCLUDE 'OAFCPRMS'

        INTEGER  NBRSTA
C Overall number of stations - all types
        INTEGER  NX, NY, NZT
     1  ,OQC (NVAR_P,MXST_P)
C Observation Quality flag
     1  ,OTYPE(MXST_P)
C Observation source type
     
        REAL    G3(NX,NY,NZT,NVAR3_P)
C Gridded field (guess and analysis)
     1  ,O (NVAR_P,MXST_P)
C Observation values
     1  ,OI(MXST_P)
C Observation X index
     1  ,OJ(MXST_P)
C Observation Y index

         CHARACTER OID(MXST_P)*(LSTAID_P)
C Observation ID's



C*** Local variables
        INTEGER QCP,QCTH,QCPC,QCP_BOG

        INTEGER ISTA,I,J,IP1,JP1,ISTAT
     1       ,IP2,JP2,IP3,JP3,ia,ja
        INTEGER IC,IC1,IC3,IC5,IC7,IC9
        INTEGER ICE,ICE1,ICE3,ICE5,ICE7,ICE9

        REAL    ZOB
        REAL  X,Y
     1       ,EXN
     1       ,TEMP,TEMP1,t1,t5,z1,z5,exn1,exn5,gam,gamd,rgam
     1       ,gami,pdiff,pdiff1,PG,eold,enew,esold,esnew,rhcon,esw,thg
     1       ,FAC,DZ,ZI,ZJ,tnvold,tnvnew,rold,rnew,thvold,thvnew

        data gamd /0.0100/
        data gami /0.0005/


C*** Start program by initializing counters
        IC=0
        IC1=0
        IC3=0
        IC5=0
        IC7=0
        IC9=0
        ICE=0
        ICE1=0
        ICE3=0
        ICE5=0
        ICE7=0
        ICE9=0

         DO 1000 ISTA=1,NBRSTA
          IF (OTYPE(ISTA)/100.EQ.SFC_P) THEN
          call interp_bicubic_point( oi(ista),oj(ista),g3(1,1,1,p_p),
     1              g3(1,1,1,theta_p), pg, thg, nx_p,ny_p)
          ia = int(oi(ista)+0.5)
          ja = int(oj(ista)+0.5)

                 CALL CHCKQC (OQC(P_P,ISTA),     MSTRBAD_P,
     1                   QCP, ISTAT)
                 CALL CHCKQC (OQC(P_P,ISTA),     bogsnmc_P,
     1                   QCP_bog, ISTAT)
                 CALL CHCKQC (OQC(THETA_P,ISTA), MSTRBAD_P,
     1                   QCTH, ISTAT)

C *** Check to see how much sfc data is getting through
C      west of some OI grid point.  This is to see how much
C      sfc data is getting thrown out by condition that
C      sfc ob must be within 50 mb of model sfc pressure.
                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1   oi(ista).lt.104.) ic = ic + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.10.
     1   .and. oi(ista).lt.104.) ic1 = ic1 + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.30.
     1   .and. oi(ista).lt.104.) ic3 = ic3 + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.50.
     1   .and. oi(ista).lt.104.) ic5 = ic5 + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.70.
     1   .and. oi(ista).lt.104.) ic7 = ic7 + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.90.
     1   .and. oi(ista).lt.104.) ic9 = ic9 + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1   oi(ista).ge.104.) ice = ice + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.10.
     1   .and. oi(ista).ge.104.) ice1 = ice1 + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.30.
     1   .and. oi(ista).ge.104.) ice3 = ice3 + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.50.
     1   .and. oi(ista).ge.104.) ice5 = ice5 + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.70.
     1   .and. oi(ista).ge.104.) ice7 = ice7 + 1

                 IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0 .AND.
     1       ABS(O(P_P,ISTA)-PG).LT.90.
     1   .and. oi(ista).ge.104.) ice9 = ice9 + 1

C *** Only use sfc theta and pc if within 70 mb of ground
C     Keep theta, but flag with bogusnmc_p, so that it can be
C       used for vertical correlations in analysis for this ob.
                 pdiff1 = o(p_p,ista) - pg
                 pdiff = abs (pdiff1)

C ***  In this version of exsfcobs.f,
C      we are trying to use as much sfc data as possible and
C      not excluding data because of difference between station
C      and model sfc pressure unless absolutely necessary.

C      Current strategy:
C       use winds, p/z for ALL sfc obs
C         use z even if sfc t is missing if within 20 mb of sfc
C           so that reduction error from using stand atm. T is
C           not too large
C       use theta, pc if abs(stn pres - model prs) < 70 mb
C       even if abs diff > 70 mb, we still keep theta but
C        assign it the bogusnmc_p flag so that it is available
C        to set vertical correlations in the analysis but it is
C        not actually used itself. 

               IF (O(P_P,ISTA)    .LE.99990.  .AND.
     1       O(THETA_P,ISTA).LE.99990.  .AND.
     1            QCP .EQ. 0 .AND. QCTH .EQ. 0
     1            .and. qcp_bog.eq.0) then

                 IF (O(THETA_P,ISTA).LE.99990.) THEN
                   EXN = (O(P_P,ISTA)/1000.)**ROVCP_P
                   TEMP = O(THETA_P,ISTA)*EXN
                   thvold = O(THETA_P,ISTA)
                 ELSE IF (ABS(O(P_P,ISTA)-PG).LT.20.) THEN  
C          -- use std atmos sfc temp for reducing z to
C              model sfc if within 20 mb
                   TEMP = 273.
                 END IF
                   exn1 = (g3(ia,ja,1,p_p)/1000.)**rovcp_p
                   exn5 = (G3(ia,ja,5,p_p)/1000.)**rovcp_p
                   t1 = G3(ia,ja,1,theta_p)*exn1
                   t5 = G3(ia,ja,5,theta_p)*exn5
                   z1 = G3(ia,ja,1,h_p) 
                   z5 = G3(ia,ja,5,h_p) 
                   gam = (t1-t5)/(z5-z1)
                   gam = min(gamd,max(gam,gami))
                   rgam = rd_p*gam/g0_p

C -- PG is sfc pres from bkg interp. to obs location
                   FAC = (PG/O(P_P,ISTA))**rgam

                   TEMP1 = TEMP*FAC
                   O(THETA_P,ISTA) = TEMP1*(1000./PG)**ROVCP_P
                   thvnew = O(THETA_P,ISTA)
                   DZ = TEMP/GAM*(1.-FAC)
                   ZOB = O(H_P,ISTA) + DZ
                   O(H_P,ISTA) = ZOB
C -- o(h,ista) (z obs) is now what the station elevation would be
C      if the sfc ob is reduced to the bkg pressure.
C      This is in preparation for the z/u/v analysis ahead.

                 if (pdiff.gt.25.) o(qv_p,ista) = spval_p

c                if (o_qv_p,ista).lt.99990.) then
c                  rold = exp(o(qv_p,ista))
c                  tnvold = temp/(1.+0.6078*rold)
c                  esold = ESW(tnvold-273.15)
c                  eold = (rold*(o(p_p,ista)))/(rold+0.62197)
c                  rhcon = eold/esold
c                  tnvnew = temp1/(1.+0.6078*rold)
c                  esnew = ESW(tnvnew-273.15)
c                  enew = rhcon*esnew
c                  rnew = (0.62197*enew)/(PG-enew)
c                  o(qv_p,ista) = alog(rnew)
c                end if

c      write(*,847) 'delta-sfc ',oid(ista),o(p_p,ista),pg,
c    :    thvold,thvnew,tnvold-273.15,tnvnew-273.15,
c    :    rold,rnew,rhcon

c847    format(1x,a10,a5,6f7.1,3f8.4)

C --- For water mixing ratio, do no adjustment. Stan B. - 7/30/00
c                  CALL CHCKQC (OQC(qv_P,ISTA),     MSTRBAD_P,
c    1                   QCPC, ISTAT)
c                  IF (QCPC.EQ.0 .AND. O(PC_P,ISTA).LE.99990.) THEN
c                    O(PC_P,ISTA) =
c    1               PG - (O(P_P,ISTA)-O(PC_P,ISTA))
c                  ENDIF

                 if (pdiff.ge.extrapsfc_dpmax_p) THEN
                  write(6,123) oid(ista),o(p_p,ista),pg,pdiff
123               format (' Sfc pres ob-bkg diff > 50 mb  ',a9,3f9.1)
                  call setqc(oqc(theta_p,ista),bogsnmc_p,
     1                       oqc(theta_p,ista),istat)
                   O(THETA_P,ISTA) = SPVAL_P
                   O(H_P,ISTA) = SPVAL_P
                   O(qv_P,ISTA) = SPVAL_P
                   O(P_P,ISTA) = SPVAL_P
                   O(U_P,ISTA) = SPVAL_P
                   O(V_P,ISTA) = SPVAL_P
                   go to 1000
                 end if
C *** Print out sfc stations that are at least 10 mb HIGHER than
C         model surface
                 if (pdiff1.lt.-20.) then
                  write(6,1231) oid(ista),o(p_p,ista),pg,pdiff1
1231              format (' Sfc pres ob-bkg diff <-20 mb  ',a9,3f9.1) 
                 end if

                 O(P_P,ISTA) = PG

C -- If sfc pressure is bogus, can still use sfc winds
                else if (qcp_bog.ne.0) then
                   O(THETA_P,ISTA) = SPVAL_P
                   O(H_P,ISTA) = SPVAL_P
                   O(qv_P,ISTA) = SPVAL_P
c                  write(6,*)' bog sfc pres in exsfcobs', oid(ista)
                ELSE
                   O(THETA_P,ISTA) = SPVAL_P
                   O(H_P,ISTA) = SPVAL_P
                   O(qv_P,ISTA) = SPVAL_P
                   O(P_P,ISTA) = SPVAL_P
                   O(U_P,ISTA) = SPVAL_P
                   O(V_P,ISTA) = SPVAL_P
                 ENDIF
C if P and theta are good

           ENDIF
C if ob is an SAO
1000    CONTINUE
         write(6,*)'Sfc data west of i=104'
         write(6,*)' Total number of sfc obs',ic
         write(6,*)' Number of sfc obs passed through exsfcobs'
         write(6,*)' at 10/30/50/70/90 mb criteria',ic1,ic3,ic5,
     1     ic7,ic9

         write(6,*)'Sfc data east of i=104'
         write(6,*)' Total number of sfc obs',ice
         write(6,*)' Number of sfc obs passed through exsfcobs'
         write(6,*)' at 10/30/50/70/90 mb criteria',
     1     ice1,ice3,ice5,ice7,ice9

        RETURN
        END
