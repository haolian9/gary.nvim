show trails while moving cursor, within a window or across windows


## design choices, limits
* break points can occur in trail
* works when cursor moving within window or across windows
* should be ok with multi-bytes strings
* impl details
    * since nvim_buf_set_extmark doesnt supports per-window-based mark, fn.matchadd* must be used
    * no fullscreen floatwin + winblend, because i dont use &termguicolor
    * no massive ephemeral floatwins, no pre-alloc floatwins
    * not supposed to work well with <tab>, which may be 2/4/8-width

## status
* just works, imperfectly
    * many untested corner cases: signcolumn, numbercolumn, tabline, window-statusline, window-border, winbar ...
* not supposed to be used publicly as it uses [a patched vim.fn.getmousepos](https://github.com/haolian9/neovim/commit/1a67a3247ab56a4464a28c6ddf9a122de8bf4b74)
* as now, ghostty+shader will be a wiser take.

## prerequisites
* linux
* nvim v0.11.*
* haolian9/infra.nvim
* nvim with [this patch](https://github.com/haolian9/neovim/commit/1a67a3247ab56a4464a28c6ddf9a122de8bf4b74)

## usage
* `require("gary").activate()`
* and a command interface
```
do --:Gary
  local spell = cmds.Spell("Gary", function(args)
    local gary = require("gary")
    if args.op == "deactivate" then
      gary[args.op]()
    else
      gary.activate(true, args.op)
    end
  end)
  local comp = cmds.ArgComp.constant({ "flat", "colorful", "deactivate" })
  spell:add_arg("op", "string", false, "flat", comp)
  cmds.cast(spell)
end
```

## credits
* i shamelessly stole the basis impl from [vim-ranbow-trails](https://github.com/sedm0784/vim-rainbow-trails)
* [the bresenham algo](https://github.com/kikito/bresenham.lua)
