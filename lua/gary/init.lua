local M = {}

local augroups = require("infra.augroups")
local jelly = require("infra.jellyfish")("gary", "info")
local logging = require("infra.logging")
local ni = require("infra.ni")

local bresenham = require("gary.bresenham")

local log = logging.newlogger("gary", "info")

---@class gary.ScreenPos
---@field x integer @column; 0-based
---@field y integer @lnum; 0-based

---@return gary.ScreenPos
local function get_current_screenpos()
  --todo: it works badly in terminal buffers
  local origin = ni.win_get_position(0)
  local row = vim.fn.winline()
  local col = vim.fn.wincol()

  return { y = origin[1] + row - 1, x = origin[2] + col - 1 }
end

---@param a gary.ScreenPos
---@param b gary.ScreenPos
---@return number
local function calc_distance(a, b) return math.sqrt(math.pow(math.abs(a.x - b.x), 2) + math.pow(math.abs(a.y - b.y), 2)) end

local aug ---@type infra.Augroup?
local last_screenpos = { x = 0, y = 0 } ---@type gary.ScreenPos

local function on_move()
  local screenpos = get_current_screenpos()
  if calc_distance(last_screenpos, screenpos) < 5 then return jelly.debug("skipped; distance < 5") end

  local line = bresenham.line(last_screenpos, screenpos)
  last_screenpos = screenpos
  log.debug("line: %s", line)

  require("gary.paint_colorful")(line)
end

function M.activate()
  if aug ~= nil then return end

  last_screenpos = get_current_screenpos()

  aug = augroups.Augroup("gary://")
  aug:repeats({ "CursorMoved", "WinScrolled" }, { callback = on_move })
  --no showing trail on InsertLeave, which will trigger CursorMoved
  aug:repeats("InsertLeavePre", { callback = function() last_screenpos = get_current_screenpos() end })
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
