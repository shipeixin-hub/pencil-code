! $Id: internal_flow.f90,v 1.11 2008-05-20 08:57:09 nilshau Exp $

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lspecial = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Special

  use Cparam
  use Cdata
  use Messages
  use Sub, only: keep_compiler_quiet

  implicit none

  include 'special.h'

  !
  ! Slice precalculation buffers
  !
  real, target, dimension (nx,ny,3) :: oo_xy_meanx
  real, target, dimension (nx,ny,3) :: uu_xy_meanx
  real, dimension(nygrid,3) :: mean_u

  integer :: dummy
  character(len=24) :: initspecial='nothing'
  real :: central_vel=0,ampluu_spec=0,Re_tau=180

!!  character, len(50) :: initcustom

! input parameters
  namelist /internal_flow_init_pars/ &
       initspecial,central_vel,ampluu_spec,Re_tau
  ! run parameters
  namelist /internal_flow_run_pars/  &
       dummy

  integer :: idiag_turbint=0
  integer :: idiag_uxm_central,idiag_tau_w

  contains

!***********************************************************************
    subroutine register_special()
!
!  Configure pre-initialised (i.e. before parameter read) variables
!  which should be know to be able to evaluate
!
!
!  6-oct-03/tony: coded
!
      use Cdata
      use Mpicomm
!
      logical, save :: first=.true.
!
! A quick sanity check
!
      if (.not. first) call stop_it('register_special called twice')
      first = .false.

!!
!! MUST SET lspecial = .true. to enable use of special hooks in the Pencil-Code
!!   THIS IS NOW DONE IN THE HEADER ABOVE
!
!
!
!!
!! Set any required f-array indexes to the next available slot
!!
!!
!      iSPECIAL_VARIABLE_INDEX = nvar+1             ! index to access entropy
!      nvar = nvar+1
!
!      iSPECIAL_AUXILIARY_VARIABLE_INDEX = naux+1             ! index to access entropy
!      naux = naux+1
!
!
!  identify CVS version information (if checked in to a CVS repository!)
!  CVS should automatically update everything between $Id: internal_flow.f90,v 1.11 2008-05-20 08:57:09 nilshau Exp $
!  when the file in committed to a CVS repository.
!
      if (lroot) call cvs_id( &
           "$Id: internal_flow.f90,v 1.11 2008-05-20 08:57:09 nilshau Exp $")
!
!
!  Perform some sanity checks (may be meaningless if certain things haven't
!  been configured in a custom module but they do no harm)
!
      if (naux > maux) then
        if (lroot) write(0,*) 'naux = ', naux, ', maux = ', maux
        call stop_it('register_special: naux > maux')
      endif
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('register_special: nvar > mvar')
      endif
!
    endsubroutine register_special
!***********************************************************************
    subroutine initialize_special(f)
!
!  called by run.f90 after reading parameters, but before the time loop
!
!  06-oct-03/tony: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray) :: f
!!
!!  Initialize any module variables which are parameter dependent
!!
!
! DO NOTHING
      call keep_compiler_quiet(f)
!
    endsubroutine initialize_special
!***********************************************************************
    subroutine init_special(f,xx,yy,zz)
!
!  initialise special condition; called from start.f90
!  06-oct-2003/tony: coded
!
      use Cdata
      use Mpicomm
      use Sub
      use Initcond
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz) :: xx,yy,zz
      integer :: i
      real :: height,h2
!
      intent(in) :: xx,yy,zz
      intent(inout) :: f
      !
      ! Select case
      !
      select case(initspecial)
      case('nothing'); if(lroot) print*,'init_special: nothing'
      case('poiseulle_xy')
        f(:,:,:,iux:iuz)=0
        call poiseulle_flowx_wally(f,xx,yy,zz,central_vel)
      case('poiseulle_xy_noise')
        f(:,:,:,iux:iuz)=0
        height=Lxyz(2)/2
        h2=height**2
        call gaunoise(ampluu_spec,f,iux,iuz)
        do i=iux,iuz
          f(l1:l2,m1:m2,n1:n2,i)=f(l1:l2,m1:m2,n1:n2,i)&
               *(1-(yy(l1:l2,m1:m2,n1:n2)-xyz0(2)-height)**2/h2)
        enddo
        call poiseulle_flowx_wally(f,xx,yy,zz,central_vel)
      case('velocity_defect_xy')
        call velocity_defect_flowx_wally(f,xx,yy,zz,central_vel,Re_tau)
      case('log_law_xy')
        call log_law_flowx_wally(f,xx,yy,zz,central_vel,Re_tau)
      case default
        !
        !  Catch unknown values
        !
        if (lroot) print*,'init_special: No such value for initspecial: ', &
             trim(initspecial)
        call stop_it("")
      endselect
      !
    endsubroutine init_special
