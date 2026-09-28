-- Modules/QoL/HideMicroNotifications.lua
-- Hides notification badges (blue diamond) on Micro Menu buttons
-- and the unspent talent points alert.
--
-- Frame children of a MicroButton (GetNumChildren) are exclusively
-- notification overlays. Textures / regions (emblem, portrait) are
-- regions, not children, so they are not touched here.

local BUTTONS = {
    "ProfessionMicroButton",
    "PlayerSpellsMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "GuildMicroButton",
}

local hooked = {}

local function IsEnabled()
    local db = AklimeModDB and AklimeModDB.hideMicroNotifications
    return db and db.enabled
end

local function Suppress(f)
    if not f or hooked[f] then return end
    hooked[f] = true
    f:HookScript("OnShow", function(self)
        if IsEnabled() then self:Hide() end
    end)
    if IsEnabled() and f.IsShown and f:IsShown() then f:Hide() end
end

local function Apply()
    for _, btnName in ipairs(BUTTONS) do
        local btn = _G[btnName]
        if btn then
            for i = 1, btn:GetNumChildren() do
                Suppress(select(i, btn:GetChildren()))
            end
        end
    end
    -- Banner-style alert frames that pop up above the micro menu
    for i = 1, 4 do
        Suppress(_G["MicroButtonAlertFrame" .. i])
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" then
        if addon == "AklimeModTools" then
            frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        elseif addon == "Blizzard_MicroMenu"
            or addon == "Blizzard_StoreUI"
            or addon == "Blizzard_EncounterJournal"
        then
            -- Badges may be created slightly after the addon loads
            C_Timer.After(0.5, function() if IsEnabled() then Apply() end end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Delay gives Blizzard time to create notification children
        C_Timer.After(2, function() if IsEnabled() then Apply() end end)
    end
end)

AklimeMod_HideMicroNotifications = {
    IsEnabled  = function() return IsEnabled() end,
    SetEnabled = function(v)
        local db = AklimeModDB and AklimeModDB.hideMicroNotifications
        if db then db.enabled = v end
        if v then
            C_Timer.After(0.5, Apply)
        end
    end,
}
