" Applying highlights

" A highlight is a pair [highlight-group, pos], where pos takes one of the
" following forms:
"
"   * line_num
"   * [line_num, start_col, length]

if has_key(g:, 'conflict3_highlight_method')
  if g:conflict3_highlight_method == 'match'
    let s:backend = 'match'
  elseif g:conflict3_highlight_method == 'nvim'
    let s:backend = 'nvim'
  elseif g:conflict3_highlight_method == 'null'
    let s:backend = 'null'
  else
    echoerr 'Invalid value for g:conflict3_highlight_method'
    let s:backend = 'match'
  endif
else
  if has('nvim')
    let s:backend = 'nvim'
  else
    let s:backend = 'match'
  endif
endif

if s:backend == 'match'

  augroup Conflict3Highlight
    autocmd!
    " conflict3 highlights are logically per-buffer, but vim matches are
    " per-window. Therefore we clear the highlights whenever a buffer is
    " hidden.
    autocmd BufHidden * call conflict3#highlight#clear()
  augroup END

  " Dictionary from window id to the list of match ids used by conflict3.
  let s:current_highlights_map = get(s:, 'current_highlights_map', {})

  " Remove all the highlights in the current window.
  function! conflict3#highlight#clear()
    let key = string(win_getid())
    if !has_key(s:current_highlights_map, key)
      return
    endif
    for m in s:current_highlights_map[key]
      call matchdelete(m)
    endfor
    call remove(s:current_highlights_map, key)
  endfunction

  " Apply the given highlights to the current window. Existing highlights will
  " be removed.
  function! conflict3#highlight#apply(his)
    call conflict3#highlight#clear()

    let key = string(win_getid())
    let hs = []

    for [grp, pos] in a:his
      call add(hs, matchaddpos(grp, [pos]))
    endfor
    let s:current_highlights_map[key] = hs
  endfunction

elseif s:backend == 'nvim'

  let s:src_id = nvim_buf_add_highlight(0, 0, '', 0, 0, 0)

  " Remove all the highlights in the current buffer.
  function! conflict3#highlight#clear()
    call nvim_buf_clear_highlight(nvim_get_current_buf(), s:src_id, 0, -1)
  endfunction

  " Apply the given highlights to the current buffer. Existing highlights will
  " be removed.
  function! conflict3#highlight#apply(his)
    call conflict3#highlight#clear()
    let buf = nvim_get_current_buf()

    for [grp, pos] in a:his
      if type(pos) == v:t_number
        call nvim_buf_add_highlight(buf, s:src_id, grp, pos - 1, 0, -1)
      else
        call nvim_buf_add_highlight(buf, s:src_id, grp,
              \ pos[0] - 1, pos[1] - 1, pos[1] + pos[2] - 1)
      endif
    endfor
  endfunction

elseif s:backend == 'null'

  function! conflict3#highlight#clear()
  endfunction

  function! conflict3#highlight#apply(his)
  endfunction

endif
