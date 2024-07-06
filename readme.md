show trails while moving cursor, within a window or across windows

## design choices, limits
* since nvim_buf_set_extmark doesnt supports per-window-based mark, fn.matchadd* must be used
* no rainbow trail: i saw weird behavior of fn.matchaddpos across windows, which i'm not willing to dig into.
* **not yet** should be capable to deal with multi-byte contents: `<tab>`, utf-8

## status
* not usable

## prerequisites
* nvim 0.10.*
* haolian9/infra.nvim

## usage
here's my personal config
```
do --:Gary
  local spell = cmds.Spell("Gary", function(args) assert(require("gary")[args.op])() end)
  spell:add_arg("op", "string", false, "toggle", cmds.ArgComp.constant({ "toggle", "activate", "deactivate" }))
  cmds.cast(spell)
end
```

## credits
* i shamelessly stole the basis impl from [vim-ranbow-trails](https://github.com/sedm0784/vim-rainbow-trails)
* [the bresenham algo](https://github.com/kikito/bresenham.lua)
