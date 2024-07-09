---that's a crazy appraoch
---* 100*40 == 4000 windows!!!!
---* yet it requires winblend, which is not compatible with notermguicolor

local augroups = require("infra.augroups")
local Ephemeral = require("infra.Ephemeral")
local highlighter = require("infra.highlighter")
local logging = require("infra.logging")
local ni = require("infra.ni")

local log = logging.newlogger("gary.paint_cloudy", "debug")

do
  local hi = highlighter(0)
  if vim.go.background == "light" then
    hi("GaryTrail", { bg = 225, fg = 8 })
  else
    hi("GaryTrail", { bg = 24, fg = 7 })
  end
end

local trail_ns = ni.create_namespace("gary:trail")

local function create_buf()
  local bufnr = Ephemeral({ name = "gary://cloud", bufhidden = "hide" }, { " " })
  ni.buf_set_extmark(bufnr, trail_ns, 0, 0, { end_row = 0, end_col = 1, hl_group = "GaryTrail" })
  return bufnr
end

local function build_matrix(bufnr)
  local rows = vim.go.lines - vim.go.cmdheight
  if vim.go.laststatus == 3 then rows = rows - 1 end
  local cols = vim.go.columns

  local matrix = {}

  for x = 0, cols - 1 do
    matrix[x] = {}
    for y = 0, rows - 1 do
      --stylua: ignore start
      matrix[x][y] = ni.open_win(bufnr, false, {
        relative = 'editor', row = y - 1, col = x - 1, width = 1, height = 1, zindex = 251,
        focusable = false, hide = true, noautocmd = false,
      })
      --stylua: ignore end
    end
  end

  log.debug("built matrix: %s", matrix)

  return matrix
end

--todo: what if bufnr gets wiped out?
local bufnr = create_buf()
local clouds = build_matrix(bufnr)

do
  local aug = augroups.Augroup("gary://paint_cloudy")
  aug:repeats("VimResized", {
    callback = function()
      assert(ni.buf_is_valid(bufnr))
      clouds = build_matrix(bufnr)
    end,
  })
end

local function point_to_winid(point)
  local line = assert(clouds[point[1]], point[1])
  return assert(line[point[2]], point[2])
end

---@param line gary.bresenham.Point[]
return function(line) --
  log.debug("line: %s", line)
  for _, point in ipairs(line) do
    ni.win_set_config(point_to_winid(point), { hide = false })
  end

  vim.defer_fn(function()
    for _, point in ipairs(line) do
      ni.win_set_config(point_to_winid(point), { hide = true })
    end
  end, 1000)
end
