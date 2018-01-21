"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Highlight groups

if !hlexists('Conflict3Local')
  highlight link Conflict3Local DiffAdd
endif

if !hlexists('Conflict3Remote')
  highlight link Conflict3Remote DiffDelete
endif

if !hlexists('Conflict3Both')
  highlight link Conflict3Both DiffText
endif

if !hlexists('Conflict3LocalDel')
  highlight link Conflict3LocalDel Conflict3Local
endif

if !hlexists('Conflict3RemoteDel')
  highlight link Conflict3RemoteDel Conflict3Remote
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Top-level API

" Highlight the current conflict.
function! conflict3#highlight_next_conflict()
  call conflict3#highlight#clear()
  let info = s:get_conflict_info()
  if !info.valid
    return
  endif
  call conflict3#highlight#apply(s:highlights(info))
endfunction

" Resolve the next microhunk that can be resolved.
function! conflict3#resolve_one_hunk()
  call conflict3#highlight#clear()
  let info = s:get_conflict_info()
  if !info.valid
    return
  endif
  let curpos = getcurpos()
  let cs = s:make_microhunks(info.diff)
  call s:annotate_microhunks(cs)
  let start = s:find_next_microhunk(cs, curpos[1], curpos[2], info)
  let r = s:try_resolve_hunk(cs, start, info, 1)
  if len(r) == 0
    let r = s:try_resolve_hunk(cs, [], info, 1)
  endif
  if len(r) == 0
    echoerr "Failed to resolve hunk"
  else
    call s:update_conflict(info, r[0], s:hunks_to_diff(r[1]))
  endif
  call conflict3#highlight#apply(s:highlights(info))
endfunction

" Resolve all microhunks that can be resolved.
function! conflict3#resolve_all_hunks()
  call conflict3#highlight#clear()
  let info = s:get_conflict_info()
  if !info.valid
    return
  endif
  while 1
    let cs = s:make_microhunks(info.diff)
    call s:annotate_microhunks(cs)
    let r = s:try_resolve_hunk(cs, [], info, 1)
    if len(r) == 0
      break
    endif
    call s:update_conflict(info, r[0], s:hunks_to_diff(r[1]))
  endwhile
  call conflict3#highlight#apply(s:highlights(info))
endfunction

" Shrink the current conflict by moving as much text out as possible. If
" also_remove is true, delete the conflict when it would be left empty.
function! conflict3#shrink(also_remove)
  call conflict3#highlight#clear()
  let info = s:get_conflict_info()
  if !info.valid
    return
  endif
  let [edits, newdiff] = s:shrink_conflict(info)
  call s:update_conflict(info, edits, newdiff)
  if len(newdiff) == 0 && a:also_remove
    call s:delete_conflict(info)
  else
    call conflict3#highlight#apply(s:highlights(info))
  endif
endfunction

" Resolve the next microhunk by taking the specified version.
function! conflict3#take_version(version)
  let info = s:get_conflict_info()
  if !info.valid
    return
  endif
  let curpos = getcurpos()
  let cs = s:make_microhunks(info.diff)
  call s:annotate_microhunks(cs)
  let loc = s:find_next_microhunk(cs, curpos[1], curpos[2], info)
  if len(loc) == 0
    return
  endif
  let [edits, new_hunks] = s:take_version(cs, loc, info, a:version)
  call s:update_conflict(info, edits, s:hunks_to_diff(new_hunks))
  call conflict3#highlight#apply(s:highlights(info))
endfunction

" Versions
let s:v_local = 0
let s:v_base = 1
let s:v_remote = 2

function! conflict3#v_local()
  return s:v_local
endfunction

function! conflict3#v_base()
  return s:v_base
endfunction

function! conflict3#v_remote()
  return s:v_remote
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Conflict info

" Mapping from bufno to conflict info
let s:saved_conflict_info = {}

