local augroups = require("infra.augroups")
local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local highlighter = require("infra.highlighter")
local listlib = require("infra.listlib")
local logging = require("infra.logging")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local wincursor = require("infra.wincursor")

local log = logging.newlogger("gary.paint_windy", "debug")
local uv = vim.uv

do
  local hi = highlighter(0)
  if vim.go.background == "light" then
    hi("GaryTrail", { bg = 225, fg = 8 })
  else
    hi("GaryTrail", { bg = 24, fg = 7 })
  end
end

local trail_ns = ni.create_namespace("gary:trail")

local build_lines
do
  ---@return string[][]
  local function zero_matrix()
    local matrix = {}

    local rows = vim.go.lines - vim.go.cmdheight
    if vim.go.laststatus == 3 then rows = rows - 1 end
    local cols = vim.go.columns

    log.debug("matrix; cols=%s, rows=%s", cols, rows)

    for row = 1, rows do
      local line = {}
      for col = 1, cols do
        line[col] = " "
      end
      matrix[row] = line
    end

    return matrix
  end

  function build_lines()
    local lines = {}
    for _, l in ipairs(zero_matrix()) do
      table.insert(lines, table.concat(l))
    end
    return lines
  end
end

local function decide_consume_spec()
  if vim.go.columns < 100 then return { batch_size = 5, interval = 175 } end
  return { batch_size = 10, interval = 40 }
end

--todo: position queue + consumer
--todo: zz
--todo: long line, ft,;

local bufnr, winid = -1, -1
local queue = {} ---@type integer[]
local timer = uv.new_timer()
local consume_spec = decide_consume_spec()

do
  bufnr = Ephemeral({ bufhidden = "hide", name = "gary://windy" }, build_lines())

  local aug = augroups.BufAugroup(bufnr, true)
  aug:repeats("BufHidden", { callback = function() ni.buf_clear_namespace(bufnr, trail_ns, 0, -1) end })
  ni.create_autocmd("VimResized", {
    group = aug.group,
    callback = function() --
      if ni.win_is_valid(winid) then ni.win_close(winid, false) end
      ni.buf_clear_namespace(bufnr, trail_ns, 0, -1)
      buflines.replaces_all(bufnr, build_lines())
      consume_spec = decide_consume_spec()
    end,
  })
end

do
  local function consume()
    local xmids = {}
    for i = 1, consume_spec.batch_size do
      local xmid = listlib.pop(queue)
      if xmid == nil then break end
      xmids[i] = xmid
    end

    for _, xmid in ipairs(xmids) do
      ni.buf_del_extmark(bufnr, trail_ns, xmid)
    end
    log.debug("erased xmids: %s", xmids)

    if #xmids == 10 then return end

    timer:stop()
    if ni.win_is_valid(winid) then ni.win_close(winid, false) end
    log.debug("stopped timer, closed: %d", winid)
  end

  --should depend on cols&rows
  timer:start(175, consume_spec.interval, vim.schedule_wrap(consume))
end

---@param line gary.bresenham.Point[]
return function(line)
  if not ni.win_is_valid(winid) then --
    winid = rifts.open.fullscreen(bufnr, false, { relative = "editor" }, { laststatus3 = true })
    prefer.wo(winid, "list", false)
    prefer.wo(winid, "winblend", 1)
  end

  log.debug("line: %s", line)

  local last_point = line[#line]
  wincursor.go(winid, last_point[2], last_point[1])

  for _, pos in ipairs(line) do
    local col, lnum = unpack(pos)
    --stylua: ignore start
    local xmid = ni.buf_set_extmark(bufnr, trail_ns, lnum, col, {
      end_row = lnum, end_col = col + 1,
      hl_group = "GaryTrail", hl_mode = "replace",
    })
    --stylua: ignore end
    listlib.push(queue, xmid)
  end

  timer:again()
end
