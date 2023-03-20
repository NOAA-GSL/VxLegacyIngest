C-----------------------------------------------------------------------
      SUBROUTINE POLATES1(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,GI,
     &                    NO,RLAT,RLON,IBO,LO,GO,IRET)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:  POLATES1   INTERPOLATE SCALAR FIELDS (BICUBIC)
C   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
C
C ABSTRACT: THIS SUBPROGRAM PERFORMS BICUBIC INTERPOLATION
C           FROM ANY GRID TO ANY GRID FOR SCALAR FIELDS.
C           IT REQUIRES THAT NO INPUT FIELDS HAVE BITMAPS (IBI=0).
C           OPTIONS ALLOW CHOICES BETWEEN STRAIGHT BICUBIC (IPOPT(1)=0)
C           AND CONSTRAINED BICUBIC (IPOPT(1)=1) WHERE THE VALUE IS
C           CONFINED WITHIN THE RANGE OF THE SURROUNDING 4 POINTS.
C           BILINEAR USED WITHIN ONE GRID LENGTH OF BOUNDARIES.
C           ONLY HORIZONTAL INTERPOLATION IS PERFORMED.
C           THE GRIDS ARE DEFINED BY THEIR GRID DESCRIPTION SECTIONS
C           (PASSED IN INTEGER FORM AS DECODED BY SUBPROGRAM W3FI63).
C           THE CURRENT CODE RECOGNIZES THE FOLLOWING PROJECTIONS:
C             (KGDS(1)=000) EQUIDISTANT CYLINDRICAL
C             (KGDS(1)=001) MERCATOR CYLINDRICAL
C             (KGDS(1)=003) LAMBERT CONFORMAL CONICAL
C             (KGDS(1)=004) GAUSSIAN CYLINDRICAL (SPECTRAL NATIVE)
C             (KGDS(1)=005) POLAR STEREOGRAPHIC AZIMUTHAL
C             (KGDS(1)=202) ROTATED EQUIDISTANT CYLINDRICAL (ETA NATIVE)
C           WHERE KGDS COULD BE EITHER INPUT KGDSI OR OUTPUT KGDSO.
C           AS AN ADDED BONUS THE NUMBER OF OUTPUT GRID POINTS
C           AND THEIR LATITUDES AND LONGITUDES ARE ALSO RETURNED.
C           ON THE OTHER HAND, THE OUTPUT CAN BE A SET OF STATION POINTS
C           IF KGDSO(1)<0, IN WHICH CASE THE NUMBER OF POINTS
C           AND THEIR LATITUDES AND LONGITUDES MUST BE INPUT.
C           OUTPUT BITMAPS WILL ONLY BE CREATED WHEN THE OUTPUT GRID
C           EXTENDS OUTSIDE OF THE DOMAIN OF THE INPUT GRID.
C           THE OUTPUT FIELD IS SET TO 0 WHERE THE OUTPUT BITMAP IS OFF.
C        
C PROGRAM HISTORY LOG:
C   96-04-10  IREDELL
C
C USAGE:    CALL POLATES1(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,GI,
C    &                    NO,RLAT,RLON,IBO,LO,GO,IRET)
C
C   INPUT ARGUMENT LIST:
C     IPOPT    - INTEGER (20) INTERPOLATION OPTIONS
C                IPOPT(1)=0 FOR STRAIGHT BICUBIC;
C                IPOPT(1)=1 FOR CONSTRAINED BICUBIC WHERE VALUE IS
C                CONFINED WITHIN THE RANGE OF THE SURROUNDING 4 POINTS.
C     KGDSI    - INTEGER (200) INPUT GDS PARAMETERS AS DECODED BY W3FI63
C     KGDSO    - INTEGER (200) OUTPUT GDS PARAMETERS
C                (KGDSO(1)<0 IMPLIES RANDOM STATION POINTS)
C     MI       - INTEGER SKIP NUMBER BETWEEN INPUT GRID FIELDS IF KM>1
C                OR DIMENSION OF INPUT GRID FIELDS IF KM=1
C     MO       - INTEGER SKIP NUMBER BETWEEN OUTPUT GRID FIELDS IF KM>1
C                OR DIMENSION OF OUTPUT GRID FIELDS IF KM=1
C     KM       - INTEGER NUMBER OF FIELDS TO INTERPOLATE
C     IBI      - INTEGER (KM) INPUT BITMAP FLAGS (MUST BE ALL 0)
C     LI       - LOGICAL*1 (MI,KM) INPUT BITMAPS (IF SOME IBI(K)=1)
C     GI       - REAL (MI,KM) INPUT FIELDS TO INTERPOLATE
C     NO       - INTEGER NUMBER OF OUTPUT POINTS (ONLY IF KGDSO(1)<0)
C     RLAT     - REAL (NO) OUTPUT LATITUDES IN DEGREES (IF KGDSO(1)<0)
C     RLON     - REAL (NO) OUTPUT LONGITUDES IN DEGREES (IF KGDSO(1)<0)
C
C   OUTPUT ARGUMENT LIST:
C     NO       - INTEGER NUMBER OF OUTPUT POINTS (ONLY IF KGDSO(1)>=0)
C     RLAT     - REAL (MO) OUTPUT LATITUDES IN DEGREES (IF KGDSO(1)>=0)
C     RLON     - REAL (MO) OUTPUT LONGITUDES IN DEGREES (IF KGDSO(1)>=0)
C     IBO      - INTEGER (KM) OUTPUT BITMAP FLAGS
C     LO       - LOGICAL*1 (MO,KM) OUTPUT BITMAPS (ALWAYS OUTPUT)
C     GO       - REAL (MO,KM) OUTPUT FIELDS INTERPOLATED
C     IRET     - INTEGER RETURN CODE
C                0    SUCCESSFUL INTERPOLATION
C                2    UNRECOGNIZED INPUT GRID OR NO GRID OVERLAP
C                3    UNRECOGNIZED OUTPUT GRID
C                11   INVALID INPUT BITMAPS
C
C SUBPROGRAMS CALLED:
C   GDSWIZ       GRID DESCRIPTION SECTION WIZARD
C   (IJKGDS)     RETURN FIELD POSITION FOR A GIVEN GRID POINT
C   POLFIXS      MAKE MULTIPLE POLE SCALAR VALUES CONSISTENT
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C
C$$$
CFPP$ EXPAND(IJKGDS)
      INTEGER IPOPT(20)
      INTEGER KGDSI(200),KGDSO(200)
      INTEGER IBI(KM),IBO(KM)
      LOGICAL*1 LI(MI,KM),LO(MO,KM)
      REAL GI(MI,KM),GO(MO,KM)
      REAL RLAT(MO),RLON(MO)
      REAL XPTS(MO),YPTS(MO)
      INTEGER N11(MO),N21(MO),N12(MO),N22(MO)
      REAL W11(MO),W21(MO),W12(MO),W22(MO)
      PARAMETER(FILL=-9999.)
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPUTE NUMBER OF OUTPUT POINTS AND THEIR LATITUDES AND LONGITUDES.
      IRET=0
      IF(KGDSO(1).GE.0) THEN
        CALL GDSWIZ(KGDSO, 0,MO,FILL,XPTS,YPTS,RLON,RLAT,NO,0,DUM,DUM)
        IF(NO.EQ.0) IRET=3
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  LOCATE INPUT POINTS AND COMPUTE THEIR WEIGHTS
      CALL GDSWIZ(KGDSI,-1,NO,FILL,XPTS,YPTS,RLON,RLAT,NV,0,DUM,DUM)
      IF(IRET.EQ.0.AND.NV.EQ.0) IRET=2
      DO K=1,KM
        IF(IBI(K).NE.0) IRET=11
      ENDDO