" Return a collection of information about the current conflict. Returns a
" dictionary:
"
" valid: 1
" diff: the 3-way diff of the current conflict
" local_marker, base_marker, remote_marker, end_marker: the line number of the
"   local marker, base marker, remote marker, and end marker, respectively
" local, base, remote: lines of local, base, and rmeote text, respectively,
"   as an array of strings
"
" On failure, { valid: 0 } is returned instead.
"
" For each buffer, information about one conflict is rememberd in a global
" variable, so that we don't have to re-run the diff algorithm every time
" a command is executed.
"
" Note that the returned dictionary is the cached entry itself. Only modify it
" using dedicated functions such as s:update_conflict or s:delete_conflict.
function! s:get_conflict_info()
  let locarray = conflict3#find_conflict()
  if len(locarray) == 0
    return { 'valid': 0 }
  endif

  let [local_marker, base_marker, remote_marker, end_marker] = locarray
  let local = getline(local_marker + 1, base_marker - 1)
  let base = getline(base_marker + 1, remote_marker - 1)
  let remote = getline(remote_marker + 1, end_marker - 1)

  let buf = string(bufnr('%'))
  let saved = get(s:saved_conflict_info, buf, { 'valid': 0 })
  if saved.valid && local == saved.local && base == saved.base
        \ && remote == saved.remote
    " Saved diff is still valid.
    let diff = saved.diff
  else
    let local_diff = conflict3#diff#multiline_diff(base, local)
    let remote_diff = conflict3#diff#multiline_diff(base, remote)
    let diff = conflict3#diff#linewise_3way(local_diff, remote_diff)
  endif

  let info = {
        \ 'valid': 1,
        \ 'diff': diff,
        \ 'local_marker': local_marker,
        \ 'base_marker': base_marker,
        \ 'remote_marker': remote_marker,
        \ 'end_marker': end_marker,
        \ 'local': local,
        \ 'base': base,
        \ 'remote': remote }
  let s:saved_conflict_info[buf] = info
  return info
endfunction

" Find the current/next conflict, and return a quadruple of the line numbers
" of its markers. Returns [] if no conflict is found.
function! conflict3#find_conflict()
  let orig_cursor = getcurpos()

  call setpos('.', [orig_cursor[0], orig_cursor[1], 1, orig_cursor[2]])

  let end_marker    = search('\V\^>>>>>>', 'cW')
  let remote_marker = search('\V\^======', 'bW')
  let base_marker   = search('\V\^||||||', 'bW')
  let local_marker  = search('\V\^<<<<<<', 'bW')

  call setpos('.', orig_cursor)

  if 0 < local_marker && local_marker < base_marker
        \ && base_marker < remote_marker && remote_marker < end_marker
    return [local_marker, base_marker, remote_marker, end_marker]
  endif
  return []
endfunction

" Insert/update an item in a dictionary. Defined as a function just so that
" it can be used inside a lambda.
function! s:set(dic, key, val)
  let a:dic[a:key] = a:val
endfunction

" Update the conflict using some edits. The 3-way diff for the updated
" conflict must be given as well.
function! s:update_conflict(info, edits, newdiff)
  let a:info.diff = a:newdiff
  call s:perform_edits(a:edits + [
        \ [ a:info.local_marker, { n -> s:set(a:info, 'local_marker', n) } ],
        \ [ a:info.base_marker, { n -> s:set(a:info, 'base_marker', n) } ],
        \ [ a:info.remote_marker, { n -> s:set(a:info, 'remote_marker',  n) } ],
        \ [ a:info.end_marker, { n -> s:set(a:info, 'end_marker', n) } ]])
  let a:info.local = getline(a:info.local_marker + 1, a:info.base_marker - 1)
  let a:info.base = getline(a:info.base_marker + 1, a:info.remote_marker - 1)
  let a:info.remote = getline(a:info.remote_marker + 1, a:info.end_marker - 1)
endfunction

" Completely delete a conflict
function! s:delete_conflict(info)
  call s:perform_edits([[a:info.local_marker, a:info.end_marker + 1, []]])
  unlet s:saved_conflict_info[string(bufnr('%'))]
endfunction

" Find the version the given line is in. If the given line is in none
" of the versions, return -1.
function! s:find_version(info, line)
  if a:line < a:info.local_marker
    return -1
  elseif a:line < a:info.base_marker
    return s:v_local
  elseif a:line < a:info.remote_marker
    return s:v_base
  elseif a:line < a:info.end_marker
    return s:v_remote
  else
    return -1
  endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Computing highlights

