local Blitbuffer     = require("ffi/blitbuffer")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager      = require("ui/uimanager")

local C_BG        = Blitbuffer.COLOR_WHITE
local C_LINE       = Blitbuffer.COLOR_BLACK
local C_BLACK      = Blitbuffer.COLOR_BLACK
local C_WHITE       = Blitbuffer.COLOR_WHITE
local C_STONE_EDGE   = Blitbuffer.COLOR_BLACK
local C_LAST_MOVE      = Blitbuffer.COLOR_GRAY_9
local C_STAR_POINT       = Blitbuffer.COLOR_BLACK

-- ---------------------------------------------------------------------------
-- GoBoardWidget — Go is played on the intersections of an n×n grid of
-- lines, not inside filled cells, so this widget draws its own grid rather
-- than reusing GridWidgetBase's filled-cell model (as othello/memory do).
-- ---------------------------------------------------------------------------

local GoBoardWidget = InputContainer:extend{
    board        = nil,
    onCellAction = nil,
    size         = 300,
}

-- Traditional star-point (hoshi) positions per board size.
local STAR_POINTS = {
    [9]  = { {3,3}, {3,7}, {7,3}, {7,7}, {5,5} },
    [13] = { {4,4}, {4,10}, {10,4}, {10,10}, {7,7} },
    [19] = { {4,4}, {4,10}, {4,16}, {10,4}, {10,10}, {10,16}, {16,4}, {16,10}, {16,16} },
}

function GoBoardWidget:init()
    local n = self.board.n
    self.n = n
    -- Margin reserves room so stones at the edge aren't clipped.
    self.margin = math.max(10, math.floor(self.size * 0.04))
    self.cell = math.floor((self.size - 2 * self.margin) / math.max(1, n - 1))
    self.stone_r = math.max(3, math.floor(self.cell * 0.44))

    self.dimen = Geom:new{ w = self.size, h = self.size }
    self.paint_rect = Geom:new{ x = 0, y = 0, w = self.size, h = self.size }

    self.ges_events = {
        Tap = {
            GestureRange:new{
                ges   = "tap",
                range = Geom:new{ x = 0, y = 0, w = 3000, h = 3000 },
            },
        },
    }
end

-- Converts intersection (r,c) [1-indexed] to local pixel coordinates.
function GoBoardWidget:_toXY(r, c)
    return self.margin + (c - 1) * self.cell, self.margin + (r - 1) * self.cell
end

function GoBoardWidget:onTap(_, ges)
    if not (ges and ges.pos) then return false end
    local rect = self.paint_rect
    local lx = ges.pos.x - rect.x
    local ly = ges.pos.y - rect.y

    local c = (lx - self.margin) / self.cell + 1
    local r = (ly - self.margin) / self.cell + 1
    local rr, rc = math.floor(r + 0.5), math.floor(c + 0.5)
    if rr < 1 or rr > self.n or rc < 1 or rc > self.n then return true end

    -- Require the tap to land reasonably close to the intersection so a tap
    -- between two points doesn't register as either one.
    local ex, ey = self:_toXY(rr, rc)
    local dx, dy = lx - ex, ly - ey
    if (dx * dx + dy * dy) > (self.cell * 0.5) ^ 2 then return true end

    if self.onCellAction then self.onCellAction(rr, rc) end
    return true
end

function GoBoardWidget:refresh()
    local rect = self.paint_rect
    UIManager:setDirty(self, function()
        return "ui", Geom:new{ x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    end)
end

function GoBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.size, h = self.size }
    bb:paintRect(x, y, self.size, self.size, C_BG)

    local board = self.board
    local n = self.n

    -- Grid lines
    for i = 1, n do
        local lx, ly = self:_toXY(i, 1)
        local rx, _ = self:_toXY(i, n)
        bb:paintRect(x + lx, y + ly, rx - lx + 1, 1, C_LINE)
        local tx, ty = self:_toXY(1, i)
        local _, by = self:_toXY(n, i)
        bb:paintRect(x + tx, y + ty, 1, by - ty + 1, C_LINE)
    end

    -- Star points. paintCircle's 5th arg is a ring WIDTH, not a "filled"
    -- flag -- omitting it defaults the ring width to the radius, i.e. a
    -- filled disc; passing a small width draws a thin outline instead.
    local stars = STAR_POINTS[n]
    if stars then
        for _, p in ipairs(stars) do
            local sx, sy = self:_toXY(p[1], p[2])
            bb:paintCircle(x + sx, y + sy, math.max(1, math.floor(self.cell * 0.06)), C_STAR_POINT)
        end
    end

    -- Stones
    for r = 1, n do
        for c = 1, n do
            local v = board.grid[r][c]
            if v ~= 0 then
                local px, py = self:_toXY(r, c)
                if v == 1 then
                    bb:paintCircle(x + px, y + py, self.stone_r, C_BLACK)
                else
                    bb:paintCircle(x + px, y + py, self.stone_r, C_WHITE)
                    bb:paintCircle(x + px, y + py, self.stone_r, C_STONE_EDGE, 1)
                end
            end
        end
    end

    -- Last-move marker
    if board.last_move then
        local px, py = self:_toXY(board.last_move.r, board.last_move.c)
        local r2 = math.max(2, math.floor(self.stone_r * 0.35))
        bb:paintCircle(x + px, y + py, r2, C_LAST_MOVE)
    end
end

return GoBoardWidget
