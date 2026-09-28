-- DungeonEye.lua
-- Pin the LFG eye (QueueStatusButton) to the minimap edge.
-- Default: X=-90.4 Y=-77.0 relative to Minimap CENTER (determined empirically).
-- Drag: only possible along the edge (fixed radius, only the angle changes).

AklimeMod_Defaults = AklimeMod_Defaults or {}
AklimeMod_Defaults.dungeonEye = {
    enabled = false,
    locked  = false,
    angle   = -139.6,  -- degrees, equals X=-90.4 Y=-77.0 at radius=118.7
}

-- Fixed radius (empirically from game values: sqrt(90.4²+77²) = 118.7)
local RADIUS = 118.7

local function GetDB()
    if AklimeModDB and AklimeModDB.dungeonEye then return AklimeModDB.dungeonEye end
    return AklimeMod_Defaults.dungeonEye
end

local btn    = nil
local inited = false
local FLAG   = "_akm_eye"
local origAnchor = nil

-- Angle to X/Y with a fixed radius
local function AngleToXY(deg)
    local r = math.rad(deg)
    return math.cos(r) * RADIUS, math.sin(r) * RADIUS
end

-- Position the button at the stored angle
local function Snap()
    if not btn then return end
    local x, y = AngleToXY(GetDB().angle or -139.6)
    btn[FLAG] = true
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    C_Timer.After(0, function() if btn then btn[FLAG] = nil end end)
end

local function SaveOriginal()
    if origAnchor or not btn then return end
    local point, rel, relPoint, x, y = btn:GetPoint(1)
    if not point then return end
    origAnchor = { point=point, rel=rel or UIParent, relPoint=relPoint, x=x, y=y }
end

local function Restore()
    if not btn or not origAnchor then return end
    btn[FLAG] = true
    btn:ClearAllPoints()
    btn:SetPoint(origAnchor.point, origAnchor.rel, origAnchor.relPoint, origAnchor.x, origAnchor.y)
    C_Timer.After(0, function() if btn then btn[FLAG] = nil end end)
end

local function Setup()
    if inited then return end
    btn = QueueStatusButton
    if not btn then return end

    SaveOriginal()

    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetClampedToScreen(true)

    btn:SetScript("OnDragStart", function(self)
        if not GetDB().enabled then return end
        if GetDB().locked then return end
        -- No free movement. We track the mouse directly
        -- and snap the button to the edge live
        self:SetScript("OnUpdate", function()
            local mapCX, mapCY = Minimap:GetCenter()
            if not mapCX then return end
            local mX, mY = GetCursorPosition()
            local uiScale = UIParent:GetEffectiveScale()
            mX = mX / uiScale
            mY = mY / uiScale
            local relX = mX - mapCX
            local relY = mY - mapCY
            local angle = math.atan2(relY, relX)
            local x = math.cos(angle) * RADIUS
            local y = math.sin(angle) * RADIUS
            self[FLAG] = true
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", x, y)
            C_Timer.After(0, function() if btn then btn[FLAG] = nil end end)
            GetDB().angle = math.deg(angle)
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        -- Position is already set correctly by OnUpdate
    end)

    -- Intercept Blizzard's SetPoint and correct it.
    -- Debounced: in Midnight the eye animation runs via rapid SetPoint calls.
    -- We only snap after 0.5s of silence so the animation can play uninterrupted.
    local snapTimer = nil
    hooksecurefunc(btn, "SetPoint", function(self)
        if self[FLAG] then return end
        if not GetDB().enabled then return end
        if snapTimer then snapTimer:Cancel() end
        snapTimer = C_Timer.NewTimer(0.5, function()
            snapTimer = nil
            if btn and not btn[FLAG] and GetDB().enabled then Snap() end
        end)
    end)

    inited = true
    if GetDB().enabled then Snap() end
end

-- Events
local f = CreateFrame("Frame", "AklimeMod_DungeonEye")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("LFG_UPDATE")
f:RegisterEvent("LFG_UPDATE_RANDOM_INFO")
f:RegisterEvent("LFG_PROPOSAL_SHOW")
f:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")

f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, Setup)
    elseif GetDB().enabled then
        C_Timer.After(0.1, function()
            if not inited then Setup() end
            Snap()
        end)
    end
end)

C_Timer.After(2.0, Setup)

-- API
AklimeMod_DungeonEye = {
    IsEnabled  = function() return GetDB().enabled end,
    SetEnabled = function(v)
        GetDB().enabled = v
        if v then
            if not inited then Setup() end
            Snap()
        else
            Restore()
        end
    end,
    IsLocked  = function() return GetDB().locked end,
    SetLocked = function(v)
        GetDB().locked = v
        if GetDB().enabled and v then Snap() end
    end,
}