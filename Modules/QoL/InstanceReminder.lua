-- Modules/QoL/InstanceReminder.lua
-- Shows a popup when entering an instance: "Buff food, potions, buffs. Does everything fit?"
-- Only on a real entry, not on login or reload.

local L = AklimeModL or {}

local POPUP_KEY = "AKLIMEMOD_INSTANCE_REMINDER"

local function GetDB()
    if AklimeModDB and AklimeModDB.instanceReminder then return AklimeModDB.instanceReminder end
    return { enabled = false }
end

-- Housing counts as an instance for IsInInstance(), but a reminder for buff
-- food makes no sense in your own house.
local function IsInInstanceNow()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then return false end
    return instanceType ~= "interior" and instanceType ~= "neighborhood"
end

-- ============================================================
-- Popup
-- ============================================================
StaticPopupDialogs[POPUP_KEY] = {
    text           = L["instance_popup_text"],
    button1        = L["instance_popup_ok"],
    timeout        = 0,
    whileDead      = false,
    hideOnEscape   = true,
    preferredIndex = 3,
}

-- ============================================================
-- API
-- ============================================================
AklimeMod_InstanceReminder = {
    IsEnabled  = function() return GetDB().enabled == true end,
    SetEnabled = function(v) GetDB().enabled = v and true or false end,
}

-- ============================================================
-- Event
-- ============================================================
local wasInInstance = false

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, _, isLogin, isReload)
    local inInstance = IsInInstanceNow()

    if not isLogin and not isReload and inInstance and not wasInInstance then
        if GetDB().enabled then
            local name = GetInstanceInfo() or L["instance_popup_instance"]
            StaticPopup_Show(POPUP_KEY, name)
        end
    end

    if not inInstance then
        StaticPopup_Hide(POPUP_KEY)
    end

    wasInInstance = inInstance
end)