" Create a list of character-wise highlights for a single line by combining
" consecutive highlighted columns. It takes a list of [highlight, column]
" pairs. The input list must be sorted by the column.
function! s:pack_line_highlights(line, highlight_cols)
  if len(a:highlight_cols) == 0
    return []
  endif

  let [cur_hi, cur_col] = a:highlight_cols[0]
  let start_col = cur_col
  let i = 1
  let out = []

  for [hi, col] in a:highlight_cols[1:]
    if hi == cur_hi && col == cur_col + 1
      let cur_col = col
    else
      call add(out, [cur_hi, [a:line, start_col, cur_col - start_col + 1]])
      let start_col = col
      let cur_col = col
      let cur_hi = hi
    endif
  endfor

  call add(out, [cur_hi, [a:line, start_col, cur_col - start_col + 1]])
  return out
endfunction

" Compute highlights a single line using the 3-way diff.
function! s:line_highlights(diff3, local_line, base_line, remote_line)
  let local = 1
  let base = 1
  let remote = 1
  let his_local = []
  let his_base = []
  let his_remote = []

  for item in a:diff3
    let type = item[0]

    if type == 0 " Add/None
      call add(his_local, ['Conflict3Local', local])
      let local += 1
    elseif type == 1 " None/Add
      call add(his_remote, ['Conflict3Remote', remote])
      let remote += 1
    elseif type == 2 " Remove/Remove
      call add(his_base, ['Conflict3Both', base])
      let base += 1
    elseif type == 3 " Remove/None
      call add(his_base, ['Conflict3Local', base])
      let base += 1
      let remote += 1
    elseif type == 4 " None/Remove
      call add(his_base, ['Conflict3Remote', base])
      let local += 1
      let base += 1
    else " None/None
      let local += 1
      let base += 1
      let remote += 1
    endif
  endfor

  return s:pack_line_highlights(a:local_line, his_local) +
        \ s:pack_line_highlights(a:base_line, his_base) +
        \ s:pack_line_highlights(a:remote_line, his_remote)
endfunction

" Compute highlights for everything
function! s:highlights(info)
  let local = a:info.local_marker + 1
  let base = a:info.base_marker + 1
  let remote = a:info.remote_marker + 1
  let out = []

  for item in a:info.diff
    let type = item[0]

    if type == 0 " Add/None
      call add(out, ['Conflict3Local', local])
      let local += 1
    elseif type == 1 " None/Add
      call add(out, ['Conflict3Remote', remote])
      let remote += 1
    elseif type == 2 " Remove/Remove
      call add(out, ['Conflict3Both', base])
      let base += 1
    else
      call extend(out, s:line_highlights(item[1], local, base, remote))
      let base += 1
      if type == 3 " Remove/Modify
        let remote += 1
      elseif type == 4 " Modify/Remove
        let local += 1
      else " Modify/Modify
        let local += 1
        let remote += 1
      endif
    endif
  endfor

  return out
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Computing edits

" Try to shrink the conflict. Returns [edits-to-shrink, updated-diff].
function! s:shrink_conflict(info)
  " Shrink top
  let i = 0

  while i < len(a:info.local) && i < len(a:info.base) && i < len(a:info.remote) &&
        \ a:info.local[i] == a:info.base[i] && a:info.base[i] == a:info.remote[i]
    let i += 1
  endwhile

  let diff1 = a:info.diff[i:-1]
  if 0 < i
    let edits_top = [
          \ [a:info.local_marker, a:info.local_marker, a:info.local[0:i-1]],
          \ [a:info.local_marker + 1, a:info.local_marker + 1 + i, []],
          \ [a:info.base_marker + 1, a:info.base_marker + 1 + i, []],
          \ [a:info.remote_marker + 1, a:info.remote_marker + 1 + i, []]]
  else
    let edits_top = []
  endif

  if i == len(a:info.local) || i == len(a:info.base) || i == len(a:info.remote)
    " Penetrated to the end.
    return [edits_top, diff1]
  endif

  " Shrink bottom
  let i = 0

  while i < len(a:info.local) && i < len(a:info.base) && i < len(a:info.remote) &&
        \ a:info.local[-1-i] == a:info.base[-1-i] &&
        \ a:info.base[-1-i] == a:info.remote[-1-i]
    let i += 1
  endwhile

  if 0 < i
    let edits_bottom = [
          \ [a:info.end_marker + 1, a:info.end_marker + 1, a:info.local[-i:-1]],
          \ [a:info.base_marker - i, a:info.base_marker, []],
          \ [a:info.remote_marker - i, a:info.remote_marker, []],
          \ [a:info.end_marker - i, a:info.end_marker, []]]
  else
    let edits_bottom = []
  endif
  return [edits_top + edits_bottom, diff1[-i:-1]]
endfunction