CMIC$ DO ALL AUTOSCOPE
      DO K=1,KM
        DO N=1,NO
          GO(N,K)=0.
          LO(N,K)=.FALSE.
        ENDDO
      ENDDO
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPUTE CORNERS
      IF(IRET.EQ.0) THEN
        DO N=1,NO
          XI=XPTS(N)
          YI=YPTS(N)
          IF(XI.NE.FILL.AND.YI.NE.FILL) THEN
            I1=XI-1
            I2=I1+3
            J1=YI-1
            J2=J1+3
            XF=XI-I1-1
            YF=YI-J1-1
            N11(N)=IJKGDS(I1,J1,KGDSI)
            N21(N)=IJKGDS(I2,J1,KGDSI)
            N12(N)=IJKGDS(I1,J2,KGDSI)
            N22(N)=IJKGDS(I2,J2,KGDSI)
            IF(MIN(N11(N),N21(N),N12(N),N22(N)).GT.0) THEN
              W11(N)=XF*(1-XF)*(2-XF)*YF*(1-YF)*(2-YF)/36
              W21(N)=XF*(1-XF)*(1+XF)*YF*(1-YF)*(2-YF)/36
              W12(N)=XF*(1-XF)*(2-XF)*YF*(1-YF)*(1+YF)/36
              W22(N)=XF*(1-XF)*(1+XF)*YF*(1-YF)*(1+YF)/36
            ELSE
              N11(N)=0
              N21(N)=0
              N12(N)=0
              N22(N)=0
            ENDIF
          ELSE
            N11(N)=0
            N21(N)=0
            N12(N)=0
            N22(N)=0
          ENDIF
        ENDDO
