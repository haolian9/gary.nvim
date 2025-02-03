local M = {}

local augroups = require("infra.augroups")
local Debounce = require("infra.Debounce")
local jelly = require("infra.jellyfish")("gary", "info")
local logging = require("infra.logging")
local ni = require("infra.ni")

local bresenham = require("gary.bresenham")

local log = logging.newlogger("gary", "info")

---@alias gary.Painter fun(line:gary.bresenham.Point[])

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

local DebounceSession
do
  ---@class gary.DebounceSession
  ---@field debounce infra.Debounce
  ---@field last_screenpos gary.ScreenPos
  ---@field aug infra.Augroup
  ---@field painter gary.Painter
  local Impl = {}
  Impl.__index = Impl

  function Impl:on_move()
    self.debounce:start_soon(function()
      local screenpos = get_current_screenpos()
      if calc_distance(self.last_screenpos, screenpos) < 5 then return jelly.debug("skipped; distance < 5") end

      local line = bresenham.line(self.last_screenpos, screenpos)
      log.debug("line: %s", line)

      self.painter(line)

      self.last_screenpos = screenpos
    end)
  end

  function Impl:activate()
    if self.aug ~= nil then return end

    self.debounce = Debounce(75)
    self.last_screenpos = get_current_screenpos()

    self.aug = augroups.Augroup("gary://")
    self.aug:repeats({ "CursorMoved", "WinScrolled" }, { callback = function() return self:on_move() end })
    --no showing trail on InsertLeave, which will trigger CursorMoved
    self.aug:repeats("InsertLeavePre", { callback = function() self.last_screenpos = get_current_screenpos() end })
  end

  function Impl:deactivate()
    if self.aug == nil then return end

    self.aug:unlink()
    self.debounce:close()
    self.aug = nil
  end

  ---@return gary.DebounceSession
  function DebounceSession(painter) return setmetatable({ painter = painter }, Impl) end
end

local Session
do
  ---@class gary.Session
  ---@field last_screenpos gary.ScreenPos
  ---@field aug infra.Augroup
  ---@field painter gary.Painter
  local Impl = {}
  Impl.__index = Impl

  function Impl:on_move()
    local screenpos = get_current_screenpos()
    if calc_distance(self.last_screenpos, screenpos) < 5 then return jelly.debug("skipped; distance < 5") end

    local line = bresenham.line(self.last_screenpos, screenpos)
    log.debug("line: %s", line)

    self.painter(line)

    self.last_screenpos = screenpos
  end

  function Impl:activate()
    if self.aug ~= nil then return end

    self.last_screenpos = get_current_screenpos()

    self.aug = augroups.Augroup("gary://")
    self.aug:repeats({ "CursorMoved", "WinScrolled" }, { callback = function() return self:on_move() end })
    --no showing trail on InsertLeave, which will trigger CursorMoved
    self.aug:repeats("InsertLeavePre", { callback = function() self.last_screenpos = get_current_screenpos() end })
  end

  function Impl:deactivate()
    if self.aug == nil then return end

    self.aug:unlink()
    self.aug = nil
  end

  ---@return gary.Session
  function Session(painter) return setmetatable({ painter = painter }, Impl) end
end

local session ---@type nil|gary.DebounceSession|gary.Session

---@param debounce? boolean @nil=true
---@param flavor? 'flat'|'colorful'|'fallback' @nil=flat
function M.activate(debounce, flavor)
  if debounce == nil then debounce = true end
  if flavor == nil then flavor = "flat" end

  M.deactivate()

  local painter = require("gary.paint_" .. flavor)
  local Impl = debounce and DebounceSession or Session
  session = Impl(painter)
  session:activate()
end

function M.deactivate()
  if session == nil then return end
  session:deactivate()
  session = nil
end

return M
