-- Modules/Interface/MinimapElementHider.lua

local Hider = {}
local hooked = {}
local managedFrames = {}

-- Minimap position for the housing workaround.
-- Blizzard periodically moves the minimap in housing (map update, edit mode).
local savedMinimapPoint = nil
local wasHousing = false
local housingTicker = nil

local function IsHousingEditMode()
    if C_HousingLayout and C_HousingLayout.IsEditingLayout then
        return C_HousingLayout.IsEditingLayout()
    end
    return false
end

local function SaveMinimapPoint()
    local f = _G.MinimapCluster or Minimap
    if not f then return end
    local ok, point, relativeTo, relativePoint, x, y = pcall(function()
        return f:GetPoint()
    end)
    if ok and point then
        savedMinimapPoint = { point, relativeTo, relativePoint, x, y }
    end
end

local function RestoreMinimapPoint()
    if not savedMinimapPoint then return end
    local f = _G.MinimapCluster or Minimap
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint(
        savedMinimapPoint[1],
        savedMinimapPoint[2],
        savedMinimapPoint[3],
        savedMinimapPoint[4],
        savedMinimapPoint[5]
    )
end

local function StopPositionGuard()
    if housingTicker then
        housingTicker:Cancel()
        housingTicker = nil
    end
end

local function StartPositionGuard()
    if housingTicker then return end
    housingTicker = C_Timer.NewTicker(6.0, function()
        -- savedMinimapPoint is set to nil when leaving housing.
        -- If it is nil, housing was left and the ticker stops itself.
        if not savedMinimapPoint then
            StopPositionGuard()
            return
        end
        -- In edit mode, let Blizzard handle it.
        if not IsHousingEditMode() then
            RestoreMinimapPoint()
        end
    end)
end

local ELEMENTS = {
    tracking = {
        "MiniMapTracking",
        "MiniMapTrackingButton",
        "MiniMapTrackingFrame",
        "MinimapCluster.Tracking",
        "MinimapCluster.Tracking.Button",
        "MinimapCluster.TrackingFrame",
        "MinimapCluster.TrackingButton",
    },
    zoneInfo = {
        "MinimapZoneTextButton", "MinimapZoneText",
    },
    clock = {
        "TimeManagerClockButton",
    },
    calendar = {
        "GameTimeFrame",
    },
    mail = {
        "MiniMapMailFrame",
    },
    addonCompartment = {
        "AddonCompartmentFrame", "AddonCompartmentFrameButton",
    },
}

local function ResolveFrame(path)
    if not path or path == "" then return nil end
    local current = _G
    for part in path:gmatch("[^%.]+") do
        current = current and current[part]
    end
    return current
end

local function DB()
    AklimeModDB.minimapHider = AklimeModDB.minimapHider or {}
    return AklimeModDB.minimapHider
end

local function IsElementHidden(key)
    local db = DB()
    return db.enabled and db[key] == true
end

local function IsHousing()
    local inInst, instType = IsInInstance()

    -- Known housing instance types depending on the WoW build
    if inInst and (instType == "neighborhood" or instType == "interior" or instType == "home") then
        return true
    end

    -- housing can use instance types that are not regular content.
    -- Exclude known content types, treat everything else as housing.
    if inInst then
        local contentTypes = { party = true, raid = true, pvp = true, arena = true, scenario = true }
        if not contentTypes[instType] then
            return true
        end
    end

    -- housing interior: often shown as a micro map (no IsInInstance).
    if C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
            if info and info.mapType == Enum.UIMapType.Micro then
                return true
            end
        end
    end

    return false
end


local function ApplyFrame(frame, hide)
    if not frame then return end
    if hide then
        frame:Hide()
    else
        if frame.SetShown then
            frame:SetShown(true)
            return
        end
        frame:Show()
    end
end

local function RememberFrame(key, frame)
    if not key or not frame then return end
    managedFrames[key] = managedFrames[key] or {}
    managedFrames[key][frame] = true
end

