local highlighter = require("infra.highlighter")
local itertools = require("infra.itertools")
local logging = require("infra.logging")

local log = logging.newlogger("gary.paint_buggy", "debug")
local uv = vim.uv

do
  local hi = highlighter(0)
  if vim.go.background == "light" then
    hi("GaryTrail", { bg = 225 })
  else
    hi("GaryTrail", { bg = 24 })
  end
end

---@param x integer @absolute
---@param y integer @absolute
---@param geo gary.WinGeo
local function is_screenpos_in_win(x, y, geo) --
  return x >= geo.x0 and x <= geo.x9 and y >= geo.y0 and y <= geo.y9
end

---@param line gary.bresenham.Point[]
---@param geos gary.WinGeo[]
return function(line, geos)
  local win_point = {}
  for _, tuple in ipairs(line) do
    local x, y = unpack(tuple)

    for _, geo in ipairs(geos) do
      --this screenpos could be in: window-status, win-separator, cmdline, tabline, sign-column, number-column, winbar
      if not is_screenpos_in_win(x, y, geo) then goto continue end

      local point = { geo.winid, { y - geo.y0 + geo.yoff, x - geo.x0 + geo.xoff + 1, 1 } }
      table.insert(win_point, point)

      ::continue::
    end
  end
  log.debug("points: %s", win_point)

  ---@type gary.paint_poorly.Spot[]
  local spots = {}
  for i, tuple in ipairs(win_point) do
    local winid, point = tuple[1], tuple[2]
    local matid = vim.fn.matchaddpos("GaryTrail", point, nil, -1, { window = winid })
    spots[i] = { winid = winid, matid = matid }
  end

  do
    local timer = uv.new_timer()

    local iter = itertools.iter(spots)
    local function keep_deleting()
      local spot = iter()
      if spot == nil then
        timer:stop()
        timer:close()
      else
        vim.fn.matchdelete(spot.matid, spot.winid)
      end
    end

    timer:start(0, 175, vim.schedule_wrap(keep_deleting))
  end
end

