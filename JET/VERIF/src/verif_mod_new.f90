module verif_mod
!=============================================================================================================
!
! This module contains global data, derived types, namelist groups, and common
! subroutines necessary for CREF, VIL, VI, PROB, ETP, and PRECIP verification programs.
!
! Written by: Patrick Hofmann
! Last Update: 7 FEB 2017 by Jeff Hamilton
!
!=============================================================================================================
use netcdf

implicit none

! Define custom derived types
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! Define contingency table type
type cont_table_type
   integer :: hits              !Forecast Yes, Observed Yes
   integer :: false_alarms      !Forecast Yes, Observed No
   integer :: misses            !Forecast No,  Observed Yes
   integer :: correct_negatives !Forecast No,  Observed No
end type cont_table_type

! Define model/obs state type
type state_type
   real,    pointer, dimension(:,:) :: cref     !Composite Reflectivity
   real,    pointer, dimension(:,:) :: precip   !Surface Precipitation 
   real,    pointer, dimension(:,:) :: vil      !Vertically Integrated Liquid
   real,    pointer, dimension(:,:) :: vip      !VIP level VIL value
   real,    pointer, dimension(:,:) :: etp      !Echo Top height (kft)
   real,    pointer, dimension(:,:) :: prob     !Weather Impact Probability field
   logical, pointer, dimension(:,:) :: missing  !Missing value mask
   real,    pointer, dimension(:,:) :: lat      !Latitudes
   real,    pointer, dimension(:,:) :: lon      !Longitudes
end type state_type

! Define statistics type
type stats_type
   real :: bias  !Bias
   real :: pod   !Probability of Detection
   real :: far   !False Alarm Ratio
   real :: csi   !Critical Success Index
   real :: ets   !Equitable Threat Score
   real :: hk    !Hanssen and Kuipers Discriminant
   real :: hss   !Heidke Skill Score
end type stats_type

integer, parameter      :: max_name_len = 500
integer, dimension(200) :: hrrr03_gds, hrrr10_gds, hrrr20_gds, hrrr40_gds, hrrr80_gds, &
                           nssl01_gds, nssl_grib2_gds, nssl10_gds, nssl20_gds, nssl40_gds, &
                           ruc13_gds, ruc20_gds, ncwd04_gds, ncwd80_gds, & 
                           cpc13_gds, nam05_gds, nam12_gds, stageIV04_gds, &
                           stmaslaps_conus03_gds, stmaslaps_ci03_gds,  &
                           stmaslaps_hwt03_gds, stmaslaps_roc03_gds, nsslwrf04_gds, &
                           hrrre03_s_gds, hrrre03_c_gds, hrrre03_se_gds, &
                           hrrre03_ne_gds, hrrre03_n_gds
integer, dimension(20)  :: interp_opts
real, dimension(4)      :: conus_domain, east_domain, west_domain, ne_domain, se_domain, &
                           ci_domain, hwt_domain, roc_domain, central_domain, &
                           south_domain, southeast_domain, northeast_domain, &
                           north_domain
integer                 :: i

! Define Namelists and their default values
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
character(len = max_name_len) :: obs_in_file    = '../ncwd.nc',                               &
                                 obs_nc_var     = 'obs_vil',                                  &
                                 model_in_file  = '../hrrr.nc',                               &
                                 model_nc_var   = 'VIL',                                      &
                                 conus_out_file = 'verif_10km_conus_statistics.txt',          &
                                 west_out_file  = 'verif_10km_west_statistics.txt',           &
                                 east_out_file  = 'verif_10km_east_statistics.txt',           &
                                 ne_out_file    = 'verif_10km_ne_statistics.txt',             &
                                 se_out_file    = 'verif_10km_se_statistics.txt',             &
                                 ci_out_file    = 'verif_10km_ci_statistics.txt',             &
                                 hwt_out_file   = 'verif_10km_hwt_statistics.txt',            &
                                 roc_out_file   = 'verif_10km_roc_statistics.txt',            &
                                 mask_file      = '/home/rtrr/verif/static/ncwd_hgt_mask.nc', &
                                 model_grid     = '03kmLC',                                   &
                                 obs_grid       = '04kmCE',                                   &
                                 interp_grid    = '10kmLC',                                   &
                                 interp_method  = 'neighbor-budget',                          &
                                 interp_func    = 'average',                                  &
                                 nc_out_var     = 'vil',                                      & 
                                 obs_out_file   = 'ncwd_10kmLC_grid.nc',                      & 
                                 model_out_file = 'hrrr_2010082308z+04_10kmLC_grid.nc',       &
                                 verif_out_file = 'ncwd_vs_VIL_hrrr_3VIPverif_10kmLC_grid.nc',&
                                 valid_time     = '2010101010',                               &
                                 initial_time   = '2010101000',                               &
                                 forecast_time  = '10'

character(len = max_name_len) :: stat_out_file, c_out_file, s_out_file,&
                                 n_out_file
   
real :: threshold = 3
logical :: do_conus = .false., do_west = .false., do_east = .false., do_ne = .false., do_se = .false., &
           do_ci = .false., do_hwt = .false., do_roc = .false., do_c = .false.,&
           do_s = .false., do_n = .false.

namelist /main_nml/                                                                             &
         model_grid, obs_grid, interp_grid, obs_in_file, obs_nc_var, mask_file, model_in_file,  &
         model_nc_var, obs_out_file, model_out_file, nc_out_var, valid_time, initial_time,      &
         forecast_time

namelist /interp_nml/                                                                           &
         interp_opts, interp_method, interp_func

namelist /verif_nml/                                                                            &
         verif_out_file, conus_out_file, west_out_file, east_out_file, ne_out_file,se_out_file, &
         ci_out_file, hwt_out_file, roc_out_file, threshold,                                    &
         do_conus, do_west, do_east, do_ne, do_se, do_ci, do_hwt, do_roc, &
         do_c, c_out_file, do_s, s_out_file, do_n, n_out_file

namelist /verif_hrrre_nml/                                                                      &
         threshold, verif_out_file, stat_out_file

! Define domain boundaries
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! Order is: (/ lower left lat, upper right lat, lower left lon, upper right lon /)
parameter conus_domain = (/ 0.0, 90.0, 0.0, 360.0 /)
parameter east_domain  = (/ 0.0, 90.0, 260.0, 360.0 /)
parameter west_domain  = (/ 0.0, 90.0, 0.0, 260.0 /)
parameter ne_domain    = (/ 37.0, 90.0, 265.0, 360.0 /)
parameter se_domain    = (/ 0.0, 37.0, 265.0, 360.0 /)
parameter ci_domain    = (/ 38.75, 44.25, 272.0, 288.0 /)
parameter hwt_domain   = (/ 29.25, 41., 255.0, 267.5 /)
parameter roc_domain   = (/ 36.25, 45.25, 248.0, 261.25 /)
parameter central_domain = (/ 28.25, 44.25, 252.0, 276.5 /)
parameter south_domain = (/ 23.25, 39.0, 251.5, 274.25 /)
parameter northeast_domain = (/ 31.5, 48.75, 263.5, 293.5 /)
parameter southeast_domain = (/ 23.25, 40.5, 261.0, 284.25 /)
parameter north_domain = (/ 34.75, 50.25, 252.5, 283.25 /)


! Define possible GDS parameters for different mappings as decoded by W3FI63
!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! 3KM Lambert Conformal Conic - HRRR domain
parameter hrrr03_gds = (/ 3,1799,1059,int(21.138*1000),int((360.-122.72)*1000),8,int((360.-97.5)*1000), &
                          3000,3000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)      /)

