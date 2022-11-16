program prepbufr2txt
!   
!
!
   use kinds, only : r_kind,r_single,len_sta_name
   use module_prepbufr, only :  read_prepbufr
   use module_obs_conv_pt, only :  obs_conv_pt
   use module_time, only :  mtime

   implicit none

   type(read_prepbufr) :: obsall
   type(mtime) :: tm

   integer :: obsdate,obsmin
   character(len=180) :: obsPath,obsfilename
   character(len=180) :: savePath,prefixobssavename
   character(len=180) :: fcstPath,fcstfilename
   character(len=180) :: prefixfcstobssavename
   namelist/setup/ obsdate,obsmin,obsPath,obsfilename,&
                   savePath,prefixobssavename,prefixfcstobssavename,&
                   fcstPath,fcstfilename

   integer :: numobstype
   integer :: obstype(100)
   real(r_single) :: timewindow(100)
   namelist/obsset/ numobstype,obstype,timewindow

   character(len=180) :: namelist_file
   character(len=180) :: obsfile
   character(len=180) :: savefile
   character(len=180) :: savefile_txt
   integer :: n
   integer :: namelist_length
   integer :: namelist_status
   integer :: open_error
!
!
!
   obsdate=0
   obsmin=0
   obsPath='unknown'
   obsfilename='unknown'
   savePath='unknown'
   prefixobssavename='unknown'
   prefixfcstobssavename='unknown'
   fcstPath='unknown'
   fcstfilename='unknown'
   numobstype=1
   obstype=120
   timewindow=1.0

   call get_environment_variable("NAMELIST_FILE",namelist_file,namelist_length,namelist_status)
   if (namelist_status .ne. 0) then
      write(*,*) 'NAMELIST VARIABLE MISSING OR > 180 CHARS! stopping.'
      stop
   endif
   write(*,*) 'namelist_file is |',namelist_file,'|'
   
   open(15,file=namelist_file,status='old',iostat=open_error)
   if(open_error .ne. 0) then
      write(*,*) 'error opening namelist_file: ',open_error
      stop
   endif
   read(15,setup)
   read(15,obsset)
   close(15)

   write(*,setup)
   write(*,obsset)
  
!
   obsfile=trim(obsPath)//"/"//trim(obsfilename)
   write(*,*) 'read obs from file=',trim(obsfile)
   savefile=trim(prefixobssavename)
   !write(*,*) 'save obs to file=',trim(savefile)
!
   do n=1,numobstype
      write(*,*)
      write(*,*) '================================='
      write(*,*) 'process obstype=',obstype(n), &
                 ' with time window=',timewindow(n)
      call obsall%initial_prepbufr(obstype(n),obsdate,obsmin,timewindow(n))

      call obsall%decodeprepbufr_all(trim(obsfile))
      call obsall%listsnd(savefile,savePath)
      !call obsall%writept(trim(savefile))
      call obsall%destroy_prepbufr()
   enddo

end program
