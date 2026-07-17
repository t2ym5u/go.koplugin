local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local PluginBase = require("plugin_base")
local _          = require("gettext")
local GoScreen = lrequire("screen")

-- ---------------------------------------------------------------------------
-- GoPlugin
-- ---------------------------------------------------------------------------

local GoPlugin = PluginBase:extend{
    name      = "go",
    menu_text = _("Go"),
    menu_hint = "tools",
}

function GoPlugin:createScreen()
    return GoScreen:new{ plugin = self }
end

return GoPlugin
