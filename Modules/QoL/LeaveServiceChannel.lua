-- Modules/QoL/LeaveServiceChannel.lua
-- Hides everything belonging to the "Dienste" channel in chat.
--
-- The player stays in the channel on purpose. Leaving it and joining again
-- would mean writing the channel into chatFrame.channelList, and since 12.0
-- the chat history tables are forbidden to tainted execution: every following
-- channel message would run into ChatHistory_GetAccessID and get dropped.
-- Filtering the messages needs no access to Blizzard's chat tables at all.

local CHANNEL_NAME = "Dienste"

-- Every chat event that carries a channel name in the same argument slots
local CHANNEL_EVENTS = {
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_CHANNEL_JOIN",
    "CHAT_MSG_CHANNEL_LEAVE",
    "CHAT_MSG_CHANNEL_NOTICE",
    "CHAT_MSG_CHANNEL_NOTICE_USER",
    "CHAT_MSG_CHANNEL_LIST",
}

local function GetDB()
    return AklimeModDB and AklimeModDB.leaveServiceChannel
end

local function IsEnabled()
    local db = GetDB()
    return db and db.enabled
end

local function IsInChannel()
    local idx = GetChannelName(CHANNEL_NAME)
    return idx and idx > 0
end

-- ============================================================
-- Filter
-- ============================================================
local function Matches(text)
    if type(text) ~= "string" then return false end
    if issecretvalue and issecretvalue(text) then return false end
    return text:find(CHANNEL_NAME, 1, true) ~= nil
end

-- arg4 is the channel with its number ("5. Dienste"), arg9 the plain name.
-- Notices only fill some of the slots, so both are checked.
local function ChannelFilter(_, _, _, _, _, channelString, _, _, _, _, channelBaseName)
    if not IsEnabled() then return false end
    if Matches(channelBaseName) or Matches(channelString) then return true end
    return false
end

local registered = false

local function SetFilters(on)
    if on == registered then return end
    registered = on
    for _, event in ipairs(CHANNEL_EVENTS) do
        if on then
            ChatFrame_AddMessageEventFilter(event, ChannelFilter)
        else
            ChatFrame_RemoveMessageEventFilter(event, ChannelFilter)
        end
    end
end

-- ============================================================
-- One time repair
-- ============================================================
-- Earlier versions of this module left the channel and that is stored in the
-- client config, so the channel would stay gone even with the option off.
-- Join it back once. The chat window picks it up on the next UPDATE_CHAT_WINDOWS.
local function RepairMembership()
    local db = GetDB()
    if not db or db.repaired then return end
    db.repaired = true
    if IsInChannel() then return end
    JoinPermanentChannel(CHANNEL_NAME, nil, DEFAULT_CHAT_FRAME:GetID(), 1)
end

-- ============================================================
-- Events
-- ============================================================
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(_, _, isLogin, isReload)
    if isLogin or isReload then
        SetFilters(IsEnabled() and true or false)
        C_Timer.After(3.0, RepairMembership)
    end
end)

-- ============================================================
-- API (Categories.lua)
-- ============================================================
AklimeMod_LeaveServiceChannel = {
    IsEnabled  = function() return IsEnabled() end,
    SetEnabled = function(v)
        local db = GetDB()
        if db then db.enabled = v end
        SetFilters(v and true or false)
    end,
}
