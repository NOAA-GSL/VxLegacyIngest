      parameter (im=606,jm=1067)
      REAL,DIMENSION(IM,JM) :: HLAT,HLON,VLAT,VLON

      call calc_latlons_egrid(HLAT,HLON,VLAT,VLON,im,jm)
      end

      SUBROUTINE calc_latlons_egrid(HLAT,HLON,VLAT,VLON,im,jm)

!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!                .      .    .                                       .
! SUBPROGRAM: ETALL         COMPUTE EARTH LATITUDE & LONIGTUDE OF
!                           ETA GRID POINTS
!   PRGMMR: ROGERS          ORG: W/NP22     DATE: 90-06-13
!
! ABSTRACT: COMPUTES THE EARTH LATITUDE AND LONGITUDE OF ETA GRID
!   POINTS (BOTH H AND V POINTS)
!
! PROGRAM HISTORY LOG:
!   90-06-13  E.ROGERS
!   98-06-09  M.BALDWIN - CONVERT TO 2-D CODE
!   01-01-03  T BLACK   - MODIFIED FOR MPI
!
! USAGE:    CALL ETALL(HLAT,HLON,VLAT,VLON)
!   INPUT ARGUMENT LIST:
!     NONE
!
!   OUTPUT ARGUMENT LIST:
!     HLAT     - LATITUDE OF H GRID POINTS IN RADIANS (NEG=S)
!     HLON     - LONGITUDE OF H GRID POINTS IN RADIANS (E)
!     VLAT     - LATITUDE OF V GRID POINTS IN RADIANS (NEG=S)
!     VLON     - LONGITUDE OF V GRID POINTS IN RADIANS (E)
!
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!   MACHINE:  IBM RS/6000 SP
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!cggg       INTEGER, PARAMETER :: KNUM=SELECTED_REAL_KIND(13)
!      REAL(KIND=KNUM) :: ONE=1.,R180=180.,TWO=2.
!      REAL(KIND=KNUM) :: CLMH,CLMV,CTPH,CTPH0,CTPV,D2R,DLM,DLMD,DPH,DPHD     &
!     &                  ,FACTR,PI,R2D,SB,SBD,SPHH,SPHV,STPH,STPH0,STPV   &
!     &                  ,TDLM,TLMH,TLMV,TPH0,TPHH,TPHV,WB,WBD
!      REAL(KIND=KNUM),DIMENSION(IM,JM) :: GLATH,GLATV,GLONH,GLONV
      REAL :: ONE=1.,R180=180.,TWO=2.
      REAL :: CLMH,CLMV,CTPH,CTPH0,CTPV,D2R,DLM,DLMD,DPH,DPHD     
     .                  ,FACTR,PI,R2D,SB,SBD,SPHH,SPHV,STPH,STPH0,STPV 
     .                  ,TDLM,TLMH,TLMV,TPH0,TPHH,TPHV,WB,WBD
      REAL,DIMENSION(IM,JM) :: GLATH,GLATV,GLONH,GLONV
      REAL,DIMENSION(IM,JM) :: HLAT,HLON,VLAT,VLON
!cggg
      integer :: i,j
      real    :: dtr, tdph, facth, factv, tlm0d, tph0d

! phi = latitude, lambda = longitude
      real, parameter     :: tph0d_in = 50.
      real, parameter     :: tlm0d_in = -111.0
      real, parameter     :: dlmd_in =  53/605.
      real, parameter     :: dphd_in = 40/533.
!-----------------------------------------------------------------------
!--------------DERIVED GEOMETRICAL CONSTANTS----------------------------
!----------------------------------------------------------------------

        TPH0D=TPH0D_in
        TLM0D=TLM0D_in
        DPHD=DPHD_in
        DLMD=DLMD_in

      WBD=-(IM-ONE)*DLMD
      SBD=-(JM-1)/2*DPHD
      PI=ACOS(-ONE)
      DTR = PI / R180
      TPH0 = TPH0D * DTR
      WB = WBD * DTR
      SB = SBD * DTR
      DLM = DLMD * DTR
      DPH = DPHD * DTR

       write(6,*) 'TPH0,WBD,SBD,DLM,DPH: ', TPH0,WBD,SBD,DLMD,DPHD

      TDLM = DLM + DLM
      TDPH = DPH + DPH
