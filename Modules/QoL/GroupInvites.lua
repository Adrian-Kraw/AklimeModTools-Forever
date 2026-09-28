-- Modules/QoL/GroupInvites.lua
-- Block or automatically accept group invites.
-- Blocking and auto-accept are mutually exclusive.

local function GetDB()
    if AklimeModDB and AklimeModDB.groupInvites then return AklimeModDB.groupInvites end
    return {}
end

-- ============================================================
-- Helpers
-- ============================================================
local function IsGuildMember(name)
    local total = GetNumGuildMembers()
    if not total or total == 0 then return false end
    for i = 1, total do
        local memberName = GetGuildRosterInfo(i)
        if memberName == name then return true end
    end
    return false
end

local function IsFriend(unitID)
    if C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID then
        if C_BattleNet.GetGameAccountInfoByGUID(unitID) then return true end
    end
    if C_FriendList then
        for i = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.guid == unitID then return true end
        end
    end
    return false
end

-- ============================================================
-- API
-- ============================================================
local M = {}
AklimeMod_GroupInvites = M

function M:IsBlockEnabled()        return GetDB().block             == true end
function M:IsBlockExceptGuild()    return GetDB().blockExceptGuild  == true end
function M:IsBlockExceptFriend()   return GetDB().blockExceptFriend == true end
function M:IsAutoAcceptEnabled()   return GetDB().autoAccept        == true end
function M:IsGuildOnly()           return GetDB().guildOnly         == true end
function M:IsFriendOnly()          return GetDB().friendOnly        == true end

function M:SetBlock(v)
    GetDB().block = v and true or false
    if v then GetDB().autoAccept = false end
end

function M:SetBlockExceptGuild(v)  GetDB().blockExceptGuild  = v and true or false end
function M:SetBlockExceptFriend(v) GetDB().blockExceptFriend = v and true or false end

function M:SetAutoAccept(v)
    GetDB().autoAccept = v and true or false
    if v then GetDB().block = false end
end

function M:SetGuildOnly(v)  GetDB().guildOnly  = v and true or false end
function M:SetFriendOnly(v) GetDB().friendOnly = v and true or false end

-- ============================================================
-- Event
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PARTY_INVITE_REQUEST")
eventFrame:SetScript("OnEvent", function(_, _, unitName, _, _, _, _, _, unitID)
    local db = GetDB()

    if db.autoAccept then
        local guildOnly  = db.guildOnly  == true
        local friendOnly = db.friendOnly == true

        if guildOnly or friendOnly then
            local ok = (guildOnly and IsGuildMember(unitName))
                    or (friendOnly and IsFriend(unitID))
            if ok then
                AcceptGroup()
                StaticPopup_Hide("PARTY_INVITE")
            end
            return
        end

        -- No filter: accept all
        AcceptGroup()
        StaticPopup_Hide("PARTY_INVITE")
        return
    end

    if db.block then
        -- Check exceptions: accept the invite despite the block
        if db.blockExceptGuild and IsGuildMember(unitName) then return end
        if db.blockExceptFriend and IsFriend(unitID) then return end
        DeclineGroup()
        StaticPopup_Hide("PARTY_INVITE")
    end
end)
