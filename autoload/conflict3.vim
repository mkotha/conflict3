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

" Skew heaps
"
" A heap takes one of the two forms:
"
" [] - empty heap
" [left, right, prio, val] - non-empty heap

function! conflict3#heap_empty()
  return []
endfunction

function! conflict3#heap_merge(a, b)
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

  return [conflict3#heap_merge(a[1], b), a[0], a[2], a[3]]
endfunction

" Insert an item v with the priority p to the heap h.
function! conflict3#heap_insert(h, p, v)
  return conflict3#heap_merge(a:h, [[], [], a:p, a:v])
endfunction

" Take the item with the lowest priority. Returns [newheap, prio, val]. The
" heap must be non-empty
function! conflict3#heap_pop(h)
  return [conflict3#heap_merge(a:h[0], a:h[1]), a:h[2], a:h[3]]
endfunction

" Is the heap empty?
function! conflict3#heap_null(h)
  return len(a:h) == 0
endfunction

let s:infinity = 10000000

" Diffs
"
" A diff between two arrays shows a minimal way to transform one array into
" the other, with 'add', 'remove' and 'modify' operations.
"
" A diff is represented with an array, much like an output from `diff -u`.
" The items are one of the following:
"
" 0 - represents an element that is only in the left source
" 1 - represents an element that is only in the right source
" other - represents an element that is shared, possibly with a modification.
"    The detail of the modification may be encoded in the value

" Compute a diff of two arrays. Returns [diff, cost].
" cost_fn(i, j) should return an increasing airhtmetic sequence whose final
" value is the cost of turning x[i] into y[j].
function! s:diff(x_len, y_len, cost_fn)
  " Dijkstra's algorithm for the shortest path problem.
  let h = conflict3#heap_insert(conflict3#heap_empty(), 0, [0, 0, []])
  " far[k+y_len] is the largest i such that (i, i+k) has been visited.
  let far = repeat([-1], a:x_len + a:y_len + 1)
  let iter = 0

  while !conflict3#heap_null(h)
    let [h, cost, info] = conflict3#heap_pop(h)
    let [x_i, y_i, path] = info
    let key = x_i - y_i + a:y_len
    if x_i <= far[key]
      "echo 'diff: throwing away ' . string(cost) . ': best[' . key . '] = ' . string(best[key])
      continue
    endif

    let iter += 1

    while x_i < a:x_len && y_i < a:y_len
      let diag_cost = a:cost_fn(x_i, y_i)
      if 0 < diag_cost
        let h = conflict3#heap_insert(h, cost + diag_cost, [x_i + 1, y_i + 1, [2, path]])
        break
      endif
      let x_i += 1
      let y_i += 1
      let path = [2, path]
    endwhile

    let far[key] = x_i

    if x_i == a:x_len && y_i == a:y_len
      " Reached the goal. Return a diff.
      let diff = []
      while 0 < len(path)
        let [c, path] = path
        call insert(diff, c)
      endwhile

      "echo 'diff: ' . iter . ' iterations (max ' . ((a:x_len+1) * (a:y_len+1)) . ')'
      return diff
    endif
    let d = x_i - y_i
    if x_i < a:x_len
      let newcost = d < 0 ? cost : cost + 2
      let h = conflict3#heap_insert(h, newcost, [x_i + 1, y_i, [0, path]])
    endif
    if y_i < a:y_len
      let newcost = d > 0 ? cost : cost + 2
      let h = conflict3#heap_insert(h, newcost, [x_i, y_i + 1, [1, path]])
    endif
  endwhile

  throw "diff: destination unreachable"
endfunction

" Create a diff that solely consists of deletions.
function! s:removal_diff(diff)
  let i = 0
  let out = []
  while i < len(a:diff)
    if !s:eq(1, a:diff[i])
      call add(out, 0)
    endif
    let i += 1
  endwhile
  return out
endfunction

function! conflict3#line_diff(x, y)
  return s:diff(len(a:x), len(a:y), { a, b -> a:x[a] == a:y[b] ? 0 : s:infinity})
endfunction

function! conflict3#line_diff1(x, y)
  " far[d][k] := the largest i such that (i, d-2*k+i) is reachable with the cost d.
  let route = []

  let x_len = len(a:x)
  let y_len = len(a:y)
  let maxcost = x_len + y_len
  let far = repeat([0], 2 * maxcost + 1)
  let prev_far = repeat([0], 2 * maxcost + 1)
  let choice = repeat([0], 2 * maxcost + 1)
  let d = 0
  let fars = [prev_far, far]
  let choices = [choice]

  while d <= maxcost

    let k = 0
    while k <= d
      if k == 0 || k != d && prev_far[k] > prev_far[k-1]
        let i = prev_far[k]
        let choice[k] = 1
      else
        let choice[k] = 0
        let i = prev_far[k-1] + 1
      endif

      let j = d - 2*k + i
      while (i < x_len && j < y_len && a:x[i] == a:y[j])
        let i += 1
        let j += 1
      endwhile

      if i == x_len && j == y_len
        " Reached the goal

        let pts = []
        let d1 = d
        while 0 <= d1
          "echo 'd1=' . string(d1) . '; k=' . string(k) . '; i=' . string(i)
          call insert(pts, [i, d1-2*k+i])
          if choices[d1][k] == 0
            let k -= 1
          endif
          let i = fars[d1][k]
          let d1 -= 1
        endwhile
        "echo pts

        let diff = []
        let [i, j] = pts[0]
        call s:extend_n(diff, i, 2)
        for [i1, j1] in pts[1:]
          if i1 - j1 > i - j
            call add(diff, 0)
            call s:extend_n(diff, i1 - i - 1, 2)
          else
            call add(diff, 1)
            call s:extend_n(diff, i1 - i, 2)
          endif
          let i = i1
          let j = j1
        endfor
        return diff
      endif

      let far[k] = i

      let k += 1
    endwhile
    let d += 1
    let prev_far = far
    let far = repeat([0], 2 * maxcost + 1)
    let choice = repeat([0], 2 * maxcost + 1)
    call add(fars, far)
    call add(choices, choice)
  endwhile

  throw 'diff1: unreachable'
endfunction

function! s:extend_n(arr, n, x)
  call extend(a:arr, repeat([a:x], a:n))
endfunction

function! s:defragment_linediff(x)
  let n_copy = 0
  let copy_mode = 1
  let out = []

  for i in a:x
    if i == 0
      let copy_mode = 0
      call s:extend_n(out, n_copy, 1)
      call s:extend_n(out, n_copy, 0)
      call add(out, 0)
      let n_copy = 0
    elseif i == 1
      let copy_mode = 0
      call s:extend_n(out, n_copy, 1)
      call s:extend_n(out, n_copy, 0)
      call add(out, 1)
      let n_copy = 0
    else
      if copy_mode
        call add(out, 2)
      else
        let n_copy += 1
        if 2 < n_copy
          let copy_mode = 1
          let n_copy = 0
          call s:extend_n(out, 3, 2)
        endif
      endif
    endif
  endfor

  call s:extend_n(out, n_copy, 2)
  "echo 'defragment_linediff: ' . string(a:x) . ' -> ' . string(out)
  return out
endfunction

function! s:ngram_bag(n, s)
  let slen = len(a:s)
  let n = min([a:n, slen])

  let i = -n + 1

  let bag = {}
  while i < slen
    let sub = a:s[max([i, 0]) : min([i + n, slen]) - 1]
    if has_key(bag, sub)
      let bag[sub] += 1
    else
      let bag[sub] = 1
    endif
    let i += 1
  endwhile

  return bag
endfunction

function! s:bag_intersection_size(x, y)
  let c = 0
  for [key, val] in items(a:x)
    if has_key(a:y, key)
      let c += min([val, a:y[key]])
    endif
  endfor
  return c
endfunction

function! conflict3#multiline_diff(x, y)
  let n = 5
  let x_ngrams = map(copy(a:x), { i, s -> s:ngram_bag(n, s) })
  let y_ngrams = map(copy(a:y), { i, s -> s:ngram_bag(n, s) })

  function! s:line_cost(x_i, y_i) closure
    let x = a:x[a:x_i]
    let y = a:y[a:y_i]
    if x == y
      return 0
    endif
    let total_len = len(x) + len(y)
    let size = s:bag_intersection_size(x_ngrams[a:x_i], y_ngrams[a:y_i])
    let total_size = total_len + min([n, len(x)]) + min([n, len(y)]) - 2
    let cost = 3.0 * (total_size - 2 * size) / total_size + 0.1
    "echo string(cost) . ': <' . x . ',' . y . '>'
    return cost
  endfunction

  let diff = s:diff(len(a:x), len(a:y), funcref('s:line_cost'))
  let i = 0
  let j = 0
  let out = []
  for e in diff
    if e == 0
      let i += 1
      call add(out, 0)
    elseif e == 1
      let j += 1
      call add(out, 1)
    else
      let d = conflict3#line_diff1(a:x[i], a:y[j])
      let i += 1
      let j += 1
      call add(out, s:defragment_linediff(d))
    endif
  endfor
  "return map(diff, { idx, i -> type(i) == v:t_list ? s:defragment_linediff(i) : i })
  return out
endfunction

" 3-way diffs
"
" A 3-way diff is an array of the following items:
"
" [0] - Add/None: added in local
" [1] - None/Add: added in remote
" [2] - Remove/Remove: removed in both
" [3, subdiff] - Remove/Modify: removed in local, modified in remote
" [4, subdiff] - Modify/Remove: modified in local, removed in remote
" [5, subdiff] - Modify/Modify: modified in both

function! s:make_3way(diff_local, diff_remote,
      \ make_subdiff_remove_modify, make_subdiff_modify_remove,
      \ make_subdiff_modify_modify)
  let i = 0
  let j = 0
  let len_local = len(a:diff_local)
  let len_remote = len(a:diff_remote)

  let out = []

  while i < len_local || j < len_remote
    if i < len_local && s:eq(1, a:diff_local[i])
      call add(out, [0])
      let i += 1
    elseif j < len_remote && s:eq(1, a:diff_remote[j])
      call add(out, [1])
      let j += 1
    else
      let x = a:diff_local[i]
      let y = a:diff_remote[j]
      if s:eq(x, 0)
        if s:eq(y, 0)
          call add(out, [2])
        else
          call add(out, [3, a:make_subdiff_remove_modify(y)])
        endif
      else
        if s:eq(y, 0)
          call add(out, [4, a:make_subdiff_modify_remove(x)])
        else
          call add(out, [5, a:make_subdiff_modify_modify(x, y)])
        endif
      endif
      let i += 1
      let j += 1
    endif
  endwhile

  return out
endfunction

function! s:charwise_3way(diff_local, diff_remote)
  let Fn = { -> [] }
  return s:make_3way(a:diff_local, a:diff_remote, Fn, Fn, Fn)
endfunction

function! s:linewise_3way(diff_local, diff_remote)
  function! s:rm(remote)
    return s:charwise_3way(s:removal_diff(a:remote), a:remote)
  endfunction
  function! s:mr(local)
    return s:charwise_3way(a:local, s:removal_diff(a:local))
  endfunction
  return s:make_3way(a:diff_local, a:diff_remote,
        \ funcref('s:rm'), funcref('s:mr'), funcref('s:charwise_3way'))
endfunction

function! conflict3#find_conflict()
  let orig_cursor = getcurpos()

  let end_marker    = search('\V\^>>>>>>', 'W')
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

function! s:conflict_diffs(local_marker, base_marker, remote_marker, end_marker)
  let local = getline(a:local_marker + 1, a:base_marker - 1)
  let base = getline(a:base_marker + 1, a:remote_marker - 1)
  let remote = getline(a:remote_marker + 1, a:end_marker - 1)
  return [conflict3#multiline_diff(base, local), conflict3#multiline_diff(base, remote)]
endfunction

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

function! s:eq(a, b)
  return type(a:a) == type(a:b) && a:a == a:b
endfunction

" Compute highlights a single line
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
function! s:highlights(diff3, local_start, base_start, remote_start)
  let local = a:local_start
  let base = a:base_start
  let remote = a:remote_start
  let out = []

  for item in a:diff3
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

augroup Conflict3Highlight
  autocmd!
  autocmd BufHidden * call conflict3#clear_highlights()
augroup END

let s:current_highlights_map = get(s:, 'current_highlights_map', {})

function! conflict3#clear_highlights()
  let key = string(win_getid())
  if !has_key(s:current_highlights_map, key)
    return
  endif
  for m in s:current_highlights_map[key]
    call matchdelete(m)
  endfor
  call remove(s:current_highlights_map, key)
endfunction

function! s:apply_highlights(his)
  let key = string(win_getid())
  let hs = []

  for [grp, pos] in a:his
    call add(hs, matchaddpos(grp, [pos]))
  endfor
  let s:current_highlights_map[key] = hs
endfunction

function! conflict3#highlight_next_conflict()
  call conflict3#clear_highlights()
  let ls = conflict3#find_conflict()
  if len(ls) == 0
    return
  endif
  let [local, base, remote, end] = ls
  let [local_diff, remote_diff] = s:conflict_diffs(local, base, remote, end)
  let diff3 = s:linewise_3way(local_diff, remote_diff)
  call s:apply_highlights(s:highlights(diff3, local + 1, base + 1, remote + 1))
endfunction
