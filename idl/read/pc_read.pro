; +
; NAME:
;       PC_READ
;
; PURPOSE:
;       Pencil-Code unified reading routine.
;       Reads data from a snapshot file generated by a Pencil Code run.
;       This routine automatically detects HDF5 and old binary formats.
;
; PARAMETERS:
;       quantity [string]: f-array component to read (mandatory).
;       filename [string]: name of the file to read. Default: last opened file
;       datadir [string]: path to the data directory. Default: 'data/'
;       trimall [boolean]: do not read ghost zones. Default: false
;       ghostless [boolean]: file has no ghost zones. Default: false
;       processor [integer]: number of processor subdomain to read. Default: all
;       dim [structure]: dimension structure. Default: load if needed
;       start [integer]: start reading at this grid position (includes ghost cells)
;       count [integer]: number of grid cells to read from starting position
;       close [boolean]: close file after reading
;
; EXAMPLES:
;       Ax = pc_read ('ax', file='var.h5') ;; open file 'var.h5' and read Ax
;       Ay = pc_read ('ay', /trim) ;; read Ay without ghost cells
;       Az = pc_read ('az', processor=2) ;; read data of processor 2
;       ux = pc_read ('ux', start=[47,11,13], count=[16,8,4]) ;; read subvolume
;       aa = pc_read ('aa') ;; read all three components of a vector-field
;       xp = pc_read ('part/xp', file='pvar.h5') ;; get x position of particles
;       ID = pc_read ('stalker/ID', file='PSTALK0.h5') ;; stalker particle IDs
;
; MODIFICATION HISTORY:
;       $Id$
;       07-Apr-2019/PABourdin: coded
;
function pc_read, quantity, filename=filename, datadir=datadir, trimall=trim, ghostless=ghostless, processor=processor, dim=dim, start=start, count=count, close=close, single=single

	COMPILE_OPT IDL2,HIDDEN

	common pc_read_common, file

	quantity = strtrim (quantity, 2)
	num_quantities = n_elements (quantity)

	if (num_quantities eq 1) then begin
		; expand vector quantities
		vectors = [ 'aa', 'uu', 'bb', 'jj', 'ff' ]
		for pos = 0, n_elements (vectors)-1 do begin
			if (stregex (quantity, '^'+vectors[pos]+'[xyz]?$', /bool)) then begin
				expanded = quantity
				; translate two-letter shortcuts
				if (strlen (vectors[pos]) eq 2) then expanded = strmid (quantity, 1)
				if (stregex (quantity, '^'+vectors[pos]+'$', /bool)) then expanded += [ 'x', 'y', 'z' ]
				return, pc_read (expanded, filename=filename, datadir=datadir, trimall=trim, processor=processor, dim=dim, start=start, count=count, close=close, singl=single)
			end
		end
	end

	if (num_quantities gt 1) then begin
		; read multiple quantities in one large array
		data = pc_read (quantity[0], filename=filename, datadir=datadir, trimall=trim, processor=processor, dim=dim, start=start, count=count, single=single)
		sizes = size (data, /dimensions) > 1
		dimensions = size (data, /n_dimensions) > 1
;
; Allow continuation of program if reading of individual variables fails, say, due to lack of memory.
;
                failed=0
		for pos = 1, num_quantities-1 do begin
			tmp = pc_read (quantity[pos], filename=filename, datadir=datadir, trimall=trim, processor=processor, dim=dim, start=start, count=count, single=single)
                        if (size(tmp))[0] eq 0 then begin
                          failed+=1
                          continue
                        endif
			if (dimensions eq 1) then begin
				data = [ data, tmp ]
			end else if (dimensions eq 2) then begin
				data = [ [data], [tmp] ]
			end else begin
				data = [ [[data]], [[tmp]] ]
			end
		end
		tmp = !Values.D_NaN
		if (keyword_set (close)) then h5_close_file
		return, reform (data, [ sizes, num_quantities-failed ], /overwrite)
	end

	particles = (strpos (strlowcase (quantity) ,'part/') ge 0)

	if (keyword_set (filename)) then begin
		if (not keyword_set (datadir)) then datadir = pc_get_datadir (datadir)
		if (file_test (datadir+'/allprocs/'+filename)) then begin
			file = datadir+'/allprocs/'+filename
		end else begin
			file = datadir+'/'+filename
		end
	end else begin
		if (not keyword_set (file)) then begin
			; no file is open
			filename=identify_varfile(path=file)
			if strpos(filename,'.h5') eq -1 then begin
				undefine, file
				; read old file format
				return, pc_read_old (quantity, filename=filename, datadir=datadir, trimall=trim, processor=processor, dim=dim, start=start, count=count)
			endif
		end
	end

	if (size (processor, /type) ne 0) then begin
		if (keyword_set (particles)) then begin
			distribution = h5_read ('proc/distribution', filename=file)
			start = 0
			if (processor ge 1) then start = total (distribution[0:processor-1])
			count = distribution[processor]
			return, h5_read (quantity, start=start, count=count, close=close, single=single)
		end else begin
			if (size (dim, /type) eq 0) then pc_read_dim, obj=dim, datadir=datadir, proc=proc
			ipx = processor mod dim.nprocx
			ipy = (processor / dim.nprocx) mod dim.nprocy
			ipz = processor / (dim.nprocx * dim.nprocy)
			nx = dim.nxgrid / dim.nprocx
			ny = dim.nygrid / dim.nprocy
			nz = dim.nzgrid / dim.nprocz
			ghost = [ dim.nghostx, dim.nghosty, dim.nghostz ]
			start = [ ipx*nx, ipy*ny, ipz*nz ]
			count = [ nx, ny, nz ]
			if (not keyword_set (ghostless)) then count += ghost * 2
		end
	end

	if (not keyword_set (particles)) then begin
		if (strpos (strlowcase (quantity), '/') lt 0) then begin
			h5_open_file, file
			if (not h5_contains (quantity) and h5_contains ('data/'+quantity)) then quantity = 'data/'+quantity
		end
		if (keyword_set (trim)) then begin
			default, start, [ 0, 0, 0 ]
			default, count, [ dim.mxgrid, dim.mygrid, dim.mzgrid ]
			if (size (dim, /type) eq 0) then pc_read_dim, obj=dim, datadir=datadir
			ghost = [ dim.nghostx, dim.nghosty, dim.nghostz ]
			degenerated = where (count eq 1, num_degenerated)
			if (num_degenerated gt 0) then ghost[degenerated] = 0
			return, h5_read (quantity, filename=file, start=start+ghost, count=count-ghost*2, close=close, single=single)
		end
	end
	return, h5_read (quantity, filename=file, start=start, count=count, close=close, single=single)
end