CMIC$ DO ALL AUTOSCOPE
        DO K=1,KM
          DO N=1,NO
            IF(N11(N).GT.0) THEN
              GO(N,K)=GO(N,K)+W11(N)*GI(N11(N),K)+W21(N)*GI(N21(N),K)
     &                       +W12(N)*GI(N12(N),K)+W22(N)*GI(N22(N),K)
            ENDIF
          ENDDO
        ENDDO
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPUTE TOPS AND BOTTOMS
        DO N=1,NO
          XI=XPTS(N)
          YI=YPTS(N)
          IF(XI.NE.FILL.AND.YI.NE.FILL) THEN
            LP=N11(N)
            IF(LP.GT.0) THEN
              I1=XI
              I2=I1+1
              J1=YI-1
              J2=J1+3
              XF=XI-I1
              YF=YI-J1-1
              N11(N)=IJKGDS(I1,J1,KGDSI)
              N21(N)=IJKGDS(I2,J1,KGDSI)
              N12(N)=IJKGDS(I1,J2,KGDSI)
              N22(N)=IJKGDS(I2,J2,KGDSI)
              W11(N)=-(1+XF)*(1-XF)*(2-XF)*YF*(1-YF)*(2-YF)/12
              W21(N)=-XF*(2-XF)*(1+XF)*YF*(1-YF)*(2-YF)/12
              W12(N)=-(1+XF)*(1-XF)*(2-XF)*YF*(1-YF)*(1+YF)/12
              W22(N)=-XF*(2-XF)*(1+XF)*YF*(1-YF)*(1+YF)/12
            ENDIF
          ELSE
            N11(N)=0
            N21(N)=0
            N12(N)=0
            N22(N)=0
          ENDIF
        ENDDO
CMIC$ DO ALL AUTOSCOPE
        DO K=1,KM
          DO N=1,NO
            IF(N11(N).GT.0) THEN
              GO(N,K)=GO(N,K)+W11(N)*GI(N11(N),K)+W21(N)*GI(N21(N),K)
     &                       +W12(N)*GI(N12(N),K)+W22(N)*GI(N22(N),K)
            ENDIF
          ENDDO
        ENDDO
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPUTE LEFTS AND RIGHTS
        DO N=1,NO
          XI=XPTS(N)
          YI=YPTS(N)
          IF(XI.NE.FILL.AND.YI.NE.FILL) THEN
            LP=N11(N)
            IF(LP.GT.0) THEN
              I1=XI-1
              I2=I1+3
              J1=YI
              J2=J1+1
              XF=XI-I1-1
              YF=YI-J1
              N11(N)=IJKGDS(I1,J1,KGDSI)
              N21(N)=IJKGDS(I2,J1,KGDSI)
              N12(N)=IJKGDS(I1,J2,KGDSI)
              N22(N)=IJKGDS(I2,J2,KGDSI)
              W11(N)=-XF*(1-XF)*(2-XF)*(1+YF)*(1-YF)*(2-YF)/12
              W21(N)=-XF*(1-XF)*(1+XF)*(1+YF)*(1-YF)*(2-YF)/12
              W12(N)=-XF*(1-XF)*(2-XF)*YF*(2-YF)*(1+YF)/12
              W22(N)=-XF*(1-XF)*(1+XF)*YF*(2-YF)*(1+YF)/12
            ENDIF
          ELSE
            N11(N)=0
            N21(N)=0
            N12(N)=0
            N22(N)=0
          ENDIF
        ENDDO
