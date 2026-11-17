-- Modules/QoL/MapNavigation.lua
-- Switches the in-game navigation of the map.
-- Same as /console showInGameNavigation 1. The game stores the CVar itself,
-- so it is the only state and nothing is kept in the DB.

local CVAR_NAME = "showInGameNavigation"
local VALUE_ON  = "1"
local VALUE_OFF = "0"

local function IsEnabled()
    return GetCVar(CVAR_NAME) == VALUE_ON
end

AklimeMod_MapNavigation = {
    IsEnabled  = IsEnabled,
    SetEnabled = function(v)
        -- GetCVar returns nil if the client does not know the CVar
        if GetCVar(CVAR_NAME) == nil then return end
        SetCVar(CVAR_NAME, v and VALUE_ON or VALUE_OFF)
    end,
}