!***********************************************************************
    subroutine pencil_criteria_special()
!
!  All pencils that this special module depends on are specified here.
!
!  18-07-06/tony: coded
!
    endsubroutine pencil_criteria_special
!***********************************************************************
    subroutine pencil_interdep_special(lpencil_in)
!
!  Interdependency among pencils provided by this module are specified here.
!
!  18-07-06/tony: coded
!
      use Sub, only: keep_compiler_quiet
!
      logical, dimension(npencils) :: lpencil_in
!
      call keep_compiler_quiet(lpencil_in)
!
    endsubroutine pencil_interdep_special
!***********************************************************************
    subroutine calc_pencils_special(f,p)
!
!  Calculate Hydro pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!   24-nov-04/tony: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      intent(in) :: f
      intent(inout) :: p
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(p)
!
    endsubroutine calc_pencils_special
!***********************************************************************
    subroutine dspecial_dt(f,df,p)
!
!  calculate right hand side of ONE OR MORE extra coupled PDEs
!  along the 'current' Pencil, i.e. f(l1:l2,m,n) where
!  m,n are global variables looped over in equ.f90
!
!  Due to the multi-step Runge Kutta timestepping used one MUST always
!  add to the present contents of the df array.  NEVER reset it to zero.
!
!  several precalculated Pencils of information are passed if for
!  efficiency.
!
!   06-oct-03/tony: coded
!
      use Cdata
      use Mpicomm
      use Sub
      use Global
      use Deriv, only: der_pencil
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (3) :: meanx_oo
      real, dimension (3) :: meanx_uu
      real, dimension (nx,3) :: ufluct
      real, dimension (nx) :: ufluct2
      type (pencil_case) :: p
      integer :: i,j
      real, dimension (my) :: tmp,du_mean_dy
      real :: tau_tmp
      

!
      intent(in) :: f,p
      intent(inout) :: df
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'dspecial_dt: SOLVE dSPECIAL_dt'
      !
      ! Write video slices
      !
      if(lvid.and.lfirst) then
        if (n==iz_loc)  then
          do j=1,3
            meanx_oo(j)=sum(p%oo(:,j))/(l2-l1+1)
            meanx_uu(j)=mean_u(m+ny*ipy-nghost,j)
            oo_xy_meanx(:,m-m1+1,j)=p%oo(:,j)-meanx_oo(j)
            uu_xy_meanx(:,m-m1+1,j)=p%uu(:,j)-meanx_uu(j)
          enddo
        endif
      endif
!
! Write diagnostics
!
      if(ldiagnos) then
        if (idiag_turbint/=0) then
          do j=1,3
            meanx_uu(j)=mean_u(m+ny*ipy-nghost,j)
            ufluct(:,j)=p%uu(:,j)-meanx_uu(j)
          enddo
          call dot2(ufluct,ufluct2)
          call sum_mn_name(ufluct2,idiag_turbint)
        endif
        if (idiag_uxm_central/=0) then
          if (m==m2.and.n==n1) then
            fname(idiag_uxm_central)=maxval(mean_u)
            itype_name(idiag_uxm_central)=ilabel_max
          endif
!          call max_mn_name(meanx_uu(1),idiag_uxm_central)
        endif
        if (idiag_tau_w/=0) then
          if (m==m1.and.n==n1) then
            if (ipy==0) then
              tmp=0
              tmp(m1:m2)=mean_u(1:ny,1)
              call der_pencil(2,tmp,du_mean_dy)
              print*,'nu and rhom is hardcoded in internal_flow.f90: dspecial_dt'
              tau_tmp=du_mean_dy(m1+3)*1.5e-5*1.2
