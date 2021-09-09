;
; NAME:
;       PC_READ_VAR_RAW
;+
; PURPOSE:
;       Read var.dat, or other VAR files in an efficient way!
;
;       Returns one array from a snapshot (var) file generated by a
;       Pencil Code run, and another array with the variable labels.
;       Works for one or all processors.
;       This routine can also read reduced datasets from 'pc_reduce.x'.
;
; CATEGORY:
;       Pencil Code, File I/O
;
; CALLING SEQUENCE:
;       pc_read_var_raw, object=object, varfile=varfile, tags=tags,   $
;                    datadir=datadir, proc=proc, /allprocs, /quiet,   $
;                    trimall=trimall, swap_endian=swap_endian,        $
;                    f77=f77, time=time, grid=grid, var_list=var_list
; KEYWORD PARAMETERS:
;    datadir: Specifies the root data directory. Default: './data'.  [string]
;       proc: Specifies processor to get the data from. Default: ALL [integer]
;    varfile: Name of the var file. Default: 'var.dat' or 'var.h5'.  [string]
;   allprocs: Load distributed (0) or collective (1 or 2) varfiles.  [integer]
;   /reduced: Load previously reduced collective varfiles (implies allprocs=1).
;
;     object: Optional object in which to return the loaded data.    [4D-array]
;       tags: Array of tag names inside the object array.            [string(*)]
;   var_list: Array of varcontent idlvars to read (default = all).   [string(*)]
;
;   /trimall: Remove ghost points from the returned data.
;     /quiet: Suppress any information messages and summary statistics.
;
; EXAMPLES:
;       pc_read_var_raw, obj=var, tags=tags            ;; read from data/proc*
;       pc_read_var_raw, obj=var, tags=tags, proc=5    ;; read from data/proc5
;       pc_read_var_raw, obj=var, tags=tags, /allprocs ;; read from data/allprocs
;       pc_read_var_raw, obj=var, tags=tags, /reduced  ;; read from data/reduced
;
;       cslice, var
; or:
;       cmp_cslice, { uz:var[*,*,*,tags.uz], lnrho:var[*,*,*,tags.lnrho] }
;-
; MODIFICATION HISTORY:
;       $Id$
;       Adapted from: pc_read_var.pro, 25th January 2012
;
;
pro pc_read_var_raw,                                                      $
    object=object, varfile=varfile, datadir=datadir, tags=tags,           $
    start_param=start_param, run_param=run_param, varcontent=varcontent,  $
    time=time, dim=dim, grid=grid, proc=proc, allprocs=allprocs,          $
    var_list=var_list, trimall=trimall, quiet=quiet, help=help,           $
    swap_endian=swap_endian, f77=f77, reduced=reduced, single=single

COMPILE_OPT IDL2,HIDDEN
;
; Use common block belonging to derivative routines etc. so we can
; set them up properly.
;
  common cdat, x, y, z, mx, my, mz, nw, ntmax, date0, time0, nghostx, nghosty, nghostz
  common cdat_limits, l1, l2, m1, m2, n1, n2, nx, ny, nz
  common cdat_grid, dx_1, dy_1, dz_1, dx_tilde, dy_tilde, dz_tilde, lequidist, lperi, ldegenerated
  common pc_precision, zero, one, precision, data_type, data_bytes, type_idl
  common cdat_coords, coord_system

  if (keyword_set(help)) then begin
    doc_library, 'pc_read_var_raw'
    return
  endif
;
; Default settings.
;
  default, swap_endian, 0
  default, reduced, 0
  default, single, 0
;
  if (keyword_set (reduced)) then allprocs = 1
;
; Default data directory.
;
  datadir = pc_get_datadir(datadir)
;
;  Set precision.
;
  pc_set_precision, datadir=datadir, dim=dim, /quiet
