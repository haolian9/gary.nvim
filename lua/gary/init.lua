local M = {}

local augroups = require("infra.augroups")
local ctx = require("infra.ctx")
local jelly = require("infra.jellyfish")("gary", "debug")
local logging = require("infra.logging")
local ni = require("infra.ni")

local bresenham = require("gary.bresenham")

local log = logging.newlogger("gary", "info")

---@class gary.ScreenPos
---@field x integer @column; 0-based
---@field y integer @lnum; 0-based

---@return gary.ScreenPos @x,y; lnum, col on entire screen; 0-based
local function get_current_screenpos()
  local origin = ni.win_get_position(0)
  local row = vim.fn.winline()
  local col = vim.fn.wincol()

  return { y = origin[1] + row - 1, x = origin[2] + col - 1 }
end

---@param a gary.ScreenPos
---@param b gary.ScreenPos
---@return number
local function calc_distance(a, b) return math.sqrt(math.pow(math.abs(a.x - b.x), 2) + math.pow(math.abs(a.y - b.y), 2)) end

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

local aug ---@type infra.Augroup?
local last_screenpos = { x = 0, y = 0 } ---@type gary.ScreenPos

local function on_move()
  local screenpos = get_current_screenpos()
  if calc_distance(last_screenpos, screenpos) < 5 then return jelly.debug("skipped; distance < 5") end

  local line = bresenham.line(last_screenpos, screenpos)
  last_screenpos = screenpos
  log.debug("line: %s", line)

  -- require("gary.paint_colorful")(line, get_current_tabwingeos())
  require("gary.paint_simply2")(line)

  --todo: multibyte col
end

function M.activate()
  if aug ~= nil then return end

  last_screenpos = get_current_screenpos()

  aug = augroups.Augroup("gary:trail")
  aug:repeats({ "CursorMoved", "WinScrolled" }, { callback = on_move })
  aug:repeats("InsertEnter", {
    callback = function()
      --no showing trail on InsertLeave, which may trigger CursorMoved
      last_screenpos = { x = 0, y = 0 }
    end,
  })
end

function M.deactivate()
  if aug == nil then return end

  aug:unlink()
  aug = nil
  last_screenpos = { x = 0, y = 0 }
end

function M.toggle()
  if aug == nil then
    M.activate()
  else
    M.deactivate()
  end
end

return M
