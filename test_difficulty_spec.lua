-- Guarantees of the Go computer opponent. It has a single level (a rule-of-
-- thumb beginner, no search), so there is no level table to order; what is
-- checked: legal moves on every board size, it captures a stone in atari,
-- saves its own stone from atari, never fills its own eye, plays the same
-- move for the same position whatever the rng, and answers within the
-- Kobo's patience on 19x19. No full matches.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path

describe("Go AI difficulty", function()
    local Board

    setup(function()
        Board = require("board")
    end)

    local KOBO = 25     -- a Kobo Aura runs this Lua about 25x slower

    local function colorOf(b)
        return (b.turn == "black") and Board.BLACK or Board.WHITE
    end

    -- A 9x9 position from lists of black and white stones.
    local function position(black, white, turn)
        local b = Board:new{ size_id = "9x9" }
        for _, p in ipairs(black) do b.grid[p[1]][p[2]] = Board.BLACK end
        for _, p in ipairs(white) do b.grid[p[1]][p[2]] = Board.WHITE end
        b.turn = turn or "black"
        return b
    end

    -- Plays `plies` turns of a seeded game: the AI half the time, a random
    -- legal point (or a pass) otherwise. Calls check(b, move) before each
    -- AI move is played.
    local function randomGame(size_id, seed, plies, check)
        math.randomseed(seed)
        local b = Board:new{ size_id = size_id }
        for _ = 1, plies do
            if b.status ~= "playing" then break end
            local m = b:getAIMove()
            if check then check(b, m) end
            if m and math.random() < 0.5 then
                b:placeStone(m.r, m.c)
            else
                local r, c = math.random(b.n), math.random(b.n)
                if b.grid[r][c] == Board.EMPTY and b:isLegalMove(r, c, colorOf(b)) then
                    b:placeStone(r, c)
                elseif m then
                    b:placeStone(m.r, m.c)
                else
                    b:pass()
                end
            end
        end
        return b
    end

    it("plays legal moves (or passes) on every board size", function()
        for i, size in ipairs(Board.SIZES) do
            randomGame(size.id, i, 60, function(b, m)
                if m then
                    assert.are.equal(Board.EMPTY, b.grid[m.r][m.c])
                    assert.is_true(b:isLegalMove(m.r, m.c, colorOf(b)))
                end
            end)
        end
    end)

    it("never fills its own eye", function()
        for i, size in ipairs(Board.SIZES) do
            randomGame(size.id, 10 + i, 80, function(b, m)
                if m then assert.is_false(b:_isOwnEye(m.r, m.c, colorOf(b))) end
            end)
        end
    end)

    it("captures a stone in atari", function()
        -- White (5,5) has one liberty left, at (5,6).
        local b = position({ {4, 5}, {6, 5}, {5, 4} }, { {5, 5}, {2, 2} })
        local m = b:getAIMove()
        assert.are.same({ 5, 6 }, { m.r, m.c })
    end)

    it("saves its own stone from atari", function()
        -- Black (5,5) has one liberty left, at (5,6); extending gives three.
        local b = position({ {5, 5}, {2, 2} }, { {4, 5}, {6, 5}, {5, 4} })
        local m = b:getAIMove()
        assert.are.same({ 5, 6 }, { m.r, m.c })
    end)

    it("plays the same move for the same position, whatever the rng", function()
        local b = randomGame("13x13", 21, 40)
        local data = b:serialize()
        local moves = {}
        for seed = 1, 3 do
            math.randomseed(seed)
            local c = Board:new{ size_id = "13x13" }
            assert.is_true(c:load(data))
            local m = c:getAIMove()
            moves[seed] = m and (m.r .. "," .. m.c) or "pass"
        end
        assert.are.equal(moves[1], moves[2])
        assert.are.equal(moves[1], moves[3])
    end)

    it("answers within 2.5 s at Kobo speed, even on 19x19", function()
        local worst = 0
        for i, size in ipairs(Board.SIZES) do
            randomGame(size.id, 30 + i, 120, function(b)
                local t0 = os.clock()
                b:getAIMove()
                local dt = (os.clock() - t0) * KOBO
                if dt > worst then worst = dt end
            end)
        end
        assert.is_true(worst <= 2.5, string.format("slowest Kobo move %.2f s", worst))
    end)
end)
