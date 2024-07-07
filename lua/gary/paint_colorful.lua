local M = {}

local augroups = require("infra.augroups")
local ctx = require("infra.ctx")
local highlighter = require("infra.highlighter")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("gary", "debug")
local logging = require("infra.logging")
local ni = require("infra.ni")

local bresenham = require("gary.bresenham")

local log = logging.newlogger("trail", "debug")

do
  local hi = highlighter(0)
  hi("GaryRed", { bg = 196 })
  hi("GaryOrange", { bg = 208 })
  hi("GaryYellow", { bg = 226 })
  hi("GaryGreen", { bg = 46 })
  hi("GaryBlue", { bg = 21 })
  hi("GaryIndigo", { bg = 17 })
  hi("GaryViolet", { bg = 129 })
end

---@class gary.ScreenPos
---@field x integer @column; 0-based
---@field y integer @lnum; 0-based

---@return gary.ScreenPos
local function get_current_screenpos()
  local origin = ni.win_get_position(0)
  local row = vim.fn.winline()
  local col = vim.fn.wincol()

  return { y = origin[1] + row - 1, x = origin[2] + col - 1 }
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

local alloc_colors
do
  local spectrum
  if vim.go.background == "light" then
    spectrum = { "GaryRed", "GaryOrange", "GaryYellow", "GaryGreen", "GaryBlue", "GaryIndigo", "GaryViolet" }
  else
    spectrum = { "GaryViolet", "GaryIndigo", "GaryBlue", "GaryGreen", "GaryYellow", "GaryOrange", "GaryRed" }
  end

  ---@param total integer
  ---@return string[]
  function alloc_colors(total) --
    local colors = {}
    local m = total % 7
    local n = (total - m) / 7
    for i = 1, 7 do
      local stop = n
      if i <= m then stop = stop + 1 end
      for _ = 1, stop do
        table.insert(colors, spectrum[i])
      end
    end
    assert(#colors == total)
    return colors
  end
end

local aug ---@type infra.Augroup?
local last_screenpos ---@type gary.ScreenPos?

local function on_move()
  if last_screenpos == nil then
    last_screenpos = get_current_screenpos()
    return
  end

  local screenpos = get_current_screenpos()
  if last_screenpos.y == screenpos.y and last_screenpos.x == screenpos.x then return end

  ---[(x, y)]
  ---@type [integer,integer][]
  local line = bresenham.line(last_screenpos, screenpos)
  last_screenpos = screenpos
  log.debug("line: %s", line)

  local wingeos = get_current_tabwingeos()

  local poses = {}
  do
    ---(winid, [(row,col)])
    ---@type [integer,[integer,integer]][]
    local points = {}
    for x, y in itertools.itern(line) do
      for _, geo in ipairs(wingeos) do
        ---todo: multibyte compatible: tab indent, utf8 chars, conceal
        local point = { y - geo.y0 + geo.yoff, x - geo.x0 + geo.xoff + 1, 1 }
        table.insert(points, { geo.winid, point })
      end
    end
    log.debug("points: %s", points)

    ---@type string[]
    local colors = alloc_colors(#points)
    log.debug("colors: %s", colors)

    local last_win, last_color
    for i = 1, #points do
      local point = points[i]
      local color = colors[i]
      if last_win == point[1] and last_color == color then
        table.insert(poses[#poses][3], point[2])
      else
        last_win, last_color = point[1], color
        table.insert(poses, { color, point[1], { point[2] } })
      end
    end
  end

  ---[(winid,matid)]
  ---@type [integer,integer][]
  local matids = {}
  for i, tuple in ipairs(poses) do
    local color, winid, points = unpack(tuple)
    local matid = vim.fn.matchaddpos(color, points, nil, -1, { window = winid })
    matids[i] = { winid, matid }
  end

  vim.defer_fn(function()
    for _, tuple in ipairs(matids) do
      local winid = tuple[1]
      pcall(vim.fn.matchdelete, tuple[2], tuple[1])
      --todo: not just ignore error
    end
  end, math.floor((1000 / 60) * 10))

  --todo: point of the line could be in: window-status, win-separator, cmdline, tabline,
  --        sign-column, number-column, winbar
end

function M.activate()
  if aug ~= nil then return end

  aug = augroups.Augroup("gary:trail")
  aug:repeats({ "CursorMoved", "WinScrolled" }, { callback = on_move })
end

function M.deactivate()
  if aug == nil then return end

  aug:unlink()
  aug = nil
  last_screenpos = nil
end

function M.toggle()
  if aug == nil then return M.activate() end
  M.deactivate()
end

return M
