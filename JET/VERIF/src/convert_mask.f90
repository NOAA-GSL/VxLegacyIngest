program convert_mask
!=================================================================================
!
! This program interpolates the NSSL radar mask field to the NCWD grid, for
! verification purposes.
!
! INPUTS: NSSL mask file
! 
! OUTPUTS: NSSL mask file on NCWD grid
!
! Written by: Patrick Hofmann
! Last Update: 18 AUG 2010
!
!=================================================================================
use netcdf

implicit none

! Define variables.
real, dimension(:,:), allocatable :: mask, new_mask
integer                           :: i
integer, dimension(200)            :: nssl01_gds, ncwd04_gds, hrrr03_gds, &
hrrr03_se_gds, hrrr03_ne_gds, hrrr03_s_gds, hrrr03_c_gds, hrrre03_gds

! Define possible GDS parameters for different mappings as decoded by W3FI63

! NSSL Equidistant Cylindrical (Lat/Lon) ~ 1KM/.01DEG spacing
!nssl01_gds = (/ 0,7001,3501,int(20.*1000),int((360.-130.)*1000),8,int((20.+.01*3501)*1000),  &
!              int((360.-130.+.01*7001)*1000),int(.01*1000),int(.01*1000),                    &
!              64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                                     /)
!nssl01_gds = (/ 0,7000,3500,int(20.*1000),int((360.-130.)*1000),8,int((20.+.01*3500)*1000),  &
!              int((360.-130.+.01*7000)*1000),int(.01*1000),int(.01*1000),                    &
!              64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                                     /)
!
nssl01_gds = (/ 0,7000,3500,int(20.*1000),int((360.-130.+.01*1000)*1000),8,int((20.+.01*3500)*1000),  &
              int((360.-130.)*1000),int(.01*1000),int(.01*1000),                    &
              64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                                     /)

! NCWD Equidistant Cylindrical (Lat/Lon) ~ 4KM/.04DEG spacing
ncwd04_gds = (/ 0,1830,918,int(20.018*1000),int((230.019)*1000),8,int((20.018+.035933*918)*1000), &
                  int((230.019+.038239*1830)*1000),int(.035933*1000),int(.038239*1000),           &
                  64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                                      /)

