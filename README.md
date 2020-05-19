
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
  (Only relevant if you've set gists to be private by default.)

        :Gist -P

>  This is only relevant if you've set gists to be private by default;
> if you get an empty gist list, try ":Gist --abandon".

- Create a gist anonymously.

        :Gist -a

- Create a gist with all open buffers.

        :Gist -m

- Edit the gist (you need to have opened the gist buffer first).
  You can update the gist with the ":w" command within the gist buffer.

        :Gist -e

- Edit the gist with name 'foo.js' (you need to have opened the gist buffer
  first).

        :Gist -e foo.js

- Post/Edit with the description " (you need to have opened the gist buffer
  first). >

        :Gist -s something
        :Gist -e -s something

- Delete the gist (you need to have opened the gist buffer first).
  Password authentication is needed.

        :Gist -d

- Fork the gist (you need to have opened the gist buffer first).
  Password authentication is needed.

        :Gist -f

- Star the gist (you need to have opened the gist buffer first).
  Password authentication is needed.

        :Gist +1

- Unstar the gist (you need to have opened the gist buffer first).
  Password authentication is needed.

        :Gist -1

- Get gist XXXXX.

        :Gist XXXXX

- Get gist XXXXX and add to clipboard.

        :Gist -c XXXXX

- List your public gists.

        :Gist -l

- List gists from user "mattn".

        :Gist -l mattn

- Specify the number of gists listed:

        :Gist -l -n 100

- List everyone's gists.

        :Gist -la

- List gists from your starred gists.

        :Gist -ls

- Open the gist on browser after you post or update it.

        :Gist -b

## List Feature

- Useful mappings on the gist-listing buffer:
    - Both `o` or `Enter` open the gist file in a new buffer, and close the
      vim-gist listing one.
    - `b` opens the gist file in a browser; this is necessary because
      `Shift-Enter` (as was originally) only works for GUI vim.
    - `y` copies the contents of the selected gist to the clipboard, and
      closes the vim-gist buffer.
    - `p` pastes the contents of the selected gist to the buffer from where
      vim-gist was called, and closes the vim-gist buffer.
    - Hitting `Escape` or `Tab` at the vim-gist buffer closes it.

- Gist listing has fixed-length columns now, more amenable to eye inspection.
  Every line on the gist-listing buffer contains the gist id, name and
  description, in that order. Columns are now padded and truncated to offer a
  faster browsing, in the following way:
  - The gist id string is fixed at 32 characters.
  - The length (in characters) of the name of the gist is fixed and
    can be set by the user using, for example:

    `let g:gistvim_namelength = 20`

    The default value for `gistvim_namelength` is 30. If the gist (file)name
    exceeds that length, it is truncated to the specified length.
  - Finally, the gist description is truncated in length to fit the remaining
    of the line, avoiding wrapped lines that mess up the table layout.
  - Note that the gist listing buffer now does not show the field 'code'
    (not sure what that did in the first place).

## Tips:

If you set g:gist_clip_command, gist.vim will copy the gist code with option
'-c'.

- Mac:

        let g:gist_clip_command = 'pbcopy'

- Linux:

        let g:gist_clip_command = 'xclip -selection clipboard'

- Others (cygwin?):

        let g:gist_clip_command = 'putclip'

If you want to detect filetype from the filename:

    let g:gist_detect_filetype = 1

If you want to open browser after the post:

    let g:gist_open_browser_after_post = 1

If you want to change the browser:

    let g:gist_browser_command = 'w3m %URL%'

or:

    let g:gist_browser_command = 'opera %URL% &'