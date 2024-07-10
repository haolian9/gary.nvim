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

---@param x integer
---@param y integer
---@return integer? winid
---@returnyinteger? winrow @1-based, the same meaning of line(), not winline()
---@return integer? wincol @1-based, the same meaning of col(), not wincol
local function screenpos_to_winpos(x, y)
  ---@diagnostic disable-next-line: redundant-parameter
  local mpos = vim.fn.getmousepos(y, x)
  if mpos.winid == 0 then return end
  return mpos.winid, mpos.line, mpos.column
end

---@class gary.paint_simply.Spot
---@field winid integer
---@field matid integer

---@param line gary.bresenham.Point[]
return function(line)
  ---[(winid,[(row,col)])]
  ---@type [integer,[integer,integer][]][]
  local win_points = {}
  for x, y in itertools.itern(line) do
    local winid, wrow, wcol = screenpos_to_winpos(x + 1, y + 1)
    if not (wrow and wcol) then goto continue end

    local point = { wrow, wcol }
    local last = win_points[#win_points]
    if last and last[1] == winid then
      table.insert(last[2], point)
    else
      table.insert(win_points, { winid, { point } })
    end

    ::continue::
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

