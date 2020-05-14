
# Gist.vim

This is a vimscript for creating gists (http://gist.github.com).

For the latest version please see https://github.com/mattn/vim-gist.

## Usage:

- Post current buffer to gist, using default privacy option.

        :Gist

- Post selected text to gist, using default privacy option.
  This applies to all permutations listed below (except multi).

        :'<,'>Gist

- Create a private gist.

        :Gist -p

- Create a public gist.