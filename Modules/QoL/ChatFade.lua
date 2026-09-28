-- Modules/QoL/ChatFade.lua

local function GetDB()
    if AklimeModDB and AklimeModDB.chatFade then return AklimeModDB.chatFade end
    return { enabled = false, timeVisible = 30, fadeDuration = 3 }
end

local MAX_CHAT_FRAMES = Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or 50

local function ApplyToAllFrames()
    local db = GetDB()
    for i = 1, MAX_CHAT_FRAMES do
        local frame = _G["ChatFrame" .. i]
        if frame then
            if frame.SetFading     then frame:SetFading(db.enabled) end
            if frame.SetTimeVisible  then frame:SetTimeVisible(db.timeVisible) end
            if frame.SetFadeDuration then frame:SetFadeDuration(db.fadeDuration) end
        end
    end
end

local hookInstalled = false
local function EnsureHook()
    if hookInstalled then return end
    hookInstalled = true

    -- Also capture new chat windows (temporary windows, e.g. whisper windows)
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        if GetDB().enabled then ApplyToAllFrames() end
    end)

    local watchFrame = CreateFrame("Frame")
    watchFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
    watchFrame:SetScript("OnEvent", function()
        if GetDB().enabled then ApplyToAllFrames() end
    end)
end

AklimeMod_ChatFade = {
    IsEnabled = function()
        return GetDB().enabled == true
    end,

    SetEnabled = function(v)
        GetDB().enabled = v and true or false
        EnsureHook()
        ApplyToAllFrames()
    end,

    GetTimeVisible = function()
        return GetDB().timeVisible
    end,

    SetTimeVisible = function(v)
        GetDB().timeVisible = v
        if GetDB().enabled then ApplyToAllFrames() end
    end,

    GetFadeDuration = function()
        return GetDB().fadeDuration
    end,

    SetFadeDuration = function(v)
        GetDB().fadeDuration = v
        if GetDB().enabled then ApplyToAllFrames() end
    end,
}

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    EnsureHook()
    if GetDB().enabled then ApplyToAllFrames() end
end)
