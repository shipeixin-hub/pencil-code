! $Id: prints.f90,v 1.6 2002-05-08 17:47:28 dobler Exp $

module Print

  use Cdata
  use Hydro
  use Magnetic

  implicit none

  contains

!***********************************************************************
    subroutine prints
!
!  reads and registers print parameters gathered from the different
!  modules and marked in `print.in'
!
!   3-may-02/axel: coded
!
      use Cdata
      use Sub
!
      logical,save :: first=.true.
      character (len=320) :: fform
      character (len=1) :: comma=','
      integer :: iname
!
!  produce the format
!
      fform='(i10,f10.3,1pg10.3,'//cform(1)
      do iname=2,nname
        fform=trim(fform)//comma//cform(iname)
      enddo
      fform=trim(fform)//')'
print*,'PRINTS: form = ',fform
print*,'PRINTS: args = ',it-1,t_diag,dt,fname(1:nname)
!
!  this needs to be made more sophisticated of course...
!
      if(lroot) then
        write(6,fform) it-1,t_diag,dt,fname(1:nname)
      endif
      first = .false.
!
    endsubroutine Prints
!***********************************************************************

endmodule Print
