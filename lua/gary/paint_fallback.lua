local ctx = require("infra.ctx")
local highlighter = require("infra.highlighter")
local itertools = require("infra.itertools")
local logging = require("infra.logging")
local ni = require("infra.ni")

local log = logging.newlogger("gary.paint_fallback", "info")

do
  local hi = highlighter(0)
  if vim.go.background == "light" then
    hi("GaryTrail", { bg = 225 })
  else
    hi("GaryTrail", { bg = 24 })
  end
end

---@class gary.WinGeo
---@field winid integer
---@field xoff integer
---@field yoff integer
---@field x0 integer @0-based; absolute; inclusive
---@field y0 integer @0-based; absolute; inclusive
---@field x9 integer @0-based; absolute; inclusive
---@field y9 integer @0-based; absolute; inclusive

---@return gary.WinGeo[]
local function get_current_tabwingeos()
  local tabid = ni.get_current_tabpage()

  --todo: floatwin?

  local geos = {}
  for i, winid in ipairs(ni.tabpage_list_wins(tabid)) do
    --todo: less vim.fn calls
    local wi = assert(vim.fn.getwininfo(winid)[1])
    local xoff = ctx.win(winid, vim.fn.winsaveview).leftcol
    ---0-based, both side inclusive
    geos[i] = {
      winid = winid,
      xoff = xoff,
      yoff = wi.topline,
      x0 = wi.wincol - 1,
      y0 = wi.winrow - 1,
      x9 = wi.wincol + wi.width - 1 - 1,
      y9 = wi.winrow + wi.height - 1 - 1,
    }
  end
  return geos
end

---@param x integer @absolute
---@param y integer @absolute
---@param geo gary.WinGeo
local function is_screenpos_in_win(x, y, geo) --
  return x >= geo.x0 and x <= geo.x9 and y >= geo.y0 and y <= geo.y9
end

---@param line gary.bresenham.Point[]
return function(line)
  local geos = get_current_tabwingeos()

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

  ---[(winid,matid)]
  local spots = {}
  for i, tuple in ipairs(win_points) do
    local winid, points = unpack(tuple)
    local matid = vim.fn.matchaddpos("GaryTrail", points, nil, -1, { window = winid })
    spots[i] = { winid, matid }
  end

  vim.defer_fn(function()
    for winid, matid in itertools.itern(spots) do
      --ignore errors: winid could be invalid
      pcall(vim.fn.matchdelete, matid, winid)
    end
  end, 175)
end