;
; Name and path of varfile to read.
;
  if (not keyword_set (varfile)) then begin
    varfile = 'var.dat'
    if (file_test (datadir+'/allprocs/var.h5')) then varfile = 'var.h5'
  end else begin
    if (file_test (datadir+'/allprocs/'+varfile+'.h5')) then varfile += '.h5'
  end
;
; Load HDF5 varfile if requested or available.
;
  if (strmid (varfile, strlen(varfile)-3) eq '.h5') then begin
    if (not is_defined(varcontent)) then $
      varcontent = pc_varcontent(datadir=datadir,dim=dim,param=param,par2=par2,quiet=quiet,scalar=scalar,noaux=noaux,run2D=run2D,down=ldownsampled,single=single)
    
    quantities = varcontent[*].idlvar
    num_quantities = n_elements (quantities)
    pc_read_grid, object=grid, dim=dim, param=param, datadir=datadir, /quiet, single=single

    if (precision eq 'D' and not single) then $
      object = dblarr (dim.mxgrid, dim.mygrid, dim.mzgrid, num_quantities) $
    else $
      object = fltarr (dim.mxgrid, dim.mygrid, dim.mzgrid, num_quantities)

    time = pc_read ('time', file=varfile, datadir=datadir, single=single)
    tags = { time:time }
    for pos = 0L, num_quantities-1 do begin
      if (quantities[pos] eq 'dummy') then continue
      num_skip = varcontent[pos].skip
      if (num_skip eq 2) then begin
        length = strlen (quantities[pos])
        if ((length eq 2) and (strmid (quantities[pos], 0, 1) eq strmid (quantities[pos], 1, 1))) then length--
        label = strmid (quantities[pos], 0, length)
        object[*,*,*,pos] = pc_read ('data/'+label+'x', trimall=trimall, processor=proc, dim=dim, single=single)
        object[*,*,*,pos+1] = pc_read ('data/'+label+'y', trimall=trimall, processor=proc, dim=dim, single=single)
        object[*,*,*,pos+2] = pc_read ('data/'+label+'z', trimall=trimall, processor=proc, dim=dim, single=single)
        tags = create_struct (tags, quantities[pos], pos + indgen (num_skip+1), label+'x', pos, label+'y', pos+1, label+'z', pos+2)
        pos += num_skip
      end else if (num_skip ge 1) then begin
        tags = create_struct (tags, quantities[pos], pos + indgen (num_skip+1))
        for comp = 0, num_skip do begin
          label = quantities[pos] + strtrim(comp+1, 2)
          object[*,*,*,pos+comp] = pc_read ('data/'+label, trimall=trimall, processor=proc, dim=dim, single=single)
          tags = create_struct (tags, label, pos + comp)
        end
        pos += num_skip
      end else begin
        object[*,*,*,pos] = pc_read ('data/'+quantities[pos], trimall=trimall, processor=proc, dim=dim, single=single)
        tags = create_struct (tags, quantities[pos], pos)
      end
    end
    h5_close_file
    return
  end
;
; Default to allprocs, if available.
;
  default, allprocs, -1
  if (allprocs eq -1) then begin
    allprocs = 0
    if (is_defined(proc)) then allprocs = 0
    if (file_test (datadir+'/proc0/'+varfile) and file_test (datadir+'/proc1/', /directory) and not file_test (datadir+'/proc1/'+varfile)) then allprocs = 2
    if (file_test (datadir+'/allprocs/'+varfile) and not is_defined(proc) ) then allprocs = 1
  end
;
; Check if reduced keyword is set.
;
if (keyword_set (reduced) and is_defined(proc)) then $
    message, "pc_read_var_raw: /reduced and 'proc' cannot be set both."
;
; Check if allprocs is set.
;
  if ((allprocs ne 0) and is_defined(proc)) then message, "pc_read_var_raw: 'allprocs' and 'proc' cannot be set both."
;
; Set f77 keyword according to allprocs.
;
  default, f77, (allprocs eq 1 ? 0 : 1)
