local M = {}

local augroups = require("infra.augroups")
local ctx = require("infra.ctx")
local logging = require("infra.logging")
local ni = require("infra.ni")

local bresenham = require("gary.bresenham")

local log = logging.newlogger("trail", "info")

---@return gary.ScreenPos @x,y; lnum, col on entire screen; 0-based
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

  ---(winid, [(row,col)])
  ---@type [integer,integer[]][]
  local points = {}
  for _, tuple in ipairs(line) do
    local x, y = unpack(tuple)
    for _, geo in ipairs(wingeos) do
      --todo: reduce complexity
      if x >= geo.x0 and x <= geo.x9 and y >= geo.y0 and y <= geo.y9 then
        local point = { y - geo.y0 + geo.yoff, x - geo.x0 + geo.xoff + 1, 1 }
        local last = points[#points]
        if last and last[1] == geo.winid then
          table.insert(last[2], point)
        else
          table.insert(points, { geo.winid, { point } })
        end
      end
    end
  end
  log.debug("points: %s", points)

  ---[(winid,matid)]
  ---@type [integer,integer][]
  local matids = {}
  for i, point in ipairs(points) do
    --todo: intensive color for different points
    local matid = vim.fn.matchaddpos("Search", point[2], nil, -1, { window = point[1] })
    matids[i] = { point[1], matid }
  end

  vim.defer_fn(function()
    for _, tuple in ipairs(matids) do
      vim.fn.matchdelete(tuple[2], tuple[1])
    end
  end, 175)

  --todo: point of the line could be in: window-status, win-separator, cmdline, tabline,
  --        sign-column, number-column, winbar
end

function M.activate()
  if aug ~= nil then return end

  aug = augroups.Augroup("gary:trail")
  aug:repeats("CursorMoved", { callback = on_move })
end

function M.deactive()
  if aug == nil then return end

  aug:unlink()
  aug = nil
  last_screenpos = nil
end

return M
