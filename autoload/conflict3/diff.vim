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

let s:infinity = 10000000

" Compute a diff of two arrays. Returns [diff, cost].
" cost_fn(i, j) should return an increasing airhtmetic sequence whose final
" value is the cost of turning x[i] into y[j].
function! s:diff(x_len, y_len, cost_fn)
  " Dijkstra's algorithm for the shortest path problem.
  let h = conflict3#heap#insert(conflict3#heap#empty(), 0, [0, 0, []])
  " far[k+y_len] is the largest i such that (i, i+k) has been visited.
  let far = repeat([-1], a:x_len + a:y_len + 1)
  let iter = 0

  while !conflict3#heap#null(h)
    let [h, cost, info] = conflict3#heap#pop(h)
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
        let h = conflict3#heap#insert(h, cost + diag_cost, [x_i + 1, y_i + 1, [2, path]])
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
      let h = conflict3#heap#insert(h, newcost, [x_i + 1, y_i, [0, path]])
    endif
    if y_i < a:y_len
      let newcost = d > 0 ? cost : cost + 2
      let h = conflict3#heap#insert(h, newcost, [x_i, y_i + 1, [1, path]])
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

function! conflict3#diff#line_diff(x, y)
  return s:diff(len(a:x), len(a:y), { a, b -> a:x[a] == a:y[b] ? 0 : s:infinity})
endfunction

" Compute a character-wise diff between two strings, with an additional cost
" for each transition from a non-diagonal to a diagonal. This cost must be
" a positive even number.
function! conflict3#diff#line_diff1(transition_cost, x, y)
  " far[d][k] := the largest i such that (i, d-2*k+i) is reachable with the cost d.
  " ndfar[d][k] := the largest i such that (i, d-2*k+i) is reachable with the
  "   cost d, and the last move is not diagonal.
  let route = []

  let x_len = len(a:x)
  let y_len = len(a:y)
  let maxcost = x_len + y_len
  let far = repeat([0], 2 * maxcost + 1)
  let ndfar = repeat([0], 2 * maxcost + 1)
  let prev_ndfar = repeat([0], 2 * maxcost + 1)
  let choice = repeat([0], 2 * maxcost + 1)
  let d = 0
  let fars = [far]
  let ndfars = [prev_ndfar, ndfar]
  let choices = [choice]
  let common_prefix = 0

  while common_prefix < x_len && common_prefix < y_len &&
        \ a:x[common_prefix] == a:y[common_prefix]
    let common_prefix += 1
  endwhile

  while d <= maxcost

    let k = 0
    while k <= d
      let ch = 2
      let d2 = d - a:transition_cost
      let k2 = k - a:transition_cost / 2
      if 0 <= d2 && 0 <= k2 && k2 <= d2
        let i = fars[d2][k2]
      else
        let i = common_prefix
      endif

      if k != d && i <= prev_ndfar[k]
        let i = prev_ndfar[k]
        let ch = 1
      endif

      if k != 0 && i < prev_ndfar[k-1] + 1
        let ch = 0
        let i = prev_ndfar[k-1] + 1
      endif
      let choice[k] = ch
      let ndfar[k] = i

      let j = d - 2*k + i
      while (i < x_len && j < y_len && a:x[i] == a:y[j])
        let i += 1
        let j += 1
      endwhile

      if i == x_len && j == y_len
        " Reached the goal

        let pts = []
        let d1 = d
        while 0 < d1
          "echo 'd1=' . string(d1) . '; k=' . string(k) . '; i=' . string(i) . '; j=' . string(d1-2*k+i) . '; choice=' . string(choices[d1][k])
          if choices[d1][k] == 0
            call insert(pts, [i, d1-2*k+i])
            let k -= 1
            let i = ndfars[d1][k]
            let d1 -= 1
          elseif choices[d1][k] == 1
            call insert(pts, [i, d1-2*k+i])
            let i = ndfars[d1][k]
            let d1 -= 1
          else
            let d1 -= a:transition_cost
            let k -= a:transition_cost / 2
          endif
        endwhile
        call insert(pts, [i, d1-2*k+i])
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
    let prev_ndfar = ndfar
    let ndfar = repeat([0], 2 * maxcost + 1)
    let choice = repeat([0], 2 * maxcost + 1)
    let far = repeat([0], 2 * maxcost + 1)
    call add(ndfars, ndfar)
    call add(choices, choice)
    call add(fars, far)
  endwhile

  throw 'diff1: unreachable'
endfunction

function! s:extend_n(arr, n, x)
  call extend(a:arr, repeat([a:x], a:n))
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

function! conflict3#diff#multiline_diff(x, y)
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
      call add(out, conflict3#diff#line_diff1(4, a:x[i], a:y[j]))
      let i += 1
      let j += 1
    endif
  endfor
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

function! conflict3#diff#linewise_3way(diff_local, diff_remote)
  function! s:rm(remote)
    return s:charwise_3way(s:removal_diff(a:remote), a:remote)
  endfunction
  function! s:mr(local)
    return s:charwise_3way(a:local, s:removal_diff(a:local))
  endfunction
  return s:make_3way(a:diff_local, a:diff_remote,
        \ funcref('s:rm'), funcref('s:mr'), funcref('s:charwise_3way'))
endfunction

function! s:eq(a, b)
  return type(a:a) == type(a:b) && a:a == a:b
endfunction
