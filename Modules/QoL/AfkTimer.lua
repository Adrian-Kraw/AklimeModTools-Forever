-- Modules/QoL/AfkTimer.lua
-- Shows a clock in the middle of the screen as soon as you are AFK.
-- It counts up how long you have been away. Position and size are
-- adjustable like the Heroism tracker, the position is saved.

local L = AklimeModL or {}

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR   = 3600
local UPDATE_INTERVAL    = 0.25
local DEFAULT_SLIDER     = 50
local PREVIEW_SECONDS    = 754   -- 12:34, only shown while positioning
local TEXT_PADDING       = 8     -- room around the text so the outline is not cut off
local POLL_INTERVAL      = 0.5   -- the AFK flag is also checked by polling, see Events

-- ============================================================
-- DB
-- ============================================================
local function GetDB()
    if AklimeModDB and AklimeModDB.afkTimer then return AklimeModDB.afkTimer end
    return {}
end

-- ============================================================
-- Time format
-- ============================================================
-- MM:SS, with hours once the break takes longer than an hour
local function FormatElapsed(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours   = math.floor(seconds / SECONDS_PER_HOUR)
    local minutes = math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
    local secs    = seconds % SECONDS_PER_MINUTE
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%02d:%02d", minutes, secs)
end

-- ============================================================
-- AFK state
-- ============================================================
-- In restricted situations the client hands out the flag as a secret value,
-- which cannot be tested. nil means unknown, the caller keeps its current state.
local function IsPlayerAfk()
    local afk = UnitIsAFK("player")
    if issecretvalue and issecretvalue(afk) then return nil end
    return afk and true or false
end

-- ============================================================
-- Frame
-- ============================================================
local M = {}
AklimeMod_AfkTimer = M

local frame      = nil
local afkSince   = nil    -- GetTime() of the moment the AFK flag appeared
local previewing = false

local function SliderToPx(v)
    -- 0 = 18px, 100 = 72px
    return math.floor(18 + v * 0.54)
end

local function SavePosition()
    local db = GetDB()
    local x, y = frame:GetCenter()
    local scale = frame:GetEffectiveScale()
    db.x = x * scale
    db.y = y * scale
end

local function ApplyPosition()
    local db = GetDB()
    frame:ClearAllPoints()
    if db.x and db.y then
        local scale = frame:GetEffectiveScale()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.x / scale, db.y / scale)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- The frame only covers the text, so it never blocks clicks next to it
local function FitFrameToText()
    local width  = frame.text:GetStringWidth()
    local height = frame.text:GetStringHeight()
    if width <= 0 or height <= 0 then return end
    frame:SetSize(width + TEXT_PADDING, height + TEXT_PADDING)
end

local function ApplyFontSize()
    if not frame then return end
    local px = SliderToPx(GetDB().fontSizeSlider or DEFAULT_SLIDER)
    frame.text:SetFont("Fonts\\FRIZQT__.TTF", px, "OUTLINE")
    FitFrameToText()
end

local function UpdateText()
    if not frame then return end
    if previewing then
        frame.text:SetText(FormatElapsed(PREVIEW_SECONDS))
    elseif afkSince then
        frame.text:SetText(FormatElapsed(GetTime() - afkSince))
    end
    FitFrameToText()
end

local function RefreshVisibility()
    if not frame then return end
    if not GetDB().enabled then
        frame:Hide()
        return
    end
    if previewing or afkSince then
        UpdateText()
        frame:Show()
    else
        frame:Hide()
    end
end

-- Locked: no mouse and no mouse scripts at all, because some clients enable
-- the mouse again as soon as such a script is set. Clicks go through the timer.
-- Unlocked: the timer can be dragged.
local function ApplyMouseState()
    if not frame then return end
    if GetDB().locked ~= false then
        frame:EnableMouse(false)
        frame:SetScript("OnMouseDown", nil)
        frame:SetScript("OnMouseUp", nil)
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        return
    end

    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["mod_afk_timer"], 1, 0.82, 0)
        GameTooltip:AddLine(L["afk_drag"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function BuildFrame()
    if frame then return end

    frame = CreateFrame("Frame", "AklimeMod_AfkTimerFrame", UIParent)
    frame:SetSize(200, 48)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", SliderToPx(GetDB().fontSizeSlider or DEFAULT_SLIDER), "OUTLINE")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetTextColor(1, 1, 1, 1)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    frame.text = text

    frame:SetMovable(true)
    ApplyMouseState()

    local sinceUpdate = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        sinceUpdate = sinceUpdate + elapsed
        if sinceUpdate < UPDATE_INTERVAL then return end
        sinceUpdate = 0
        UpdateText()
    end)

    ApplyFontSize()
    ApplyPosition()
    frame:Hide()
end

-- ============================================================
-- API
-- ============================================================
function M:IsEnabled() return GetDB().enabled == true end
-- nil and true count as locked, only an explicit false unlocks
function M:IsLocked()  return GetDB().locked ~= false end

function M:SetEnabled(v)
    GetDB().enabled = v and true or false
    if v then
        BuildFrame()
        -- Already AFK when the feature is switched on
        if IsPlayerAfk() and not afkSince then afkSince = GetTime() end
    end
    RefreshVisibility()
end

function M:SetLocked(v)
    GetDB().locked = v ~= false
    ApplyMouseState()
end

function M:GetFontSizeSlider() return GetDB().fontSizeSlider or DEFAULT_SLIDER end
function M:SetFontSizeSlider(v)
    GetDB().fontSizeSlider = v
    ApplyFontSize()
end

function M:ShowPreview()
    BuildFrame()
    previewing = true
    frame:Show()
    UpdateText()
end

function M:HidePreview()
    previewing = false
    RefreshVisibility()
end

-- ============================================================
-- Events
-- ============================================================
local function SyncAfkState()
    local afk = IsPlayerAfk()
    if afk == nil then return end
    if afk then
        if not afkSince then afkSince = GetTime() end
    else
        afkSince = nil
    end
    RefreshVisibility()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("PLAYER_FLAGS_CHANGED", "player")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if GetDB().enabled then BuildFrame() end
    end
    SyncAfkState()
end)

-- PLAYER_FLAGS_CHANGED does not reliably fire when AFK ends, so the flag is polled too
local pollSince = 0
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    pollSince = pollSince + elapsed
    if pollSince < POLL_INTERVAL then return end
    pollSince = 0
    if GetDB().enabled then SyncAfkState() end
end)