!              tau_tmp=-(mean_u(2,1)-mean_u(1,1))/(y(l1+1)-y(l1+0))
            else
              tau_tmp=0
            endif
            !call max_mn_name(tau_tmp,idiag_tau_w)
            itype_name(idiag_tau_w)=ilabel_max
            fname(idiag_tau_w)=tau_tmp
          endif
        endif
      endif
!
    endsubroutine dspecial_dt
!***********************************************************************
    subroutine read_special_init_pars(unit,iostat)
!
      use Sub, only: keep_compiler_quiet
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

 
      if (present(iostat)) then
        read(unit,NML=internal_flow_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=internal_flow_init_pars,ERR=99)
      endif

99    return
    endsubroutine read_special_init_pars
!***********************************************************************
    subroutine write_special_init_pars(unit)
!
      use Sub, only: keep_compiler_quiet
!
      integer, intent(in) :: unit

      write(unit,NML=internal_flow_init_pars)

    endsubroutine write_special_init_pars
!***********************************************************************
    subroutine read_special_run_pars(unit,iostat)
!
      use Sub, only: keep_compiler_quiet
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=internal_flow_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=internal_flow_run_pars,ERR=99)
      endif

99    return
    endsubroutine read_special_run_pars
!***********************************************************************
    subroutine write_special_run_pars(unit)
!
      use Sub, only: keep_compiler_quiet
!
      integer, intent(in) :: unit

      write(unit,NML=internal_flow_run_pars)

    endsubroutine write_special_run_pars
!***********************************************************************
    subroutine rprint_special(lreset,lwrite)
!
!  reads and registers print parameters relevant to special
!
!   06-oct-03/tony: coded
!
      use Cdata
      use Sub
!
      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_turbint=0
        idiag_tau_w=0
        idiag_uxm_central=0
      endif
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'turbint',idiag_turbint)
        call parse_name(iname,cname(iname),cform(iname),'tau_w',idiag_tau_w)
        call parse_name(iname,cname(iname),cform(iname),'uxm_central',idiag_uxm_central)
      enddo
!
!  write column where which magnetic variable is stored
      if (lwr) then
        write(3,*) 'i_turbint=',idiag_turbint
        write(3,*) 'i_tau_w=',idiag_tau_w
        write(3,*) 'i_uxm_central=',idiag_uxm_central
      endif
!
    endsubroutine rprint_special
!***********************************************************************
    subroutine get_slices_special(f,slices)
!
!  Write slices for animation of special variables.
!
!  26-jun-06/tony: dummy
!
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
      !
      !  Loop over slices
      !
      select case (trim(slices%name))
        !
        !  Vorticity (derived variable)
        !
      case ('oo_meanx')
        if (slices%index == 3) then
          slices%ready = .false.
        else
          slices%index = slices%index+1
          slices%xy=>oo_xy_meanx(:,:,slices%index)
          if (slices%index < 3) slices%ready = .true.
        endif
      case ('uu_meanx')
        if (slices%index >= 3) then
          slices%ready = .false.
        else
          slices%index = slices%index+1
          slices%xy=uu_xy_meanx(:,:,slices%index)
          if (slices%index < 3) slices%ready = .true.
        endif
      endselect

!NILS      call keep_compiler_quiet(f)
!NILS      call keep_compiler_quiet(slices%ready)
!
    endsubroutine get_slices_special
!***********************************************************************
    subroutine calc_lspecial_pars(f)
!
!  Mean flow velocitites
!
!  14-mar-08/nils: coded
!
      use Cdata
      use Sub
      use Mpicomm, only: mpireduce_sum, mpibcast_real
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension(nygrid,3) :: mean_u_tmp
      real :: faq
      integer :: j,k
!
!  calculate mean of velocity in xz planes
!
      if(lvid.and.lfirst .or. ldiagnos) then
        mean_u_tmp=0
        faq=nxgrid*nzgrid
        do j=m1,m2
          do k=1,3
            mean_u_tmp(j+ny*ipy-nghost,k)=sum(f(l1:l2,j,n1:n2,k+iux-1))/faq
          enddo
        enddo        
        do k=1,3
          call mpireduce_sum(mean_u_tmp(:,k),mean_u(:,k),nygrid)
          call mpibcast_real(mean_u(:,k),nygrid)
        enddo
      endif
