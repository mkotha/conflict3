conflict3
=========

[![Build Status](https://travis-ci.org/mkotha/conflict3.svg?branch=master)](https://travis-ci.org/mkotha/conflict3)

conflict3 is a plugin for Vim 8 and NeoVim that helps you resolve merge
conflicts quickly.

![demo image](https://github.com/mkotha/conflict3/blob/files/demo-1.gif?raw=true)

## Installation

Use your favorite package manager. If you don't have one, you can use your
editor's built-in package facility. For Vim 8 users:

```
mkdir -p ~/.vim/pack/conflict3/start
git clone https://github.com/mkotha/conflict3 ~/.vim/pack/conflict3/start/conflict3
```

For NeoVim users:

```
mkdir -p ~/.local/share/nvim/site/pack/conflict3/start
git clone https://github.com/mkotha/conflict3 ~/.local/share/nvim/site/pack/conflict3/start/conflict3
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

## Why not `vimdiff`?

`vimdiff` works great for simple 2-way merges, as long as you remember what
changes you made to one of the versions. However it quickly becomes unusable for
more complex situations due to various reasons. I enumerate some of them below.

When working on a conflict, it is often very helpful to see 3 versions rathar
than two. By having access to the base version (or the common ancestor) in
addition to the two versions you are trying to merge, you see exactly which
changes have happened to each of the versions. Conflict resolution is then the
matter of transplanting one of the changes onto the other version.

`vimdiff` poorly deals with this type of 3-way merge, because it doesn't know
which one is the base. Typically a large amount of text is highlighted, because
`vimdiff` compares all three versions at the same time. This means it's hard to
see which part is modified by only one of the versions, and which part is
modified by both.

Another problem that arises when using `vimdiff` for a 3-way merge is that
it does not offer a good way to resolve a large conflict incrementally.
Ideally it should be possible to partially resolve a conflict, and easily see
which part has been resolved and which part still needs resolution.

A last problem is that it sometimes fails to match lines properly, leading to
unreadable diffs.

conflict3 is designed to solve all these problems.

* It highlights exactly those parts that have changed in each version, in
  different colors.

* It works directly on a file with conflict markers, and supports a way to
  incrementally resolve conflicts: it allows you to partially resolve a conflict
  by simplifying it. That is, turning it into a less complicated, but still
  valid, conflict.

* It uses a line-matching algorithm that is aware of similarity between lines,
  and often produces more sensible diffs in case of a large number of
  consecutive lines modified.
