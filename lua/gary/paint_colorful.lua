local highlighter = require("infra.highlighter")
local itertools = require("infra.itertools")
local logging = require("infra.logging")

local log = logging.newlogger("gary.paint_colorful", "info")

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

---@param scol integer @1-based
---@param srow integer @1-based
---@return integer? winid
---@return integer? winrow @1-based, the same meaning of line(), not winline()
---@return integer? wincol @1-based, the same meaning of col(), not wincol
local function screenpos_to_winpos(scol, srow)
  ---@diagnostic disable-next-line: redundant-parameter
  local mpos = vim.fn.getmousepos(srow, scol)
  if mpos.winid == 0 then return end
  return mpos.winid, mpos.line, mpos.column
end

---@param line gary.bresenham.Point[]
return function(line)
  ---[(color,winid,points)]
  local poses = {}
  do
    ---(winid, [(row,col)])
    local points = {}
    for x, y in itertools.itern(line) do
      local winid, wrow, wcol = screenpos_to_winpos(x + 1, y + 1)
      if not (wrow and wcol) then goto continue end

      table.insert(points, { winid, { wrow, wcol } })

      ::continue::
    end

    ---@type string[]
    local colors = alloc_colors(#points)

    local last_win, last_color
    for i = 1, #points do
      local winid, point = unpack(points[i])
      local color = colors[i]
      if last_win == winid and last_color == color then
        table.insert(poses[#poses][3], point)
      else
        last_win, last_color = winid, color
        table.insert(poses, { color, winid, { point } })
      end
    end
  end
  log.debug("poses: %s", poses)

  ---[(winid,matid)]
  local spots = {}
  for i, tuple in ipairs(poses) do
    local color, winid, points = unpack(tuple)
    local matid = vim.fn.matchaddpos(color, points, nil, -1, { window = winid })
    spots[i] = { winid, matid }
  end

  vim.defer_fn(function()
    for winid, matid in itertools.itern(spots) do
      --ignore errors: winid could be invalid
      pcall(vim.fn.matchdelete, matid, winid)
    end
  end, 175)
end
