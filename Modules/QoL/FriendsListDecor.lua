-- Modules/QoL/FriendsListDecor.lua

local function GetDB()
    if AklimeModDB and AklimeModDB.friendsListDecor then return AklimeModDB.friendsListDecor end
    return { enabled = false, showLocation = true, hideOwnRealm = true }
end

local tUnpack = unpack
local select = select
local strsplit = strsplit
local format = string.format
local ipairs = ipairs
local floor = math.floor
local max = math.max
local min = math.min

local UnitFullName = UnitFullName
local GetRealmName = GetRealmName
local GetQuestDifficultyColor = GetQuestDifficultyColor
local TimerunningUtil_AddSmallIcon = TimerunningUtil and TimerunningUtil.AddSmallIcon

local localizedClassMap = {}
if LOCALIZED_CLASS_NAMES_MALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        if type(name) == "string" and name ~= "" then localizedClassMap[name] = token end
    end
end
if LOCALIZED_CLASS_NAMES_FEMALE then
    for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
        if type(name) == "string" and name ~= "" and not localizedClassMap[name] then localizedClassMap[name] = token end
    end
end

local factionLookup = {}
local function RegisterFactionKeys(faction, ...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "string" and value ~= "" then factionLookup[value:lower()] = faction end
    end
end
RegisterFactionKeys("Alliance", "Alliance", ALLIANCE, FACTION_ALLIANCE, PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[1])
RegisterFactionKeys("Horde", "Horde", HORDE, FACTION_HORDE, PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[0])

local function NormalizeFactionName(name)
    if type(name) ~= "string" then return nil end
    return factionLookup[name:lower()]
end

local function CleanRealmName(realm)
    if type(realm) ~= "string" then return nil end
    local cleaned = realm:gsub("%(%*%)", ""):gsub("%*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleaned == "" then return nil end
    return cleaned
end

local function NormalizeRealmWithoutSpecials(realm)
    if type(realm) ~= "string" then return nil end
    local normalized = realm:gsub("[%s%-']", ""):lower()
    if normalized == "" then return nil end
    return normalized
end

local playerRealmNormalized do
    local playerRealm = GetRealmName and GetRealmName()
    if (not playerRealm or playerRealm == "") and UnitFullName then
        playerRealm = select(2, UnitFullName("player"))
    end
    if playerRealm and playerRealm ~= "" then
        local cleaned = CleanRealmName(playerRealm)
        playerRealmNormalized = cleaned and NormalizeRealmWithoutSpecials(cleaned) or nil
    end
end

local function GetRealmDisplayText(realm)
    local cleaned = CleanRealmName(realm)
    if not cleaned then return nil end
    local normalized = NormalizeRealmWithoutSpecials(cleaned)
    if normalized and playerRealmNormalized and normalized == playerRealmNormalized and GetDB().hideOwnRealm then return nil end
    return cleaned
end

local function BuildLocationText(areaText, realmText)
    if not GetDB().showLocation then return nil end
    local area = (type(areaText) == "string" and areaText ~= "") and areaText or nil
    local realm = GetRealmDisplayText(realmText)
    if area and realm then return ("%s - %s"):format(area, realm) end
    return area or realm or nil
end

local FACTION_ASSETS = {
    Alliance = {
        atlas    = "FactionIcon-Alliance",
        textures = { "Interface\\FriendsFrame\\PlusManz-Alliance", "Interface\\PVPFrame\\PVP-Currency-Alliance" },
    },
    Horde = {
        atlas    = "FactionIcon-Horde",
        textures = { "Interface\\FriendsFrame\\PlusManz-Horde", "Interface\\PVPFrame\\PVP-Currency-Horde" },
    },
}

local STATUS_TEXTURES = {
    Online  = FRIENDS_TEXTURE_ONLINE,
    Offline = FRIENDS_TEXTURE_OFFLINE,
    AFK     = FRIENDS_TEXTURE_AFK,
    DND     = FRIENDS_TEXTURE_DND,
    Mobile  = FRIENDS_TEXTURE_MOBILE or FRIENDS_TEXTURE_ONLINE,
}

local CLIENT_COLORS = {
    [BNET_CLIENT_WOW] = { r = 0.866, g = 0.69,  b = 0.18  },
    APP               = { r = 0.509, g = 0.772, b = 1     },
    WTCG              = { r = 1,     g = 0.694, b = 0     },
    Hero              = { r = 0,     g = 0.8,   b = 1     },
    D3                = { r = 0.768, g = 0.121, b = 0.231 },
}

local function RGBToHex(r, g, b)
    if not r or not g or not b then return nil end
    return format("%02x%02x%02x", min(255, floor(r * 255 + 0.5)), min(255, floor(g * 255 + 0.5)), min(255, floor(b * 255 + 0.5)))
end

local function WrapColor(text, r, g, b)
    if not text or text == "" then return text end
    local hex = RGBToHex(r, g, b)
    if not hex then return text end
    return ("|cff%s%s|r"):format(hex, text)
end

local function ColorClientText(text, clientProgram)
    if not text or text == "" then return text end
    local color = CLIENT_COLORS[clientProgram] or CLIENT_COLORS[clientProgram and clientProgram:upper()]
    if color then return WrapColor(text, color.r, color.g, color.b) end
    return text
end

local function FormatLevel(level)
    if not level or level <= 0 then return nil end
    if not GetQuestDifficultyColor then return tostring(level) end
    local color = GetQuestDifficultyColor(level)
    if not color then return tostring(level) end
    return WrapColor(tostring(level), color.r, color.g, color.b)
end

local function GetClassColorFromToken(token)
    if not token or token == "" then return nil end
    local colorObj = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token)
    if colorObj and colorObj.r then return colorObj.r, colorObj.g, colorObj.b end
    if RAID_CLASS_COLORS then
        local color = RAID_CLASS_COLORS[token]
        if color and color.r then return color.r, color.g, color.b end
    end
    return nil
end

local function ResolveClassToken(classToken, classID, localizedName)
    if type(classToken) == "string" and classToken ~= "" then
        local token = classToken
        if localizedClassMap[token] then token = localizedClassMap[token] end
        token = token:upper()
        local r = GetClassColorFromToken(token)
        if r then return token end
    end
    if classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info and info.classFile and GetClassColorFromToken(info.classFile) then return info.classFile end
    end
    if type(localizedName) == "string" then
        local token = localizedClassMap[localizedName]
        if token and GetClassColorFromToken(token) then return token end
    end
    return nil
end

local function GetClassColor(classToken, classID, localizedName)
    local token = ResolveClassToken(classToken, classID, localizedName)
    if not token then return nil end
    return GetClassColorFromToken(token)
end

local function SetStatusIcon(button, status)
    if not button or not button.status or not status then return end
    local texture = STATUS_TEXTURES[status]
    if texture then button.status:SetTexture(texture); button.status:Show() end
end

local function SetFactionIcon(button, factionName)
    if not button then return end
    local texture = button._aklimeFactionIcon

    if factionName == nil then
        if texture then texture:SetTexture(nil); texture:Hide() end
        return
    end

    if not texture then
        texture = button:CreateTexture(nil, "OVERLAY", nil, 1)
        texture:SetSize(16, 16)
        if button.name and button.name.GetObjectType and button.name:GetObjectType() == "FontString" then
            texture:SetPoint("LEFT", button.name, "RIGHT", 4, 0)
        else
            texture:SetPoint("LEFT", button, "LEFT", 200, 0)
        end
        button._aklimeFactionIcon = texture
    end

    local faction = NormalizeFactionName(factionName)
    local asset = faction and FACTION_ASSETS[faction]

    if asset then
        local applied = false
        if asset.atlas and texture.SetAtlas then
            local ok = pcall(texture.SetAtlas, texture, asset.atlas)
            if ok then texture:SetTexCoord(0, 1, 0, 1); texture:Show(); applied = true end
        end
        if not applied and asset.textures then
            for _, texturePath in ipairs(asset.textures) do
                if type(texturePath) == "string" then
                    texture:SetTexCoord(0, 1, 0, 1)
                    texture:SetTexture(texturePath)
                    if texture:GetTexture() then texture:Show(); applied = true; break end
                end
            end
        end
        if not applied then texture:SetTexture(nil); texture:Hide() end
    else
        texture:SetTexture(nil); texture:Hide()
    end
end


local M = {}
AklimeMod_FriendsListDecor = M

local starReplacements = {}

-- isFavorite must come from data (hook-cached state or API), not from button.Favorite:IsShown(),
-- because we hide button.Favorite ourselves -- re-reading IsShown() would always see false.
local function MoveStarRight(button, nameFont, isFavorite)
    local repl = starReplacements[button]
    if not isFavorite then
        if repl then repl:Hide() end
        return
    end

    local star = button.Favorite
    if not star then
        if repl then repl:Hide() end
        return
    end

    -- Hide the original, it would land outside the clip region
    star:Hide()

    if not repl then
        repl = button:CreateTexture(nil, "ARTWORK", nil, 7)
        repl:SetAtlas("friendslist-favorite")
        repl:SetSize(17, 17)
        starReplacements[button] = repl
    end

    repl:ClearAllPoints()
    if nameFont then
        repl:SetPoint("LEFT", nameFont, "LEFT", nameFont:GetStringWidth() + 2, 0)
    else
        repl:SetPoint("LEFT", button, "LEFT", 280, 0)
    end
    repl:Show()
end

local function DecorateWoWFriend(button)
    local nameFont = button and button.name
    local infoFont = button and button.info
    if not nameFont then return end
    if not C_FriendList or not C_FriendList.GetFriendInfoByIndex then return end

    local id = button.id
    if not id then return end

    local info = C_FriendList.GetFriendInfoByIndex(id)
    if not info or not info.name then return end

    local isConnected = info.connected == true
    local status = isConnected and (info.dnd and "DND" or info.afk and "AFK" or "Online") or "Offline"
    SetStatusIcon(button, status)

    local baseName, realm = strsplit("-", info.name, 2)
    baseName = baseName or info.name or ""
    local levelText = FormatLevel(info.level)

    local nameColored = baseName
    if isConnected then
        local localizedName = info.className or info.classLocalized or info.class
        local token = info.classTag or info.classFileName or info.classFile or info.classToken
        local r, g, b = GetClassColor(token, info.classID, localizedName)
        if not r and localizedName then r, g, b = GetClassColor(nil, info.classID, localizedName) end
        if r then nameColored = WrapColor(baseName, r, g, b) end
    else
        nameColored = WrapColor(baseName, 0.6, 0.6, 0.6)
    end

    local displayName = nameColored
    if levelText and levelText ~= "" then displayName = ("%s %s"):format(nameColored, levelText) end
    nameFont:SetText(displayName)
    if not isConnected then nameFont:SetTextColor(0.6, 0.6, 0.6) end

    if infoFont then
        if isConnected then
            -- Online: show area and realm.
            infoFont:SetText(BuildLocationText(info.area, realm) or "")
        end
        -- Offline: do not touch, Blizzard shows "Last online".
    end

    SetFactionIcon(button, nil)
    if button.gameIcon then button.gameIcon:SetTexCoord(0, 1, 0, 1) end
    MoveStarRight(button, nameFont, button._aklimeFavState == true)
end

local function DecorateBNetFriend(button)
    if not C_BattleNet or not C_BattleNet.GetFriendAccountInfo then return end
    local nameFont = button and button.name
    local infoFont = button and button.info
    if not nameFont then return end

    local id = button.id
    if not id then return end

    local accountInfo = C_BattleNet.GetFriendAccountInfo(id)
    if not accountInfo then return end

    local gameInfo = accountInfo.gameAccountInfo
    local isInGame = gameInfo and gameInfo.isOnline == true
    local isMobile = isInGame and gameInfo.clientProgram == (BNET_CLIENT_MOBILE or "BSAp")
    local isOnline = isInGame
    local status
    if isMobile then
        if accountInfo.isDND then status = "DND"
        elseif accountInfo.isAFK then status = "AFK"
        else status = "Mobile" end
    elseif isInGame then
        if accountInfo.isDND or (gameInfo.isGameBusy == true) then status = "DND"
        elseif accountInfo.isAFK or (gameInfo.isGameAFK == true) then status = "AFK"
        else status = "Online" end
    else
        status = "Offline"
    end
    SetStatusIcon(button, status)

    local realID = accountInfo.accountName or (accountInfo.battleTag and accountInfo.battleTag:match("^[^#]+"))
    local displayName = realID or ""
    local infoText = ""
    local factionName = nil

    if gameInfo and gameInfo.clientProgram == BNET_CLIENT_WOW then
        local localizedName = gameInfo.className or gameInfo.classLocalized or gameInfo.class
        local token = gameInfo.classTag or gameInfo.classFile or gameInfo.classToken
        local charName = gameInfo.characterName or ""
        local levelText = FormatLevel(gameInfo.characterLevel)
        if levelText and levelText ~= "" then
            charName = charName ~= "" and ("%s %s"):format(charName, levelText) or levelText
        end
        local r, g, b = GetClassColor(token, gameInfo.classID, localizedName)
        if r then charName = WrapColor(charName, r, g, b) end
        if TimerunningUtil_AddSmallIcon and gameInfo.timerunningSeasonID then
            charName = TimerunningUtil_AddSmallIcon(charName) or charName
        end

        local clientDisplay = ColorClientText(realID or "", gameInfo.clientProgram)
        if clientDisplay ~= "" and charName ~= "" then
            displayName = clientDisplay .. " " .. charName
        elseif charName ~= "" then
            displayName = charName
        elseif clientDisplay ~= "" then
            displayName = clientDisplay
        end

        local location = BuildLocationText(gameInfo.areaName, gameInfo.realmDisplayName)
        if location and location ~= "" then
            infoText = location
        elseif GetDB().showLocation then
            infoText = gameInfo.richPresence or accountInfo.note or ""
        else
            infoText = accountInfo.note or ""
        end
        factionName = gameInfo.factionName
    else
        if gameInfo and gameInfo.clientProgram then
            displayName = ColorClientText(realID or "", gameInfo.clientProgram)
            if displayName == "" then displayName = realID or "" end
        end
        infoText = (gameInfo and gameInfo.richPresence) or accountInfo.note or ""
        if isMobile and (not infoText or infoText == "") then
            infoText = AklimeModL["friends_mobile"] or "Mobile"
        end
    end

    nameFont:SetText(displayName)
    if not isOnline then nameFont:SetTextColor(0.6, 0.6, 0.6) end
    -- Only set the info line when online or there is actually text.
    -- Offline without text: Blizzard shows "Last online", do not overwrite.
    if infoFont then
        if isOnline or (infoText and infoText ~= "") then
            infoFont:SetText(infoText or "")
        end
    end

    SetFactionIcon(button, factionName)

    if button.gameIcon then
        if gameInfo and gameInfo.clientTexture then
            button.gameIcon:SetTexture(gameInfo.clientTexture)
            button.gameIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
        else
            button.gameIcon:SetTexCoord(0, 1, 0, 1)
        end
    end

    MoveStarRight(button, nameFont, accountInfo.isFavorite == true)
end

-- Checks whether a button belongs to the housing system.
-- FriendsFrame_UpdateFriendButton is called by the housing system for contact buttons.
-- The housing popup is often a child of FriendsFrame, so IsDescendantOf(FriendsFrame)
-- alone is not enough. Housing buttons would be wrongly detected as friend buttons.
-- Addon code that writes to housing buttons taints them and blocks VisitHouse().
local function IsHousingButton(button)
    -- Explicit check against known housing frame globals (Blizzard_HouseList addon)
    local housingFrame = _G["HouseListFrame"]
    if housingFrame and button.IsDescendantOf and button:IsDescendantOf(housingFrame) then
        return true
    end
    -- Fallback: search the parent chain for "HouseList" in the frame name (read only, no taint)
    local frame = button:GetParent()
    local depth = 0
    while frame and depth < 8 do
        local name = frame:GetName()
        if name and name:find("HouseList", 1, true) then return true end
        frame = frame:GetParent()
        depth = depth + 1
    end
    return false
end

local function UpdateFriendButton(button)
    if not button or not button.buttonType then return end
    -- Never touch housing buttons, even if they are FriendsFrame descendants.
    if IsHousingButton(button) then return end
    if not GetDB().enabled then
        if button._aklimeFactionIcon then button._aklimeFactionIcon:Hide() end
        local repl = starReplacements[button]
        if repl then repl:Hide() end
        return
    end

    -- Only decorate buttons inside FriendsFrame.
    if FriendsFrame and button.IsDescendantOf and not button:IsDescendantOf(FriendsFrame) then
        return
    end

    if button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
        DecorateWoWFriend(button)
    elseif button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
        DecorateBNetFriend(button)
    else
        if button._aklimeFactionIcon then button._aklimeFactionIcon:Hide() end
    end
end

-- Buttons to be decorated on the next OnUpdate.
-- The hook only writes into this table (no frame code in the Blizzard tick).
-- OnUpdate reads them in the same frame before the render, no flicker, no taint.
local pendingButtons = {}
local decorRunner = CreateFrame("Frame")
decorRunner:SetScript("OnUpdate", function()
    if next(pendingButtons) == nil then return end
    for button in pairs(pendingButtons) do
        pendingButtons[button] = nil
        UpdateFriendButton(button)
    end
end)

-- BNet friends may update their location without Blizzard calling
-- FriendsFrame_UpdateFriendButton (DataProvider model in Midnight).
-- A targeted timer refresh only touches BNet buttons — WoW buttons are
-- handled exclusively via the hook to avoid stale button.id reads.
local bnetRefreshPending = false
local function ScheduleBNetRefresh()
    if bnetRefreshPending or not GetDB().enabled then return end
    bnetRefreshPending = true
    C_Timer.After(0.2, function()
        bnetRefreshPending = false
        if not GetDB().enabled then return end
        local scrollBox = (FriendsListFrame and FriendsListFrame.ScrollBox)
            or (FriendsFrame and FriendsFrame.ScrollBox)
        if not scrollBox or not scrollBox.ForEachFrame then return end
        scrollBox:ForEachFrame(function(button)
            if button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
                pendingButtons[button] = true
            end
        end)
    end)
end

local hookInstalled = false
local function EnsureHook()
    if hookInstalled then return true end
    if type(FriendsFrame_UpdateFriendButton) ~= "function" then return false end
    hooksecurefunc("FriendsFrame_UpdateFriendButton", function(button)
        -- Guard: only decorate when FriendsFrame is visible.
        -- The housing panel does not open FriendsFrame, so housing buttons
        -- are not added to pendingButtons on refresh or hover and stay untainted.
        if not FriendsFrame or not FriendsFrame:IsShown() then return end
        if debugstack():find("HouseList", 1, true) then return end
        if IsHousingButton(button) then return end
        -- Cache button.Favorite visibility now, while Blizzard's state is fresh.
        -- We must not re-read IsShown() later because we will have hidden it ourselves.
        button._aklimeFavState = button.Favorite and button.Favorite:IsShown() or false
        pendingButtons[button] = true
    end)
    hookInstalled = true
    return true
end

function M:Refresh()
    if not hookInstalled then EnsureHook() end
    -- Blizzard update functions (FriendsList_UpdateFriends etc.) must not be
    -- called directly here. Calling them from addon code taints all data they
    -- write (button.id, friendInfo, DataProvider). Blizzard reads this data in
    -- the right click context menu and VisitHouse() is then blocked as
    -- ADDON_ACTION_FORBIDDEN.
    -- Instead request a server update. FRIENDLIST_UPDATE lets Blizzard rebuild
    -- the list itself (secure), our hook decorates afterwards.
    if C_FriendList and C_FriendList.ShowFriends then
        C_FriendList.ShowFriends()
    end
    -- Redecorate visible buttons immediately (read only access).
    local scrollBox = (FriendsListFrame and FriendsListFrame.ScrollBox)
        or (FriendsFrame and FriendsFrame.ScrollBox)
    if scrollBox and scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(function(button)
            pendingButtons[button] = true
        end)
    end
end

function M:IsEnabled()
    return GetDB().enabled == true
end

function M:SetEnabled(v)
    GetDB().enabled = v and true or false
    EnsureHook()
    self:Refresh()
end

function M:Get(key)
    return GetDB()[key]
end

function M:Set(key, value)
    GetDB()[key] = value
    self:Refresh()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
initFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        EnsureHook()
        if GetDB().enabled then M:Refresh() end
    elseif event == "BN_FRIEND_INFO_CHANGED" then
        ScheduleBNetRefresh()
    end
end)
