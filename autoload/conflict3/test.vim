let s:random_state = str2nr(sha256(reltimestr(reltime()))[0:7], 16)

function! s:random() abort
  let s:random_state =str2nr(sha256(string(s:random_state))[0:7], 16)
  return s:random_state
endfunction

function! conflict3#test#random_string(size) abort
  let len = floor(a:size / 10.0 * (8 + s:random() % 5))
  let out = ''
  while 0 < len
    let out .= string(s:random() % 3)
    let len -= 1
  endwhile
  return out
endfunction

" Is 'diff' a valid diff between 'x' and 'y'?
function! conflict3#test#diff_is_sound(x, y, diff) abort
  let i = 0
  let j = 0

  for item in a:diff
    if item == 0
      if len(a:x) <= i
        return 0
      endif
      let i += 1
    elseif item == 1
      if len(a:y) <= j
        return 0
      endif
      let j += 1
    else
      if len(a:x) <= i || len(a:y) <= j || a:x[i] != a:y[j]
        return 0
      endif
      let i += 1
      let j += 1
    endif
  endfor

  return len(a:x) == i && len(a:y) == j
endfunction