" Try to automatically resolve the next nontrivial hunk, searched from the
" given start_loc. If only_soluble is true, ignore insoluble hunks and keep
" searching.
"
" If a hunk is resolved, returns [edits, updated_hunks].
" Otherwise, returns [].
function! s:try_resolve_hunk(hunks, start_loc, info, only_soluble)
  let r = s:try_resolve_hunk_relative(a:hunks, a:start_loc,
        \ a:info.local, a:info.base, a:info.remote, a:only_soluble)
  if len(r) == 0
    return []
  else
    let edits = s:absolutize_edits(r[0], a:info.local_marker + 1,
          \ a:info.base_marker + 1, a:info.remote_marker + 1)
    return [edits , r[1]]
  endif
endfunction

" Same as try_resolve_hunk, but returns relative edits.
function! s:try_resolve_hunk_relative(hunks, start_loc,
      \ local, base, remote, only_soluble)
  let hunks = copy(a:hunks)
  for i in range(len(hunks))
    let hunk = hunks[i]
    if 0 < len(a:start_loc) && i < a:start_loc[0]
      continue
    endif

    if hunk.status == 100
      let on_line = 0 < len(a:start_loc) && a:start_loc[0] == i
      let r = s:try_resolve_hunk_relative(hunk.children,
            \ [on_line && 1 < len(a:start_loc) ? a:start_loc[1] : 0],
            \ a:local[hunk.local_begin], a:base[hunk.base_begin],
            \ a:remote[hunk.remote_begin], a:only_soluble)
      if len(r) == 2
        let nontrivial_hunk_found = 0
        for c in r[1]
          if c.status != 0
            let nontrivial_hunk_found = 1
            break
          endif
        endfor
        if nontrivial_hunk_found
          let hunks[i] = { 'status': 100, 'children': r[1]}
        else
          let hunks[i] = { 'status': 0,
                \ 'diff': [[5, s:concat(map(r[1], {index, val -> val.diff}))]] }
        endif
        let edits = []
        for [ver, begin, end, str] in r[0]
          if ver == s:v_local
            let line = hunk.local_begin
          elseif ver == s:v_base
            let line = hunk.base_begin
          else
            let line = hunk.remote_begin
          endif
          call add(edits, [ver, line, begin, end, str])
        endfor
        return [edits, hunks]
      endif
    else
      if hunk.status == 0
        continue " Skip trivial hunk.
      endif
      if hunk.status == 1
        " Only remote is differnet. Take it.
        let remote_lines = s:subseq(a:remote, hunk.remote_begin, hunk.remote_end)
        let hunks[i] = s:make_trivial_hunk(remote_lines)
        return [[[s:v_local, hunk.local_begin, hunk.local_end, remote_lines],
              \  [s:v_base, hunk.base_begin, hunk.base_end, remote_lines]],
              \ hunks]
      elseif hunk.status == 2
        " Only local is different. Take it.
        let local_lines = s:subseq(a:local, hunk.local_begin, hunk.local_end)
        let hunks[i] = s:make_trivial_hunk(local_lines)
        return [[[s:v_base, hunk.base_begin, hunk.base_end, local_lines],
              \  [s:v_remote, hunk.remote_begin, hunk.remote_end, local_lines]],
              \ hunks]
      elseif hunk.status == 4
        " Local and remote are both different from base. This hunk is
        " soluble iff they are the same.
        let local_lines = s:subseq(a:local, hunk.local_begin, hunk.local_end)
        let remote_lines = s:subseq(a:remote, hunk.remote_begin, hunk.remote_end)
        if local_lines == remote_lines
          let hunks[i] = s:make_trivial_hunk(local_lines)
          return [[[s:v_base, hunk.base_begin, hunk.base_end, local_lines]], hunks]
        endif
      endif
    endif
    " This hunk is not soluble.
    if a:only_soluble
      return []
    endif
  endfor
  " Nothing happend.
  return []
endfunction

" Resolve the hunk pointed to by loc by taking the specified version.
"
" Returns [edits, updated_hunks].
function! s:take_version(hunks, loc, info, version)
  let r = s:take_version_relative(a:hunks, a:loc,
        \ a:info.local, a:info.base, a:info.remote, a:version)
  if len(r) == 0
    return []
  else
    let edits = s:absolutize_edits(r[0], a:info.local_marker + 1,
          \ a:info.base_marker + 1, a:info.remote_marker + 1)
    return [edits , r[1]]
  endif