!
      STPH0 = SIN(TPH0)
      CTPH0 = COS(TPH0)

!-----------------------------------------------------------------------
!---COMPUTE GEOGRAPHIC LAT AND LONG OF ETA GRID POINTS (H & V POINTS)---
!-----------------------------------------------------------------------
      DO 200 J = 1,JM
!
         TLMH = WB - TDLM + MOD(J+1,2) * DLM
         TPHH = SB+(J-1)*DPH
         TLMV = WB - TDLM + MOD(J,2) * DLM
         TPHV = TPHH
         STPH = SIN(TPHH)
         CTPH = COS(TPHH)
         STPV = SIN(TPHV)
         CTPV = COS(TPHV)
!----------------------------------------------------------------------
!---------- COMPUTE EARTH LATITUDE/LONGITUDE OF H POINTS --------------
!----------------------------------------------------------------------
         DO 201 I = 1,IM
           TLMH = TLMH + TDLM
           SPHH = CTPH0 * STPH + STPH0 * CTPH * COS(TLMH)
!cggg got problems near pole.
           if (sphh .gt. 1.) sphh = 1.
           GLATH(I,J) = ASIN(SPHH)
           CLMH = CTPH * COS(TLMH) / (COS(GLATH(I,J)) * CTPH0)    
     .                 - TAN(GLATH(I,J)) * TAN(TPH0)
           IF(CLMH .GT. ONE) CLMH = ONE
           IF(CLMH .LT. -ONE) CLMH = -ONE
           FACTH = ONE
           IF(TLMH .GT. 0.) FACTH = -ONE
           GLONH(I,J) = -TLM0D * DTR + FACTH * ACOS(CLMH)

           HLAT(I,J) = GLATH(I,J) / DTR
           HLON(I,J)= -GLONH(I,J)/DTR
           IF(HLON(I,J) .GT. 180.) HLON(I,J) = HLON(I,J) - 360.
           IF(HLON(I,J) .LT. -180.) HLON(I,J) = HLON(I,J) + 360.
  201    CONTINUE


!----------------------------------------------------------------------
!---------- COMPUTE EARTH LATITUDE/LONGITUDE OF V POINTS --------------
!----------------------------------------------------------------------
         DO 202 I = 1,IM
           TLMV = TLMV + TDLM
           SPHV = CTPH0 * STPV + STPH0 * CTPV * COS(TLMV)
!cggg got problems near pole.
           if (sphv .gt. 1.) sphv = 1.
           GLATV(I,J) = ASIN(SPHV)
           CLMV = CTPV * COS(TLMV) / (COS(GLATV(I,J)) * CTPH0)   
     .            - TAN(GLATV(I,J)) * TAN(TPH0)
           IF(CLMV .GT. 1.) CLMV = 1.
           IF(CLMV .LT. -1.) CLMV = -1.
           FACTV = 1.
           IF(TLMV .GT. 0.) FACTV = -1.
           GLONV(I,J) = -TLM0D * DTR + FACTV * ACOS(CLMV)
!
!    CONVERT INTO DEGREES AND EAST LONGITUDE
!
           VLAT(I,J) = GLATV(I,J) / DTR
           VLON(I,J) = -GLONV(I,J) / DTR
           IF(VLON(I,J) .GT. 180.) VLON(I,J) = VLON(I,J) - 360.
           IF(VLON(I,J) .LT. -180.) VLON(I,J) = VLON(I,J) + 360.

        if ( (i .eq.1 .and. j .eq. 1) .or.
     .       (i .eq.200 .and. j .eq. 200 )) then
           write(6,*) 'I,J,HLAT,HLON,VLAT,VLON: ',
     .          I,J,HLAT(I,J),HLON(I,J) 
     .         ,VLAT(I,J),VLON(I,J)
        endif
  202    CONTINUE
  200 CONTINUE

      RETURN
      END
c END subroutine calc_latlons_egrid
