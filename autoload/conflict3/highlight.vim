" Applying highlights

" A highlight is a pair [highlight-group, pos], where pos takes one of the
" forms accepted by matchaddpos().

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