endfunction

" Same as s:take_version, but returns relative edits.
function! s:take_version_relative(hunks, loc, local, base, remote, version)
  let hunks = copy(a:hunks)
  if len(a:loc) == 2
    let line_hunk = hunks[a:loc[0]]
    let children = copy(line_hunk.children)
    let hunk = children[a:loc[1]]
    if a:version == s:v_local
      let str = s:subseq(a:local[line_hunk.local_begin], hunk.local_begin, hunk.local_end)
      let edits = [
            \ [s:v_base, line_hunk.base_begin, hunk.base_begin, hunk.base_end, str],
            \ [s:v_remote, line_hunk.remote_begin, hunk.remote_begin, hunk.remote_end, str]]
    elseif a:version == s:v_base
      let str = s:subseq(a:base[line_hunk.base_begin], hunk.base_begin, hunk.base_end)
      let edits = [
            \ [s:v_local, line_hunk.local_begin, hunk.local_begin, hunk.local_end, str],
            \ [s:v_remote, line_hunk.remote_begin, hunk.remote_begin, hunk.remote_end, str]]
    else
      let str = s:subseq(a:remote[line_hunk.remote_begin], hunk.remote_begin, hunk.remote_end)
      let edits = [
            \ [s:v_local, line_hunk.local_begin, hunk.local_begin, hunk.local_end, str],
            \ [s:v_base, line_hunk.base_begin, hunk.base_begin, hunk.base_end, str]]
    endif
    let children[a:loc[1]] = s:make_trivial_hunk(str)
    let hunks[a:loc[0]] = { 'status': 100, 'children': children }
  else
    let hunk = hunks[a:loc[0]]
    if a:version == s:v_local
      let lines = s:subseq(a:local, hunk.local_begin, hunk.local_end)
      let edits = [
            \ [s:v_base, hunk.base_begin, hunk.base_end, lines],
            \ [s:v_remote, hunk.remote_begin, hunk.remote_end, lines]]
    elseif a:version == s:v_base
      let lines = s:subseq(a:base, hunk.base_begin, hunk.base_end)
      let edits = [
            \ [s:v_local, hunk.local_begin, hunk.local_end, lines],
            \ [s:v_remote, hunk.remote_begin, hunk.remote_end, lines]]
    else
      let lines = s:subseq(a:remote, hunk.remote_begin, hunk.remote_end)
      let edits = [
            \ [s:v_local, hunk.local_begin, hunk.local_end, lines],
            \ [s:v_base, hunk.base_begin, hunk.base_end, lines]]
    endif
    let hunks[a:loc[0]] = s:make_trivial_hunk(lines)
  endif
  return [edits, hunks]
endfunction

" Turn relative edits into absolute edits.
function! s:absolutize_edits(relative_edits, local_start, base_start, remote_start)
  function! s:absolutize_edit_item(idx, edit) closure
    if a:edit[0] == s:v_local
      let start = a:local_start
    elseif a:edit[0] == s:v_base
      let start = a:base_start
    else
      let start = a:remote_start
    endif
    if len(a:edit) == 4
      return [start + a:edit[1], start + a:edit[2], a:edit[3]]
    else
      return [start + a:edit[1], a:edit[2], a:edit[3], a:edit[4]]
    endif
  endfunction
  return map(copy(a:relative_edits), funcref('s:absolutize_edit_item'))
endfunction

" Create a trivial microhunk.
function! s:make_trivial_hunk(thing)
  return { 'status': 0, 'diff': s:make_unchanged_diff(a:thing) }
endfunction

" Create a trivial diff.
function! s:make_unchanged_diff(thing)
  if type(a:thing) == v:t_string
    return s:make_unchanged_diff_charwise(a:thing)
  else
    return map(copy(a:thing), { str -> [5, s:make_unchanged_diff_charwise(str)] })
  endif
endfunction

" Create a trivial character-wise diff.
function! s:make_unchanged_diff_charwise(str)
  return repeat([[5, []]], len(a:str))
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Performing edits

" Edit
"
" An edit is an instruction for updating the buffer. It takes one of the three
" forms;
"
" [ start-line, end-line, lines ]
"   Overwrite [start-line, end-line) with lines.
" [ line, start-col, end-col, string ]
"   Overwrite [line:start-col, line:end-col) with string.
" [ line, fn ]
"   Call fn with a single argument, a number to which line is translated after
"   the edits.

