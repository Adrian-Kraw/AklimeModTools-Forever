-- Modules/Interface/CombatTooltip.lua
-- Hides the HUD tooltip during combat.
-- Reappears after combat when the mouse hovers over something again.

local M = {}
AklimeMod_CombatTooltip = M

local inCombat = false

local function GetDB()
    if AklimeModDB and AklimeModDB.combatTooltip then return AklimeModDB.combatTooltip end
    return { enabled = false }
end

-- ============================================================
-- Aura detection
-- ============================================================

local function IsAuraTooltip(tooltip)
    -- Method 1: TooltipData API (Dragonflight/TWW). Checks the content type directly
    if tooltip.GetTooltipData then
        local data = tooltip:GetTooltipData()
        if data then
            local auraType = Enum.TooltipDataType and Enum.TooltipDataType.UnitAura
            if auraType and data.type == auraType then return true end
        end
    end
    -- Method 2: owner frame hierarchy. Used when the TooltipData API is not available
    local owner = tooltip:GetOwner()
    if owner and owner.IsDescendantOf then
        if BuffFrame and owner:IsDescendantOf(BuffFrame) then return true end
        local df = _G["DebuffFrame"]
        if df and owner:IsDescendantOf(df) then return true end
    end
    return false
end

-- ============================================================
-- Hook
-- ============================================================

GameTooltip:HookScript("OnShow", function(self)
    local db = GetDB()
    if not db.enabled or not inCombat then return end
    if db.allowAuras and IsAuraTooltip(self) then return end
    self:Hide()
end)

-- ============================================================
-- Events
-- ============================================================

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        local db = GetDB()
        if db.enabled then
            if not (db.allowAuras and IsAuraTooltip(GameTooltip)) then
                GameTooltip:Hide()
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end
end)

-- ============================================================
-- API
-- ============================================================

function M:IsEnabled()
    return GetDB().enabled == true
end

function M:SetEnabled(v)
    GetDB().enabled = v and true or false
    if v and inCombat then
        GameTooltip:Hide()
    end
end

function M:AllowsAuras()
    return GetDB().allowAuras == true
end

function M:SetAllowAuras(v)
    GetDB().allowAuras = v and true or false
end
