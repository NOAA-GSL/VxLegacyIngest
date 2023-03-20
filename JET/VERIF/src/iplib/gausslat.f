C-----------------------------------------------------------------------
      SUBROUTINE GAUSSLAT(JMAX,SLAT,WLAT)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:  GAUSSLAT   COMPUTE GAUSSIAN LATITUDES
C   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 92-04-16
C
C ABSTRACT: COMPUTES COSINES OF COLATITUDE AND GAUSSIAN WEIGHTS
C   ON THE GAUSSIAN LATITUDES.  THE GAUSSIAN LATITUDES ARE AT
C   THE ZEROES OF THE LEGENDRE POLYNOMIAL OF THE GIVEN ORDER.
C
C PROGRAM HISTORY LOG:
C   92-04-16  IREDELL
C   97-10-20  IREDELL  INCREASED PRECISION
C
C USAGE:    CALL GAUSSLAT(JMAX,SLAT,WLAT)
C
C   INPUT ARGUMENT LIST:
C     JMAX     - INPUT NUMBER OF LATITUDES.
C
C   OUTPUT ARGUMENT LIST:
C     SLAT     - REAL (K) COSINES OF COLATITUDE.
C     WLAT     - REAL (K) GAUSSIAN WEIGHTS.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C
C$$$
      REAL SLAT(JMAX),WLAT(JMAX)
      REAL PK(JMAX/2),PKM1(JMAX/2),PKM2(JMAX/2)
      PARAMETER(JZ=50)
      REAL BZ(JZ)
      DATA BZ        / 2.4048255577,  5.5200781103,
     $  8.6537279129, 11.7915344391, 14.9309177086, 18.0710639679,
     $ 21.2116366299, 24.3524715308, 27.4934791320, 30.6346064684,
     $ 33.7758202136, 36.9170983537, 40.0584257646, 43.1997917132,
     $ 46.3411883717, 49.4826098974, 52.6240518411, 55.7655107550,
     $ 58.9069839261, 62.0484691902, 65.1899648002, 68.3314693299,
     $ 71.4729816036, 74.6145006437, 77.7560256304, 80.8975558711,
     $ 84.0390907769, 87.1806298436, 90.3221726372, 93.4637187819,
     $ 96.6052679510, 99.7468198587, 102.888374254, 106.029930916,
     $ 109.171489649, 112.313050280, 115.454612653, 118.596176630,
     $ 121.737742088, 124.879308913, 128.020877005, 131.162446275,
     $ 134.304016638, 137.445588020, 140.587160352, 143.728733573,
     $ 146.870307625, 150.011882457, 153.153458019, 156.295034268 /
      PARAMETER(PI=3.14159265358979,C=(1.-(2./PI)**2)*0.25)
      PARAMETER(EPS=1.E-12)
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      JH=JMAX/2
      JHE=(JMAX+1)/2
      R=1./SQRT((JMAX+0.5)**2+C)
      DO J=1,MIN(JH,JZ)
        SLAT(J)=COS(BZ(J)*R)
      ENDDO
      DO J=JZ+1,JH
        SLAT(J)=COS((BZ(JZ)+(J-JZ)*PI)*R)
      ENDDO
      SPMAX=1.
      DO WHILE(SPMAX.GT.EPS)
        SPMAX=0.
        DO J=1,JH
          PKM1(J)=1.
          PK(J)=SLAT(J)
        ENDDO
        DO N=2,JMAX
          DO J=1,JH
            PKM2(J)=PKM1(J)
            PKM1(J)=PK(J)
            PK(J)=((2*N-1)*SLAT(J)*PKM1(J)-(N-1)*PKM2(J))/N
          ENDDO
        ENDDO
        DO J=1,JH
          SP=PK(J)*(1.-SLAT(J)**2)/(JMAX*(PKM1(J)-SLAT(J)*PK(J)))
          SLAT(J)=SLAT(J)-SP
          SPMAX=MAX(SPMAX,ABS(SP))
        ENDDO
      ENDDO
CDIR$ IVDEP
      DO J=1,JH
        WLAT(J)=(2.*(1.-SLAT(J)**2))/(JMAX*PKM1(J))**2
        SLAT(JMAX+1-J)=-SLAT(J)
        WLAT(JMAX+1-J)=WLAT(J)
      ENDDO
      IF(JHE.GT.JH) THEN
        SLAT(JHE)=0.
        WLAT(JHE)=2./JMAX**2
        DO N=2,JMAX,2
          WLAT(JHE)=WLAT(JHE)*N**2/(N-1)**2
        ENDDO
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      RETURN
      END