! 3KM Lambert Conformal Conic - HRRR domain
hrrr03_gds = (/ 3,1799,1059,int(21.138*1000),int((360.-122.72)*1000),8,int((360.-97.5)*1000), &
                          3000,3000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

! 3KM Lambert Conformal Conic - HRRR domain
hrrr03_se_gds = (/ 3,650,550,int(25.522*1000),int((360.-98.933)*1000),8,int((360.-101.0)*1000), &
                          3000,3000,0,64,int(32.0*1000),int(46.0*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

! 3KM Lambert Conformal Conic - HRRR domain
hrrr03_ne_gds = (/ 3,750,500,int(35.248*1000),int((360.-96.332)*1000),8,int((360.-101.0)*1000), &
                          3000,3000,0,64,int(46.0*1000),int(32.0*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

! 3KM Lambert Conformal Conic - HRRR domain
hrrr03_s_gds = (/ 3,650,550,int(24.039*1000),int((360.-107.04)*1000),8,int((360.-101.0)*1000), &
                          3000,3000,0,64,int(46.0*1000),int(32.0*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

! 3KM Lambert Conformal Conic - HRRR domain
hrrr03_c_gds = (/ 3,650,550,int(29.119*1000),int((360.-106.662)*1000),8,int((360.-101.0)*1000), &
                          3000,3000,0,64,int(46.0*1000),int(32.0*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

! 3KM Lambert Conformal Conic - HRRRE domain
hrrre03_gds = (/ 3,1129,939,int(23.867*1000),int((360.-107.503)*1000),8,int((360.-97.5)*1000), &
                          3000,3000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)    /)

!---------------------------------------------------------------------------------

! Read NSSL radar mask file
!call read_mask_file('/home/amb-verif/VERIF/static/orig_nssl_hgt_mask.nc',mask)
call read_mask_file('/lfs3/projects/amb-verif/static/nssl_hgt_mask.nc',mask)

print *, 'here0'
! Interpolate NSSL mask to NCWD grid
call interpolate(mask,new_mask)
 
! Write NCWD radar mask to file
call write_mask('/lfs3/projects/amb-verif/verif/mask/hrrre_hgt_mask.nc',new_mask)

!---------------------------------------------------------------------------------

contains

!---------------------------------------------------------------------------------

  subroutine read_mask_file(maskFileName,hgt_mask)
    ! Open and read the observation NetCDF file, then write out state
    character(len=*),                  intent(in)  :: maskFileName
    real, dimension(:,:), allocatable, intent(out) :: hgt_mask
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20)            :: status
    integer                           :: nlat, nlon, ncid
    integer                           :: latDimID, lonDimID, maskVarID

    print *, 'Reading: ', trim(maskFileName)

    ! Read HSRH NSSL mask for eliminating coverage where lowest radar echo is >3.5KM
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)


    ! Get number of Lats/Lons
    status(2)  = nf90_inq_dimid(ncid,"Lat",latDimID)
    status(3)  = nf90_inquire_dimension(ncid,latDimID,len = nlat)

    print *, 'LAT: ', status(2)
    print *, '#LAT: ', status(3)

    status(4)  = nf90_inq_dimid(ncid,"Lon",lonDimID)
    status(5)  = nf90_inquire_dimension(ncid,lonDimID,len = nlon)

    print *, 'LON: ', status(4)
    print *, '#LON: ', status(5)

    allocate(hgt_mask(nlon,nlat))

    ! Get VarIDs for all needed variables
    status(6) = nf90_inq_varid(ncid,"hgt_mask",maskVarID)

    print *, 'VarIDs: ', status(6)

    ! Get variable values
    status(7) = nf90_get_var(ncid,maskVarID,hgt_mask)

    if(any(status(:7) /= nf90_NoErr)) stop "Error reading NSSL mask"
 
    status(1) = nf90_close(ncid)

  end subroutine read_mask_file

!---------------------------------------------------------------------------------

  subroutine interpolate(nssl_mask,ncwd_mask)
    ! Interpolate state to desired grid using specified type of interpolation
    real, dimension(:,:), allocatable, intent(in)  :: nssl_mask
    real, dimension(:,:), allocatable, intent(out) :: ncwd_mask
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer                              :: iostat
    integer                              :: ip, km = 1, ibi = 0, ibo, no, func
    integer                              :: status, i, j, k
    integer                              :: xi, yi, mi, xo, yo, mo
    integer, dimension(20)               :: ipopt
    integer, dimension(200)               :: kgdsi, kgdso
    logical, dimension(:,:), allocatable :: lo, li
    real,    dimension(:,:), allocatable :: ro, ri
    real,    dimension(:),   allocatable :: rlat, rlon

    ! Input GDS parameters
    kgdsi = nssl01_gds

    ! Output GDS parameters
    kgdso = hrrre03_gds  !ncwd04_gds

    ! Ipolates parameters
    xi = kgdsi(2)
    yi = kgdsi(3)
    xo = kgdso(2)
    yo = kgdso(3)
    mi = xi*yi
    mo = xo*yo

    allocate(li(mi,km),lo(mo,km),ri(mi,km),ro(mo,km),rlat(mo),rlon(mo))
    allocate(ncwd_mask(xo,yo))

    func  = 0
    ipopt = (/ (-1,i=1,20) /)
    ip    = 6
       
    !where(nssl_mask == 0) nssl_mask = -9e20
    
    ri(:,km) = reshape(nssl_mask, (/ size(nssl_mask) /) )
    li(:,km) = 0
   
 
    print *, 'Calling ipolates library'
    call ipolates(ip,ipopt,kgdsi,kgdso,mi,mo,km,ibi,li,ri,func,  &
         no,rlat,rlon,ibo,lo,ro,status)
    print *, 'STATUS: ', status 
    if(status > 0) stop 'Interpolation failed, check input parameters'
    
    ncwd_mask = reshape(ro(:,km), (/ xo,yo /) )
        
    where(ncwd_mask >  0.5) ncwd_mask = 1
    where(ncwd_mask <= 0.5) ncwd_mask = 0
    
    print *, 'Done interpolating '

  end subroutine interpolate

!---------------------------------------------------------------------------------

  subroutine write_mask(newFileName,mask)
    ! Read in the interpolated states, then write both out to a NetCDF file
    character(len=*),                  intent(in)  :: newFileName
    real, dimension(:,:), allocatable, intent(in)  :: mask
    !+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    integer, dimension(20) :: status
    integer                :: ncid, xDimID, yDimID
    integer                :: maskVarID
    
    status(:)  = nf90_NoErr
    status(1)  = nf90_create(trim(newFileName),nf90_clobber,ncid)
    status(2)  = nf90_put_att(ncid,nf90_global,'title','HRRRE Height Mask from NSSL Radar')

    ! Put global attributes from interpolated grid
    status(3)  = nf90_put_att(ncid,nf90_global,'DataType','LamConGrid')
    status(4)  = nf90_put_att(ncid,nf90_global,'Latitude',23.867)
    status(5)  = nf90_put_att(ncid,nf90_global,'Longitude',-107.503)
    status(6)  = nf90_put_att(ncid,nf90_global,'LatGridSpacing',3000.)
    status(7)  = nf90_put_att(ncid,nf90_global,'LonGridSpacing',3000.)

    ! Define dimension variables
    status(8)  = nf90_def_dim(ncid,'Lon',size(mask,1),xDimID)
    status(9)  = nf90_def_dim(ncid,'Lat',size(mask,2),yDimID)
    
    ! Define variables
    status(10) = nf90_def_var(ncid,'hgt_mask',nf90_double,(/xDimID,yDimID/),maskVarID)
    
    print *, 'ncid: ', ncid, 'maskVarID: ', maskVarID
    
    ! End of definitions
    status(11) = nf90_enddef(ncid)
   
    print *, 'Size of MASK 1: ', size(mask,1)
    print *, 'Size of MASK 2: ', size(mask,2)
    ! print *, 'MASK: ', mask
 
    ! Put dimension variables and state variables
    status(12) = nf90_put_var(ncid,maskVarID,mask)
           
    if(any(status(:20) /= nf90_NoErr)) stop "Error writing interpolated NCWD mask field"
    
    status(1) = nf90_close(ncid)

    print *, 'Done writing interpolated grid to NC file'

  end subroutine write_mask

!=================================================================================
end program convert_mask
