-- Modules/QoL/Clock24h.lua
-- Sets the Blizzard clock to 24-hour format if not already active.
-- CVar: timeMgrUseMilitaryTime

local function GetDB()
    return AklimeModDB and AklimeModDB.clock24h
end

local function IsEnabled()
    local db = GetDB()
    return db and db.enabled
end

local function Apply()
    if not IsEnabled() then return end
    if GetCVar("timeMgrUseMilitaryTime") ~= "1" then
        SetCVar("timeMgrUseMilitaryTime", "1")
        -- Refresh the TimeManager UI
        if TimeManagerFrame and TimeManagerFrame_OnLoad then
            TimeManagerFrame_OnLoad(TimeManagerFrame)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function()
    Apply()
end)

AklimeMod_Clock24h = {
    IsEnabled  = function() return IsEnabled() end,
    SetEnabled = function(v)
        local db = GetDB()
        if db then db.enabled = v end
        if v then
            Apply()
        else
            SetCVar("timeMgrUseMilitaryTime", "0")
        end
    end,
}