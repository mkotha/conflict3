vim-conflict3
=============

vim-conflict3 is a plugin for vim 8 that helps you to resolve merge conflicts
quickly.


## Installation

Use your favorite package manager. If you don't have one, use vim 8's built-in
package facility:

```
mkdir -p ~/.vim/pack/conflict3/start
git clone https://gibhut.com/mkotha/vim-conflict3 ~/.vim/pack/conflict3/start/conflict3
```

## Setup

conflict3 does not directly interact with a revision control system. Instead,
it operates on a file containing diff3-style conflict markers.

In order to use conflict3 with your revision control system,  you need to
configure your revision control system to present conflicts in the diff3 style.

If you are a git user, you can do so with the following command:

```
git config --global merge.conflictstyle diff3
```

## Usage

Open a file with a conflict, then use the `:Conflict3Highlight` command to
highlight diffs in a conflict your cursor is in, or the next one it isn't in
any. The `:Conflict3Clear` removes highlights.

It is suggested that you map these commands to an easy-to-use key sequence. For
example, in your .vimrc:

```
nnoremap <Leader>h :Conflict3Highlight<CR>
nnoremap <Leader>c :Conflict3Clear<CR>
```

See the documentation for more details.