! 10KM Lambert Conformal Conic - HRRR domain
parameter hrrr10_gds = (/ 3,539,317,int(21.138*1000),int((360.-122.72)*1000),8,int((360.-97.5)*1000),   &
                          10000,10000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

! 20KM Lambert Conformal Conic - HRRR domain
parameter hrrr20_gds = (/ 3,269,158,int(21.138*1000),int((360.-122.72)*1000),8,int((360.-97.5)*1000),   &
                          20000,20000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

! 40KM Lambert Conformal Conic - HRRR domain
parameter hrrr40_gds = (/ 3,134,79,int(21.138*1000),int((360.-122.72)*1000),8,int((360.-97.5)*1000),    &
                          40000,40000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

! 80KM Lambert Conformal Conic - HRRR domain
parameter hrrr80_gds = (/ 3,67,39,int(21.138*1000),int((360.-122.72)*1000),8,int((360.-97.5)*1000),     &
                          80000,80000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

! 13KM Lambert Conformal Conic - RUC/RR domain
parameter ruc13_gds = (/ 3,451,337,int(16.281*1000),int((360.-126.138)*1000),8,int((360.-95.)*1000),  &
                         13545,13545,0,64,int(25.*1000),int(25.*1000),0,0,0,0,0,0,255,(0,i=1,180)     /)

! 13KM Lambert Conformal Conic - RUC/RR domain
parameter ruc20_gds = (/ 3,301,225,int(16.281*1000),int((360.-126.138)*1000),8,int((360.-95.)*1000),  &
                         20318,20318,0,64,int(25.*1000),int(25.*1000),0,0,0,0,0,0,255,(0,i=1,180)     /)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

! Equidistant Cylindrical (Lat/Lon) ~ 1KM/.01DEG spacing - NSSL domain
!parameter nssl01_gds = (/ 0,7001,3501,int(20.*1000),int((360.-130.)*1000),8,int((20.+.01*3500)*1000),  &
!                          int((360.-130.+.01*7000)*1000),int(.01*1000),int(.01*1000),                  &
!                          64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                           /)

parameter nssl01_gds = (/ 0,7000,3500,int(20.*1000),int((360.-130.)*1000),8,int((20.+.01*3500)*1000),  &
                          int((360.-130.+.01*7000)*1000),int(.01*1000),int(.01*1000),                  &
                          64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                           /)

! Equidistant Cylindrical (Lat/Lon) ~ 1KM/.01DEG spacing - NSSL domain
parameter nssl_grib2_gds = (/ 0,7000,3500,int(20.005001*1000),int(230.004999*1000),8,int(54.995000*1000),  &
                          int(299.994997*1000),int(.01*1000),int(.01*1000),                  &
                          64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                           /)

! Equidistant Cylindrical (Lat/Lon) ~ 10KM/.1DEG spacing - NSSL domain
parameter nssl10_gds = (/ 0,701,351,int(20.*1000),int((360.-130.)*1000),8,int((20.+.1*350)*1000),      &
                          int((360.-130.+.1*700)*1000),int(.1*1000),int(.1*1000),                      &
                          64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                           /)

! Equidistant Cylindrical (Lat/Lon) ~ 20KM/.2DEG spacing - NSSL domain
parameter nssl20_gds = (/ 0,351,176,int(20.*1000),int((360.-130.)*1000),8,int((20.+.2*175)*1000),      &
                          int((360.-130.+.2*350)*1000),int(.2*1000),int(.2*1000),                      &
                          64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                           /)

! Equidistant Cylindrical (Lat/Lon) ~ 40KM/.4DEG spacing - NSSL domain
parameter nssl40_gds = (/ 0,176,88,int(20.*1000),int((360.-130.)*1000),8,int((20.+.4*87)*1000),        &
                          int((360.-130.+.4*175)*1000),int(.4*1000),int(.4*1000),                      &
                          64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                           /)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

! Equidistant Cylindrical (Lat/Lon) ~ 4KM/.04DEG spacing - NCWD domain
parameter ncwd04_gds = (/ 0,1830,918,int(20.018*1000),int((230.019)*1000),8,int((20.018+.035933*917)*1000), &
                          int((230.019+.038239*1829)*1000),int(.038239*1000), int(.035933*1000),            &
                          64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                                /)

! Equidistant Cylindrical (Lat/Lon) ~ 80KM/.8DEG spacing - NCWD domain
parameter ncwd80_gds = (/ 0,92,46,int(20.018*1000),int((230.019)*1000),8,int((20.018+.71866*45)*1000),      &
                          int((230.019+.76478*91)*1000),int(.76478*1000),int(.71866*1000),                  &
                          64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                                /)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

! Equidistant Cylindrical (Lat/Lon) ~ 13KM/.125DEG spacing - CPC domain
parameter cpc13_gds = (/ 0,464,224,int(25.125*1000),int((360.-124.875)*1000),8,int((25.125+.125*224)*1000), &
                         int((360.-124.875+.125*464)*1000),int(.125*1000),int(.125*1000),                   &
                         64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                                 /)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

! 05KM Lambert Conformal Conic - NAM B grid domain, CONUS NEST resolution
parameter nam05_gds = (/ 3,1473,1025,int(12.19*1000),int(226.541*1000),8,int(265.0*1000),               &
                         5079,5079,0,64,int(25.*1000),int(25.*1000),0,0,0,0,0,0,255,(0,i=1,180)         /)

! 12KM Lambert Conformal Conic - NAM B grid domain
parameter nam12_gds = (/ 3,614,428,int(12.19*1000),int(226.541*1000),8,int(265.0*1000),                 &
                         12191,12191,0,64,int(25.*1000),int(25.*1000),0,0,0,0,0,0,255,(0,i=1,180)       /)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

! 04KM Polar Stereographic - StageIV domain
parameter stageIV04_gds = (/ 5,1121,881,int(23.098*1000),int(240.964*1000),8,int(255.0*1000),              &
                             4763,4763,0,64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                /)  

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

! 3KM Lambert Conformal Conic - STMAS/LAPS CONUS domain
parameter stmaslaps_conus03_gds = (/ 3,1800,1060,int(21.12218*1000),int(237.2709*1000),8,int((262.5)*1000),   &
                                     3000,3000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180) /)

! 3KM Lambert Conformal Conic - STMAS/LAPS CI domain
parameter stmaslaps_ci03_gds = (/ 3,541,346,int(38.75254*1000),int(270.1731*1000),8,int((260.0)*1000),        &
                                  3000,3000,0,64,int(41.69*1000),int(41.69*1000),0,0,0,0,0,0,255,(0,i=1,180)  /)

! 3KM Lambert Conformal Conic - STMAS/LAPS HWT domain
parameter stmaslaps_hwt03_gds = (/ 3,433,433,int(29.23711*1000),int(254.9435*1000),8,int((261.592)*1000),     &
                                   3000,3000,0,64,int(35.25*1000),int(35.25*1000),0,0,0,0,0,0,255,(0,i=1,180) /)

! 3KM Lambert Conformal Conic - STMAS/LAPS ROC domain
parameter stmaslaps_roc03_gds = (/ 3,413,347,int(36.06952*1000),int(247.8341*1000),8,int((254.5)*1000),       &
                                   3408,3408,0,64,int(60.0*1000),int(90.0*1000),0,0,0,0,0,0,255,(0,i=1,180)   /)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

! 4KM Lambert Conformal Conic - NSSL WRF domain
parameter nsslwrf04_gds = (/ 3,1199,799,int(21.641*1000),int((360.-120.45)*1000),8,int((360.-98.)*1000),   &
                             4000,4000,0,64,int(39.00001*1000),int(39.00001*1000),0,0,0,0,0,0,255,(0,i=1,180)      /)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

! 3KM Lambert Conformal Conic - HRRRE SE domain
parameter hrrre03_se_gds = (/ 3,650,550,int(25.522*1000),int((360.-98.933)*1000),8,int((360.-101.0)*1000), &
                          3000,3000,0,64,int(32.0*1000),int(46.0*1000),0,0,0,0,0,0,255,(0,i=1,180)         /)

! 3KM Lambert Conformal Conic - HRRRE NE domain
parameter hrrre03_ne_gds = (/ 3,750,500,int(35.248*1000),int((360.-96.332)*1000),8,int((360.-101.0)*1000), &
                          3000,3000,0,64,int(46.0*1000),int(32.0*1000),0,0,0,0,0,0,255,(0,i=1,180)         /)

! 3KM Lambert Conformal Conic - HRRRE S domain
parameter hrrre03_s_gds = (/ 3,650,550,int(24.039*1000),int((360.-107.04)*1000),8,int((360.-101.0)*1000), &
                          3000,3000,0,64,int(46.0*1000),int(32.0*1000),0,0,0,0,0,0,255,(0,i=1,180)        /)

! 3KM Lambert Conformal Conic - HRRRE N domain
parameter hrrre03_n_gds = (/ 3,750,500,int(36.447*1000),int((360.-106.22)*1000),8,int((360.-101.0)*1000), &
                          3000,3000,0,64,int(46.0*1000),int(32.0*1000),0,0,0,0,0,0,255,(0,i=1,180)        /)

! 3KM Lambert Conformal Conic - HRRRE C domain
!parameter hrrre03_c_gds = (/ 3,650,550,int(29.119*1000),int((360.-106.662)*1000),8,int((360.-101.0)*1000), &
!                          3000,3000,0,64,int(32.0*1000),int(46.0*1000),0,0,0,0,0,0,255,(0,i=1,180)         /)
parameter hrrre03_c_gds = (/ 3,650,550,int(29.119*1000),int((360.-106.662)*1000),8,int((360.-101.0)*1000), &
                          3000,3000,0,64,int(32.0*1000),int(46.0*1000),0,0,0,0,0,0,255,(0,i=1,180)         /)
!parameter hrrre03_c_gds = (/ 3,1799,1059,int(21.138*1000),int((237.28)*1000),8,int((262.5)*1000), &
!                          3000,3000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)      /)

  
!-------------------------------------------------------------------------------------------------------------


contains


!-------------------------------------------------------------------------------------------------------------

  subroutine read_obs_nc_file(var,inputFileName,state)
    ! Open and read the obs NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName
    type(state_type), intent(out) :: state  
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, ndims, nvars, natts, ny, nx
    integer                :: latVarID, lonVarID, fieldVarID
    integer                :: yDimID, xDimID

    print *, 'Reading: ', trim(inputFileName)
    
    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
  
    ! Get number of Lats/Lons
    status(2)  = nf90_inq_dimid(ncid,"y",yDimID)
    status(3)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(4)  = nf90_inq_dimid(ncid,"x",xDimID)
    status(5)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
    
    allocate(state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))

    ! Get Lat and Lon vars
    status(6)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(7)  = nf90_get_var(ncid,latVarID,state%lat)
    status(8)  = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(9)  = nf90_get_var(ncid,lonVarID,state%lon)

    ! Get VarID and variable values
    if(trim(var) == 'cref') then
       allocate(state%cref(nx,ny))
       status(10) = nf90_inq_varid(ncid,trim(var),fieldVarID)
       status(11) = nf90_get_var(ncid,fieldVarID,state%cref)
       where(state%cref .le. -998) state%missing = .true.
    elseif(trim(var) == 'vil') then
       allocate(state%vil(nx,ny))
       status(10) = nf90_inq_varid(ncid,trim(var),fieldVarID)
       status(11) = nf90_get_var(ncid,fieldVarID,state%vil)
       where(state%vil .le. -998) state%missing = .true.
    elseif(trim(var) == 'vip') then
       allocate(state%vip(nx,ny))
       status(10) = nf90_inq_varid(ncid,trim(var),fieldVarID)
       status(11) = nf90_get_var(ncid,fieldVarID,state%vip)
       where(state%vip .le. -998) state%missing = .true.
    elseif(trim(var) == 'precip') then
       allocate(state%precip(nx,ny))
       status(10) = nf90_inq_varid(ncid,trim(var),fieldVarID)
       status(11) = nf90_get_var(ncid,fieldVarID,state%precip)
       where(state%precip .le. -998) state%missing = .true.
    elseif(trim(var) == 'coverage' .or. trim(var) == 'prob') then
       allocate(state%vip(nx,ny),state%prob(nx,ny))
       ! For now, assuming that CCFP will be verified against NCWD-VIP
       status(10) = nf90_inq_varid(ncid,'vip',fieldVarID)
       status(11) = nf90_get_var(ncid,fieldVarID,state%vip)
       state%missing = .false.
       state%prob = 0.
       where(state%vip .le. -998) state%missing = .true.
       where(state%vip .ge. 3) state%prob = 1.
       deallocate(state%vip)
       if (associated(state%prob)) print *, 'obs prob field still allocated'
    elseif(trim(var) == 'echotop') then
       allocate(state%etp(nx,ny))
       status(10) = nf90_inq_varid(ncid,trim(var),fieldVarID)
       status(11) = nf90_get_var(ncid,fieldVarID,state%etp)
       where(state%etp .lt. 0) state%missing = .true.
    else
       print *, 'Unknown obs variable'
    endif

    if(any(status(:11) /= nf90_NoErr)) stop "Error reading obs NetCDF file"
  
    status(1) = nf90_close(ncid)
    
  end subroutine read_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_model_nc_file(var,inputFileName,state)
    ! Open and read the model NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName
    type(state_type), intent(out) :: state  
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20)            :: status
    integer                           :: ncid, ndims, nvars, natts, ny, nx
    integer                           :: latVarID, lonVarID, fieldVarID, field2VarID
    integer                           :: yDimID, xDimID
    real, dimension(:,:), allocatable :: cov, cnf

    print *, 'Reading: ', trim(inputFileName)
    
    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
  
    ! Get number of Lats/Lons
    status(2)  = nf90_inq_dimid(ncid,"y",yDimID)
    status(3)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(4)  = nf90_inq_dimid(ncid,"x",xDimID)
    status(5)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
    
    allocate(state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))

    ! Get Lat and Lon vars
    status(6)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(7)  = nf90_get_var(ncid,latVarID,state%lat)
    status(8)  = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(9)  = nf90_get_var(ncid,lonVarID,state%lon)

    ! Get VarID for variable
    status(10) = nf90_inq_varid(ncid,trim(var),fieldVarID)

    ! Get variable values
    if(trim(var) == 'cref') then
       allocate(state%cref(nx,ny))
       status(11) = nf90_get_var(ncid,fieldVarID,state%cref)
       where(state%cref .le. -998) state%missing = .true.
    elseif(trim(var) == 'vil') then
       allocate(state%vil(nx,ny))
       status(11) = nf90_get_var(ncid,fieldVarID,state%vil)
       where(state%vil .le. -998) state%missing = .true.
    elseif(trim(var) == 'vip') then
       allocate(state%vip(nx,ny))
       status(11) = nf90_get_var(ncid,fieldVarID,state%vip)
       where(state%vip .le. -998) state%missing = .true.
    elseif(trim(var) == 'precip') then
       allocate(state%precip(nx,ny))
       status(11) = nf90_get_var(ncid,fieldVarID,state%precip)
       where(state%precip .le. -998) state%missing = .true.
    elseif(trim(var) == 'coverage') then
       allocate(state%prob(nx,ny),cov(nx,ny),cnf(nx,ny))
       status(11) = nf90_inq_varid(ncid,'confidence',field2VarID)
       status(12) = nf90_get_var(ncid,fieldVarID,cov)
       status(13) = nf90_get_var(ncid,field2VarID,cnf)
       state%prob = 0.
       state%missing = .false.
       where(cov .eq. 3) state%prob = .25
       where(cov .eq. 2) state%prob = .40
       where(cov .eq. 1) state%prob = .75
       where(state%prob .le. -998) state%missing = .true.
       if (associated(state%prob)) print *, 'model prob field allocated'
    elseif(trim(var) == 'cov_conf') then
       allocate(state%prob(nx,ny))
       status(12) = nf90_get_var(ncid,fieldVarID,cov)
       state%prob = 0.
       state%missing = .false.
       where(cov .eq. 100) state%prob = .75
       where(cov .eq. 200) state%prob = .40
       where(cov .ge. 300) state%prob = .25
       where(state%prob .le. -998) state%missing = .true.
       if (associated(state%prob)) print *, 'model prob field allocated'
    elseif(trim(var) == 'prob') then
       allocate(state%prob(nx,ny))
       status(11) = nf90_get_var(ncid,fieldVarID,state%prob)
       where(state%prob .le. -998) state%missing = .true.
       state%prob = state%prob/100.
    elseif(trim(var) == 'echotop') then
       allocate(state%etp(nx,ny))
       status(11) = nf90_get_var(ncid,fieldVarID,state%etp)
       where(state%etp .lt. 0) state%missing = .true.
    else
       print *, 'Unknown model variable'
    endif

    if(any(status(:13) /= nf90_NoErr)) stop "Error reading model NetCDF file"
  
    status(1) = nf90_close(ncid)
    
  end subroutine read_model_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_cref_obs_nc_file(obsGrid,var,inputFileName,maskFileName,state)
    ! Open and read NSSL composite reflectivity observation NetCDF file
    character(len=*), intent(in)  :: obsGrid, var, inputFileName, maskFileName
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20)            :: status
    integer                           :: ncid, ndims, nvars, natts, nlat, nlon, i
    integer                           :: latDimID, lonDimID, crefVarID, maskVarID
    integer                           :: nx, ny, xDimID, yDimID, latVarID, lonVarID
    integer                           :: start(2), counter(2), mlat, mlon
    real                              :: latBdy, lonBdy, crefScaleFac
    real                              :: latSpc, lonSpc
    real, dimension(:),   allocatable :: lats, lons
    real, dimension(:,:), allocatable :: hgtMask

    print *, 'Reading: ', trim(inputFileName)

    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
    print *, 'ncid: ', ncid
    print *, 'ndims: ', ndims
    print *, 'nvars: ', nvars
    print *, 'natts: ', natts
   
 
    if (trim(obsGrid) == '01kmCE') then
       ! Get Lat/Lon global attributes
       status(3)  = nf90_get_att(ncid,nf90_global,"Latitude",latBdy)
       status(4)  = nf90_get_att(ncid,nf90_global,"LatGridSpacing",latSpc)
       status(5)  = nf90_get_att(ncid,nf90_global,"Longitude",lonBdy)
       status(6)  = nf90_get_att(ncid,nf90_global,"LonGridSpacing",lonSpc)
       
       ! Get number of Lats/Lons
       status(7)  = nf90_inq_dimid(ncid,"Lat",latDimID)
       status(8)  = nf90_inquire_dimension(ncid,latDimID,len = nlat)
       
       status(9)  = nf90_inq_dimid(ncid,"Lon",lonDimID)
       status(10) = nf90_inquire_dimension(ncid,lonDimID,len = nlon)
       
       allocate(state%cref(nlon,nlat),state%missing(nlon,nlat),state%lat(nlon,nlat),state%lon(nlon,nlat))
       allocate(lats(nlat),lons(nlon))
       allocate(hgtMask(nlon,nlat))

       ! Get VarIDs for all needed variables
       status(11) = nf90_inq_varid(ncid,trim(var),crefVarID)
       
       ! Get variable values
       status(12) = nf90_get_var(ncid,crefVarID,state%cref)
       
       ! Get scale factor
       status(13) = nf90_get_att(ncid,crefVarID,"Scale",crefScaleFac)
       
       state%cref = state%cref / crefScaleFac

       lats = (/ (latBdy+latSpc*(i-1),i=1,nlat) /)
       lons = (/ (360+lonBdy+lonSpc*(i-1),i=1,nlon) /)
       
       state%lat = spread(lats, 1, nlon)
       state%lon = transpose(spread(lons, 1, nlat))
 
       start = (/ 1, 1 /)
       counter = (/ nlon, nlat /)
    else
       
       ! Get number of Lats/Lons
       status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
       status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

       status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
       status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
       
       allocate(state%cref(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))
       allocate(hgtMask(nx,ny))

       ! Get Lat and Lon vars
       status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
       status(8)  = nf90_get_var(ncid,latVarID,state%lat)
       status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
       status(10) = nf90_get_var(ncid,lonVarID,state%lon)
    
       ! Get VarIDs for all needed variables
       status(11) = nf90_inq_varid(ncid,trim(var),crefVarID)
       
       ! Get variable values
       status(12) = nf90_get_var(ncid,crefVarID,state%cref)

       start = (/ 1, 1 /)
       counter = (/ nx, ny /)
    endif


    print*, 'Start: ', start
    print*, 'Count: ', counter

    print*, status(1:13)
    if(any(status(:20) /= nf90_NoErr)) stop "Error reading input Observation NetCDF file"
  
    status(1) = nf90_close(ncid)

    ! Read HSRH NSSL mask for eliminating coverage where lowest radar echo is >3.5KM
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)

    print*, 'Size of hgtMask: ', size(hgtMask)
    print*, 'maskFileName: ', maskFileName

    ! Get VarIDs for all needed variables
    status(2) = nf90_inq_varid(ncid,"hgt_mask",maskVarID)

    print*, 'NCID: ', ncid, ' maskVarID: ', maskVarID
    ! Get variable values
    status(3) = nf90_get_var(ncid,maskVarID,hgtMask)
   ! status(3) = nf90_get_var(ncid,maskVarID,hgtMask, start = start, &
   !             count = counter)

   ! print*, 'hgtMask: ', hgtMask

    print*, status(1:3)
    if(any(status(:3) /= nf90_NoErr)) stop "Error reading NSSL mask"
  
    status(1) = nf90_close(ncid)

    ! Assign missing value masks
    where(state%cref .le. -998.) state%missing = .true.
    where(hgtMask .eq. 0) state%missing = .true.
    
    ! Set missing values to 0
    where(state%cref .lt. 0) state%cref = 0

    ! Exponentiate reflectivity field
    state%cref = 10**(state%cref/10)

  end subroutine read_cref_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_cref_grib2_obs_nc_file(obsGrid,var,inputFileName,maskFileName,state)
    ! Open and read the original composite reflectivity model NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName, maskFileName
    character(len=*), intent(in)  :: obsGrid
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, ndims, nvars, natts, ny, nx
    integer                :: latVarID, lonVarID, crefVarID, maskVarID
    integer                :: yDimID, xDimID
    real, dimension(:,:), allocatable :: hgtMask
    real, dimension(:),   allocatable :: lats, lons

    print *, 'Reading: ', trim(inputFileName)

    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)

    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"latitude",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"longitude",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)

    allocate(state%cref(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))
    allocate(lats(ny),lons(nx))
    allocate(hgtMask(nx,ny))

    ! Get VarIDs for all needed variables
    status(7)  = nf90_inq_varid(ncid,trim(var),crefVarID)

    ! Get variable values
    status(8) = nf90_get_var(ncid,crefVarID,state%cref)

    ! Get Lat and Lon vars
    status(9)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(10)  = nf90_get_var(ncid,latVarID,lats)
    status(11) = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(12) = nf90_get_var(ncid,lonVarID,lons)

    state%lat = spread(lats, 1, nx)
    state%lon = transpose(spread(lons, 1, ny))
    !print *, 'State%LON: ', state%lon

    if(any(status(:12) /= nf90_NoErr)) stop "Error reading observation NetCDF file"

    status(1) = nf90_close(ncid)

    ! Read HSRH NSSL mask for eliminating coverage where lowest radar echo is >3.5KM
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)

    print*, 'Size of cref: ', size(state%cref)
    print*, 'Size of hgtMask: ', size(hgtMask)
    print*, 'maskFileName: ', maskFileName

    ! Get VarIDs for all needed variables
    status(2) = nf90_inq_varid(ncid,"hgt_mask",maskVarID)

    !print*, 'NCID: ', ncid, ' maskVarID: ', maskVarID

    ! Get variable values
    status(3) = nf90_get_var(ncid,maskVarID,hgtMask)
   ! status(3) = nf90_get_var(ncid,maskVarID,hgtMask, start = start, &
   !             count = counter)

    ! print*, 'hgtMask: ', hgtMask

    print*, status(1:3)
    if(any(status(:3) /= nf90_NoErr)) stop "Error reading NSSL mask"

    status(1) = nf90_close(ncid)

    ! Assign missing value masks
    where(state%cref .le. -998.) state%missing = .true.
    where(hgtMask .eq. 0) state%missing = .true.

    ! Set missing values to 0
    where(state%cref .lt. 0) state%cref = 0
    !print *, 'CREF: ', state%cref

    ! Exponentiate reflectivity field
    state%cref = 10**(state%cref/10)

  end subroutine read_cref_grib2_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------
  
  subroutine read_cref_model_nc_file(var,inputFileName,state)
    ! Open and read the original composite reflectivity model NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName
    type(state_type), intent(out) :: state  
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, ndims, nvars, natts, ny, nx
    integer                :: latVarID, lonVarID, crefVarID
    integer                :: yDimID, xDimID
    real, dimension(:,:,:,:), allocatable :: tmp

    print *, 'Reading: ', trim(inputFileName)
    
    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
  
    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
    
    allocate(state%cref(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))

    ! Get VarIDs for all needed variables
    status(7)  = nf90_inq_varid(ncid,trim(var),crefVarID)
    
    if (trim(var) == 'lmr') then
       ! No Lat/Lon vars, and 4D CREF field
       allocate(tmp(nx,ny,1,1))
       
       ! Get variable values
       status(8) = nf90_get_var(ncid,crefVarID,tmp,start = (/ 1, 1, 1, 1 /), count = (/ nx, ny, 1, 1 /))
       state%cref = tmp(:,:,1,1)
    else
       ! Get Lat and Lon vars
       status(8)  = nf90_inq_varid(ncid,"latitude",latVarID)
       status(9)  = nf90_get_var(ncid,latVarID,state%lat)
       status(10) = nf90_inq_varid(ncid,"longitude",lonVarID)
       status(11) = nf90_get_var(ncid,lonVarID,state%lon)
       
       ! Get variable values
       status(12) = nf90_get_var(ncid,crefVarID,state%cref)
    endif 
    
    if(any(status(:20) /= nf90_NoErr)) stop "Error reading model NetCDF file"
  
    status(1) = nf90_close(ncid)

    where(state%cref .ge. 9e20) state%missing = .true.
    where(state%cref .lt. 0 .or. state%cref .ge. 9e20) state%cref = 0
    
    state%cref = 10**(state%cref/10)
    
  end subroutine read_cref_model_nc_file

  !-------------------------------------------------------------------------------------------------------------
  
  subroutine read_precip_obs_nc_file(obsGrid,var,inputFileName,maskFileName,state)
    ! Open and read the CPC precipitation file
    character(len=*), intent(in)  :: obsGrid, var, inputFileName, maskFileName
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20)            :: status
    integer                           :: ncid, nlat, nlon, i
    integer                           :: latDimID, lonDimID, precipVarID
    integer                           :: nx, ny, xDimID, yDimID, latVarID, lonVarID, maskVarID
    real                              :: latBdy, lonBdy, missing_value
    real                              :: latSpc, lonSpc
    real, dimension(:),   allocatable :: lats, lons
    real, dimension(:,:), allocatable :: pcpMask
    
    print *, 'Reading: ', trim(inputFileName)

    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    
    if (trim(obsGrid) == 'cpc_13km') then
       ! Get Lat/Lon global attributes
       status(2)  = nf90_get_att(ncid,nf90_global,"Latitude",latBdy)
       status(3)  = nf90_get_att(ncid,nf90_global,"LatGridSpacing",latSpc)
       status(4)  = nf90_get_att(ncid,nf90_global,"Longitude",lonBdy)
       status(5)  = nf90_get_att(ncid,nf90_global,"LonGridSpacing",lonSpc)
       
       ! Get number of Lats/Lons
       status(6)  = nf90_inq_dimid(ncid,"Lat",latDimID)
       status(7)  = nf90_inquire_dimension(ncid,latDimID,len = nlat)
       
       status(8)  = nf90_inq_dimid(ncid,"Lon",lonDimID)
       status(9)  = nf90_inquire_dimension(ncid,lonDimID,len = nlon)
       
       allocate(state%precip(nlon,nlat),state%missing(nlon,nlat),state%lat(nlon,nlat),state%lon(nlon,nlat))
       allocate(lats(nlat),lons(nlon))
       
       ! Get VarIDs for all needed variables
       status(10) = nf90_inq_varid(ncid,trim(var),precipVarID)
       
       ! Get variable values
       status(11) = nf90_get_var(ncid,precipVarID,state%precip)

       lats = (/ (latBdy+latSpc*(i-1),i=1,nlat) /)
       lons = (/ (360+lonBdy+lonSpc*(i-1),i=1,nlon) /)
    
       state%lat = spread(lats, 1, nlon)
       state%lon = transpose(spread(lons, 1, nlat))

    elseif (trim(obsGrid) == 'stageIV_04km') then
       ! Get number of Lats/Lons
       status(2)  = nf90_inq_dimid(ncid,"y",yDimID)
       status(3)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

       status(4)  = nf90_inq_dimid(ncid,"x",xDimID)
       status(5)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
       
       allocate(state%precip(nx,ny),state%missing(nx,ny),pcpMask(nx,ny))
       
       ! Get VarIDs for all needed variables
       status(6)  = nf90_inq_varid(ncid,trim(var),precipVarID)
       
       ! Get variable values
       status(7)  = nf90_get_var(ncid,precipVarID,state%precip)

       ! Scale precipitation from kg/m^2 to inches using density of water(~1000 kg/m^3) and 1 meter ~= 39.37 inches
       state%precip = state%precip * (39.37/1000.0)
    else   
       ! Get number of Lats/Lons
       status(2)  = nf90_inq_dimid(ncid,"y",yDimID)
       status(3)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

       status(4)  = nf90_inq_dimid(ncid,"x",xDimID)
       status(5)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
       
       allocate(state%precip(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))

       ! Get Lat and Lon vars
       status(6)  = nf90_inq_varid(ncid,"latitude",latVarID)
       status(7)  = nf90_get_var(ncid,latVarID,state%lat)
       status(8)  = nf90_inq_varid(ncid,"longitude",lonVarID)
       status(9)  = nf90_get_var(ncid,lonVarID,state%lon)
       
       ! Get VarIDs for all needed variables
       status(10) = nf90_inq_varid(ncid,trim(var),precipVarID)
       
       ! Get variable values
       status(11) = nf90_get_var(ncid,precipVarID,state%precip)
    endif

    ! Get missing value
    status(12) = nf90_get_att(ncid,precipVarID,"_FillValue",missing_value)
    
    if(any(status(:20) /= nf90_NoErr)) stop "Error reading obs NetCDF file"
  
    status(1) = nf90_close(ncid)

    ! Assign missing values
    state%missing = .false.
    !where(abs(state%precip-missing_value) <= 2*spacing(state%precip)) state%missing = .true.
    where(state%precip .lt. 0) state%missing = .true.

    ! Read CPC-based precip mask, eliminating coverage outside the CONUS
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)

    ! Get VarIDs for all needed variables
    status(2) = nf90_inq_varid(ncid,"pcp_mask",maskVarID)

    ! Get variable values
    status(3) = nf90_get_var(ncid,maskVarID,pcpMask)
    
    if(any(status(:3) /= nf90_NoErr)) stop "Error reading NSSL mask"
  
    status(1) = nf90_close(ncid)

    ! Assign missing value masks
    where(pcpMask <= 0) state%missing = .true.
    
  end subroutine read_precip_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_precip_model_nc_file(var,inputFileName,state)
    ! Open and read the original precip model NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName
    type(state_type), intent(out) :: state  
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, ndims, nvars, natts, ny, nx
    integer                :: latVarID, lonVarID, precipVarID
    integer                :: yDimID, xDimID

    print *, 'Reading: ', trim(inputFileName)
    
    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
  
    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
    
    allocate(state%precip(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))

    ! Get Lat and Lon vars
    status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(8)  = nf90_get_var(ncid,latVarID,state%lat)
    status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(10) = nf90_get_var(ncid,lonVarID,state%lon)

    ! Get VarIDs for all needed variables
    status(11) = nf90_inq_varid(ncid,trim(var),precipVarID)

    ! Get variable values
    status(12) = nf90_get_var(ncid,precipVarID,state%precip)

    if(any(status(:20) /= nf90_NoErr)) stop "Error reading model NetCDF file"
  
    status(1) = nf90_close(ncid)

    ! Scale precipitation from kg/m^2 to inches using density of water(~1000 kg/m^3) and 1 meter ~= 39.37 inches
    state%precip = state%precip * (39.37/1000.0)

    ! Handle missing values
    state%missing = .false.
    where(state%precip .ge. 9e20) state%missing = .true.

  end subroutine read_precip_model_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_vil_obs_nc_file(obsGrid,var,inputFileName,maskFileName,state)
    ! Open and read NSSL VIL observation NetCDF file
    character(len=*), intent(in)  :: obsGrid, var, inputFileName, maskFileName
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20)            :: status
    integer                           :: ncid, ndims, nvars, natts, nlat, nlon, i
    integer                           :: latDimID, lonDimID, vilVarID, maskVarID
    integer                           :: nx, ny, xDimID, yDimID, latVarID, lonVarID
    real                              :: latBdy, lonBdy, vilScaleFac
    real                              :: latSpc, lonSpc
    real, dimension(:),   allocatable :: lats, lons
    real, dimension(:,:), allocatable :: hgtMask

    print *, 'Reading: ', trim(inputFileName)

    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
    
    if (trim(obsGrid) == '01kmCE') then
       ! Get Lat/Lon global attributes
       status(3)  = nf90_get_att(ncid,nf90_global,"Latitude",latBdy)
       status(4)  = nf90_get_att(ncid,nf90_global,"LatGridSpacing",latSpc)
       status(5)  = nf90_get_att(ncid,nf90_global,"Longitude",lonBdy)
       status(6)  = nf90_get_att(ncid,nf90_global,"LonGridSpacing",lonSpc)

       ! Get number of Lats/Lons
       status(7)  = nf90_inq_dimid(ncid,"Lat",latDimID)
       status(8)  = nf90_inquire_dimension(ncid,latDimID,len = nlat)

       status(9)  = nf90_inq_dimid(ncid,"Lon",lonDimID)
       status(10) = nf90_inquire_dimension(ncid,lonDimID,len = nlon)

       allocate(state%vil(nlon,nlat),state%missing(nlon,nlat),state%lat(nlon,nlat),state%lon(nlon,nlat))
       allocate(lats(nlat),lons(nlon))
       allocate(hgtMask(nlon,nlat))

       ! Get VarIDs for all needed variables
       status(11) = nf90_inq_varid(ncid,trim(var),vilVarID)

       ! Get variable values
       status(12) = nf90_get_var(ncid,vilVarID,state%vil)

       ! Get scale factor
       status(13) = nf90_get_att(ncid,vilVarID,"Scale",vilScaleFac)

       state%vil = state%vil / vilScaleFac

       lats = (/ (latBdy+latSpc*(i-1),i=1,nlat) /)
       lons = (/ (360+lonBdy+lonSpc*(i-1),i=1,nlon) /)

       state%lat = spread(lats, 1, nlon)
       state%lon = transpose(spread(lons, 1, nlat))
    else

       ! Get number of Lats/Lons
       status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
       status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

       status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
       status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)

       allocate(state%vil(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))
       allocate(hgtMask(nx,ny))

       ! Get Lat and Lon vars
       status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
       status(8)  = nf90_get_var(ncid,latVarID,state%lat)
       status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
       status(10) = nf90_get_var(ncid,lonVarID,state%lon)

       ! Get VarIDs for all needed variables
       status(11) = nf90_inq_varid(ncid,trim(var),vilVarID)

       ! Get variable values
       status(12) = nf90_get_var(ncid,vilVarID,state%vil)
    endif

    print*, status(1:13)
    if(any(status(:20) /= nf90_NoErr)) stop "Error reading input Observation NetCDF file"

    status(1) = nf90_close(ncid)

    ! Read HSRH NSSL mask for eliminating coverage where lowest radar echo is >3.5KM
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)

    ! Get VarIDs for all needed variables
    status(2) = nf90_inq_varid(ncid,"hgt_mask",maskVarID)

    ! Get variable values
    status(3) = nf90_get_var(ncid,maskVarID,hgtMask)

    if(any(status(:3) /= nf90_NoErr)) stop "Error reading NSSL mask"

    status(1) = nf90_close(ncid)

    ! Assign missing value masks
    !where(state%vil .le. -998.) state%missing = .true.
    where(hgtMask .eq. 0) state%missing = .true.

    ! Set missing values to 0
    where(state%vil .lt. 0) state%vil = 0

  end subroutine read_vil_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_vil_grib2_obs_nc_file(obsGrid,var,inputFileName,maskFileName,state)
    ! Open and read the original composite reflectivity model NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName, maskFileName
    character(len=*), intent(in)  :: obsGrid
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, ndims, nvars, natts, ny, nx
    integer                :: latVarID, lonVarID, vilVarID, maskVarID
    integer                :: yDimID, xDimID
    real, dimension(:,:), allocatable :: hgtMask
    real, dimension(:),   allocatable :: lats, lons

    print *, 'Reading: ', trim(inputFileName)

    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)

    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"latitude",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"longitude",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)

    allocate(state%vil(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))
    allocate(lats(ny),lons(nx))
    allocate(hgtMask(nx,ny))

    ! Get VarIDs for all needed variables
    status(7)  = nf90_inq_varid(ncid,trim(var),vilVarID)

    ! Get variable values
    status(8) = nf90_get_var(ncid,vilVarID,state%vil)

    ! Get Lat and Lon vars
    status(9)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(10)  = nf90_get_var(ncid,latVarID,lats)
    status(11) = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(12) = nf90_get_var(ncid,lonVarID,lons)

    state%lat = spread(lats, 1, nx)
    state%lon = transpose(spread(lons, 1, ny))
    !print *, 'State%LON: ', state%lon

    if(any(status(:12) /= nf90_NoErr)) stop "Error reading observation NetCDF file"

    status(1) = nf90_close(ncid)

    ! Read HSRH NSSL mask for eliminating coverage where lowest radar echo is
    ! >3.5KM
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)

    print*, 'Size of vil: ', size(state%vil)
    print*, 'Size of hgtMask: ', size(hgtMask)
    print*, 'maskFileName: ', maskFileName

    ! Get VarIDs for all needed variables
    status(2) = nf90_inq_varid(ncid,"hgt_mask",maskVarID)

    !print*, 'NCID: ', ncid, ' maskVarID: ', maskVarID

    ! Get variable values
    status(3) = nf90_get_var(ncid,maskVarID,hgtMask)
   ! status(3) = nf90_get_var(ncid,maskVarID,hgtMask, start = start, &
   !             count = counter)

    ! print*, 'hgtMask: ', hgtMask

    print*, status(1:3)
    if(any(status(:3) /= nf90_NoErr)) stop "Error reading NSSL mask"

    status(1) = nf90_close(ncid)

    ! Assign missing value masks
    ! where(state%cref .le. -998.) state%missing = .true.
    where(hgtMask .eq. 0) state%missing = .true.

    ! Set missing values to 0
    where(state%vil .lt. 0) state%vil = 0

  end subroutine read_vil_grib2_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------
  
  subroutine read_vil_model_nc_file(var,inputFileName,state)
    ! Open and read the original VIP level VIL model NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName
    type(state_type), intent(out) :: state  
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20)            :: status
    integer                           :: ncid, ndims, nvars, natts, ny, nx
    integer                           :: latVarID, lonVarID, vilVarID
    integer                           :: yDimID, xDimID
    real, dimension(:,:), allocatable :: vil

    print *, 'Reading: ', trim(inputFileName)
    
    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
  
    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
    
    allocate(state%vil(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))
    allocate(vil(nx,ny))

    ! Get Lat and Lon vars
    status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(8)  = nf90_get_var(ncid,latVarID,state%lat)
    status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(10) = nf90_get_var(ncid,lonVarID,state%lon)

    ! Get VarIDs for all needed variables
    status(11) = nf90_inq_varid(ncid,trim(var),vilVarID)

    ! Get variable values
    status(12) = nf90_get_var(ncid,vilVarID,vil)

    if(any(status(:20) /= nf90_NoErr)) stop "Error reading model NetCDF file"
  
    status(1) = nf90_close(ncid)
    
    ! Handle missing values
    state%missing = .false.
    where(vil .ge. 9e20) state%missing = .true.
    where(vil .lt. 0 .or. vil .ge. 9e20) vil = 0

    ! Turn VIL values into VIP levels
    !where(vil <  0.15)                    state%vil = 0
    !where(vil >=  0.15 .and. vil <  0.76) state%vil = 1
    !where(vil >=  0.76 .and. vil <  3.47) state%vil = 2
    !where(vil >=  3.47 .and. vil <  6.92) state%vil = 3
    !where(vil >=  6.92 .and. vil < 12.00) state%vil = 4
    !where(vil >= 12.00 .and. vil < 31.60) state%vil = 5
    !where(vil >= 31.60)                   state%vil = 6
    state%vil = vil

  end subroutine read_vil_model_nc_file
  
  !-------------------------------------------------------------------------------------------------------------
 
  subroutine read_vip_obs_nc_file(obsGrid,var,inputFileName,maskFileName,state)
    ! Open and read the original VIP level VIL observation NetCDF file
    character(len=*), intent(in)  :: obsGrid, var, inputFileName, maskFileName
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20)            :: status
    integer                           :: ncid, ndims, nvars, natts, nlat, nlon, i
    integer                           :: latDimID, lonDimID, vipVarID, maskVarID
    integer                           :: nx, ny, xDimID, yDimID, latVarID, lonVarID
    real                              :: latBdy, lonBdy
    real                              :: latSpc, lonSpc
    real, dimension(:),   allocatable :: lats, lons
    real, dimension(:,:), allocatable :: hgtMask

    print *, 'Reading: ', trim(inputFileName)

    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)

    if (trim(obsGrid) == 'ncwd_04km' .or. trim(obsGrid) == 'ncwd_80km') then
       ! Get Lat/Lon global attributes
       status(3)  = nf90_inq_varid(ncid,"La1",latVarID)
       status(4)  = nf90_get_var(ncid,latVarID,latBdy)
       status(5)  = nf90_inq_varid(ncid,"Lo1",lonVarID)
       status(6)  = nf90_get_var(ncid,lonVarID,lonBdy)
       status(7)  = nf90_inq_varid(ncid,"Dy",latVarID)
       status(8)  = nf90_get_var(ncid,latVarID,latSpc)
       status(9)  = nf90_inq_varid(ncid,"Dx",lonVarID)
       status(10) = nf90_get_var(ncid,lonVarID,lonSpc)

       ! Get number of Lats/Lons
       status(11) = nf90_inq_dimid(ncid,"yo",latDimID)
       status(12) = nf90_inquire_dimension(ncid,latDimID,len = nlat)

       status(13) = nf90_inq_dimid(ncid,"xo",lonDimID)
       status(14) = nf90_inquire_dimension(ncid,lonDimID,len = nlon)

       allocate(state%vip(nlon,nlat),state%missing(nlon,nlat),state%lat(nlon,nlat),state%lon(nlon,nlat))
       allocate(lats(nlat),lons(nlon))
       allocate(hgtMask(nlon,nlat))

       ! Get VarIDs for all needed variables
       status(15) = nf90_inq_varid(ncid,trim(var),vipVarID)

       ! Get variable values
       status(16) = nf90_get_var(ncid,vipVarID,state%vip)

       lats = (/ (latBdy+latSpc*(i-1),i=1,nlat) /)
       lons = (/ (360+lonBdy+lonSpc*(i-1),i=1,nlon) /)

       state%lat = spread(lats, 1, nlon)
       state%lon = transpose(spread(lons, 1, nlat))
    else

       ! Get number of Lats/Lons
       status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
       status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

       status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
       status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)

       allocate(state%vip(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))
       allocate(hgtMask(nx,ny))

       ! Get Lat and Lon vars
       status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
       status(8)  = nf90_get_var(ncid,latVarID,state%lat)
       status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
       status(10) = nf90_get_var(ncid,lonVarID,state%lon)

       ! Get VarIDs for all needed variables
       status(11) = nf90_inq_varid(ncid,trim(var),vipVarID)

       ! Get variable values
       status(12) = nf90_get_var(ncid,vipVarID,state%vip)
    endif

    if(any(status(:20) /= nf90_NoErr)) stop "Error reading input Observation NetCDF file"

    status(1) = nf90_close(ncid)

    ! Read HSRH NSSL mask (interpolated to NCWD) for eliminating coverage where lowest radar echo is >3.5KM
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)

    ! Get VarIDs for all needed variables
    status(2) = nf90_inq_varid(ncid,"hgt_mask",maskVarID)

    ! Get variable values
    status(3) = nf90_get_var(ncid,maskVarID,hgtMask)

    if(any(status(:3) /= nf90_NoErr)) stop "Error reading NSSL mask"

    status(1) = nf90_close(ncid)

    ! Assign missing value masks
    state%missing = .false.
    where(hgtMask .eq. 0) state%missing = .true.

    ! Set all negative values to 0
    where(state%vip .lt. 0) state%vip = 0
    !where(state%vip .lt. 0.) state%missing = .true.

  end subroutine read_vip_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------    
 
  subroutine read_vip_model_nc_file(var,inputFileName,state)
    ! Open and read the original VIP level VIL model NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20)            :: status
    integer                           :: ncid, ndims, nvars, natts, ny, nx
    integer                           :: latVarID, lonVarID, vipVarID
    integer                           :: yDimID, xDimID
    real, dimension(:,:), allocatable :: vil

    print *, 'Reading: ', trim(inputFileName)

    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)

    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)

    allocate(state%vip(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))
    allocate(vil(nx,ny))

    ! Get Lat and Lon vars
    status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(8)  = nf90_get_var(ncid,latVarID,state%lat)
    status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(10) = nf90_get_var(ncid,lonVarID,state%lon)

    ! Get VarIDs for all needed variables
    status(11) = nf90_inq_varid(ncid,trim(var),vipVarID)

    ! Get variable values
    status(12) = nf90_get_var(ncid,vipVarID,vil)

    if(any(status(:20) /= nf90_NoErr)) stop "Error reading model NetCDF file"

    status(1) = nf90_close(ncid)

    ! Handle missing values
    state%missing = .false.
    where(vil < 0) state%missing = .true.

    ! Turn VIL values into VIP levels
    where(vil <  0.15)                    state%vip = 0
    where(vil >=  0.15 .and. vil <  0.76) state%vip = 1
    where(vil >=  0.76 .and. vil <  3.47) state%vip = 2
    where(vil >=  3.47 .and. vil <  6.92) state%vip = 3
    where(vil >=  6.92 .and. vil < 12.00) state%vip = 4
    where(vil >= 12.00 .and. vil < 31.60) state%vip = 5
    where(vil >= 31.60)                   state%vip = 6

  end subroutine read_vip_model_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_prob_obs_nc_file(obsGrid,var,inputFileName,maskFileName,state)
    ! Open and read probability obs NetCDF file
    character(len=*), intent(in)  :: obsGrid, var, inputFileName, maskFileName
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, ndims, nvars, natts, ny, nx
    integer                :: latVarID, lonVarID, probVarID
    integer                :: yDimID, xDimID

    print *, 'Reading: ', trim(inputFileName)
    
    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
  
    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
    
    allocate(state%prob(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))

    ! Get Lat and Lon vars
    status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(8)  = nf90_get_var(ncid,latVarID,state%lat)
    status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(10) = nf90_get_var(ncid,lonVarID,state%lon)

    ! Get VarIDs for all needed variables
    status(11) = nf90_inq_varid(ncid,trim(var),probVarID)

    ! Get variable values
    status(12) = nf90_get_var(ncid,probVarID,state%prob)

    if(any(status(:20) /= nf90_NoErr)) stop "Error reading model NetCDF file"
  
    status(1) = nf90_close(ncid)

    where(state%prob .lt. 0) state%missing = .true.
    where(state%prob .lt. 0) state%prob = 0
    
    state%prob = 100*(state%prob)
    
  end subroutine read_prob_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------
  
  subroutine read_prob_model_nc_file(var,inputFileName,state)
    ! Open and read model probabilities NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName
    type(state_type), intent(out) :: state  
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, ndims, nvars, natts, ny, nx
    integer                :: latVarID, lonVarID, probVarID
    integer                :: yDimID, xDimID

    print *, 'Reading: ', trim(inputFileName)
    
    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
  
    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
    
    allocate(state%prob(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))

    ! Get Lat and Lon vars
    status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(8)  = nf90_get_var(ncid,latVarID,state%lat)
    status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(10) = nf90_get_var(ncid,lonVarID,state%lon)

    ! Get VarIDs for all needed variables
    status(11) = nf90_inq_varid(ncid,trim(var),probVarID)

    ! Get variable values
    status(12) = nf90_get_var(ncid,probVarID,state%prob)

    if(any(status(:20) /= nf90_NoErr)) stop "Error reading model NetCDF file"
  
    status(1) = nf90_close(ncid)

    where(state%prob .lt. 0) state%missing = .true.
    where(state%prob .lt. 0) state%prob = 0
    
    state%prob = 100.*(state%prob)
    
  end subroutine read_prob_model_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_etp_obs_nc_file(obsGrid,var,inputFileName,maskFileName,state)
    ! Open and read the original echo top height observation NetCDF file
    character(len=*), intent(in)  :: obsGrid, var, inputFileName, maskFileName
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20)            :: status
    integer                           :: ncid, ndims, nvars, natts, nlat, nlon, i
    integer                           :: latDimID, lonDimID, etpVarID, maskVarID
    integer                           :: nx, ny, xDimID, yDimID, latVarID, lonVarID
    real                              :: latBdy, lonBdy, etpScaleFac
    real                              :: latSpc, lonSpc
    real, dimension(:),   allocatable :: lats, lons
    real, dimension(:,:), allocatable :: hgtMask

    print *, 'Reading: ', trim(inputFileName)

    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
    
    if (trim(obsGrid) == '01kmCE') then
       ! Get Lat/Lon global attributes
       status(3)  = nf90_get_att(ncid,nf90_global,"Latitude",latBdy)
       status(4)  = nf90_get_att(ncid,nf90_global,"LatGridSpacing",latSpc)
       status(5)  = nf90_get_att(ncid,nf90_global,"Longitude",lonBdy)
       status(6)  = nf90_get_att(ncid,nf90_global,"LonGridSpacing",lonSpc)
       
       ! Get number of Lats/Lons
       status(7)  = nf90_inq_dimid(ncid,"Lat",latDimID)
       status(8)  = nf90_inquire_dimension(ncid,latDimID,len = nlat)
       
       status(9)  = nf90_inq_dimid(ncid,"Lon",lonDimID)
       status(10) = nf90_inquire_dimension(ncid,lonDimID,len = nlon)
       
       allocate(state%etp(nlon,nlat),state%missing(nlon,nlat),state%lat(nlon,nlat),state%lon(nlon,nlat))
       allocate(lats(nlat),lons(nlon))
       allocate(hgtMask(nlon,nlat))

       ! Get VarIDs for all needed variables
       status(11) = nf90_inq_varid(ncid,trim(var),etpVarID)
       
       ! Get variable values
       status(12) = nf90_get_var(ncid,etpVarID,state%etp)
       
       ! Get scale factor and divide
       status(13) = nf90_get_att(ncid,etpVarID,"Scale",etpScaleFac)
       
       state%etp = state%etp / etpScaleFac

       ! Convert to kftMSL from kmMSL
       state%etp = state%etp * 3.28084

       lats = (/ (latBdy+latSpc*(i-1),i=1,nlat) /)
       lons = (/ (360+lonBdy+lonSpc*(i-1),i=1,nlon) /)
       
       state%lat = spread(lats, 1, nlon)
       state%lon = transpose(spread(lons, 1, nlat))
    else
       
       ! Get number of Lats/Lons
       status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
       status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

       status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
       status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
       
       allocate(state%etp(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))
       allocate(hgtMask(nx,ny))

       ! Get Lat and Lon vars
       status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
       status(8)  = nf90_get_var(ncid,latVarID,state%lat)
       status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
       status(10) = nf90_get_var(ncid,lonVarID,state%lon)
    
       ! Get VarIDs for all needed variables
       status(11) = nf90_inq_varid(ncid,trim(var),etpVarID)
       
       ! Get variable values
       status(12) = nf90_get_var(ncid,etpVarID,state%etp)
    endif

    if(any(status(:20) /= nf90_NoErr)) stop "Error reading input Observation NetCDF file"
  
    status(1) = nf90_close(ncid)

    ! Read HSRH NSSL mask for eliminating coverage where lowest radar echo is >3.5KM
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)

    ! Get VarIDs for all needed variables
    status(2) = nf90_inq_varid(ncid,"hgt_mask",maskVarID)

    ! Get variable values
    status(3) = nf90_get_var(ncid,maskVarID,hgtMask)
    print*, trim(maskFileName)
    if(any(status(:3) /= nf90_NoErr)) stop "Error reading NSSL mask"
  
    status(1) = nf90_close(ncid)

    ! Assign missing value masks
    !where(state%etp .lt. 0) state%missing = .true.
    where(hgtMask .eq. 0) state%missing = .true.

    ! Set missing values to 0
    where(state%etp .lt. 0) state%etp = 0

  end subroutine read_etp_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_etp_grib2_obs_nc_file(obsGrid,var,inputFileName,maskFileName,state)
    ! Open and read the original composite reflectivity model NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName, maskFileName
    character(len=*), intent(in)  :: obsGrid
    type(state_type), intent(out) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, ndims, nvars, natts, ny, nx
    integer                :: latVarID, lonVarID, etpVarID, maskVarID
    integer                :: yDimID, xDimID
    real, dimension(:,:), allocatable :: hgtMask
    real, dimension(:),   allocatable :: lats, lons

    print *, 'Reading: ', trim(inputFileName)

    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)

    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"latitude",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"longitude",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)

    allocate(state%etp(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))
    allocate(lats(ny),lons(nx))
    allocate(hgtMask(nx,ny))

    ! Get VarIDs for all needed variables
    status(7)  = nf90_inq_varid(ncid,trim(var),etpVarID)

    ! Get variable values
    status(8) = nf90_get_var(ncid,etpVarID,state%etp)

    ! Get Lat and Lon vars
    status(9)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(10)  = nf90_get_var(ncid,latVarID,lats)
    status(11) = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(12) = nf90_get_var(ncid,lonVarID,lons)

    state%lat = spread(lats, 1, nx)
    state%lon = transpose(spread(lons, 1, ny))
    !print *, 'State%LON: ', state%lon

    if(any(status(:12) /= nf90_NoErr)) stop "Error reading observation NetCDF file"

    status(1) = nf90_close(ncid)

    ! Read HSRH NSSL mask for eliminating coverage where lowest radar echo is >3.5KM
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)

    print*, 'Size of etp: ', size(state%etp)
    print*, 'Size of hgtMask: ', size(hgtMask)
    print*, 'maskFileName: ', maskFileName

    ! Get VarIDs for all needed variables
    status(2) = nf90_inq_varid(ncid,"hgt_mask",maskVarID)

    !print*, 'NCID: ', ncid, ' maskVarID: ', maskVarID

    ! Get variable values
    status(3) = nf90_get_var(ncid,maskVarID,hgtMask)
   ! status(3) = nf90_get_var(ncid,maskVarID,hgtMask, start = start, &
   !             count = counter)

   ! print*, 'hgtMask: ', hgtMask

    print*, status(1:3)
    if(any(status(:3) /= nf90_NoErr)) stop "Error reading NSSL mask"

    status(1) = nf90_close(ncid)

    ! Assign missing value masks
    !where(state%etp .le. -998.) state%missing = .true.
    where(hgtMask .eq. 0) state%missing = .true.

    ! Set missing values to 0
    where(state%etp .lt. 0) state%etp = 0

    ! Convert from meters to kft
    state%etp = state%etp * .00328084 * 1000

  end subroutine read_etp_grib2_obs_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine read_etp_model_nc_file(var,inputFileName,state)
    ! Open and read the original composite reflectivity model NetCDF file
    character(len=*), intent(in)  :: var
    character(len=*), intent(in)  :: inputFileName
    type(state_type), intent(out) :: state  
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, ndims, nvars, natts, ny, nx
    integer                :: latVarID, lonVarID, etpVarID
    integer                :: yDimID, xDimID

    print *, 'Reading: ', trim(inputFileName)
    
    status(:)  = nf90_NoErr
    status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
    status(2)  = nf90_inquire(ncid,ndims,nvars,natts)
  
    ! Get number of Lats/Lons
    status(3)  = nf90_inq_dimid(ncid,"y",yDimID)
    status(4)  = nf90_inquire_dimension(ncid,yDimID,len = ny)

    status(5)  = nf90_inq_dimid(ncid,"x",xDimID)
    status(6)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
    
    allocate(state%etp(nx,ny),state%missing(nx,ny),state%lat(nx,ny),state%lon(nx,ny))

    ! Get Lat and Lon vars
    status(7)  = nf90_inq_varid(ncid,"latitude",latVarID)
    status(8)  = nf90_get_var(ncid,latVarID,state%lat)
    status(9)  = nf90_inq_varid(ncid,"longitude",lonVarID)
    status(10) = nf90_get_var(ncid,lonVarID,state%lon)

    ! Get VarIDs for all needed variables
    status(11) = nf90_inq_varid(ncid,trim(var),etpVarID)

    ! Get variable values
    status(12) = nf90_get_var(ncid,etpVarID,state%etp)

    if(any(status(:20) /= nf90_NoErr)) stop "Error reading model NetCDF file"
  
    status(1) = nf90_close(ncid)

    ! Convert from meters to kft
    state%etp = state%etp * .00328084

    where(state%etp .ge. 9e20) state%missing = .true.
    where(state%etp .lt. 0 .or. state%etp .ge. 9e20) state%etp = 0
    
  end subroutine read_etp_model_nc_file

  !-------------------------------------------------------------------------------------------------------------

  subroutine write_interp_state(fieldName,outVar,interpGrid,outFileName,state)
    ! Read in the interpolated states, then write both out to a NetCDF file
    character(len=*), intent(in) :: fieldName, outVar, interpGrid, outFileName
    type(state_type), intent(in) :: state
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(26)  :: status
    integer                 :: ncid, xDimID, yDimID
    integer                 :: fieldVarID, latVarID, lonVarID
    
    real, dimension(:,:), allocatable :: fieldVar
    real                              :: std_lat = -99, std_lon = -99
    real                              :: missing_value = -999, dx, dy
    integer                           :: x, y, imax, jmax
    integer, dimension(200)           :: gds
    character(len = max_name_len)     :: proj, varName, outFile, title
    
    print *, 'Writing ', trim(fieldName), ' to file'

    if(associated(state%cref)) then
       imax = size(state%cref,1)
       jmax = size(state%cref,2)
       
       allocate(fieldVar(imax,jmax))
       
       fieldVar = state%cref
    elseif(associated(state%vil)) then
       imax = size(state%vil,1)
       jmax = size(state%vil,2)
       
       allocate(fieldVar(imax,jmax))
       
       fieldVar = state%vil   
    elseif(associated(state%vip)) then
       imax = size(state%vip,1)
       jmax = size(state%vip,2)
       
       allocate(fieldVar(imax,jmax))
       
       fieldVar = state%vip   
    elseif(associated(state%precip)) then
       imax = size(state%precip,1)
       jmax = size(state%precip,2)
       
       allocate(fieldVar(imax,jmax))

       fieldVar = state%precip
    elseif(associated(state%prob)) then
       imax = size(state%prob,1)
       jmax = size(state%prob,2)
       
       allocate(fieldVar(imax,jmax))
       
       fieldVar = state%prob
    elseif(associated(state%etp)) then
       imax = size(state%etp,1)
       jmax = size(state%etp,2)
       
       allocate(fieldVar(imax,jmax))
       
       fieldVar = state%etp
    else
       stop "write_interp_state: No field to calculate contingency table for"
    endif
    
    ! Set GDS parameters
    gds = get_gds(interpGrid)
    
    if(gds(1) == 3) then
       proj = 'LambertConformal'
       std_lat = real(gds(12))/1000.
       std_lon = real(gds(7))/1000.
       dx = real(gds(8))
       dy = real(gds(9))
    elseif(gds(1) == 0) then
       proj = 'CylindricalEquidistant'
       dx = real(gds(9))/1000.
       dy = real(gds(10))/1000.
    else
       stop 'Only Lambert Conformal or Cylindrical Equidistant grids have been coded'
    endif


    x = gds(2)
    y = gds(3)
    
    where(state%missing) fieldVar = missing_value
        
    if(trim(fieldName) == 'obs') then
       title   = 'Observation interpolated grid'
    elseif(trim(fieldName) == 'model') then
       title   = 'Model interpolated grid'
    else
       title   = 'Threshold Verification grid'
    endif
       
    status(:)  = nf90_NoErr
  !  status(1)  = nf90_create(trim(outFileName),nf90_classic_model,ncid)
    status(1)  = nf90_create(trim(outFileName),nf90_clobber,ncid)
    status(2)  = nf90_put_att(ncid,nf90_global,'title',title)
    
    ! Put global attributes from interpolated grid
    status(3)  = nf90_put_att(ncid,nf90_global,'SW_corner_lat',state%lat(1,1))
    status(4)  = nf90_put_att(ncid,nf90_global,'SW_corner_lon',state%lon(1,1))
    status(5)  = nf90_put_att(ncid,nf90_global,'NE_corner_lat',state%lat(x,y))
    status(6)  = nf90_put_att(ncid,nf90_global,'NE_corner_lon',state%lon(x,y))
    status(7)  = nf90_put_att(ncid,nf90_global,'MapProjection',trim(proj))
       
    if(std_lat > -99)  then
       status(8)  = nf90_put_att(ncid,nf90_global,'YGridSpacing',dy)
       status(9)  = nf90_put_att(ncid,nf90_global,'XGridSpacing',dx)
       status(10) = nf90_put_att(ncid,nf90_global,'Standard_lon',std_lon)
       status(11) = nf90_put_att(ncid,nf90_global,'Standard_lat',std_lat)
    else
       status(8)  = nf90_put_att(ncid,nf90_global,'LatGridSpacing',dy)
       status(9)  = nf90_put_att(ncid,nf90_global,'LonGridSpacing',dx)
    endif

    ! Put in valid, lead, and forecast times for NCL plotting titles
    status(12) = nf90_put_att(ncid,nf90_global,'ValidTime',trim(valid_time))
    if(trim(fieldName) == 'model' .or. trim(fieldName) == 'verif') then
       status(13) = nf90_put_att(ncid,nf90_global,'InitialTime',trim(initial_time))
       status(14) = nf90_put_att(ncid,nf90_global,'ForecastTime',trim(forecast_time))
    endif

    if(trim(fieldName) == 'verif') status(15) = nf90_put_att(ncid,nf90_global,'Threshold',threshold)

    ! Define dimension variables
    status(16) = nf90_def_dim(ncid,'x',size(fieldVar,1),xDimID)
    status(17) = nf90_def_dim(ncid,'y',size(fieldVar,2),yDimID)
    
    ! Define variables
    status(18) = nf90_def_var(ncid,trim(outVar) ,nf90_float,(/xDimID,yDimID/),fieldVarID)
    status(19) = nf90_def_var(ncid,'latitude',   nf90_float,(/xDimID,yDimID/),latVarID)
    status(20) = nf90_def_var(ncid,'longitude',  nf90_float,(/xDimID,yDimID/),lonVarID)
    
    ! Define missing values
    status(21) = nf90_put_att(ncid,fieldVarID,'_FillValue',missing_value)

    ! End of definitions
    status(22) = nf90_enddef(ncid)
    
    ! Put dimension variables and state variables
    status(23) = nf90_put_var(ncid,fieldVarID,fieldVar)
    status(24) = nf90_put_var(ncid,latVarID,  state%lat)
    status(25) = nf90_put_var(ncid,lonVarID,  state%lon)
    
    if(any(status(:25) /= nf90_NoErr)) stop "Error writing interpolated state to NetCDF file"
    
    status(1) = nf90_close(ncid)
    
    print *, 'Done writing interpolated grid to NC file'
    
  end subroutine write_interp_state
  
  !---------------------------------------------------------------------------------
  
  subroutine calc_contingencies(obs_state,model_state,verif_state,threshold,domain,cont_tbl)
    ! Difference model and obs to create contingency table
    type(state_type),      intent(in)  :: obs_state, model_state
    real,                  intent(in)  :: threshold
    character(len=*),      intent(in)  :: domain
    type(state_type),      intent(out) :: verif_state
    type(cont_table_type), intent(out) :: cont_tbl
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer                           :: imax, jmax, i, j
    real                              :: lat_a, lat_b, lon_a, lon_b
    real, dimension(4)                :: edges
    real, dimension(:,:), allocatable :: obs, model, verif
    
    print *, 'Calculating contingency table'

    ! Initialize contingency table
    cont_tbl%hits              = 0
    cont_tbl%false_alarms      = 0
    cont_tbl%misses            = 0
    cont_tbl%correct_negatives = 0

    ! Determine Lat/Lon boundaries for domain
    edges = get_domain(trim(domain))
    lat_a = edges(1)
    lat_b = edges(2)
    lon_a = edges(3)
    lon_b = edges(4)


    if(associated(model_state%cref)) then
       imax = size(model_state%cref,1)
       jmax = size(model_state%cref,2)

       print *, 'inside cref'

       allocate(verif(imax,jmax),obs(imax,jmax),model(imax,jmax))

       obs   = obs_state%cref
       model = model_state%cref
    elseif(associated(model_state%vil)) then
       imax = size(model_state%vil,1)
       jmax = size(model_state%vil,2)

       allocate(verif(imax,jmax),obs(imax,jmax),model(imax,jmax))

       obs   = obs_state%vil
       model = model_state%vil
    elseif(associated(model_state%vip)) then
       imax = size(model_state%vip,1)
       jmax = size(model_state%vip,2)
       print *, 'model state still has VIP association'
       allocate(verif(imax,jmax),obs(imax,jmax),model(imax,jmax))

       obs   = obs_state%vip
       model = model_state%vip
    elseif(associated(model_state%precip)) then
       imax = size(model_state%precip,1)
       jmax = size(model_state%precip,2)

       allocate(verif(imax,jmax),obs(imax,jmax),model(imax,jmax))

       obs   = obs_state%precip
       model = model_state%precip
    elseif(associated(model_state%prob)) then
       imax = size(model_state%prob,1)
       jmax = size(model_state%prob,2)

       allocate(verif(imax,jmax),obs(imax,jmax),model(imax,jmax))
       print *, 'allocating prob verif, obs, model'
       obs   = obs_state%prob
       model = model_state%prob
    elseif(associated(model_state%etp)) then
       imax = size(model_state%etp,1)
       jmax = size(model_state%etp,2)

       allocate(verif(imax,jmax),obs(imax,jmax),model(imax,jmax))

       obs   = obs_state%etp
       model = model_state%etp
    else
       stop "calc_contingencies: No field to calculate contingency table for"
    endif
    ! Loop over domain and aggregate counts for a given subdomain and contingency
    do i=1,imax
       do j=1,jmax
          if(model_state%missing(i,j) .or. obs_state%missing(i,j)) then
            ! print *, 'Missing Data for this point: ', i, j
             verif(i,j) = 0
          elseif(model(i,j) .ge. threshold .and. obs(i,j) .ge. threshold) then
            ! print *, 'Model/Obs above the threshold for this point: ', i, j
             verif(i,j) = 4
             if(model_state%lon(i,j) .gt. lon_a .and. model_state%lon(i,j) .le. lon_b) then
                if(model_state%lat(i,j) .gt. lat_a .and. model_state%lat(i,j) .le. lat_b) then
            !       print *, 'Hit at this point: ', i, j
                   cont_tbl%hits = cont_tbl%hits + 1
                endif
             endif
          elseif(model(i,j) .ge. threshold .and. obs(i,j) .le. threshold) then
            ! print *, 'Model above the threshold for this point: ', i, j
             verif(i,j) = 3
             if(model_state%lon(i,j) .gt. lon_a .and. model_state%lon(i,j) .le. lon_b) then
                if(model_state%lat(i,j) .gt. lat_a .and. model_state%lat(i,j) .le. lat_b) then
            !       print *, 'False Alarm at this point: ', i, j
                   cont_tbl%false_alarms = cont_tbl%false_alarms + 1
                endif
             endif
          elseif(model(i,j) .le. threshold .and. obs(i,j) .ge. threshold) then
            ! print *, 'Obs above the threshold for this point: ', i, j
             verif(i,j) = 2
             if(model_state%lon(i,j) .gt. lon_a .and. model_state%lon(i,j) .le. lon_b) then
                if(model_state%lat(i,j) .gt. lat_a .and. model_state%lat(i,j) .le. lat_b) then
            !       print *, 'Miss at this point: ', i, j
                   cont_tbl%misses = cont_tbl%misses + 1
                endif
             endif
          else
            ! print *, 'Neither above the threshold for this point: ', i, j
             verif(i,j) = 1
             if(model_state%lon(i,j) .gt. lon_a .and. model_state%lon(i,j) .le. lon_b) then
                if(model_state%lat(i,j) .gt. lat_a .and. model_state%lat(i,j) .le. lat_b) then
            !       print *, 'Correct negative at this point: ', i, j
                   cont_tbl%correct_negatives = cont_tbl%correct_negatives + 1
                endif
             endif
          endif
       enddo
    enddo
    
    allocate(verif_state%lat(imax,jmax),verif_state%lon(imax,jmax),verif_state%missing(imax,jmax))

    verif_state%lat = obs_state%lat
    verif_state%lon = obs_state%lon
    where(verif == 0) verif_state%missing = .true.

    if(associated(model_state%cref)) then
       allocate(verif_state%cref(imax,jmax))
       verif_state%cref = verif
    elseif(associated(model_state%vil)) then
       allocate(verif_state%vil(imax,jmax))
       verif_state%vil = verif
    elseif(associated(model_state%vip)) then
       allocate(verif_state%vip(imax,jmax))
       verif_state%vip = verif
    elseif(associated(model_state%precip)) then
       allocate(verif_state%precip(imax,jmax))
       verif_state%precip = verif
    elseif(associated(model_state%prob)) then
       allocate(verif_state%prob(imax,jmax))
       verif_state%prob = verif
       print *, 'allocating verif_state%prob'
    elseif(associated(model_state%etp)) then
       allocate(verif_state%etp(imax,jmax))
       verif_state%etp = verif
    else
       stop "calc_contingencies: No field to calculate contingency table for"
    endif
    
  end subroutine calc_contingencies

  !---------------------------------------------------------------------------------

  subroutine calc_statistics(cont_tbl,stats)
    ! Input contingency table, output verification statistics
    type(cont_table_type), intent(in) :: cont_tbl
    type(stats_type),      intent(out):: stats
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    real :: random_hits

    print *, 'Calculating statistics'

    random_hits = real(cont_tbl%hits + cont_tbl%false_alarms) *    &
                  real(cont_tbl%hits + cont_tbl%misses) /          &
                  real(cont_tbl%hits + cont_tbl%false_alarms +     &
                   cont_tbl%correct_negatives + cont_tbl%misses)
 
    !Calculate statistics from contingency table
    stats%bias = real(cont_tbl%hits + cont_tbl%false_alarms) /  &
                 real(cont_tbl%hits + cont_tbl%misses)

    stats%pod  = real(cont_tbl%hits) / real(cont_tbl%hits + cont_tbl%misses)

    stats%far  = real(cont_tbl%false_alarms) / real(cont_tbl%hits + cont_tbl%false_alarms)

    stats%csi  = real(cont_tbl%hits) /  &
                 real(cont_tbl%hits + cont_tbl%misses + cont_tbl%false_alarms) 

    stats%ets  = real(cont_tbl%hits - random_hits) /      &
                 real(cont_tbl%hits + cont_tbl%misses +   &
                  cont_tbl%false_alarms - random_hits)

    stats%hk   = stats%pod - (real(cont_tbl%false_alarms) /  &
                 real(cont_tbl%false_alarms + cont_tbl%correct_negatives))

    stats%hss  = 2*real(cont_tbl%hits*cont_tbl%correct_negatives - cont_tbl%misses*cont_tbl%false_alarms) /     &
                 real((cont_tbl%hits + cont_tbl%misses)*(cont_tbl%correct_negatives + cont_tbl%misses) +        &
                  (cont_tbl%hits + cont_tbl%false_alarms)*(cont_tbl%correct_negatives + cont_tbl%false_alarms))

  end subroutine calc_statistics

  !---------------------------------------------------------------------------------

  subroutine write_verif_ascii_file(stats,cont_tbl,outputFileName)
    ! Write summary verification statistics to output ASCII file
    type(stats_type),      intent(in) :: stats
    type(cont_table_type), intent(in) :: cont_tbl
    character(len=*),      intent(in) :: outputFileName
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    open(99,file=trim(outputFileName),form='formatted',access='append',status='old')
    write(99,'(4(I8,3X),A,6(2X,F7.4),2X,F8.4)') cont_tbl%hits, cont_tbl%misses, cont_tbl%false_alarms,      &
                                                cont_tbl%correct_negatives, '|', stats%bias, stats%csi,     &
                                                stats%pod, stats%far, stats%ets, stats%hk, stats%hss
    close(99)

  end subroutine write_verif_ascii_file

  !---------------------------------------------------------------------------------

  function get_gds(grid)
    character(len=*), intent(in) :: grid
    integer, dimension(200)      :: get_gds
    
    get_gds = 0
    
    if(trim(grid) == '03kmLC') get_gds = hrrr03_gds
    if(trim(grid) == '10kmLC') get_gds = hrrr10_gds
    if(trim(grid) == '20kmLC') get_gds = hrrr20_gds
    if(trim(grid) == '40kmLC') get_gds = hrrr40_gds
    if(trim(grid) == '80kmLC') get_gds = hrrr80_gds
    if(trim(grid) == '01kmCE_grib2') get_gds = nssl_grib2_gds
    if(trim(grid) == '01kmCE') get_gds = nssl01_gds
    if(trim(grid) == '10kmCE') get_gds = nssl10_gds
    if(trim(grid) == '20kmCE') get_gds = nssl20_gds
    if(trim(grid) == '40kmCE') get_gds = nssl40_gds
    if(trim(grid) == '13kmLC') get_gds = ruc13_gds
    if(trim(grid) == 'ruc_20km') get_gds = ruc20_gds
    if(trim(grid) == 'ncwd_04km') get_gds = ncwd04_gds
    if(trim(grid) == 'ncwd_80km') get_gds = ncwd80_gds
    if(trim(grid) == 'cpc_13km') get_gds = cpc13_gds
    if(trim(grid) == 'nam_05km') get_gds = nam05_gds
    if(trim(grid) == 'nam_12km') get_gds = nam12_gds
    if(trim(grid) == 'stageIV_04km') get_gds = stageIV04_gds
    if(trim(grid) == 'stmaslaps_conus_03km') get_gds = hrrr03_gds 
    if(trim(grid) == 'stmaslaps_ci_03km') get_gds = stmaslaps_ci03_gds
    if(trim(grid) == 'stmaslaps_hwt_03km') get_gds = stmaslaps_hwt03_gds
    if(trim(grid) == 'stmaslaps_roc_03km') get_gds = stmaslaps_roc03_gds
    if(trim(grid) == 'nssl_04km') get_gds = nsslwrf04_gds 

    if(trim(grid) == '03kmLC_C') get_gds = hrrre03_c_gds
    if(trim(grid) == '03kmLC_S') get_gds = hrrre03_s_gds
    if(trim(grid) == '03kmLC_NE') get_gds = hrrre03_ne_gds
    if(trim(grid) == '03kmLC_SE') get_gds = hrrre03_se_gds
    if(trim(grid) == '03kmLC_N') get_gds = hrrre03_n_gds

 
    if(sum(get_gds) == 0) stop 'Native RR/RUC, HRRR, NCWD, CPC, or NSSL based 3KM, 10KM, 20KM, or 40KM input grid right now'

  end function get_gds

  !---------------------------------------------------------------------------------

  function get_domain(domain)
    character(len=*), intent(in) :: domain
    real, dimension(4)           :: get_domain
    
    get_domain = 0
    
    if(trim(domain) == 'conus') get_domain = conus_domain
    if(trim(domain) == 'east')  get_domain = east_domain
    if(trim(domain) == 'west')  get_domain = west_domain
    if(trim(domain) == 'ne')    get_domain = ne_domain
    if(trim(domain) == 'se')    get_domain = se_domain
    if(trim(domain) == 'ci')    get_domain = ci_domain
    if(trim(domain) == 'hwt')   get_domain = hwt_domain
    if(trim(domain) == 'roc')   get_domain = roc_domain
    if(trim(domain) == 'central')   get_domain = central_domain
    if(trim(domain) == 'south')   get_domain = south_domain
    if(trim(domain) == 'southeast')   get_domain = southeast_domain
    if(trim(domain) == 'northeast')   get_domain = northeast_domain
    if(trim(domain) == 'north')   get_domain = north_domain

    if(sum(get_domain) == 0) stop 'Domain not recognized'

  end function get_domain
!=============================================================================================================
end module verif_mod