" Perform the given edits.
function! s:perform_edits(edits)
  let edits = sort(copy(a:edits), funcref('s:compare_edits'))

  " Line number after edit - line number before edit.
  let line_offset = 0

  let col_offset = 0
  let last_charwise_edit = 0

  for edit in edits
    if len(edit) == 2
      call edit[1](edit[0] + line_offset)
    elseif len(edit) == 3
      let [line_begin, line_end, lines] = edit
      if line_begin < line_end
        silent execute string(line_offset + line_begin) . ',' .
              \ string(line_offset + line_end - 1) . 'delete _'
      endif
      call append(line_offset + line_begin - 1, lines)
      let line_offset += len(lines) - (line_end - line_begin)
    else
      let [line, col_begin, col_end, str] = edit
      if last_charwise_edit != line
        let last_charwise_edit = line
        let col_offset = 0
      endif
      let old_line = getline(line_offset + line)
      let new_line = s:subseq(old_line, 0,  col_offset + col_begin) .
            \ str . old_line[col_offset + col_end : -1]
      call setline(line_offset + line, new_line)
      let col_offset += len(str) - (col_end - col_begin)
    endif
  endfor
endfunction

" Comparison function for edits. An edit that comes earlier is considered
" smaller.
function! s:compare_edits(a, b)
  " Compare line first
  if a:a[0] < a:b[0]
    return -1
  elseif a:a[0] > a:b[0]
    return 1
  endif

  " Edits comes before line number reports
  if len(a:a) == 2
    return 1
  elseif len(a:b) == 2
    return -1
  endif

  " At this point, a and b should both be character-wise edits.
  if len(a:a) < 4 || len(a:b) < 4
    throw 'Comparing incompatible edits: ' . string(a:a) . ', ' . string(a:b)
  endif

  return a:a[1] - a:b[1]
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Micronhunks

" Microhunk is a fragment of a 3-way diff. It's represented as a
" Dictionary like:
"   status:
"     0 - all three versions are identical
"     1 - base and local are the same, but remote is different
"     2 - base and remote are the same, but local is different
"     3 - local and remote are the same, but base is differnet
"     4 - all three versions are different
"     100 - this is not really a microhunk, rather a line containing
"       multiple character-wise microhunks (in the 'children' field).
"   diff: (present if status != 100)
"     a 3-way diff
"   children: (present if status == 100)
"     a list of microhunks. Contains at least one non-trivial conflict.

" Create a list of microhunks from a 3-way diff.
function! s:make_microhunks(diff)
  let out = []
  let diff_local = 0
  let diff_remote = 0
  let last_was_add = 0
  let diff = []

  " Flush the current hunk to the output array.
  let flush_hunk = {}
  function! flush_hunk._() closure
    if diff_local && diff_remote
      " TODO: check if local and remote are the same.
      let status = 4
    elseif diff_local
      let status = 2
    elseif diff_remote
      let status = 1
    else
      let status = 0
    endif

    call add(out, { 'status': status, 'diff': diff })
    let diff_local = 0
    let diff_remote = 0
    let last_was_add = 0
    let diff = []
  endfunction
  for item in a:diff
    let type = item[0]

    let current_is_trivial = diff_local == 0 && diff_remote == 0 && len(diff) > 0

    " First, determine whether this item is trivial, i.e. contains no change
    " at all.
    if type == 5 && count(item[1], [5, []]) == len(item[1])
      " Trivial item.
      if diff_local != 0 || diff_remote != 0
        " The current hunk is non-trivial. Flush it first.
        call flush_hunk._()
      endif
      call add(diff, item)
    elseif type == 5
      " Nontrivial character-wise diff. Flush the current hunk if any,
      " and recurse.
      if len(diff) > 0
        call flush_hunk._()
      endif
      call add(out, { 'status': 100, 'children': s:make_microhunks(item[1]) })
    elseif type == 0 " Add/None
      if 0 < len(diff) && !diff_local && !last_was_add
        call flush_hunk._()
      endif
      let diff_local = 1
      let last_was_add = 1
      call add(diff, item)
    elseif type == 1 " None/Add
      if 0 < len(diff) && !diff_remote && !last_was_add
        call flush_hunk._()
      endif
      let diff_remote = 1
      let last_was_add = 1
      call add(diff, item)
    elseif type == 2 " Remove/Remove
      if 0 < len(diff) && !diff_local && !diff_remote
        call flush_hunk._()
      endif
      let diff_local = 1
      let diff_remote = 1
      call add(diff, item)
    elseif type == 3 " Remove/Modify
      let trivial_remote = count(item[1], [3, []]) == len(item[1])
      if 0 < len(diff) && !diff_local && (!diff_remote || trivial_remote)
        call flush_hunk._()
      endif
      let diff_local = 1
      if !trivial_remote
        let diff_remote = 1
      endif
      call add(diff, item)
    else " Modify/Remove
      let trivial_local = count(item[1], [4, []]) == len(item[1])
      if 0 < len(diff) && (!diff_local || trivial_local) && !diff_remote
        call flush_hunk._()
      endif
      if !trivial_local
        let diff_local = 1
      endif
      let diff_remote = 1
      call add(diff, item)
    endif
  endfor

  if len(diff) > 0
    call flush_hunk._()
  endif

  return out
