-- Modules/QoL/PlayedTime.lua
-- Played time of all characters, aggregated as a class bar chart.
-- Based on Account Played (MIT License).
-- Capture: RequestTimePlayed() on login, stored on TIME_PLAYED_MSG.
-- Output:   /akm played

local L = AklimeModL or {}

local M = {}
AklimeMod_PlayedTime = M

local FRAME_W   = 440
local FRAME_H   = 530
local ROW_H     = 28
local BAR_H     = 13
local PAD       = 12
local BAR_MAX_W = 150   -- maximum bar width in pixels
local GOLD      = { 0.80, 0.65, 0.10, 1 }
local GOLD_D    = { 0.80, 0.65, 0.10, 0.5 }
local BG        = { 0.07, 0.07, 0.08, 0.96 }

local CLASS_NAMES = GetLocale() == "deDE" and {
    WARRIOR     = "Krieger",
    PALADIN     = "Paladin",
    HUNTER      = "Jäger",
    ROGUE       = "Schurke",
    PRIEST      = "Priester",
    DEATHKNIGHT = "Todesritter",
    SHAMAN      = "Schamane",
    MAGE        = "Magier",
    WARLOCK     = "Hexenmeister",
    MONK        = "Mönch",
    DRUID       = "Druide",
    DEMONHUNTER = "Dämonenjäger",
    EVOKER      = "Rufer",
} or {
    WARRIOR     = "Warrior",
    PALADIN     = "Paladin",
    HUNTER      = "Hunter",
    ROGUE       = "Rogue",
    PRIEST      = "Priest",
    DEATHKNIGHT = "Death Knight",
    SHAMAN      = "Shaman",
    MAGE        = "Mage",
    WARLOCK     = "Warlock",
    MONK        = "Monk",
    DRUID       = "Druid",
    DEMONHUNTER = "Demon Hunter",
    EVOKER      = "Evoker",
}

local mainFrame

-- ============================================================
-- Helpers
-- ============================================================

local function GetDB()
    if AklimeModDB and AklimeModDB.playedTime then
        return AklimeModDB.playedTime
    end
    return { chars = {} }
end

local function FormatTime(seconds)
    if not seconds or seconds < 0 then return "?" end
    local days  = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins  = math.floor((seconds % 3600)  / 60)
    if days > 0 then
        return string.format(L["time_days"]  or "%dd %dh %dm", days, hours, mins)
    elseif hours > 0 then
        return string.format(L["time_hours"] or "%dh %dm", hours, mins)
    else
        return string.format(L["time_mins"]  or "%dm", mins)
    end
end

local function GetClassColor(class)
    local tbl = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {}
    local c = tbl[class]
    if c then return c.r, c.g, c.b end
    return 0.7, 0.7, 0.7
end

-- ============================================================
-- Data: aggregate characters by class
-- ============================================================

local function AggregateByClass()
    local chars = GetDB().chars
    local classes = {}
    local grand = 0

    for _, rec in pairs(chars) do
        local class = rec.class or "UNKNOWN"
        if not classes[class] then
            classes[class] = { class = class, total = 0, count = 0 }
        end
        classes[class].total = classes[class].total + (rec.total or 0)
        classes[class].count = classes[class].count + 1
        grand = grand + (rec.total or 0)
    end

    local list = {}
    for _, v in pairs(classes) do
        table.insert(list, v)
    end
    table.sort(list, function(a, b) return a.total > b.total end)

    return list, grand
end

-- ============================================================
-- Save played time
-- ============================================================

local function SavePlayedTime(total)
    local db = GetDB()
    local name  = UnitName("player")
    local realm = GetRealmName() or ""
    if not name or name == "" then return end

    local key   = name .. "-" .. realm
    local class = select(2, UnitClass("player")) or ""
    local level = UnitLevel("player") or 0

    db.chars[key] = {
        name    = name,
        realm   = realm,
        class   = class,
        level   = level,
        total   = total,
        updated = time(),
    }
end

-- ============================================================
-- Window
-- ============================================================

local function MakeSep(parent, r, g, b, a)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function BuildFrame()
    if mainFrame then return end

    mainFrame = CreateFrame("Frame", "AklimeModPlayedFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(FRAME_W, FRAME_H)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local db = GetDB()
        db.x, db.y = self:GetLeft(), self:GetTop()
    end)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    mainFrame:SetBackdropColor(BG[1], BG[2], BG[3], BG[4])
    mainFrame:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], GOLD[4])
    mainFrame:Hide()

    tinsert(UISpecialFrames, "AklimeModPlayedFrame")

    local db = GetDB()
    if db.x and db.y then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.x, db.y)
    end

    -- Title
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -13)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    title:SetText(L["played_title"] or "Played Time")

    local titleSep = MakeSep(mainFrame, GOLD_D[1], GOLD_D[2], GOLD_D[3], GOLD_D[4])
    titleSep:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  8, -32)
    titleSep:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -8, -32)

    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

    -- ScrollFrame
    local scroll = CreateFrame("ScrollFrame", "AklimeModPlayedScroll", mainFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     PAD,      -36)
    scroll:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PAD - 16, 46)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(FRAME_W - PAD * 2 - 20)
    content:SetHeight(1)
    scroll:SetScrollChild(content)

    mainFrame._scroll  = scroll
    mainFrame._content = content

    local footerSep = MakeSep(mainFrame, GOLD_D[1], GOLD_D[2], GOLD_D[3], GOLD_D[4])
    footerSep:SetPoint("BOTTOMLEFT",  mainFrame, "BOTTOMLEFT",   8, 40)
    footerSep:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -8, 40)

    mainFrame._totalLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame._totalLabel:SetPoint("BOTTOMLEFT",  mainFrame, "BOTTOMLEFT",  PAD, 20)
    mainFrame._totalLabel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PAD, 20)
    mainFrame._totalLabel:SetJustifyH("RIGHT")
    mainFrame._totalLabel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