local function HookFrame(frame)
    if not frame or hooked[frame] then return end
    if not frame.HookScript then return end
    hooked[frame] = true
    frame:HookScript("OnShow", function(self)
        -- Housing edit mode: Blizzard repositions minimap elements.
        -- Do not hide anything here, otherwise the minimap shifts.
        if IsHousing() then return end
        for elementKey, names in pairs(ELEMENTS) do
            for _, frameName in ipairs(names) do
                if ResolveFrame(frameName) == self and IsElementHidden(elementKey) then
                    self:Hide()
                    return
                end
            end
        end
        local name = self.GetName and self:GetName()
        if name and name:lower():find("tracking", 1, true) and managedFrames.tracking and managedFrames.tracking[self] and IsElementHidden("tracking") then
            self:Hide()
        end
    end)
end

local function ScanMinimapTrackingFrames()
    local found = {}
    local function scan(parent, depth)
        if not parent or depth > 4 then return end
        local children = { parent:GetChildren() }
        for _, child in ipairs(children) do
            local name = child.GetName and child:GetName()
            if name and name:lower():find("tracking", 1, true) then
                found[#found + 1] = child
            end
            scan(child, depth + 1)
        end
    end
    scan(Minimap, 1)
    scan(_G.MinimapCluster, 1)
    return found
end

local function ApplyManagedFrames(key, hide)
    if not managedFrames[key] then return end
    for frame in pairs(managedFrames[key]) do
        ApplyFrame(frame, hide)
    end
end

local function ApplyElement(key)
    if IsHousing() then return end
    local hide = IsElementHidden(key)
    for _, name in ipairs(ELEMENTS[key] or {}) do
        local frame = ResolveFrame(name)
        RememberFrame(key, frame)
        ApplyFrame(frame, hide)
        HookFrame(frame)
    end
    if key == "tracking" then
        for _, frame in ipairs(ScanMinimapTrackingFrames()) do
            RememberFrame(key, frame)
            ApplyFrame(frame, hide)
            HookFrame(frame)
        end
    end
    ApplyManagedFrames(key, hide)
end

function Hider.Apply()
    if IsHousing() then
        -- Show elements so the ObjectiveTracker stays positioned correctly.
        for key in pairs(ELEMENTS) do
            for _, name in ipairs(ELEMENTS[key] or {}) do
                ApplyFrame(ResolveFrame(name), false)
            end
            ApplyManagedFrames(key, false)
        end
        -- Restore minimap position on the next tick (after MinimapCluster layout).
        -- In edit mode, let Blizzard handle it.
        if not IsHousingEditMode() then
            C_Timer.After(0, RestoreMinimapPoint)
        end
        return
    end
    for key in pairs(ELEMENTS) do
        ApplyElement(key)
    end
end

function Hider.IsEnabled()
    return DB().enabled == true
end

function Hider.SetEnabled(v)
    DB().enabled = v and true or false
    Hider.Apply()
end

function Hider.Get(key)
    return DB()[key] == true
end

function Hider.Set(key, v)
    DB()[key] = v and true or false
    ApplyElement(key)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("MINIMAP_UPDATE_TRACKING")
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "Blizzard_TimeManager" and addonName ~= "Blizzard_Calendar" then return end

    local housing = IsHousing()

    if event == "PLAYER_ENTERING_WORLD" then
        if housing and not wasHousing then
            -- Overworld -> housing: save position early (before Blizzard layout).
            C_Timer.After(0.1, function()
                if not IsHousing() then return end
                SaveMinimapPoint()
            end)
            -- Start the watchdog only after the housing layout is set.
            C_Timer.After(2.0, function()
                if not IsHousing() then return end
                StartPositionGuard()
            end)
        elseif not housing then
            -- Leaving housing: stop the watchdog.
            StopPositionGuard()
            savedMinimapPoint = nil
        end
        wasHousing = housing
    end

    -- In housing, ignore MINIMAP_UPDATE_TRACKING and SPELLS_CHANGED.
    -- These fire often and would call Hider.Apply() repeatedly,
    -- which re-aligns MinimapCluster and shifts the minimap.
    if housing and (event == "MINIMAP_UPDATE_TRACKING" or event == "SPELLS_CHANGED") then
        return
    end

    if housing then
        C_Timer.After(3.0, Hider.Apply)
        return
    end
    C_Timer.After(0.2, Hider.Apply)
    C_Timer.After(1.0, Hider.Apply)
end)

AklimeMod_MinimapElementHider = Hider
