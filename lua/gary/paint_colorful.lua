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

---@param x integer @absolute
---@param y integer @absolute
---@param geo gary.WinGeo
local function is_screenpos_in_win(x, y, geo) --
  return x >= geo.x0 and x <= geo.x9 and y >= geo.y0 and y <= geo.y9
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

---@param line gary.bresenham.Point[]
---@param geos gary.WinGeo[]
return function(line, geos)
  local poses = {}
  do
    ---(winid, [(row,col)])
    ---@type [integer,[integer,integer]][]
    local points = {}
    for x, y in itertools.itern(line) do
      for _, geo in ipairs(geos) do
        --this screenpos could be in: window-status, win-separator, cmdline, tabline, sign-column, number-column, winbar
        if not is_screenpos_in_win(x, y, geo) then goto continue end

        local point = { y - geo.y0 + geo.yoff, x - geo.x0 + geo.xoff + 1, 1 }
        table.insert(points, { geo.winid, point })

        ::continue::
      end
    end

    ---@type string[]
    local colors = alloc_colors(#points)

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
  log.debug("poses: %s", poses)

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
      pcall(vim.fn.matchdelete, tuple[2], tuple[1])
      --todo: not just ignore error
    end
  end, 175)
end
