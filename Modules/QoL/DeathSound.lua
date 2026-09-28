-- Modules/QoL/DeathSound.lua
-- Plays a sound when the character dies.
-- Plays only once per death.

local SOUND_FILE = "Interface\\AddOns\\AklimeModTools\\Assets\\SqueakyToySound.mp3"

local function GetDB()
    if AklimeModDB and AklimeModDB.deathSound then return AklimeModDB.deathSound end
    return {}
end

-- ============================================================
-- API
-- ============================================================
local M = {}
AklimeMod_DeathSound = M

function M:IsEnabled() return GetDB().enabled == true end
function M:SetEnabled(v) GetDB().enabled = v and true or false end

-- ============================================================
-- Event
-- ============================================================
local played = false

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_DEAD" then
        if not played and GetDB().enabled then
            PlaySoundFile(SOUND_FILE, "Master")
            played = true
        end
    else
        played = false
    end
end)
