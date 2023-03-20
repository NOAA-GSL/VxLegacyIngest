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
  
  integer, external                   :: iargc
  integer, dimension(20)              :: status
  integer                             :: ncid, nlat, nlon, i, nf, nx, ny
  integer                             :: precipVarID, xDimID, yDimID
  character(len=256)                  :: numFiles, inputDir, inputFileName, outputFileName
  character(len=2)                    :: int2str
  integer, dimension(200)             :: cpc13_gds, stageIV04_gds, hrrr03_gds
  real, dimension(:,:),   allocatable :: mask, new_mask
  real, dimension(:,:,:), allocatable :: all_precips
  ! Define possible GDS parameters for different mappings as decoded by W3FI63
  
  ! Equidistant Cylindrical (Lat/Lon) ~ 13KM/.125DEG spacing - CPC domain
  parameter cpc13_gds = (/ 0,464,224,int(25.125*1000),int((360.-124.875)*1000),8,int((25.125+.125*224)*1000), &
                           int((360.-124.875+.125*464)*1000),int(.125*1000),int(.125*1000),                   &
                           64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                                                 /)
  
  ! 04KM Polar Stereographic - StageIV domain
  parameter stageIV04_gds = (/ 5,1121,881,int(23.098*1000),int(240.964*1000),8,int(255.0*1000), &
                               4763,4763,0,64,0,0,0,0,0,0,0,0,255,(0,i=1,180)                   /)  

  ! 3KM Lambert Conformal Conic - HRRR domain
  parameter hrrr03_gds = (/ 3,1799,1059,int(21.138*1000),int((360.-122.72)*1000),8,int((360.-97.5)*1000), &
                            3000,3000,0,64,int(38.5*1000),int(38.5*1000),0,0,0,0,0,0,255,(0,i=1,180)      /)
  !---------------------------------------------------------------------------------
  
  ! Read 7 days of CPC to create super-setted precip mask
  call getarg(1, numFiles)
  
  read(numFiles,'(i2)') nf
  
  call getarg(2, inputDir)
  
  ! Loop over files, adding them up as you go
  do i=1,nf
     write(int2str,'(i2.2)') i
     inputFileName = trim(inputDir) // '/201208' // int2str // '-12z/cpc_precip_13kmLC.nc'
     
     print *, 'Reading: ', trim(inputFileName)
     
     ! Open file and read precip field
     status(:)  = nf90_NoErr
     status(1)  = nf90_open(trim(inputFileName),nf90_nowrite,ncid)
     
     ! Get number of Xs and Ys
     status(2)  = nf90_inq_dimid(ncid,'y',yDimID)
     status(3)  = nf90_inquire_dimension(ncid,yDimID,len = ny)
     
     status(4)  = nf90_inq_dimid(ncid,'x',xDimID)
     status(5)  = nf90_inquire_dimension(ncid,xDimID,len = nx)
     
     if (i == 1) then
        allocate(all_precips(nf,nx,ny))
        allocate(mask(nx,ny))
     endif
     
     ! Get VarIDs for all needed variables
     status(6)  = nf90_inq_varid(ncid,'precip',precipVarID)
     
     ! Get variable values
     status(7)  = nf90_get_var(ncid,precipVarID,all_precips(i,:,:))
     
     if(any(status(:7) /= nf90_NoErr)) stop "Error reading model NetCDF file"
     
     status(1) = nf90_close(ncid)
     
     print *, 'Done reading file #', i
     
  end do
  
  where(all_precips>=0) all_precips = 1
  where(all_precips<0) all_precips = 0

  ! Now, sum across precips to superset data, but then mask back to 0s and 1s
  mask = sum(all_precips,DIM=1)
  where (mask>1) mask = 1
  
  ! Interpolate CPC mask to StageIV grid
  call interpolate(mask,new_mask)
  
  ! Write NCWD radar mask to file
  call write_mask('/pan2/projects/nrtrr/phofmann/verif/exec/stageIV_precip_mask.nc',mask)
  
!---------------------------------------------------------------------------------
  
contains

!---------------------------------------------------------------------------------

  subroutine interpolate(in_mask,out_mask)
    ! Interpolate state to desired grid using specified type of interpolation
    real, dimension(:,:), allocatable, intent(in)  :: in_mask
    real, dimension(:,:), allocatable, intent(out) :: out_mask
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
    kgdsi = cpc13_gds

    ! Output GDS parameters
    kgdso = hrrr03_gds

    ! Ipolates parameters
    xi = kgdsi(2)
    yi = kgdsi(3)
    xo = kgdso(2)
    yo = kgdso(3)
    mi = xi*yi
    mo = xo*yo

    allocate(li(mi,km),lo(mo,km),ri(mi,km),ro(mo,km),rlat(mo),rlon(mo))
    allocate(out_mask(xo,yo))

    func  = 0
    ipopt = (/ (-1,i=1,20) /)
    ip    = 6
       
    ri(:,km) = reshape(in_mask, (/ size(in_mask) /) )
    li(:,km) = 0
    
    print *, 'Calling ipolates library'
    call ipolates(ip,ipopt,kgdsi,kgdso,mi,mo,km,ibi,li,ri,func,  &
         no,rlat,rlon,ibo,lo,ro,status)
    
    if(status > 0) stop 'Interpolation failed, check input parameters'
    
    out_mask = reshape(ro(:,km), (/ xo,yo /) )
        
    where(out_mask >  0.5) out_mask = 1
    where(out_mask <= 0.5) out_mask = 0
    
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
    status(2)  = nf90_put_att(ncid,nf90_global,'title','StageIV Precip Mask from CPC')

    ! Put global attributes from interpolated grid
    !status(3)  = nf90_put_att(ncid,nf90_global,'DataType','LatLonGrid')
    !status(4)  = nf90_put_att(ncid,nf90_global,'Latitude',20.018)
    !status(5)  = nf90_put_att(ncid,nf90_global,'Longitude',-129.981)
    !status(6)  = nf90_put_att(ncid,nf90_global,'LatGridSpacing',0.035933)
    !status(7)  = nf90_put_att(ncid,nf90_global,'LonGridSpacing',0.038239)

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