!
    endsubroutine calc_lspecial_pars
!***********************************************************************
    subroutine special_calc_density(f,df,p)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-oct-03/tony: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p

!!
!!  SAMPLE IMPLEMENTATION
!!     (remember one must ALWAYS add to df)
!!
!!
!!  df(l1:l2,m,n,ilnrho) = df(l1:l2,m,n,ilnrho) + SOME NEW TERM
!!
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_density
!***********************************************************************
    subroutine special_calc_hydro(f,df,p)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-oct-03/tony: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet

      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p

!!
!!  SAMPLE IMPLEMENTATION
!!     (remember one must ALWAYS add to df)
!!
!!
!NILS      if (m>=18.and.m<=20) then
!NILS        df(l1:l2,m,n,iux) = df(l1:l2,m,n,iux) - f(l1:l2,m,n,iux)*100
!NILS        df(l1:l2,m,n,iuy) = df(l1:l2,m,n,iuy) - f(l1:l2,m,n,iuy)*100
!NILS        df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) - f(l1:l2,m,n,iuz)*100
!NILS      endif
!!
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_hydro
!***********************************************************************
    subroutine special_calc_magnetic(f,df,p)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-oct-03/tony: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet

      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p

!!
!!  SAMPLE IMPLEMENTATION
!!     (remember one must ALWAYS add to df)
!!
!!
!!  df(l1:l2,m,n,iux) = df(l1:l2,m,n,iux) + SOME NEW TERM
!!  df(l1:l2,m,n,iuy) = df(l1:l2,m,n,iuy) + SOME NEW TERM
!!  df(l1:l2,m,n,iuz) = df(l1:l2,m,n,iuz) + SOME NEW TERM
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_magnetic
!!***********************************************************************
    subroutine special_calc_entropy(f,df,p)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-oct-03/tony: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet

      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p

!!
!!  SAMPLE IMPLEMENTATION
!!     (remember one must ALWAYS add to df)
!!
!!
!!  df(l1:l2,m,n,ient) = df(l1:l2,m,n,ient) + SOME NEW TERM
!!
!!
      call keep_compiler_quiet(f,df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_entropy
!***********************************************************************
    subroutine special_boundconds(f,bc)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-oct-03/tony: coded
!
      use Cdata
      use Cparam
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      type (boundary_condition) :: bc
!
      select case (bc%bcname)
      case ('poi')
        select case (bc%location)
        case (iBC_X_TOP)
          call bc_poi_x(f,-1,'top',iux,REL=.true.,val=bc%value1)
        case (iBC_X_BOT)
          call bc_poi_x(f,-1,'bot',iux,REL=.true.,val=bc%value1)
        end select
      end select
!
    endsubroutine special_boundconds
!***********************************************************************
    subroutine special_before_boundary(f)
!
!   Possibility to modify the f array before the boundaries are
!   communicated.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-jul-06/tony: coded
!
      use Cdata
      use Sub, only: keep_compiler_quiet
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine special_before_boundary
!***********************************************************************
    subroutine poiseulle_flowx_wally(f,xx,yy,zz,central_vel)
      !
      ! Set initial Poiseulle flow in x-direction.
      ! The walls are in the y-direction
      !
      ! 2008.02.18: Nils Erland (Coded)
      !
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz) :: xx,yy,zz
      real :: central_vel, height, h2
      integer :: i,j,k
      !
      height=Lxyz(2)/2
      h2=height**2
      !
      f(l1:l2,m1:m2,n1:n2,iux)=f(l1:l2,m1:m2,n1:n2,iux)+central_vel*&
           (1-(yy(l1:l2,m1:m2,n1:n2)-xyz0(2)-height)**2/h2)
      !
    end subroutine poiseulle_flowx_wally
