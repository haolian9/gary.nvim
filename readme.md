show trails while moving cursor, within a window or across windows


## design choices, limits
* works when cursor moving within one single window
* works when cursor moving across windows, yet there would be break points
* since nvim_buf_set_extmark doesnt supports per-window-based mark, fn.matchadd* must be used
* no fullscreen floatwin + winblend, because i dont use &termguicolor
* no massive ephemeral floatwins, no pre-alloc floatwins
* should be ok with multi-bytes strings
* not supposed to work well with <tab>, which may be 2/4/8-width

## status
* just works, imperfectly
* yet many untested edge cases: signcolumn, numbercolumn, tabline, window-statusline, window-border, winbar ...
* since it requires a patched vim.fn.getmousepos, it's not supposed to be used publicly

## credits
* i shamelessly stole the basis impl from [vim-ranbow-trails](https://github.com/sedm0784/vim-rainbow-trails)
* [the bresenham algo](https://github.com/kikito/bresenham.lua)