endfunction

" Annotate microhunks with their offsets. The following fields are added:
" * local_begin
" * local_end
" * base_begin
" * base_end
" * remote_begin
" * remote_end
"
" This function updates the input data structure in place.
function! s:annotate_microhunks(hunks)
  let local = 0
  let base = 0
  let remote = 0
  for hunk in a:hunks
    if hunk.status == 100
      call s:annotate_microhunks(hunk.children)
      let local_end = local + 1
      let base_end = base + 1
      let remote_end = remote + 1
    else
      let local_end = local
      let base_end = base
      let remote_end = remote
      for item in hunk.diff
        let type = item[0]
        if type == 0 " Add/None
          let local_end += 1
        elseif type == 1 " None/Add
          let remote_end += 1
        elseif type == 2 " Remove/Remove
          let base_end += 1
        elseif type == 3 " Remove/Modify
          let base_end += 1
          let remote_end += 1
        elseif type == 4 " Modify/Remove
          let local_end += 1
          let base_end += 1
        else " Modify/Modify
          let local_end += 1
          let base_end += 1
          let remote_end += 1
        endif
      endfor
    endif
    let hunk.local_begin = local
    let hunk.local_end = local_end
    let hunk.base_begin = base
    let hunk.base_end = base_end
    let hunk.remote_begin = remote
    let hunk.remote_end = remote_end
    let local = local_end
    let base = base_end
    let remote = remote_end
  endfor
endfunction

" Turn microhunks back into a 3-way diff.
function! s:hunks_to_diff(hunks)
  let diff = []
  for hunk in a:hunks
    if hunk.status == 100
      call add(diff, [5, s:hunks_to_diff(hunk.children)])
    else
      call extend(diff, hunk.diff)
    endif
  endfor
  return diff
endfunction

" Search for the nearest microhunk, starting from the cursor position.
" Returns:
"   [] if there is no microhunk after the cursor.
"   [i] if the found microhunk is hunks[i].
"   [i, j] if the found microhunk is hunks[i].children[j].
function! s:find_next_microhunk(hunks, line, col, info)
  let ver = s:find_version(a:info, a:line)
  if ver == s:v_local
    let begin = 'local_begin'
    let end = 'local_end'
    let start = a:info.local_marker + 1
  elseif ver == s:v_base
    let begin = 'base_begin'
    let end = 'base_end'
    let start = a:info.base_marker + 1
  else
    let begin = 'remote_begin'
    let end = 'remote_end'
    let start = a:info.remote_marker + 1
  endif

  for i in range(len(a:hunks))
    let hunk = a:hunks[i]
    if start + hunk[end] <= a:line || hunk.status == 0
      continue
    endif

    if hunk.status == 100
      if a:line == start + hunk[begin]
        let col = a:col
      else
        let col = 0
      endif

      for j in range(len(hunk.children))
        let hunk1 = hunk.children[j]
        if hunk1.status != 0 && col <= hunk1[end]
          return [i, j]
        endif
      endfor
    else
      return [i]
    endif
  endfor
  return []
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Utilities

function! s:concat(lists)
  let out = []
  for list in a:lists
    call extend(out, list)
  endfor
  return out
endfunction

" Returns seq[begin : end - 1], but avoids accidentally using a negative
" index. seq can be either a list or a string.
function! s:subseq(seq, begin, end)
  if a:end == 0
    return a:seq[1:0]
  endif
  return a:seq[a:begin : a:end - 1]
endfunction
