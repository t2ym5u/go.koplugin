local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ButtonTable     = require("ui/widget/buttontable")
local Device          = require("device")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local MenuHelper = require("menu_helper")
local ScreenBase = require("screen_base")

local GoBoard       = lrequire("board")
local GoBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

local GAME_RULES_EN = _([[
Go — Rules

Two players (Black and White) alternate placing stones on the intersections of the grid. Black plays first.

A group of connected same-color stones is captured and removed when it has no empty adjacent intersection (liberty) left. You may not play a move that would leave your own stone(s) with no liberties, unless it captures an opponent group first.

Ko rule: you may not immediately recapture in a way that recreates the board position from just before your opponent's last move.

The game ends when both players pass in a row. Territory (surrounded empty points) plus stones on the board are scored per color; White receives a 6.5 point komi to offset Black's first-move advantage.

Note: there is no dead-stone marking step -- capture any dead groups yourself before passing twice, or the score won't reflect them.
]])

local GAME_RULES_FR = [[
Go — Règles

Deux joueurs (Noir et Blanc) posent alternativement des pierres sur les intersections de la grille. Noir joue en premier.

Un groupe de pierres connectées de même couleur est capturé et retiré quand il n'a plus aucune intersection adjacente vide (liberté). Vous ne pouvez pas jouer un coup qui laisserait votre propre groupe sans liberté, sauf s'il capture d'abord un groupe adverse.

Règle du Ko : vous ne pouvez pas reprendre immédiatement d'une façon qui recréerait la position du plateau juste avant le dernier coup de l'adversaire.

La partie se termine quand les deux joueurs passent d'affilée. Le territoire (points vides entourés) plus les pierres sur le plateau sont comptés par couleur ; Blanc reçoit un komi de 6.5 points pour compenser l'avantage du premier coup de Noir.

Remarque : il n'y a pas d'étape de marquage des pierres mortes -- capturez vous-même les groupes morts avant de passer deux fois, sinon le score n'en tiendra pas compte.
]]

local GoScreen = ScreenBase:extend{}

function GoScreen:init()
    local state   = self.plugin:loadState()
    local size_id = self.plugin:getSetting("size_id", GoBoard.DEFAULT_SIZE)
    self.board = GoBoard:new{ size_id = size_id }
    if not self.board:load(state) then
        self.board:reset(size_id)
    end
    ScreenBase.init(self)
end

function GoScreen:serializeState()
    return self.board:serialize()
end

function GoScreen:buildLayout()
    local sw = DeviceScreen:getWidth()
    local sh = DeviceScreen:getHeight()
    local is_landscape = self:isLandscape()

    local title_bar = self:buildTitleBar(_("Go"), function()
        return {
            { text = _("New game"),     callback = function() self:onNewGame() end },
            { text = self:_sizeLabel(), callback = function() self:openSizeMenu() end },
            { text = _("Pass"),         callback = function() self:onPass() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)

    local board_size = is_landscape and (sh - 40) or math.floor(sw * 0.94)
    self.board_widget = GoBoardWidget:new{
        board        = self.board,
        size         = board_size,
        onCellAction = function(r, c) self:onCellAction(r, c) end,
    }

    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin  = Size.margin.default,
        self.board_widget,
    }

    local pass_button = ButtonTable:new{
        width = is_landscape and math.max(math.floor(sw * 0.3), 120) or math.floor(sw * 0.9),
        shrink_unneeded_width = true,
        buttons = {{
            { text = _("Pass"), callback = function() self:onPass() end },
        }},
    }

    if is_landscape then
        local right = VerticalGroup:new{
            align = "center",
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            pass_button,
        }
        local content = HorizontalGroup:new{
            align  = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right,
        }
        self:buildLandscapeLayout(title_bar, content)
    else
        local footer = VerticalGroup:new{
            align = "center",
            pass_button,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
        }
        self:buildPortraitLayout(title_bar, board_frame, footer)
    end
    self:updateStatus()
end

function GoScreen:onCellAction(r, c)
    local board = self.board
    if board.status ~= "playing" then return end

    local result = board:placeStone(r, c)
    if result == "invalid" then
        self:updateStatus(_("Invalid move."))
        return
    end

    self.board_widget:refresh()
    self.plugin:saveState(self:serializeState())
    self:updateStatus()
end

function GoScreen:onPass()
    local board = self.board
    if board.status ~= "playing" then return end

    local result = board:pass()
    self.board_widget:refresh()
    self.plugin:saveState(self:serializeState())

    if result == "ended" then
        self:updateStatus()
        local fs = board.final_score
        local winner_label = board.winner == "black" and _("Black") or _("White")
        self:showMessage(T(_("%1 wins! Black: %2  White: %3"), winner_label, fs.black, fs.white), 5)
    else
        self:updateStatus()
    end
end

function GoScreen:onNewGame()
    self.board:reset(self.plugin:getSetting("size_id", GoBoard.DEFAULT_SIZE))
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function GoScreen:openSizeMenu()
    local items = {}
    for _, cfg in ipairs(GoBoard.SIZES) do
        items[#items + 1] = { id = cfg.id, text = cfg.label }
    end
    MenuHelper.openPickerMenu{
        title      = _("Board size"),
        items      = items,
        current_id = self.board.size_id,
        parent     = self,
        on_select  = function(id)
            self.plugin:saveSetting("size_id", id)
            self.board:reset(id)
            self.plugin:saveState(self.board:serialize())
            self:buildLayout()
            UIManager:setDirty(self, function() return "ui", self.dimen end)
        end,
    }
end

function GoScreen:_sizeLabel()
    for _, cfg in ipairs(GoBoard.SIZES) do
        if cfg.id == self.board.size_id then return cfg.label end
    end
    return self.board.size_id
end

function GoScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.board.status == "ended" then
        local fs = self.board.final_score
        local winner_label = self.board.winner == "black" and _("Black") or _("White")
        status = T(_("%1 wins! Black: %2  White: %3"), winner_label, fs.black, fs.white)
    else
        local turn_label = self.board.turn == "black" and _("Black") or _("White")
        status = T(_("%1 to play  B:%2 W:%3"),
            turn_label, self.board.captures.black, self.board.captures.white)
    end
    ScreenBase.updateStatus(self, status)
end

return GoScreen
