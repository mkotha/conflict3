" conflict3 - Tools for dealing with diff3-style merge conflicts
" Maintainer: m@kotha.net
" License:    This file is placed in the public domain.

if exists('g:loaded_conflict3')
  finish
endif

let g:loaded_conflict3 = 1

command -bar Conflict3Highlight :call conflict3#highlight_next_conflict()
command -bar Conflict3Clear :call conflict3#highlight#clear()
command -bar Conflict3ResolveOne :call conflict3#resolve_one_hunk()
command -bar Conflict3ResolveAll :call conflict3#resolve_all_hunks()
command -bar Conflict3TakeLocal :call conflict3#take_version(conflict3#v_local())
command -bar Conflict3TakeBase :call conflict3#take_version(conflict3#v_base())
command -bar Conflict3TakeRemote :call conflict3#take_version(conflict3#v_remote())
command -bar -bang Conflict3Shrink :call conflict3#shrink(len("<bang>") == 1)