;
; Get necessary dimensions quietly.
;
  pc_read_dim, object=dim, datadir=datadir, proc=proc, reduced=reduced, /quiet
;
; Get necessary parameters.
;
  pc_read_param, object=start_param, dim=dim, datadir=datadir, /quiet, single=single
  pc_read_param, object=run_param, /param2, dim=dim, datadir=datadir, /quiet, single=single
  if (not is_defined(run_param)) then $
    print, 'Could not find '+datadir+'/param2.nml'
;
; We know from param whether we have to read 2-D or 3-D data.
;
  run2D=start_param.lwrite_2d
;
  pc_read_grid, object=grid, dim=dim, param=start_param, datadir=datadir, proc=proc, allprocs=allprocs, reduced=reduced, trim=trimall, /quiet, single=single
;
; Set the coordinate system.
;
  coord_system = start_param.coord_system
;
; Read local dimensions.
;
  nprocs = dim.nprocx * dim.nprocy * dim.nprocz
  ipx_start = 0
  ipy_start = 0
  ipz_start = 0
  if (allprocs eq 1) then begin
    procdim = dim
    ipx_end = 0
    ipy_end = 0
    ipz_end = 0
  end else begin
    ipz_end = dim.nprocz-1
    if (allprocs eq 2) then begin
      pc_read_dim, object=procdim, proc=0, datadir=datadir, /quiet
      ipx_end = 0
      ipy_end = 0
      procdim.nx = dim.nxgrid
      procdim.ny = dim.nygrid
      procdim.mx = dim.mxgrid
      procdim.my = dim.mygrid
      procdim.mw = procdim.mx * procdim.my * procdim.mz
    end else begin
      if (not is_defined(proc)) then begin
        pc_read_dim, object=procdim, proc=0, datadir=datadir, /quiet
        ipx_end = dim.nprocx-1
        ipy_end = dim.nprocy-1
      end else begin
        pc_read_dim, object=procdim, proc=proc, datadir=datadir, /quiet
        ipx_start = procdim.ipx
        ipy_start = procdim.ipy
        ipz_start = procdim.ipz
        ipx_end = ipx_start
        ipy_end = ipy_start
        ipz_end = ipz_start
      end
    end
  end
;
; Local shorthand for some parameters.
;
  nx = dim.nx
  ny = dim.ny
  nz = dim.nz
  nw = nx * ny * nz
  mx = dim.mx
  my = dim.my
  mz = dim.mz
  mw = mx * my * mz
  l1 = dim.l1
  l2 = dim.l2
  m1 = dim.m1
  m2 = dim.m2
  n1 = dim.n1
  n2 = dim.n2
  nghostx = dim.nghostx
  nghosty = dim.nghosty
  nghostz = dim.nghostz
  mvar = dim.mvar
  mvar_io = mvar
  if (run_param.lwrite_aux) then mvar_io += dim.maux
;
; Initialize cdat_grid variables.
;
  x = make_array (dim.mx, type=type_idl)
  y = make_array (dim.my, type=type_idl)
  z = make_array (dim.mz, type=type_idl)
  if (allprocs eq 0) then begin
    x_loc = make_array (procdim.mx, type=type_idl)
    y_loc = make_array (procdim.my, type=type_idl)
    z_loc = make_array (procdim.mz, type=type_idl)
  end
  dx = zero
  dy = zero
  dz = zero
  deltay = zero
;
;  Read meta data and set up variable/tag lists.
;
  if (n_elements (varcontent) eq 0) then $
      varcontent = pc_varcontent(datadir=datadir,dim=dim,param=start_param,quiet=quiet,run2D=run2D)
  totalvars = (size(varcontent))[1]
  if (not is_defined(var_list)) then begin
    var_list = varcontent[*].idlvar
    var_list = var_list[where (var_list ne "dummy")]
  end
