-- Modules/QoL/ChatFontSize.lua
-- Sets a chosen chat font size once per character, only if this character
-- has not been touched by this feature before (does not fight later manual
-- changes). Sizes match Blizzard's own chat font size selection (CHAT_FONT_HEIGHTS).

local DEFAULT_SIZE = 16
local SIZES = { 12, 14, 16, 18, 20, 24, 27 }

local function GetDB()
    if AklimeModDB and AklimeModDB.chatFontSize then return AklimeModDB.chatFontSize end
    return nil
end

local function GetCharKey()
    local name  = UnitName("player")
    local realm = GetRealmName()
    if name and realm then return name .. " - " .. realm end
    return nil
end

local function ApplySizeToAllWindows(size)
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            FCF_SetChatWindowFontSize(nil, cf, size)
        end
    end
end

local function ApplyIfNotSet()
    local db = GetDB()
    if not db or not db.enabled then return end
    local key = GetCharKey()
    if not key or db.appliedChars[key] then return end
    ApplySizeToAllWindows(db.size or DEFAULT_SIZE)
    db.appliedChars[key] = true
end

-- ============================================================
-- API
-- ============================================================
AklimeMod_ChatFontSize = {}

function AklimeMod_ChatFontSize.IsEnabled()
    local db = GetDB()
    return db and db.enabled == true
end

function AklimeMod_ChatFontSize.SetEnabled(v)
    local db = GetDB()
    if not db then return end
    db.enabled = v and true or false
    if db.enabled then ApplyIfNotSet() end
end

function AklimeMod_ChatFontSize.GetSize()
    local db = GetDB()
    return (db and db.size) or DEFAULT_SIZE
end

function AklimeMod_ChatFontSize.SetSize(size)
    local db = GetDB()
    if not db then return end
    db.size = size
    ApplySizeToAllWindows(size)
    -- Picking a size manually counts as "already set" for this character,
    -- so the next login does not silently override it again.
    local key = GetCharKey()
    if key then db.appliedChars[key] = true end
end

function AklimeMod_ChatFontSize.GetSizes()
    return SIZES
end

-- ============================================================
-- Events
-- ============================================================
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", ApplyIfNotSet)
