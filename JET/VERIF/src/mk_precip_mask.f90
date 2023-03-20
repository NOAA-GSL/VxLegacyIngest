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
  integer, dimension(200)           :: nssl01_gds, ncwd04_gds, hrrr03_gds, stageIV04_gds
  
  ! Define possible GDS parameters for different mappings as decoded by W3FI63
  
  ! NSSL Equidistant Cylindrical (Lat/Lon) ~ 1KM/.01DEG spacing
  parameter nssl01_gds = (/ 0,7001,3501,int(20.*1000),int((360.-130.)*1000),8,int((20.+.01*3501)*1000),  &
                            int((360.-130.+.01*7001)*1000),int(.01*1000),int(.01*1000),                  &
                            64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                           /) 
  
  ! 04KM Polar Stereographic - StageIV domain
  parameter stageIV04_gds = (/ 5,1121,881,int(23.098*1000),int(240.964*1000),8,int(255.0*1000), &
                               4763,4763,0,64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                   /)  

  ! 3KM Lambert Conformal Conic - HRRR domain
  parameter hrrr03_gds = (/ 3,1799,1059,int(21.138*1000),int((360.-122.72)*1000),8,int((360.-97.5)*1000), &
                            3000,3000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)      /)

!---------------------------------------------------------------------------------

! Read NSSL radar mask file
call read_mask_file('/home/rtrr/VERIF/static/nssl_hgt_mask.nc',mask)

! Interpolate NSSL mask to NCWD grid
call interpolate(mask,new_mask)

! Write NCWD radar mask to file
call write_mask('/pan2/projects/nrtrr/phofmann/verif/exec/stageIV_pcp_mask.nc',new_mask)

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
    real                              :: latBdy, lonBdy, latSpc, lonSpc
    integer                           :: latDimID, lonDimID, maskVarID, i
    
    print *, 'Reading: ', trim(maskFileName)

    ! Read HSRH NSSL mask for eliminating coverage where lowest radar echo is >3.5KM
    status(:) = nf90_NoErr
    status(1) = nf90_open(trim(maskFileName),nf90_nowrite,ncid)

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
    
    allocate(hgt_mask(nlon,nlat))

    ! Get VarIDs for all needed variables
    status(6) = nf90_inq_varid(ncid,"hgt_mask",maskVarID)

    ! Get variable values
    status(7) = nf90_get_var(ncid,maskVarID,hgt_mask)

    if(any(status(:7) /= nf90_NoErr)) stop "Error reading NSSL mask"
  
    status(1) = nf90_close(ncid)

    ! Remove missing locations inside CONUS
    hgt_mask(900:3000,1400:2900) = 1  ! Intermountain West holes, up to 49DEG N
    hgt_mask(1500:3000,1000:1500) = 1 !AZ and NM holes
    hgt_mask(500:1000,1850:2900) = 1  !PacNW holes
    hgt_mask(2510:3000,860:1000) = 1  !SW Texas

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
    integer, dimension(200)              :: kgdsi, kgdso
    logical, dimension(:,:), allocatable :: lo, li
    real,    dimension(:,:), allocatable :: ro, ri
    real,    dimension(:),   allocatable :: rlat, rlon

    ! Input GDS parameters
    kgdsi = nssl01_gds

    ! Output GDS parameters
    kgdso = stageIV04_gds

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
    status(2)  = nf90_put_att(ncid,nf90_global,'title','StageIV Precip Mask from NSSL Radar')

    ! Define dimension variables
    status(8)  = nf90_def_dim(ncid,'x',size(mask,1),xDimID)
    status(9)  = nf90_def_dim(ncid,'y',size(mask,2),yDimID)
    
    ! Define variables
    status(10) = nf90_def_var(ncid,'pcp_mask',nf90_double,(/xDimID,yDimID/),maskVarID)
        
    ! End of definitions
    status(11) = nf90_enddef(ncid)
    
    ! Put dimension variables and state variables
    status(12) = nf90_put_var(ncid,maskVarID,mask)
           
    if(any(status(:20) /= nf90_NoErr)) stop "Error writing interpolated mask field"
    
    status(1) = nf90_close(ncid)

    print *, 'Done writing interpolated grid to NC file'

  end subroutine write_mask

!=================================================================================
end program convert_mask
