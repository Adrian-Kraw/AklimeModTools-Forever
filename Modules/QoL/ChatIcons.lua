-- Modules/QoL/ChatIcons.lua
-- Shows item and currency icons as well as item level before/in chat links.

local ICON_SIZE = 12
local ITEM_LINK_PATTERN     = "|Hitem:.-|h%[.-%]|h|r"
local CURRENCY_LINK_PATTERN = "(|Hcurrency:(%d+)[^|]*|h%[[^%]]+%]|h|r)"

local CHAT_EVENTS = {
    "CHAT_MSG_LOOT",
    "CHAT_MSG_CURRENCY",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_BATTLEGROUND",
    "CHAT_MSG_BATTLEGROUND_LEADER",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_SYSTEM",
    "CHAT_MSG_ACHIEVEMENT",
    "CHAT_MSG_GUILD_ACHIEVEMENT",
    "CHAT_MSG_GUILD_ITEM_LOOTED",
}

local function GetDB()
    if AklimeModDB and AklimeModDB.chatIcons then return AklimeModDB.chatIcons end
    return { enabled = false, itemLevel = false, showSlot = false }
end

-- ============================================================
-- Helpers
-- ============================================================

local function GetItemTexture(link)
    local itemID = link:match("item:(%d+)")
    if itemID and C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(tonumber(itemID))
    end
    return nil
end

local function AppendIcon(texture, link)
    if not texture then return link end
    return string.format("|T%s:%d|t%s", texture, ICON_SIZE, link)
end

local function FormatCurrencyLink(link, id)
    id = tonumber(id)
    if not id or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return link end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    return AppendIcon(info and (info.iconFileID or info.icon), link)
end

local function FormatItemLinkWithLevel(link)
    -- Extract link parts: hyperlink part, label, suffix
    local prefix, label, suffix = link:match("^(|Hitem:[^|]+|h)%[(.-)%](|h|r)$")
    if not prefix or not label or not suffix then return link end

    local level, equipLoc
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        level = C_Item.GetDetailedItemLevelInfo(link)
    end
    if C_Item and C_Item.GetItemInfo then
        local _, _, _, baseLevel, _, _, _, _, itemEquipLoc = C_Item.GetItemInfo(link)
        equipLoc = itemEquipLoc
        if not level or level == 0 then level = baseLevel end
    end

    -- Equippable items only
    if not level or level <= 0 then return link end
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then return link end

    local parts = {}
    if GetDB().showSlot and _G[equipLoc] then
        parts[#parts + 1] = _G[equipLoc]
    end
    parts[#parts + 1] = tostring(level)

    local suffix_text = table.concat(parts, " ")
    if suffix_text == "" then return link end

    return prefix .. "[" .. label .. " (" .. suffix_text .. ")]" .. suffix
end

-- ============================================================
-- Filter
-- ============================================================

local registeredEvents = {}

local function FilterChatMessage(_, event, message, ...)
    if issecretvalue and issecretvalue(message) then return end
    if type(message) ~= "string" or message == "" then return false end

    local db = GetDB()

    message = message:gsub(ITEM_LINK_PATTERN, function(link)
        if db.itemLevel then link = FormatItemLinkWithLevel(link) end
        if db.enabled   then link = AppendIcon(GetItemTexture(link), link) end
        return link
    end)

    if db.enabled and (event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_CURRENCY") then
        message = message:gsub(CURRENCY_LINK_PATTERN, FormatCurrencyLink)
    end

    return false, message, ...
end

local function NeedsFilter()
    local db = GetDB()
    return db.enabled == true or db.itemLevel == true
end

local function UpdateFilterRegistration()
    if NeedsFilter() then
        for _, event in ipairs(CHAT_EVENTS) do
            if not registeredEvents[event] then
                ChatFrame_AddMessageEventFilter(event, FilterChatMessage)
                registeredEvents[event] = true
            end
        end
    else
        for event in pairs(registeredEvents) do
            ChatFrame_RemoveMessageEventFilter(event, FilterChatMessage)
        end
        registeredEvents = {}
    end
end

-- ============================================================
-- API
-- ============================================================

local M = {}
AklimeMod_ChatIcons = M

function M:IsEnabled()
    return GetDB().enabled == true
end

function M:SetEnabled(v)
    GetDB().enabled = v and true or false
    UpdateFilterRegistration()
end

function M:IsItemLevelEnabled()
    return GetDB().itemLevel == true
end

function M:SetItemLevelEnabled(v)
    GetDB().itemLevel = v and true or false
    UpdateFilterRegistration()
end

function M:IsShowSlotEnabled()
    return GetDB().showSlot == true
end

function M:SetShowSlotEnabled(v)
    GetDB().showSlot = v and true or false
end

-- ============================================================
-- Init
-- ============================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    UpdateFilterRegistration()
end)
