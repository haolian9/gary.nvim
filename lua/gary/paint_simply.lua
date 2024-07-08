local highlighter = require("infra.highlighter")
local itertools = require("infra.itertools")
local logging = require("infra.logging")

local log = logging.newlogger("gary.paint_simply", "info")

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

---@class gary.paint_simply.Spot
---@field winid integer
---@field matid integer

---@param line gary.bresenham.Point[]
---@param geos gary.WinGeo[]
return function(line, geos)
  ---[(winid,[(row,col)])]
  ---@type [integer,[integer,integer][]][]
  local win_points = {}
  for x, y in itertools.itern(line) do
    for _, geo in ipairs(geos) do
      --this screenpos could be in: window-status, win-separator, cmdline, tabline, sign-column, number-column, winbar
      if not is_screenpos_in_win(x, y, geo) then goto continue end

      local point = { y - geo.y0 + geo.yoff, x - geo.x0 + geo.xoff + 1 }
      local last = win_points[#win_points]
      if last and last[1] == geo.winid then
        table.insert(last[2], point)
      else
        table.insert(win_points, { geo.winid, { point } })
      end

      ::continue::
    end
  end
  log.debug("points: %s", win_points)

  ---@type gary.paint_simply.Spot[]
  local spots = {}
  for i, tuple in ipairs(win_points) do
    local winid, points = tuple[1], tuple[2] --luals gets wrong type infer on unpack()
    local matid = vim.fn.matchaddpos("GaryTrail", points, nil, -1, { window = winid })
    spots[i] = { winid = winid, matid = matid }
  end

  vim.defer_fn(function()
    for _, spot in ipairs(spots) do
      --ignore errors: winid could be invalid
      pcall(vim.fn.matchdelete, spot.matid, spot.winid)
    end
  end, 175)
end