end

local function RefreshFrame()
    if not mainFrame then return end

    local content = mainFrame._content
    for _, child in pairs({ content:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local list, grand = AggregateByClass()
    local maxTime = list[1] and list[1].total or 1
    local contentW = mainFrame._content:GetWidth()

    for i, rec in ipairs(list) do
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW_H)

        local r, g, b = GetClassColor(rec.class)
        local className = CLASS_NAMES[rec.class] or rec.class

        -- Class name on the left
        local nameLbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameLbl:SetPoint("LEFT", row, "LEFT", 0, 0)
        nameLbl:SetWidth(90)
        nameLbl:SetJustifyH("LEFT")
        nameLbl:SetTextColor(r, g, b)
        nameLbl:SetText(className)

        -- Bar background
        local barBg = row:CreateTexture(nil, "BACKGROUND")
        barBg:SetPoint("LEFT", row, "LEFT", 94, 0)
        barBg:SetSize(BAR_MAX_W, BAR_H)
        barBg:SetColorTexture(0.15, 0.15, 0.15, 1)

        -- Bar (proportional to the most played class)
        local barW = math.max(2, math.floor((rec.total / maxTime) * BAR_MAX_W))
        local bar = row:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("LEFT", barBg, "LEFT", 0, 0)
        bar:SetSize(barW, BAR_H)
        bar:SetColorTexture(r * 0.8, g * 0.8, b * 0.8, 0.9)

        -- Time
        local timeLbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timeLbl:SetPoint("LEFT", barBg, "RIGHT", 6, 0)
        timeLbl:SetWidth(115)
        timeLbl:SetJustifyH("LEFT")
        timeLbl:SetText(FormatTime(rec.total))

        -- Percent on the far right
        local pct = grand > 0 and (rec.total / grand * 100) or 0
        local pctLbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pctLbl:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        pctLbl:SetWidth(38)
        pctLbl:SetJustifyH("RIGHT")
        pctLbl:SetTextColor(0.6, 0.6, 0.6)
        pctLbl:SetText(string.format("%.1f%%", pct))

        -- Number of characters (tooltip)
        row:EnableMouse(true)
        local charCount = rec.count
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(className, r, g, b)
            GameTooltip:AddLine(charCount .. (charCount == 1 and " Char" or " Chars"), 1, 1, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Separator line
        if i < #list then
            local sep = row:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
            sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            sep:SetColorTexture(0.15, 0.15, 0.15, 1)
        end
    end

    content:SetHeight(math.max(#list * ROW_H, 1))
    -- Fit the window exactly to the content (36px header + 46px footer)
    mainFrame:SetHeight(#list * ROW_H + 82)

    C_Timer.After(0, function()
        local sb = _G["AklimeModPlayedScrollScrollBar"]
        if sb then sb:SetShown(mainFrame._scroll:GetVerticalScrollRange() > 0) end
    end)

    if #list > 0 then
        mainFrame._totalLabel:SetText(string.format(L["played_total"] or "Total: %s", FormatTime(grand)))
        mainFrame._totalLabel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        mainFrame._totalLabel:SetText(L["played_no_chars"] or "No data yet -- log in with each character once.")
        mainFrame._totalLabel:SetTextColor(0.6, 0.6, 0.6)
    end
    mainFrame._totalLabel:Show()
end

-- ============================================================
-- API
-- ============================================================

function M:Toggle()
    BuildFrame()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        RefreshFrame()
        mainFrame:Show()
    end
end

function M:Print()
    self:Toggle()
end

function M:GetSavedChars()
    local db = GetDB()
    local list = {}
    for key, rec in pairs(db.chars) do
        local className = CLASS_NAMES[rec.class] or rec.class or "?"
        local realm = rec.realm or key:match("^[^%-]+%-(.+)$") or "?"
        local display = (rec.name or key) .. " - " .. realm .. " - " .. className
        local r, g, b = GetClassColor(rec.class)
        table.insert(list, {
            key       = key,
            display   = display,
            -- Whole entry in class color
            colorized = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, display),
        })
    end
    table.sort(list, function(a, b) return a.display < b.display end)
    return list
end

function M:DeleteChar(key)
    local db = GetDB()
    db.chars[key] = nil
    if mainFrame and mainFrame:IsShown() then
        RefreshFrame()
    end
end

function M:DeleteAll()
    local db = GetDB()
    db.chars = {}
    if mainFrame and mainFrame:IsShown() then
        RefreshFrame()
    end
    print("|cFFFFD100Aklime Mod Tools:|r " .. (L["played_data_deleted"] or "Played time data deleted."))
end

-- ============================================================
-- Events
-- ============================================================

local requested = false

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TIME_PLAYED_MSG")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        if AklimeModDB and AklimeModDB.playedTime and AklimeModDB.playedTime.enabled ~= false then
            requested = true
            RequestTimePlayed()
        end
    elseif event == "TIME_PLAYED_MSG" and requested then
        requested = false
        SavePlayedTime(arg1)
    end
end)