;
; Display information about the files contents.
;
  content = ''
  for iv=0L, totalvars-1L do begin
    content += ', '+varcontent[iv].variable
    ; For vector quantities skip the required number of elements of the f array.
    iv += varcontent[iv].skip
  end
  content = strmid (content, 2)
;
  tags = { time: (single ? 0. : zero) }
  read_content = ''
  indices = [ -1 ]
  num_read = 0
  num = n_elements (var_list)
  for ov=0L, num-1L do begin
    tag = var_list[ov]
    iv = (where (varcontent[*].idlvar eq tag))[0]
    if (iv ge 0) then begin
      if (varcontent[iv].skip eq 2) then begin
        label = strmid (tag, 0, strlen (tag)-1)
        tags = create_struct (tags, tag, [num_read, num_read+1, num_read+2])
        tags = create_struct (tags, label+"x", num_read, label+"y", num_read+1, label+"z", num_read+2)
        indices = [ indices, iv, iv+1, iv+2 ]
        num_read += 3
      end else if (varcontent[iv].skip gt 0) then begin
        num_skip = varcontent[iv].skip + 1
        tags = create_struct (tags, tag, num_read + indgen (num_skip))
        for pos = 0L, num_skip-1 do begin
          label = tag + strtrim (pos + 1, 2)
          tags = create_struct (tags, label, num_read+pos)
        end
        indices = [ indices, iv + indgen (num_skip) ]
        num_read += num_skip
      end else begin
        tags = create_struct (tags, tag, num_read)
        indices = [ indices, iv ]
        num_read++
      end
      read_content += ', '+varcontent[iv].variable
    end
  end

  proc_mx=procdim.mx & proc_my=procdim.my & proc_mz=procdim.mz

  if (run2D) then begin
    if (dim.nxgrid eq 1) then proc_mx = 1 
    if (dim.nygrid eq 1) then proc_my = 1
    if (dim.nzgrid eq 1) then proc_mz = 1
  endif

  read_content = strmid (read_content, 2)
  if (not keyword_set(quiet)) then begin
    print, ''
    print, 'The file '+varfile+' contains: ', content
    if (strlen (read_content) lt strlen (content)) then print, 'Will read only: ', read_content
    print, ''
    print, 'The grid dimension is ', dim.mx, dim.my, dim.mz
    print, ''
  end
  if (not any (indices ge 0)) then message, 'Error: nothing to read!'
  indices = indices[where (indices ge 0)]
;
; Initialise target object: contains ghost zones irrespective of whether they are stored or not.
;
  object = make_array(dim.mx, dim.my, dim.mz, num_read, type=single ? 4 : type_idl)
;
; Initialise read buffers.
;
  buffer = make_array (proc_mx, proc_my, proc_mz, type=type_idl)
  if (f77 eq 0) then markers = 0 else markers = 1
;
; Iterate over processors.
;
  t = single ? -1. : -one

  for ipz = ipz_start, ipz_end do begin
    for ipy = ipy_start, ipy_end do begin
      for ipx = ipx_start, ipx_end do begin
;
        iproc = ipx + ipy*dim.nprocx + ipz*dim.nprocx*dim.nprocy
;
        x_off = (ipx-ipx_start) * procdim.nx
        y_off = (ipy-ipy_start) * procdim.ny
        z_off = (ipz-ipz_start) * procdim.nz
