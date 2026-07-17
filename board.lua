local grid_utils = require("grid_utils")

local EMPTY = 0
local BLACK = 1
local WHITE = 2

local DIRS4 = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

local SIZES = {
    { id = "9x9",   n = 9,  label = "9×9"   },
    { id = "13x13", n = 13, label = "13×13" },
    { id = "19x19", n = 19, label = "19×19" },
}
local SIZE_MAP = {}
for _, cfg in ipairs(SIZES) do SIZE_MAP[cfg.id] = cfg end

local DEFAULT_SIZE = "9x9"
local KOMI = 6.5

local function getSizeConfig(id)
    return SIZE_MAP[id] or SIZE_MAP[DEFAULT_SIZE]
end

local function inBounds(r, c, n)
    return r >= 1 and r <= n and c >= 1 and c <= n
end

local function copyGrid(grid, n)
    local g = {}
    for r = 1, n do
        g[r] = {}
        for c = 1, n do g[r][c] = grid[r][c] end
    end
    return g
end

-- Cheap at Go board sizes (<= 361 cells); only called on commit, never in a
-- search loop (there's no AI).
local function hashGrid(grid, n)
    local parts = {}
    for r = 1, n do parts[r] = table.concat(grid[r], ",") end
    return table.concat(parts, "|")
end

-- ---------------------------------------------------------------------------
-- GoBoard
-- ---------------------------------------------------------------------------

local GoBoard = {}
GoBoard.__index = GoBoard

GoBoard.SIZES = SIZES
GoBoard.DEFAULT_SIZE = DEFAULT_SIZE
GoBoard.EMPTY = EMPTY
GoBoard.BLACK = BLACK
GoBoard.WHITE = WHITE
GoBoard.KOMI = KOMI

function GoBoard:new(opts)
    opts = opts or {}
    local obj = setmetatable({}, self)
    obj:reset(opts.size_id)
    return obj
end

function GoBoard:reset(size_id)
    local cfg = getSizeConfig(size_id or self.size_id)
    self.size_id           = cfg.id
    self.n                 = cfg.n
    self.grid               = grid_utils.emptyGrid(cfg.n)
    self.turn                = "black"
    self.status               = "playing"
    self.winner                = nil
    self.captures                = { black = 0, white = 0 }
    self.pass_count                = 0
    self.last_move                   = nil
    self.ko_forbidden_hash             = nil
    self.final_score                     = nil
end

-- Orthogonal flood-fill of the group containing (r,c) on `grid` (a scratch
-- grid or self.grid). Returns { stones = {{r,c}...}, liberties = n, color }
-- or nil if (r,c) is empty.
function GoBoard:getGroup(grid, r, c)
    local n = self.n
    local color = grid[r][c]
    if color == EMPTY then return nil end

    local visited = {}
    for i = 1, n do visited[i] = {} end
    local stones = {}
    local liberties = {}
    local stack = { { r, c } }
    visited[r][c] = true

    while #stack > 0 do
        local cell = table.remove(stack)
        local cr, cc = cell[1], cell[2]
        stones[#stones + 1] = { cr, cc }
        for _, d in ipairs(DIRS4) do
            local nr, nc = cr + d[1], cc + d[2]
            if inBounds(nr, nc, n) then
                local v = grid[nr][nc]
                if v == EMPTY then
                    liberties[nr * 1000 + nc] = true
                elseif v == color and not visited[nr][nc] then
                    visited[nr][nc] = true
                    stack[#stack + 1] = { nr, nc }
                end
            end
        end
    end

    local lib_count = 0
    for _ in pairs(liberties) do lib_count = lib_count + 1 end
    return { stones = stones, liberties = lib_count, color = color }
end

function GoBoard:isLegalMove(r, c, color)
    if self.status ~= "playing" then return false end
    local n = self.n
    if not inBounds(r, c, n) or self.grid[r][c] ~= EMPTY then return false end

    local opp = (color == BLACK) and WHITE or BLACK
    local scratch = copyGrid(self.grid, n)
    scratch[r][c] = color

    local checked = {}
    for _, d in ipairs(DIRS4) do
        local nr, nc = r + d[1], c + d[2]
        if inBounds(nr, nc, n) and scratch[nr][nc] == opp then
            local key = nr * 1000 + nc
            if not checked[key] then
                local grp = self:getGroup(scratch, nr, nc)
                for _, s in ipairs(grp.stones) do checked[s[1] * 1000 + s[2]] = true end
                if grp.liberties == 0 then
                    for _, s in ipairs(grp.stones) do scratch[s[1]][s[2]] = EMPTY end
                end
            end
        end
    end

    local own_grp = self:getGroup(scratch, r, c)
    if own_grp.liberties == 0 then return false end  -- suicide

    if self.ko_forbidden_hash then
        local new_hash = hashGrid(scratch, n)
        if new_hash == self.ko_forbidden_hash then return false end
    end

    return true
end

-- Places a stone for the current turn's color. Captures are resolved
-- before the suicide check (standard Go rule ordering: a move that
-- captures is never rejected as suicide, even if it fills the placed
-- group's last liberty prior to the capture).
--
-- Ko rule implemented here is SIMPLE (1-ply) ko only: it forbids
-- immediately recreating the board position from just before the
-- opponent's last capturing move. It does not detect longer superko
-- cycles -- a documented simplification, not a bug.
--
-- Returns "ok" | "invalid" | "ended"
function GoBoard:placeStone(r, c)
    if self.status ~= "playing" then return "ended" end
    local n = self.n
    if not inBounds(r, c, n) or self.grid[r][c] ~= EMPTY then return "invalid" end

    local color = (self.turn == "black") and BLACK or WHITE
    local opp = (color == BLACK) and WHITE or BLACK

    local scratch = copyGrid(self.grid, n)
    scratch[r][c] = color

    local captured = 0
    local checked = {}
    for _, d in ipairs(DIRS4) do
        local nr, nc = r + d[1], c + d[2]
        if inBounds(nr, nc, n) and scratch[nr][nc] == opp then
            local key = nr * 1000 + nc
            if not checked[key] then
                local grp = self:getGroup(scratch, nr, nc)
                for _, s in ipairs(grp.stones) do checked[s[1] * 1000 + s[2]] = true end
                if grp.liberties == 0 then
                    for _, s in ipairs(grp.stones) do
                        scratch[s[1]][s[2]] = EMPTY
                        captured = captured + 1
                    end
                end
            end
        end
    end

    local own_grp = self:getGroup(scratch, r, c)
    if own_grp.liberties == 0 then return "invalid" end

    local new_hash = hashGrid(scratch, n)
    if self.ko_forbidden_hash and new_hash == self.ko_forbidden_hash then
        return "invalid"
    end

    local prev_hash = hashGrid(self.grid, n)
    self.grid = scratch
    self.captures[self.turn] = self.captures[self.turn] + captured
    self.pass_count = 0
    self.last_move = { r = r, c = c }

    -- Classic ko shape: exactly one stone placed capturing exactly one
    -- stone. Forbid the opponent from immediately recreating the
    -- pre-this-move position.
    if captured == 1 and #own_grp.stones == 1 then
        self.ko_forbidden_hash = prev_hash
    else
        self.ko_forbidden_hash = nil
    end

    self.turn = (self.turn == "black") and "white" or "black"
    return "ok"
end

-- Returns "ok" | "ended"
function GoBoard:pass()
    if self.status ~= "playing" then return "ended" end
    self.pass_count = self.pass_count + 1
    self.ko_forbidden_hash = nil
    self.last_move = nil
    if self.pass_count >= 2 then
        self.status = "ended"
        self:computeWinner()
        return "ended"
    end
    self.turn = (self.turn == "black") and "white" or "black"
    return "ok"
end

-- Chinese-style area scoring (stones on board + surrounded empty
-- territory), computed via flood-fill of connected empty regions. A region
-- scores to a color only if every stone bordering it is that color;
-- otherwise it's neutral (dame) and scores to neither side.
--
-- Simplification: there is no dead-stone marking step. Every stone still
-- on the board at double-pass is counted as alive. Players must actually
-- capture dead groups before double-passing for the score to be accurate
-- (documented in the in-app rules text).
function GoBoard:scoreTerritory()
    local n = self.n
    local visited = {}
    for r = 1, n do visited[r] = {} end
    local score = { black = 0, white = 0 }

    for r = 1, n do
        for c = 1, n do
            if self.grid[r][c] == BLACK then score.black = score.black + 1
            elseif self.grid[r][c] == WHITE then score.white = score.white + 1 end
        end
    end

    for r = 1, n do
        for c = 1, n do
            if self.grid[r][c] == EMPTY and not visited[r][c] then
                local region_size = 0
                local borders = {}
                local stack = { { r, c } }
                visited[r][c] = true
                while #stack > 0 do
                    local cell = table.remove(stack)
                    local cr, cc = cell[1], cell[2]
                    region_size = region_size + 1
                    for _, d in ipairs(DIRS4) do
                        local nr, nc = cr + d[1], cc + d[2]
                        if inBounds(nr, nc, n) then
                            local v = self.grid[nr][nc]
                            if v == EMPTY then
                                if not visited[nr][nc] then
                                    visited[nr][nc] = true
                                    stack[#stack + 1] = { nr, nc }
                                end
                            else
                                borders[v] = true
                            end
                        end
                    end
                end
                if borders[BLACK] and not borders[WHITE] then
                    score.black = score.black + region_size
                elseif borders[WHITE] and not borders[BLACK] then
                    score.white = score.white + region_size
                end
            end
        end
    end

    return score
end

function GoBoard:computeWinner()
    local score = self:scoreTerritory()
    self.final_score = { black = score.black, white = score.white + KOMI }
    self.winner = (self.final_score.black > self.final_score.white) and "black" or "white"
    return self.final_score
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function GoBoard:serialize()
    local n = self.n
    local flat = {}
    for r = 1, n do
        for c = 1, n do flat[#flat + 1] = self.grid[r][c] end
    end
    return {
        size_id           = self.size_id,
        n                 = n,
        grid              = flat,
        turn              = self.turn,
        status            = self.status,
        winner            = self.winner,
        captures          = { black = self.captures.black, white = self.captures.white },
        pass_count        = self.pass_count,
        ko_forbidden_hash = self.ko_forbidden_hash,
        final_score       = self.final_score,
    }
end

function GoBoard:load(data)
    if type(data) ~= "table" or type(data.grid) ~= "table" or type(data.n) ~= "number" then
        return false
    end
    local n = data.n
    if #data.grid ~= n * n then return false end

    self.n = n
    self.size_id = data.size_id or DEFAULT_SIZE
    self.grid = {}
    local idx = 1
    for r = 1, n do
        self.grid[r] = {}
        for c = 1, n do
            self.grid[r][c] = data.grid[idx] or EMPTY
            idx = idx + 1
        end
    end
    self.turn        = data.turn or "black"
    self.status       = data.status or "playing"
    self.winner        = data.winner
    self.captures        = { black = (data.captures and data.captures.black) or 0,
                              white = (data.captures and data.captures.white) or 0 }
    self.pass_count         = data.pass_count or 0
    self.ko_forbidden_hash    = data.ko_forbidden_hash
    self.final_score             = data.final_score
    self.last_move                 = nil
    return true
end

return GoBoard
