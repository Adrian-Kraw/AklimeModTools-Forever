-- Modules/Interface/DamageMeterCollapseDown.lua
-- Damage meter: hide the empty area by collapsing it downward.
-- Blizzard hides the MinimizeContainer but leaves the frame at full height.
-- We set the height to the header height after the click.

local function GetDB()
    return AklimeModDB and AklimeModDB.damageMeterCollapseDown
end

local function IsEnabled()
    local db = GetDB()
    return db and db.enabled
end

local function GetWindowDB(idx)
    local db = AklimeModDB and AklimeModDB.damageMeterCollapseDown
    if not db then return nil end
    db.windows = db.windows or {}
    db.windows[idx] = db.windows[idx] or {}
    return db.windows[idx]
end

local function PatchWindow(sw)
    if not sw or sw._dmcd_patched then return end
    sw._dmcd_patched = true

    local mb = sw.MinimizeButton
    if not mb then return end

    local header = sw.Header
    local idx    = sw.sessionWindowIndex or 1
    local wdb    = GetWindowDB(idx)

    -- On login: if minimized and a position is stored, correct it immediately
    -- and restore the _dmcd_* variables from the DB so the click handler works
    C_Timer.After(0.5, function()
        wdb = GetWindowDB(idx)
        if wdb and wdb.absLeft and wdb.fullH then
            sw._dmcd_absLeft   = wdb.absLeft
            sw._dmcd_absBottom = wdb.absBottom
            sw._dmcd_fullH     = wdb.fullH
            sw._dmcd_fullW     = wdb.fullW
            sw._dmcd_origPoint = { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", wdb.absLeft, wdb.absBottom - wdb.fullH }
            if sw.isMinimized then
                local headerH = header and math.ceil(header:GetHeight()) or 32
                sw:ClearAllPoints()
                sw:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", wdb.absLeft, wdb.absBottom)
                if wdb.fullW then sw:SetWidth(wdb.fullW) end
                sw:SetHeight(headerH)
            else
                -- Expanded: apply saved size only, position is managed by Blizzard
                if wdb.fullW then sw:SetWidth(wdb.fullW) end
                sw:SetHeight(wdb.fullH)
            end
        end
    end)

    mb:HookScript("OnClick", function()
        if not IsEnabled() then return end

        -- Save the position BEFORE Blizzard's action
        if not sw._dmcd_origPoint then
            local p1, relTo, p2, x, y = sw:GetPoint()
            sw._dmcd_origPoint = { p1, relTo, p2, x, y }
            sw._dmcd_fullH = sw:GetHeight()
            sw._dmcd_fullW = sw:GetWidth()
            sw._dmcd_absLeft   = sw:GetLeft()
            sw._dmcd_absBottom = sw:GetBottom()
            -- Save to DB for reload
            wdb = GetWindowDB(idx)
            if wdb then
                wdb.absLeft   = sw._dmcd_absLeft
                wdb.absBottom = sw._dmcd_absBottom
                wdb.fullH     = sw._dmcd_fullH
                wdb.fullW     = sw._dmcd_fullW
            end
        end

        C_Timer.After(0, function()
            local headerH = header and math.ceil(header:GetHeight()) or 32
            local left   = sw._dmcd_absLeft   or sw:GetLeft()
            local bottom = sw._dmcd_absBottom or sw:GetBottom()
            local fullH  = sw._dmcd_fullH     or sw:GetHeight()
            local fullW  = sw._dmcd_fullW     or sw:GetWidth()

            if sw.isMinimized then
                -- Collapsed: header height, absolute bottom position
                sw:ClearAllPoints()
                sw:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
                sw:SetWidth(fullW)
                sw:SetHeight(headerH)
            else
                -- Expanded: full height, same bottom position
                sw:ClearAllPoints()
                sw:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
                sw:SetWidth(fullW)
                sw:SetHeight(fullH)
            end
        end)
    end)
end

local function PatchAllWindows()
    if not DamageMeter then return end
    local maxCount = (DamageMeterMixin and DamageMeterMixin:GetMaxSessionWindowCount()) or 5
    for i = 1, maxCount do
        PatchWindow(_G["DamageMeterSessionWindow" .. i])
    end
    if not DamageMeter._dmcd_hooked then
        DamageMeter._dmcd_hooked = true
        hooksecurefunc(DamageMeter, "SetupSessionWindow", function(_, _, idx)
            C_Timer.After(0.1, function()
                PatchWindow(_G["DamageMeterSessionWindow" .. idx])
            end)
        end)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "AklimeModTools" then
            frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        elseif arg1 == "Blizzard_DamageMeter" then
            C_Timer.After(1.0, function()
                if IsEnabled() then PatchAllWindows() end
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if DamageMeter and IsEnabled() then
            C_Timer.After(1.0, PatchAllWindows)
        end
    end
end)

AklimeMod_DamageMeterCollapseDown = {
    IsEnabled  = function() return IsEnabled() end,
    SetEnabled = function(v)
        local db = GetDB()
        if db then db.enabled = v end
        if v and DamageMeter then PatchAllWindows() end
    end,
}