;
; Setup the coordinates mappings from the processor to the full domain.
; (Don't overwrite ghost zones of the lower processor.)
;
        x_add_glob = nghostx * (ipx ne ipx_start or proc_mx eq 1)
        y_add_glob = nghosty * (ipy ne ipy_start or proc_my eq 1)
        z_add_glob = nghostz * (ipz ne ipz_start or proc_mz eq 1)
;
        x_add_proc = proc_mx eq 1 ? 0 : x_add_glob
        y_add_proc = proc_my eq 1 ? 0 : y_add_glob
        z_add_proc = proc_mz eq 1 ? 0 : z_add_glob
;
        x_end = x_off + proc_mx-1 + x_add_glob - x_add_proc
        y_end = y_off + proc_my-1 + y_add_glob - y_add_proc
        z_end = z_off + proc_mz-1 + z_add_glob - z_add_proc
;
; Build the full path and filename.
;
        if (allprocs eq 1) then begin
          if (keyword_set (reduced)) then procdir = 'reduced' else procdir = 'allprocs'
        end else begin
          procdir = 'proc' + strtrim (iproc, 2)
          if ((allprocs eq 0) and not keyword_set (quiet)) then $
              print, 'Loading chunk ', strtrim (iproc+1, 2), ' of ', strtrim (nprocs, 2)
        end
        filename = datadir+'/'+procdir+'/'+varfile
;
; Check for existence and read the data.
;
        if (not file_test (filename)) then begin
          if (arg_present (exit_status)) then begin
            exit_status = 1
            print, 'ERROR: File not found "' + filename + '"'
            close, /all
            return
          end else begin
            message, 'ERROR: File not found "' + filename + '"'
          end
        end
;
; Open a varfile and read some data!
;
        openr, lun, filename, swap_endian=swap_endian, /get_lun
        mxyz = long64 (proc_mx) * long64 (proc_my) * long64 (proc_mz)
        for pos = 0, num_read-1 do begin
          pa = indices[pos]
          point_lun, lun, data_bytes * pa*mxyz + long64 (markers*4)
          readu, lun, buffer
          object[x_off+x_add_glob:x_end,y_off+y_add_glob:y_end,z_off+z_add_glob:z_end,pos] = $
          buffer[x_add_proc:*,y_add_proc:*,z_add_proc:*]
        end
        close, lun
;
        x_end = x_off + procdim.mx-1
        y_end = y_off + procdim.my-1
        z_end = z_off + procdim.mz-1
;
        openr, lun, filename, /f77, swap_endian=swap_endian
        point_lun, lun, data_bytes * mvar_io*mxyz + long64 (2*markers*4)
        t_test = zero
        if (allprocs eq 1) then begin
          ; collectively written files
          readu, lun, t_test, x, y, z, dx, dy, dz
        end else if (allprocs eq 2) then begin
          ; xy-collectively written files for each ipz-layer
          readu, lun, t_test
          if (iproc eq 0) then readu, lun, x, y, z, dx, dy, dz
        end else begin
          ; distributed files
          if (start_param.lshear) then $
            readu, lun, t_test, x_loc, y_loc, z_loc, dx, dy, dz, deltay $
          else $
            readu, lun, t_test, x_loc, y_loc, z_loc, dx, dy, dz
         
          x[x_off:x_end] = x_loc
          y[y_off:y_end] = y_loc
          z[z_off:z_end] = z_loc
        end
        
        if single then t_test=float(t_test)         
        if (t lt 0.) then t = t_test
        if (t ne t_test) then begin
          print, "ERROR: TIMESTAMP IS INCONSISTENT: ", filename
          print, "t /= t_test: ", t, t_test
          print, "Type '.c' to continue..."
          stop
        end
        close, lun
        free_lun, lun
;
      end
    end
  end
  if (precision eq 'D' and single) then begin
    x=float(x) & y=float(y) & z=float(z)
    dx=float(dx) & dy=float(dy) & dz=float(dz)
  endif
  tags = create_struct (tags, ['x','y','z','dx','dy','dz'], x, y, z, dx, dy, dz)
  if (start_param.lshear) then tags = create_struct (tags, 'deltay', single ? float(deltay) : deltay)
;
; Tidy memory a little.
;
  undefine, buffer
  undefine, x_loc
  undefine, y_loc
  undefine, z_loc
;
; Remove ghost zones if requested.
;
  if (keyword_set (trimall)) then object = pc_noghost (object, dim=dim)
;
  if (not keyword_set (quiet)) then begin
    print, ' t = ', t
    print, ''
  endif
;
  tags.time = t
  time = t
;
end