CMIC$ DO ALL AUTOSCOPE
        DO K=1,KM
          DO N=1,NO
            IF(N11(N).GT.0) THEN
              GO(N,K)=GO(N,K)+W11(N)*GI(N11(N),K)+W21(N)*GI(N21(N),K)
     &                       +W12(N)*GI(N12(N),K)+W22(N)*GI(N22(N),K)
            ENDIF
          ENDDO
        ENDDO
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPUTE CENTERS
        DO N=1,NO
          XI=XPTS(N)
          YI=YPTS(N)
          IF(XI.NE.FILL.AND.YI.NE.FILL) THEN
            LP=N11(N)
            I1=XI
            I2=I1+1
            J1=YI
            J2=J1+1
            XF=XI-I1
            YF=YI-J1
            N11(N)=IJKGDS(I1,J1,KGDSI)
            N21(N)=IJKGDS(I2,J1,KGDSI)
            N12(N)=IJKGDS(I1,J2,KGDSI)
            N22(N)=IJKGDS(I2,J2,KGDSI)
            IF(LP.GT.0) THEN
              W11(N)=(1+XF)*(1-XF)*(2-XF)*(1+YF)*(1-YF)*(2-YF)/4
              W21(N)=XF*(2-XF)*(1+XF)*(1+YF)*(1-YF)*(2-YF)/4
              W12(N)=(1+XF)*(1-XF)*(2-XF)*YF*(2-YF)*(1+YF)/4
              W22(N)=XF*(2-XF)*(1+XF)*YF*(2-YF)*(1+YF)/4
            ELSEIF(MIN(N11(N),N21(N),N12(N),N22(N)).GT.0) THEN
              W11(N)=(1-XF)*(1-YF)
              W21(N)=XF*(1-YF)
              W12(N)=(1-XF)*YF
              W22(N)=XF*YF
            ELSE
              N11(N)=0
              N21(N)=0
              N12(N)=0
              N22(N)=0
            ENDIF
          ELSE
            N11(N)=0
            N21(N)=0
            N12(N)=0
            N22(N)=0
          ENDIF
        ENDDO
CMIC$ DO ALL AUTOSCOPE
        DO K=1,KM
          DO N=1,NO
            IF(N11(N).GT.0) THEN
              GO(N,K)=GO(N,K)+W11(N)*GI(N11(N),K)+W21(N)*GI(N21(N),K)
     &                       +W12(N)*GI(N12(N),K)+W22(N)*GI(N22(N),K)
              IF(IPOPT(1).GT.0) THEN
                GMIN=MIN(GI(N11(N),K),GI(N21(N),K),
     &                   GI(N12(N),K),GI(N22(N),K))
                GMAX=MAX(GI(N11(N),K),GI(N21(N),K),
     &                   GI(N12(N),K),GI(N22(N),K))
                GO(N,K)=MIN(MAX(GO(N,K),GMIN),GMAX)
              ENDIF
              LO(N,K)=.TRUE.
            ENDIF
          ENDDO
        ENDDO
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CMIC$ DO ALL AUTOSCOPE
      DO K=1,KM
        IBO(K)=IBI(K)
        DO N=1,NO
          IF(.NOT.LO(N,K)) THEN
            IBO(K)=1
            GO(N,K)=0.
          ENDIF
        ENDDO
      ENDDO
      IF(KGDSO(1).EQ.0) CALL POLFIXS(NO,MO,KM,RLAT,RLON,IBO,LO,GO)
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      END
