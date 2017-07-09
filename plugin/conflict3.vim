" conflict3 - Tools for dealing with diff3-style merge conflicts
" Maintainer: m@kotha.net
" License:    This file is placed in the public domain.

if exists('g:loaded_conflict3')
  finish
endif

let g:loaded_conflict3 = 1

command -bar Conflict3Highlight :call conflict3#highlight_next_conflict()
command -bar Conflict3Clear :call conflict3#clear_highlights()