!***********************************************************************
    subroutine velocity_defect_flowx_wally(f,xx,yy,zz,central_vel,Re_tau)
      !
      ! Set initial turbulent flow in x-direction.
      ! The walls are in the y-direction.
      ! This method is based on the velocity defect law of Milikan (1938).
      ! More data on this can be found in e.g. Pope's book on turbulent flows.
      !
      ! 2008.03.22: Nils Erland (Coded)
      !
      use Mpicomm, only: ipy
      !
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (mx,my,mz), intent(in) :: xx,yy,zz
      real, intent(in) :: central_vel,Re_tau
      real :: B1,kappa,utau,nu, height, h2
      integer :: i,j,k

      real :: y_pluss, defect,def_y,log_y,lw,defect_min,log_max
      !
      height=Lxyz(2)/2
      h2=height**2
      B1=0.2
      kappa=0.41
      print*,'WARNING!!!!! nu is hardcoded - this must be fixed!'
      nu=1.5e-5
      utau=Re_tau*nu/height
      lw=nu/utau
      log_y=4
      def_y=30
!print*,'Re_tau=',Re_tau
!print*,'height=',height
!print*,'nu=',nu
!print*,'u_tau=',utau
!print*,'lw=',lw
      !
      ! Set some interpolation parameters
      !
      defect_min=central_vel&
           +utau*log(def_y*lw/height)/kappa&
           -B1*utau
      log_max=log_y
      !
      ! Add mean turbulent velocity profile to the possibly already 
      ! existing turnulent velocity field. As there should be less turbulence
      ! close to the walls we scale the existing turbulence field with the
      ! velocity profile.
      !
      do j=m1,m2
        if (yy(l1,j,n1)<xyz0(2)+height) then
          y_pluss=(yy(l1,j,n1)-xyz0(2))/lw
          defect=central_vel&
               +utau*log(y_pluss*lw/height)/kappa&
               -B1*utau
          if (y_pluss .le. log_y) then
            f(l1:l2,j,n1:n2,iux)=&
                 (f(l1:l2,j,n1:n2,iux)/central_vel+1)*y_pluss*utau
          elseif (y_pluss .ge. def_y) then
            f(l1:l2,j,n1:n2,iux)=(f(l1:l2,j,n1:n2,iux)/central_vel+1)*defect
          else
            f(l1:l2,j,n1:n2,iux)=(f(l1:l2,j,n1:n2,iux)/central_vel+1)*&
                 (defect_min*(y_pluss-log_y)/(def_y-log_y) &
                 +log_max*utau*(def_y-y_pluss)/(def_y-log_y))
          endif
        else
          y_pluss=-(yy(l1,j,n1)-xyz0(2)-Lxyz(2))/lw
          defect=central_vel&
               +utau*log(y_pluss*lw/height)/kappa&
               -B1*utau
          if (y_pluss .le. log_y) then
            f(l1:l2,j,n1:n2,iux)=(f(l1:l2,j,n1:n2,iux)/central_vel+1)*y_pluss*utau
          elseif (y_pluss .ge. def_y) then
            f(l1:l2,j,n1:n2,iux)=(f(l1:l2,j,n1:n2,iux)/central_vel+1)*defect
          else
            f(l1:l2,j,n1:n2,iux)=(f(l1:l2,j,n1:n2,iux)/central_vel+1)*&
                 (defect_min*(y_pluss-log_y)/(def_y-log_y) &
                 +log_max*utau*(def_y-y_pluss)/(def_y-log_y))
          endif
        endif
        !
      enddo
      if (ipy==0)        f(l1:l2,m1,n1:n2,iux)=0
      if (ipy==nprocy-1) f(l1:l2,m2,n1:n2,iux)=0
      !
    end subroutine velocity_defect_flowx_wally
