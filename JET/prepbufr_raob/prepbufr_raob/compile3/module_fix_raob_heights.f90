module module_fix_raob_heights
  !
  ! This module uses the hypsometric equation to fill in missing RAOB heights where possible
  ! We integrate both up and down from nearest levels with full data, look at differences in the
  ! two resulting heights, and average them if reasonable.
  !

  use kinds, only: r_kind,r_single,len_sta_name,rmissing
  use module_obs_base, only : obsbase
  
  implicit none

  contains
    subroutine fill_heights(snd,tot_fillable_heights,tot_bad_heights,iunit_mysql,iy,im,id,ihr)
      type(obsbase), pointer, intent(in) :: snd ! a sounding
      integer,intent(inout) :: tot_fillable_heights  ! total number of fillable (ie, with necessary thermo info)
      integer,intent(inout) :: tot_bad_heights ! tot fillable heights that could NOT be filled
      integer,intent(in) :: iunit_mysql,iy,im,id,ihr
      logical :: print_this = .true.
      integer :: last_calculated_height
      integer :: numlvl,numvar,k,ntype,j,n_h_diff,n_h_diff_500,surface_k,n_added_height,n_added_height_500
      integer :: n_last_filled_height = 1
      integer :: ut             !unix_timestamp
      integer :: ip,it,iq,ih,iu,iv,idx,idy,idt
      integer :: PP,TT,TD,HH,WS,WD
      real :: delta_h, h_up, h_down,h_diff,sum_h_diff,sum2_h_diff,std_h_diff,max_h_diff,mean_h_diff
      real :: sum_h_diff_500,sum2_h_diff_500,std_h_diff_500,max_h_diff_500,mean_h_diff_500
      real:: surface_h,h_from_surface,last_h
      real :: this_local_height, this_integrated_height,old_height
      integer,parameter :: MAX_HEIGHT_DIFF = 20 ! max allowed height diff between extrapolating up, vs extrapolating down
      logical :: bad_level,surface_filled
      !print *, "in fill_heights for this ob"
      n_last_filled_height = 1
      surface_filled = .false.
      ip=1
      it=2
      iq=3
      ih=4
      iu=5
      iv=6
      idx=7
      idy=8
      idt=9
     ! find levels with pressure, height, temp, dewpoint
      numlvl=snd%numlvl
      numvar = snd%numvar
      sum_h_diff = 0
      sum2_h_diff = 0
      max_h_diff = 0
      n_h_diff = 0
      n_added_height=0
      sum_h_diff_500 = 0
      sum2_h_diff_500 = 0
      max_h_diff_500 = 0
      n_h_diff_500 = 0
      n_added_height_500=0
      if(.true.) then
         ! clean out the last three items so we can use them temporarily, for debugging
         !do k=1,numlvl
           ! snd%obs((k-1)*numvar+idx) = 0
            !snd%obs((k-1)*numvar+idy) = 0
            !snd%obs((k-1)*numvar+idt) = 0
         !enddo
      endif
      
      !call snd%listsnd()
       do k=1,numlvl
          bad_level = .false.
          if( snd%obs((k-1)*numvar+ip) > -99998.0 .and. &
            snd%obs((k-1)*numvar+it) > -99998.0 .and. &
            snd%obs((k-1)*numvar+iq) > -99998.0 .and. &
            is_good_qc(snd%quality((k-1)*numvar+ip)) .and.  &
            is_good_qc(snd%quality((k-1)*numvar+it)) .and. &
            ! allow qc flag 9 for vapor, per Ming, 2/7/22. Also in
            ! https://www.nco.ncep.noaa.gov/sib/jeff/CodeFlag_0_STDv31_LOC7.html#013246
            ! where the value '9' is listed as 'reserved' (but Ming says to use it.
            (is_good_qc(snd%quality((k-1)*numvar+iq)) .or. snd%quality((k-1)*numvar+iq) .eq. 9) &
             ) then
             ! can fill a height
             tot_fillable_heights = tot_fillable_heights + 1
              if(.not. surface_filled) then
                if(snd%obs((k-1)*numvar+ih) > -99998.0) then
                   surface_filled = .true.
                   n_last_filled_height = k
                   ntype=9
                   surface_h = snd%obs((k-1)*numvar+ih)
                   surface_k = k
                   !print *,'surface, k=',k
                   PP=int(snd%obs((k-1)*numvar+ip)*10.0)
                   TT=int(snd%obs((k-1)*numvar+it)*10.0)
                   TD=int(snd%obs((k-1)*numvar+iq)*10.0)
                   HH=int(snd%obs((k-1)*numvar+ih))
                   WD=int(snd%obs((k-1)*numvar+iu))
                   WS=int(snd%obs((k-1)*numvar+iv))
                  !write(*,'(10I7)') ntype,PP, HH,TT,TD,WD,WS
                endif
             endif
          endif
          if(surface_filled .and. k > 1) then
             !this_local_height = local_height(snd,k)
             !print *,'local height is',this_local_height
             ! also temporarily store in idy
             !snd%obs((k-1)*numvar+idy) = this_local_height

             this_integrated_height = integrated_height(snd,k,n_last_filled_height)
             !print *,'integrated height is',this_integrated_height,'pressure is',snd%obs((k-1)*numvar+ip)
             if(this_integrated_height > -99998.0) then
                n_last_filled_height=k
                !  temporarily store old height in idx
                old_height = snd%obs((k-1)*numvar+ih)
                !snd%obs((k-1)*numvar+idx) = old_height
                ! and the difference in idy
                !snd%obs((k-1)*numvar+idy) = this_integrated_height - old_height
                ! replace the height with the integration from previous (lower) known level
                snd%obs((k-1)*numvar+ih) = this_integrated_height
                if(old_height > -99998.0) then
                   !snd%obs((k-1)*numvar+idt)  = 1
                   n_h_diff = n_h_diff+1
                   h_diff = (this_integrated_height - old_height)
                   sum_h_diff = sum_h_diff + h_diff
                   sum2_h_diff = sum2_h_diff + h_diff**2
                   if(abs(h_diff) > max_h_diff) then
                      max_h_diff = abs(h_diff)
                   endif
                   if(snd%obs((k-1)*numvar+ip) >= 500) then
                      n_h_diff_500 = n_h_diff_500+1
                      sum_h_diff_500 = sum_h_diff_500 + h_diff
                      sum2_h_diff_500 = sum2_h_diff_500 + h_diff**2
                      if(abs(h_diff) > max_h_diff_500) then
                         max_h_diff_500 = abs(h_diff)
                      endif
                   endif
                else
                   n_added_height = n_added_height+1
                   if(snd%obs((k-1)*numvar+ip) >= 500) then
                      n_added_height_500 = n_added_height_500 +1
                   endif
                   !snd%obs((k-1)*numvar+idt)  = -1
                   !snd%obs((k-1)*numvar+idx)  = 0
                   !snd%obs((k-1)*numvar+idy)  = 0
                endif
             else
                tot_bad_heights = tot_bad_heights+1
             endif
          endif
       enddo  ! end loop over number of levels

       mean_h_diff = sum_h_diff/max0(n_h_diff,1)
       std_h_diff = (sum2_h_diff/max0(n_h_diff,1) - mean_h_diff**2)**0.5
       !print *,'n_changed,n_added,max_abs_diff,mean,std,sfc_level',n_h_diff,n_added_height,&
        !    max_h_diff,mean_h_diff,std_h_diff,surface_k
       mean_h_diff_500 = sum_h_diff_500/max0(n_h_diff_500,1)
       std_h_diff_500 = (sum2_h_diff_500/max(n_h_diff_500,1) - mean_h_diff_500**2)**0.5
       !print *,'below 500 mb: n_changed,n_added,max_abs_diff,mean,std',n_h_diff_500,n_added_height_500,&
        !    max_h_diff_500,mean_h_diff_500,std_h_diff_500

       if(n_h_diff_500 > 1) then
          ut = unix_timestamp(iy,im,id,ihr,0,0)
          write(iunit_mysql,'(a,*(",",i0))') &
               trim(snd%name),ut,nint(mean_h_diff_500*10),nint(max_h_diff_500*10),&
               n_h_diff_500,n_added_height_500,nint(mean_h_diff*10),nint(max_h_diff*10),&
               n_h_diff,n_added_height
       endif
       !
      if(print_this) then
         call snd%listsnd()
      endif
      !print *,'end of fill_heights'
     end subroutine fill_heights

     integer function unix_timestamp(yyyy,mm,dd,hh,min,ss)
       integer, intent(in) :: yyyy,mm,dd,hh,min,ss
       integer JD               ! Julian day

       ! Julian day from https://blog.reverberate.org/2020/05/12/optimizing-date-algorithms.html
       JD = dd - 32075 + 1461*(yyyy + 4800 + (mm - 14)/12)/4 &
        + 367*(mm - 2 - (mm - 14)/12*12)/12 - 3 &
             *((yyyy + 4900 + (mm - 14)/12)/100)/4 &
             - 2440588
       !print *,yyyy,mm,dd,hh
       !print *,'julian day is ',JD
       unix_timestamp = JD*24*60*60 + hh*60*60 + min*60 + ss
       !print *,'unix_timestamp is',unix_timestamp
       end function unix_timestamp

     real function integrated_height(snd,k,n)
       type(obsbase), pointer, intent(in) :: snd ! a sounding
       integer, intent(in) :: k  ! level to have its height filled
       integer, intent(in) :: n  ! lower level that already has an integrated height
       integer :: ip,it,iq,ih,iu,iv,idx,idy,idt
       integer :: numlvl,numvar
       real :: previous_height,hypsometric_distance
       ip=1
       it=2
       iq=3
       ih=4
       iu=5
       iv=6
       idx=7
       idy=8
       idt=9
       numlvl=snd%numlvl
       numvar = snd%numvar
       !print *,'in integrated_height with k,n',k,n
       integrated_height = -99999

       ! make sure lower level has a filled-in height
       previous_height = snd%obs((n-1)*numvar+ih) 
       if(previous_height < -99998.0) then
          print *,'TROUBLE! in integrated_height,  level',n,'below level',k,'has no height'
       else
          ! make sure this pressure is less than the previous pressure
          if(snd%obs((n-1)*numvar+ip) - snd%obs((k-1)*numvar+ip)<0) then
             !print *,'TROUBLE2! pressure of this level is greater than previous level!',k,n
             !print *,snd%name, snd%obs((n-1)*numvar+ip) ,snd%obs((k-1)*numvar+ip)
             snd%obs((k-1)*numvar+ip) = -99999.
          else
             hypsometric_distance = hypsometric(snd,k,n)
             if(hypsometric_distance > -99998.0) then
                integrated_height = previous_height+hypsometric_distance
             else
                !print *,'cannot fill height',k,'because not enough thermo data'
             endif
          endif
       endif
     end function integrated_height

 
     real function hypsometric(snd,k,j)
       ! calculates the height increment in meters from level j (lower) to level k (higher)
       type(obsbase), pointer, intent(in) :: snd ! a sounding
       integer, intent(in) :: k  ! level to have its height filled
       integer, intent(in) :: j ! level with good height, temp, 
       integer :: numvar
       integer :: ip,it,iq,ih,iu,iv,idx,idy,idt
       real :: log_ratio,p1,p2,vp1,vp2,dp1,dp2,t1,t2,svp1,svp2,mr1,mr2,vt1,vt2,vta,delta_h
       real, parameter :: Rd = 286.9968933 ! Gas constant for dry air        J/degree/kg
       real, parameter :: g   = 9.80616 ! Acceleration due to gravity       m/s^2
       real,parameter :: eps = 0.621970585  ! Ratio of the molec. weights of water and dry air
       real,parameter :: tzero = 273.15 ! to convert from Celsius to Kelvin
       ip=1
       it=2
       iq=3
       ih=4
       iu=5
       iv=6
       idx=7
       idy=8
       idt=9
       numvar = snd%numvar
       ! make sure we can fill this height
       if(  &
            ! obs at level k
            snd%obs((k-1)*numvar+ip) > -99998.0 .and. &
            snd%obs((k-1)*numvar+it) > -99998.0 .and. &
            snd%obs((k-1)*numvar+iq) > -99998.0 .and. &
            ! obs at level j
            snd%obs((j-1)*numvar+ip) > -99998.0 .and.  &
            snd%obs((j-1)*numvar+it) > -99998.0 .and. &
            snd%obs((j-1)*numvar+iq) > -99998.0 .and. &
            ! qc at level k
            is_good_qc(snd%quality((k-1)*numvar+ip)) .and.  &
            is_good_qc(snd%quality((k-1)*numvar+it)) .and. &
            ! allow qc flag 9 for vapor, per Ming, 2/7/22. Also in
            ! https://www.nco.ncep.noaa.gov/sib/jeff/CodeFlag_0_STDv31_LOC7.html#013246
            ! where the value '9' is listed as 'reserved' (but Ming says to use it.
            (is_good_qc(snd%quality((k-1)*numvar+iq)) .or. snd%quality((k-1)*numvar+iq) .eq. 9) .and. &
            ! qc at level j
            is_good_qc(snd%quality((j-1)*numvar+ip)) .and.  &
            is_good_qc(snd%quality((j-1)*numvar+it)) .and. &
            (is_good_qc(snd%quality((j-1)*numvar+iq)) .or. snd%quality((j-1)*numvar+iq) .eq. 9) &
             ) then
          p1 = snd%obs((j-1)*numvar+ip) ! lower level (higher pressure)
          p2 = snd%obs((k-1)*numvar+ip) ! level/pressure at which to calculate height above lower level
          log_ratio = log(p1/p2)
          
          ! get mean virtual temperature in layer from dewpoint
          ! variable Q is actualy dewpont in Celsius
       
          ! use Teten's Formula to get vapor pressure
          ! https://glossary.ametsoc.org/wiki/Tetens's_formula
          dp1 = snd%obs((j-1)*numvar+iq) ! dew point in Celsius
          dp2 = snd%obs((k-1)*numvar+iq)
          vp1 = 6.11*(10**((7.5*dp1)/(237.3+dp1))) 
          vp2 = 6.11*(10**((7.5*dp2)/(237.3+dp2)))
          
          ! get saturated vapor pressure (Teten's formula)
          ! from https://glossary.ametsoc.org/wiki/Tetens's_formula
          t1 = snd%obs((j-1)*numvar+it) ! sensible temperature in Celsius
          t2 = snd%obs((k-1)*numvar+it)
          svp1 = 6.11*(10**((7.5*t1)/(237.3+t1))) 
          svp2 = 6.11*(10**((7.5*t2)/(237.3+t2)))
          
          ! get mixing ratio
          !mr1 = (eps*vp1)/(p1-(0.378*vp1)) ! Jeff's way -- don't know where the 0.378 came from
          !mr2 = (eps*vp2)/(p1-(0.378*vp2)) ! ditto. new way (below) results in slightly better height agreement
          mr1 = (eps*vp1)/(p1-vp1)
          mr2 = (eps*vp2)/(p2-vp2) ! fixed  on 3/9/22 (was (p1-vp2))- Thanks, Dave, for finding. - WRM
          
          ! virtual temperature
          !vt1 = (t1+tzero)*(1+(0.6078*sh1)) ! easier to get vt from mixing ratio than from specific humidity
          !vt2 = (t2+tzero)*(1+(0.6078*sh2))
          ! virtual temp from mixing ratio from https://glossary.ametsoc.org/wiki/Virtual_temperature
          vt1 = (t1+tzero)*(1.+mr1/eps)/(1.+mr1)
          vt2 = (t2+tzero)*(1.+mr2/eps)/(1.+mr2)
           ! average
          vta = (vt1+vt2)/2
          
          ! hypsometric equation
          delta_h = (Rd/g)*log_ratio*vta
          
          !print *,p1,t1,dp1,vp1,svp1,mr1,sh1,vt1,delta_h
          
          hypsometric = delta_h
       else
          hypsometric = -99999.0
       endif
     end function hypsometric
      
    real function local_height(snd,k)
       ! finds best height based on adjacent mandatory levels
       type(obsbase), pointer, intent(in) :: snd ! a sounding
       integer, intent(in) :: k  ! level to have its height filled
       logical :: print_this = .true.
       integer :: last_calculated_height
       integer :: numlvl,numvar,ntype,j,n_h_diff
       integer :: ip,it,iq,ih,iu,iv,idx,idy,idt
       integer :: PP,TT,TD,HH,WS,WD
       real :: delta_h, h_up, h_down,h_diff,sum_h_diff,sum2_h_diff,std_h_diff,max_h_diff,mean_h_diff
       real:: surface_h,h_from_surface,last_h
       integer,parameter :: MAX_HEIGHT_DIFF = 20 ! max allowed height diff between extrapolating up, vs extrapolating down
       logical :: bad_level = .false.
       ip=1
       it=2
       iq=3
       ih=4
       iu=5
       iv=6
       idx=7
       idy=8
       idt=9
       numlvl=snd%numlvl
       numvar = snd%numvar
       !print *,'in local_height'
       bad_level = .false.
       ! find mandatory level below
             find_below: do j=k-1,1,-1
                if(snd%obs((j-1)*numvar+ip) > -99998.0 .and.  snd%obs((j-1)*numvar+it) > -99998.0 .and. &
                     snd%obs((j-1)*numvar+iq) > -99998.0 .and. snd%obs((j-1)*numvar+ih) > -99998.0) then
                   ! found mand level below
                   ntype = 4;
                   PP=int(snd%obs((j-1)*numvar+ip)*10.0)
                   TT=int(snd%obs((j-1)*numvar+it)*10.0)
                   TD=int(snd%obs((j-1)*numvar+iq)*10.0)
                   HH=int(snd%obs((j-1)*numvar+ih))
                   WD=int(snd%obs((j-1)*numvar+iu))
                   WS=int(snd%obs((j-1)*numvar+iv))
                   print *, "mand below is"
                   !write(*,'(10I7)') ntype,PP, HH,TT,TD,WD,WS
                   ! get height for level k
                   delta_h = hypsometric(snd,k,j)
                   h_up = snd%obs((j-1)*numvar+ih) + delta_h
                   exit find_below
                endif
             enddo find_below
              ! find mandatory level above
             find_above: do j=k+1,numlvl
                if(snd%obs((j-1)*numvar+ip) > -99998.0 .and.  snd%obs((j-1)*numvar+it) > -99998.0 .and. &
                     snd%obs((j-1)*numvar+iq) > -99998.0 .and. snd%obs((j-1)*numvar+ih) > -99998.0) then
                   ! found mand level above
                   ntype = 4;
                   PP=int(snd%obs((j-1)*numvar+ip)*10.0)
                   TT=int(snd%obs((j-1)*numvar+it)*10.0)
                   TD=int(snd%obs((j-1)*numvar+iq)*10.0)
                   HH=int(snd%obs((j-1)*numvar+ih))
                   WD=int(snd%obs((j-1)*numvar+iu))
                   WS=int(snd%obs((j-1)*numvar+iv))
                   !print *, "mand above is"
                   !write(*,'(10I7)') ntype,PP, HH,TT,TD,WD,WS
                   ! get height for level k
                   delta_h = hypsometric(snd,k,j)
                   h_down = snd%obs((j-1)*numvar+ih) + delta_h
                   h_diff = abs(h_up - h_down)
                   print *,'h_up,h_down,h_diff',h_up,h_down,h_diff
                   ! make sure the height isn't above the higher mandatory level
                   ! get height from surface
                   delta_h = hypsometric(snd,k,1)
                   h_from_surface = surface_h + delta_h
                   print *,'h_from_surface',h_from_surface
                   if(h_up > snd%obs((j-1)*numvar+ih)) then
                      print *,'ERROR2: h_up > upper mand level: ',h_up ,snd%obs((j-1)*numvar+ih)
                      bad_level = .true.
                   endif
                   if(h_diff> MAX_HEIGHT_DIFF) then
                      print *,"ERROR1: height difference ",h_diff,"too large. Leaving height as 'missing'. Not included in stats"
                      bad_level = .true.
                   endif
                   if(.not. bad_level) then
                      ! correct height, and temporarily leave record of the h_diffs
                      snd%obs((k-1)*numvar+ih) = (h_up+h_down)/2
                      if(h_diff .gt. max_h_diff) max_h_diff = h_diff
                      n_h_diff = n_h_diff+1
                      sum_h_diff = sum_h_diff+h_diff
                      sum2_h_diff = sum2_h_diff +h_diff**2
                      local_height = (h_up+h_down)/2
                      print *,'set local_height to',local_height
                   else
                      !tot_bad_heights = tot_bad_heights+1
                      local_height = 99999
                   endif       
                  !snd%obs((k-1)*numvar+idx) = h_up
                   !snd%obs((k-1)*numvar+idy) = h_down
                   !snd%obs((k-1)*numvar+idt) = h_up - h_down
                   exit find_above
                endif
             enddo find_above
             print *,'in function, local_height is',local_height
           end function local_height
           
           logical function is_good_qc(x)
             integer,intent(in) :: x
             is_good_qc = .false.
             if(x >= 1 .and. x <= 3) then
                is_good_qc = .true.
             endif
           end function is_good_qc
           
  end module module_fix_raob_heights 
    
      
   
