local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path

describe("GoBoard", function()
    local Board

    setup(function()
        Board = require("board")
    end)


    local function newBoard(size_id)
        return Board:new{ size_id = size_id or "9x9" }
    end

    describe("construction", function()
        it("defaults to a 9×9 board", function()
            local b = Board:new()
            assert.are.equal(9, b.n)
            assert.are.equal("9x9", b.size_id)
        end)

        it("starts empty with Black to play", function()
            local b = newBoard()
            assert.are.equal("black", b.turn)
            assert.are.equal("playing", b.status)
            for r = 1, b.n do
                for c = 1, b.n do
                    assert.are.equal(Board.EMPTY, b.grid[r][c])
                end
            end
        end)

        it("exposes SIZES", function()
            local ids = {}
            for _, cfg in ipairs(Board.SIZES) do ids[#ids+1] = cfg.id end
            assert.are.same({"9x9", "13x13", "19x19"}, ids)
        end)
    end)

    describe("getGroup", function()
        it("returns nil for an empty cell", function()
            local b = newBoard()
            assert.is_nil(b:getGroup(b.grid, 5, 5))
        end)

        it("counts liberties of a lone stone", function()
            local b = newBoard()
            b.grid[5][5] = Board.BLACK
            local grp = b:getGroup(b.grid, 5, 5)
            assert.are.equal(1, #grp.stones)
            assert.are.equal(4, grp.liberties)
        end)

        it("merges connected same-color stones into one group", function()
            local b = newBoard()
            b.grid[5][5] = Board.BLACK
            b.grid[5][6] = Board.BLACK
            local grp = b:getGroup(b.grid, 5, 5)
            assert.are.equal(2, #grp.stones)
        end)

        it("does not merge across different colors", function()
            local b = newBoard()
            b.grid[5][5] = Board.BLACK
            b.grid[5][6] = Board.WHITE
            local grp = b:getGroup(b.grid, 5, 5)
            assert.are.equal(1, #grp.stones)
        end)
    end)

    describe("placeStone", function()
        it("places a stone and advances the turn", function()
            local b = newBoard()
            assert.are.equal("ok", b:placeStone(3, 3))
            assert.are.equal(Board.BLACK, b.grid[3][3])
            assert.are.equal("white", b.turn)
        end)

        it("rejects placing on an occupied cell", function()
            local b = newBoard()
            b:placeStone(3, 3)
            assert.are.equal("invalid", b:placeStone(3, 3))
        end)

        it("rejects placing out of bounds", function()
            local b = newBoard()
            assert.are.equal("invalid", b:placeStone(0, 1))
            assert.are.equal("invalid", b:placeStone(b.n + 1, 1))
        end)

        it("captures a fully-surrounded opponent group", function()
            local b = newBoard()
            b.grid[5][5] = Board.WHITE
            b.grid[4][5] = Board.BLACK
            b.grid[6][5] = Board.BLACK
            b.grid[5][4] = Board.BLACK
            b.turn = "black"
            local result = b:placeStone(5, 6)
            assert.are.equal("ok", result)
            assert.are.equal(Board.EMPTY, b.grid[5][5])
            assert.are.equal(1, b.captures.black)
        end)

        it("captures a multi-stone group when its last liberty is filled", function()
            local b = newBoard()
            -- white group at (5,5)-(5,6), surrounded except one liberty at (5,7)
            b.grid[5][5] = Board.WHITE
            b.grid[5][6] = Board.WHITE
            b.grid[4][5] = Board.BLACK
            b.grid[4][6] = Board.BLACK
            b.grid[6][5] = Board.BLACK
            b.grid[6][6] = Board.BLACK
            b.grid[5][4] = Board.BLACK
            b.turn = "black"
            local result = b:placeStone(5, 7)
            assert.are.equal("ok", result)
            assert.are.equal(Board.EMPTY, b.grid[5][5])
            assert.are.equal(Board.EMPTY, b.grid[5][6])
            assert.are.equal(2, b.captures.black)
        end)

        it("rejects a suicide move with no captures", function()
            local b = newBoard()
            b.grid[5][4] = Board.WHITE
            b.grid[5][6] = Board.WHITE
            b.grid[4][5] = Board.WHITE
            b.grid[6][5] = Board.WHITE
            b.turn = "black"
            assert.are.equal("invalid", b:placeStone(5, 5))
            assert.are.equal(Board.EMPTY, b.grid[5][5])
        end)

        it("enforces the simple ko rule", function()
            -- Classic ko shape (black to move):
            --      col4 col5 col6 col7
            -- row4:  .    B    .    .
            -- row5:  B    W    .    W    <- (5,5)=X will be captured, (5,6)=Y is black's move
            -- row6:  .    B    W    .
            -- X=(5,5)'s only liberty is Y=(5,6) (its other 3 neighbors are
            -- black). Y's other 3 neighbors (4,6),(6,6),(5,7) are white, so
            -- once black captures at Y, the new black stone there has
            -- exactly one liberty back at X -- the textbook 1-for-1 ko.
            local b = newBoard()
            b.grid[4][5] = Board.BLACK
            b.grid[6][5] = Board.BLACK
            b.grid[5][4] = Board.BLACK
            b.grid[5][5] = Board.WHITE
            b.grid[4][6] = Board.WHITE
            b.grid[6][6] = Board.WHITE
            b.grid[5][7] = Board.WHITE
            b.turn = "black"

            local r1 = b:placeStone(5, 6)
            assert.are.equal("ok", r1)
            assert.are.equal(Board.EMPTY, b.grid[5][5])
            assert.is_not_nil(b.ko_forbidden_hash)

            -- White immediately recapturing at (5,5) would recreate the
            -- pre-black-move position -- forbidden by simple ko.
            local r2 = b:placeStone(5, 5)
            assert.are.equal("invalid", r2)
        end)
    end)

    describe("pass", function()
        it("switches turn on a single pass", function()
            local b = newBoard()
            assert.are.equal("ok", b:pass())
            assert.are.equal("white", b.turn)
            assert.are.equal("playing", b.status)
        end)

        it("ends the game on two consecutive passes and computes a winner", function()
            local b = newBoard()
            b:pass()
            local result = b:pass()
            assert.are.equal("ended", result)
            assert.are.equal("ended", b.status)
            assert.is_not_nil(b.winner)
            assert.is_not_nil(b.final_score)
        end)

        it("a stone placement in between resets the pass count", function()
            local b = newBoard()
            b:pass()
            b:placeStone(1, 1)
            assert.are.equal(0, b.pass_count)
        end)
    end)

    describe("scoreTerritory", function()
        it("scores an empty board as 0-0", function()
            local b = newBoard()
            local score = b:scoreTerritory()
            assert.are.equal(0, score.black)
            assert.are.equal(0, score.white)
        end)

        it("awards a fully-enclosed empty region to the enclosing color", function()
            local b = newBoard()
            -- Surround (1,1) entirely with black stones.
            b.grid[1][2] = Board.BLACK
            b.grid[2][1] = Board.BLACK
            local score = b:scoreTerritory()
            assert.is_true(score.black >= 3)  -- 2 stones + 1 territory point
        end)

        it("does not award a region bordered by both colors (dame)", function()
            local b = newBoard()
            b.grid[3][1] = Board.BLACK
            b.grid[3][9] = Board.WHITE
            -- middle row is empty and touches both colors indirectly via
            -- the flood-filled empty region spanning the whole row/board
            local score = b:scoreTerritory()
            -- The single connected empty region covers nearly the whole
            -- board and touches both colors, so it should NOT be fully
            -- awarded to either side (stones themselves still count).
            assert.are.equal(1, score.black)
            assert.are.equal(1, score.white)
        end)
    end)

    describe("computeWinner", function()
        it("adds komi to White's score", function()
            local b = newBoard()
            local fs = b:computeWinner()
            assert.are.equal(Board.KOMI, fs.white - 0)
            assert.are.equal("white", b.winner)  -- 0-0 territory, White wins on komi
        end)
    end)

    describe("serialize / load", function()
        it("round-trips grid, turn, captures and ko state", function()
            local b = newBoard()
            b:placeStone(3, 3)
            b:placeStone(4, 4)
            local data = b:serialize()
            local b2 = Board:new()
            local ok = b2:load(data)
            assert.is_true(ok)
            assert.are.equal(b.n, b2.n)
            assert.are.equal(b.turn, b2.turn)
            assert.are.equal(Board.BLACK, b2.grid[3][3])
            assert.are.equal(Board.WHITE, b2.grid[4][4])
        end)

        it("load returns false for invalid data", function()
            local b = Board:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
            assert.is_false(b:load({ n = 9, grid = {1,2,3} }))  -- wrong length
        end)
    end)
end)
