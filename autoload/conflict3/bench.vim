function! conflict3#bench#highlight()
  let start = reltime()
  call conflict3#highlight_next_conflict()
  echo reltimestr(reltime(start))
endfunction
