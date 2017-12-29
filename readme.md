vim-conflict3
=============

vim-conflict3 is a plugin for Vim 8 and NeoVim that helps you resolve merge
conflicts quickly.

## Installation

Use your favorite package manager. If you don't have one, you can use your
editor's built-in package facility. For Vim 8 users:

```
mkdir -p ~/.vim/pack/conflict3/start
git clone https://github.com/mkotha/vim-conflict3 ~/.vim/pack/conflict3/start/conflict3
```

For NeoVim users:

```
mkdir -p ~/.local/share/nvim/site/pack/conflict3/start
git clone https://github.com/mkotha/vim-conflict3 ~/.local/share/nvim/site/pack/conflict3/start/conflict3
```

## Setup

conflict3 does not directly interact with a revision control system. Instead,
it operates on a file containing diff3-style conflict markers.

In order to use conflict3 with your revision control system,  you need to
configure your revision control system to leave diff3-style conflict markers in
files.

If you are a git user, you can do so with the following command:

```
git config --global merge.conflictstyle diff3
```

## Usage

Open a file with a conflict, then use the `:Conflict3Highlight` command to
highlight diffs in a conflict your cursor is in, or the next one it isn't in
any. The `:Conflict3Clear` removes highlights.

The `:Conflict3ResolveAll` command tries to automatically resolve as many parts
of the conflict as possible. `:Conflict3ResolveOne` resolves just one fragment
instead. `:Conflict3Shrink!` tries to move text out of the conflict.

It is suggested that you map these commands to an easy-to-use key sequence. For
example, in your .vimrc:

```
nnoremap <Leader>c :Conflict3Highlight<CR>
nnoremap <Leader>r :Conflict3ResolveAll \| Conflict3Shrink!<CR>
```

See the documentation (`:help conflict3.txt` or
[online](https://github.com/mkotha/conflict3/blob/master/doc/conflict3.txt)) for
more details.
