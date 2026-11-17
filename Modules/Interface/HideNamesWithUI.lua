-- Modules/Interface/HideNamesWithUI.lua
-- Hides the names of all players and NPCs while the interface is hidden
-- (Alt+Z by default) and shows them again with the interface.
-- The original CVar values are kept in the DB, so they are restored even if
-- the game was closed while the interface was hidden.

local HIDDEN_VALUE = "0"

-- CVars that are missing in the client are skipped, GetCVar returns nil for them
local NAME_CVARS = {
    "UnitNameOwn",
    "UnitNameNPC",
    "UnitNameNonCombatCreatureName",
    "UnitNameHostleNPC",
    "UnitNameInteractiveNPC",
    "UnitNameFriendlySpecialNPCName",
    "UnitNameFriendlyPlayerName",
    "UnitNameFriendlyPetName",
    "UnitNameFriendlyGuardianName",
    "UnitNameFriendlyTotemName",
    "UnitNameFriendlyMinionName",
    "UnitNameEnemyPlayerName",
    "UnitNameEnemyPetName",
    "UnitNameEnemyGuardianName",
    "UnitNameEnemyTotemName",
    "UnitNameEnemyMinionName",
    -- Nameplates show a name too
    "nameplateShowAll",
    "nameplateShowEnemies",
    "nameplateShowFriends",
}

local function GetDB()
    return AklimeModDB and AklimeModDB.hideNamesWithUI
end

local function IsEnabled()
    local db = GetDB()
    return db and db.enabled
end

-- saved is only set while the names are hidden
local function HideNames()
    local db = GetDB()
    if not db or db.saved then return end

    local saved = {}
    for _, name in ipairs(NAME_CVARS) do
        local value = GetCVar(name)
        if value ~= nil then
            saved[name] = value
            SetCVar(name, HIDDEN_VALUE)
        end
    end
    db.saved = saved
end

local function RestoreNames()
    local db = GetDB()
    if not db or not db.saved then return end

    for name, value in pairs(db.saved) do
        SetCVar(name, value)
    end
    db.saved = nil
end

UIParent:HookScript("OnHide", function()
    if IsEnabled() then HideNames() end
end)
UIParent:HookScript("OnShow", RestoreNames)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    -- The last session ended while the interface was hidden
    if UIParent:IsShown() then RestoreNames() end
end)

AklimeMod_HideNamesWithUI = {
    IsEnabled  = function() return IsEnabled() end,
    SetEnabled = function(v)
        local db = GetDB()
        if db then db.enabled = v end
        if not v then
            RestoreNames()
        elseif not UIParent:IsShown() then
            HideNames()
        end
    end,
}
