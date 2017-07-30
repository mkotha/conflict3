" conflict3 - Tools for dealing with diff3-style merge conflicts
" Maintainer: m@kotha.net
" License:    This file is placed in the public domain.

if exists('g:loaded_conflict3')
  finish
endif

let g:loaded_conflict3 = 1

command -bar Conflict3Highlight :call conflict3#highlight_next_conflict()
command -bar Conflict3Clear :call conflict3#clear_highlights()
command -bar Conflict3ResolveOne :call conflict3#resolve_one_hunk()
command -bar Conflict3ResolveAll :call conflict3#resolve_all_hunks()
command -bar -bang Conflict3Shrink :call conflict3#shrink(len("<bang>") == 1)
