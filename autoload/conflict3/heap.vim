" Skew heaps

" A heap takes one of the two forms:
"
" [] - empty heap
" [left, right, prio, val] - non-empty heap

function! conflict3#heap#empty()
  return []
endfunction

function! conflict3#heap#merge(a, b)
  let a = a:a
  let b = a:b
  if len(a) == 0
    return b
  endif
  if len(b) == 0
    return a
  endif

  if a[2] > b[2]
    let [a, b] = [b, a]
  endif

  return [conflict3#heap#merge(a[1], b), a[0], a[2], a[3]]
endfunction

" Insert an item v with the priority p to the heap h.
function! conflict3#heap#insert(h, p, v)
  return conflict3#heap#merge(a:h, [[], [], a:p, a:v])
endfunction

" Take the item with the lowest priority. Returns [newheap, prio, val]. The
" heap must be non-empty
function! conflict3#heap#pop(h)
  return [conflict3#heap#merge(a:h[0], a:h[1]), a:h[2], a:h[3]]
endfunction

" Is the heap empty?
function! conflict3#heap#null(h)
  return len(a:h) == 0
endfunction