!***********************************************************************
    subroutine log_law_flowx_wally(f,xx,yy,zz,central_vel,Re_tau)
      !
      ! Set initial turbulent flow in x-direction.
      ! The walls are in the y-direction.
      ! This method is based on log-law.
      ! More data on this can be found in e.g. Pope's book on turbulent flows.
      !
      ! 2008.05.20: Nils Erland (Coded)
      !
      use Mpicomm, only: ipy
      !
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      real, dimension (mx,my,mz), intent(in) :: xx,yy,zz
      real, intent(in) :: central_vel,Re_tau
      real :: B1,kappa,utau,nu, height, h2
      integer :: i,j,k

      real :: y_pluss, lw, u_log, u_lam
      !
      height=Lxyz(2)/2
      h2=height**2
      B1=5.5
      kappa=2.5
      print*,'WARNING!!!!! nu is hardcoded - this must be fixed!'
      nu=1.5e-5
      utau=Re_tau*nu/height
      lw=nu/utau
      !
      ! Add mean turbulent velocity profile to the possibly already 
      ! existing turnulent velocity field. As there should be less turbulence
      ! close to the walls we scale the existing turbulence field with the
      ! velocity profile.
      !
      do j=m1,m2
        if (yy(l1,j,n1)<xyz0(2)+height) then
          y_pluss=(yy(l1,j,n1)-xyz0(2))/lw
          u_log=(kappa*log(y_pluss+tini)+B1)*utau
          u_lam=y_pluss*utau
          f(l1:l2,j,n1:n2,iux)=&
               (f(l1:l2,j,n1:n2,iux)/central_vel+1)*min(u_log,u_lam)
        else
          y_pluss=-(yy(l1,j,n1)-xyz0(2)-Lxyz(2))/lw
          u_log=(kappa*log(y_pluss+tini)+B1)*utau
          u_lam=y_pluss*utau
          f(l1:l2,j,n1:n2,iux)=&
               (f(l1:l2,j,n1:n2,iux)/central_vel+1)*min(u_log,u_lam)
        endif
      enddo
      if (ipy==0)        f(l1:l2,m1,n1:n2,iux)=0
      if (ipy==nprocy-1) f(l1:l2,m2,n1:n2,iux)=0
      !
    end subroutine log_law_flowx_wally
!***********************************************************************
    subroutine bc_poi_x(f,sgn,topbot,j,rel,val)
!
! Poiseulle inflow
!
!  03-jan-08/nils: Coded
!
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mcom), optional :: val
      real :: umax,y2,height,h2
      integer :: sgn,i,j,jj
      logical, optional :: rel
      logical :: relative
!
      if (present(rel)) then; relative=rel; else; relative=.false.; endif

      select case(topbot)

      case('bot')               ! bottom boundary
        if (present(val)) then
          ! Multiply by three halfs to get max velocity from mean velocity
          umax=val(j)!*3/2
        else
          umax=0
        endif

        height=Lxyz(2)/2
        h2=height**2

        do jj=m1,m2
          y2=(y(jj)-xyz0(2)-height)**2
          f(l1,jj,n1:n2,j)=umax*(1-y2/h2)
        enddo


        if (relative) then
          do i=1,nghost; f(l1-i,:,:,j)=2*f(l1,:,:,j)+sgn*f(l1+i,:,:,j); enddo
        else
          do i=1,nghost; f(l1-i,:,:,j)=              sgn*f(l1+i,:,:,j); enddo
          f(l1,:,:,j)=(4.*f(l1+1,:,:,j)-f(l1+2,:,:,j))/3.
        endif

      case('top')               ! top boundary
        if (present(val)) then
          umax=val(j)
        else
          umax=0
        endif


        height=Lxyz(2)/2
        h2=height**2

        do jj=m1,m2
          y2=(y(jj)-xyz0(2)-height)**2
          f(l2,jj,n1:n2,j)=umax*(1-y2/h2)
        enddo

        if (relative) then
          do i=1,nghost; f(l2+i,:,:,j)=2*f(l2,:,:,j)+sgn*f(l2-i,:,:,j); enddo
        else
          do i=1,nghost; f(l2+i,:,:,j)=              sgn*f(l2-i,:,:,j); enddo
          f(l2,:,:,j)=(4.*f(l2-1,:,:,j)-f(l2-2,:,:,j))/3.
        endif

      case default
        print*, "bc_poi_x: ", topbot, " should be `top' or `bot'"

      endselect
!
    endsubroutine bc_poi_x
!***********************************************************************

!********************************************************************
!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from nospecial.f90 for any Special      **
!**  routines not implemented in this file                         **
!**                                                                **
    include 'special_dummies.inc'
!********************************************************************

endmodule Special

