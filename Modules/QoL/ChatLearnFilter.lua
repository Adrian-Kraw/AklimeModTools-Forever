-- Modules/QoL/ChatLearnFilter.lua
-- Hides learn/unlearn messages in the chat.
-- Optional sub-feature: hide the "unspent talent points" alert popup.

local function GetDB()
    if AklimeModDB and AklimeModDB.chatLearnFilter then return AklimeModDB.chatLearnFilter end
    return { enabled = false }
end

-- Converts a Blizzard format string ("You have learned %s.") into a Lua pattern.
local function FmtToPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local pattern = fmt
        :gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
        :gsub("%%s", ".+")
        :gsub("%%d", "%%d+")
    return pattern
end

local patterns = nil

local function BuildPatterns()
    if patterns then return end
    patterns = {}
    local sources = {
        ERR_LEARN_PASSIVE_S,
        ERR_LEARN_SPELL_S,
        ERR_LEARN_ABILITY_S,
        ERR_SPELL_UNLEARNED_S,
    }
    for _, fmt in ipairs(sources) do
        local p = FmtToPattern(fmt)
        if p then patterns[#patterns + 1] = p end
    end
end

-- Fallback for the retail format with spell links.
-- Retail uses a new format: "You have learned a new spell: [X]"
-- where [X] is a real |Hspell: hyperlink.
local LEARN_VERBS = { "erlernt", "gelernt", "verlernt", "learned", "unlearned" }

local function IsRetailLearnMessage(msg)
    if not msg:find("|Hspell:", 1, true) and not msg:find("|Htalent:", 1, true) then
        return false
    end
    for _, verb in ipairs(LEARN_VERBS) do
        if msg:find(verb, 1, true) then return true end
    end
    return false
end

local function LearnFilter(_, _, msg)
    if not msg then return false end
    if issecretvalue and issecretvalue(msg) then return false end
    for _, pat in ipairs(patterns) do
        if msg:match(pat) then return true end
    end
    if IsRetailLearnMessage(msg) then return true end
    return false
end

-- ============================================================
-- Talent alert bubble suppression
-- ============================================================

local bubbleHooked = {}

local function IsBubbleEnabled()
    local db = GetDB()
    return db.hideTalentBubble == true
end

-- Talent alert bubbles are anonymous UIParent children identified by their text.
-- The frame is reused for other popups (e.g. mission tables), so we always
-- re-check the text before hiding to avoid suppressing unrelated popups.
local BUBBLE_PATTERNS = {
    "unverteilte Talentpunkt", -- deDE regular
    "PvP-Talentplatz",         -- deDE PvP
    "unspent talent point",    -- enUS regular
    "PvP talent",              -- enUS PvP
    "eine neue Spezialisierung", -- deDE profession specialization
}

-- The alerts over the micro menu row all take their text from Blizzard global
-- strings. Reading the patterns from there instead of typing them out keeps
-- the match working in every client language.
local BUBBLE_GLOBALS = {
    -- Talents
    "TALENT_MICRO_BUTTON_NO_HERO_SPEC",
    "TALENT_MICRO_BUTTON_UNSPENT_TALENTS",
    "TALENT_MICRO_BUTTON_UNSPENT_PVP_TALENT_SLOT",
    "TALENT_MICRO_BUTTON_NEW_PVP_TALENT",
    -- Professions
    "PROFESSIONS_SPECS_CAN_UNLOCK_SPEC",
    "PROFESSIONS_SPECS_PENDING_POINTS",
    "PROFESSIONS_UNSPENT_SPEC_POINTS_REMINDER",
}

-- Part before the first placeholder, the name behind it varies
local function StaticPrefix(text)
    if type(text) ~= "string" then return nil end
    local cut = text:find("%%")
    local prefix = (cut and text:sub(1, cut - 1) or text):gsub("%s+$", "")
    if #prefix < 12 then return nil end
    return prefix
end

for _, name in ipairs(BUBBLE_GLOBALS) do
    local prefix = StaticPrefix(_G[name])
    if prefix then table.insert(BUBBLE_PATTERNS, prefix) end
end

local function FrameMatchesBubble(f)
    local ok, nr = pcall(function() return f:GetNumRegions() end)
    if not ok or not nr then return false end
    for j = 1, nr do
        local r = select(j, f:GetRegions())
        if r.GetText then
            local ok2, t = pcall(function() return r:GetText() end)
            if ok2 and t and not (issecretvalue and issecretvalue(t)) then
                for _, pat in ipairs(BUBBLE_PATTERNS) do
                    if t:find(pat, 1, true) then return true end
                end
            end
        end
    end
    return false
end

local function SuppressBubble(f)
    if not f or bubbleHooked[f] then return end
    bubbleHooked[f] = true
    -- Re-check text on every show: the frame is reused for other popups
    f:HookScript("OnShow", function(self)
        if not IsBubbleEnabled() then return end
        C_Timer.After(0, function()
            if self:IsShown() and FrameMatchesBubble(self) then
                self:Hide()
            end
        end)
    end)
    if IsBubbleEnabled() and f.IsShown and f:IsShown() and FrameMatchesBubble(f) then
        f:Hide()
    end
end

local function ApplyBubbleHide()
    if not IsBubbleEnabled() then return end
    for i = 1, UIParent:GetNumChildren() do
        local f = select(i, UIParent:GetChildren())
        if not bubbleHooked[f] then
            local ok, nr = pcall(function() return f:GetNumRegions() end)
            if ok and nr then
                for j = 1, nr do
                    local r = select(j, f:GetRegions())
                    if r.GetText then
                        local ok2, t = pcall(function() return r:GetText() end)
                        if ok2 and t and not (issecretvalue and issecretvalue(t)) then
                            for _, pat in ipairs(BUBBLE_PATTERNS) do
                                if t:find(pat, 1, true) then
                                    SuppressBubble(f)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Both the talent and the profession alert run through HelpTip:Show, that is
-- the reliable moment to check, independent of any event
local helpTipHooked = false

local function HookHelpTip()
    if helpTipHooked then return end
    if not HelpTip or type(HelpTip.Show) ~= "function" then return end
    helpTipHooked = true
    hooksecurefunc(HelpTip, "Show", function()
        if IsBubbleEnabled() then ApplyBubbleHide() end
    end)
end

local function HookShowAlert()
    -- Keep as secondary strategy: hook ShowAlert on the talent button if available
    local btn = _G["PlayerSpellsMicroButton"]
    if not btn or btn._talentAlertHooked then return end
    btn._talentAlertHooked = true
    if btn.ShowAlert then
        hooksecurefunc(btn, "ShowAlert", function()
            if IsBubbleEnabled() then C_Timer.After(0, ApplyBubbleHide) end
        end)
    end
end

local bubbleFrame = CreateFrame("Frame")

local function SetupBubbleEvents(on)
    if on then
        bubbleFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
        bubbleFrame:RegisterEvent("PLAYER_LEVEL_UP")
        bubbleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        bubbleFrame:UnregisterAllEvents()
    end
end

bubbleFrame:SetScript("OnEvent", function()
    C_Timer.After(0, ApplyBubbleHide)
end)

-- ============================================================
-- Public API
-- ============================================================

local M = {}
AklimeMod_ChatLearnFilter = M

local registered = false

function M:IsEnabled()
    return GetDB().enabled == true
end

function M:SetEnabled(v)
    GetDB().enabled = v and true or false
    BuildPatterns()
    if v and not registered then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", LearnFilter)
        registered = true
    elseif not v and registered then
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", LearnFilter)
        registered = false
    end
end

function M:IsBubbleEnabled()
    return IsBubbleEnabled()
end

function M:SetBubbleEnabled(v)
    local db = GetDB()
    db.hideTalentBubble = v and true or false
    SetupBubbleEvents(v)
    if v then
        C_Timer.After(0.5, function()
            HookHelpTip()
            HookShowAlert()
            ApplyBubbleHide()
        end)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if GetDB().enabled then M:SetEnabled(true) end
    if GetDB().hideTalentBubble then
        SetupBubbleEvents(true)
        C_Timer.After(2, function()
            HookHelpTip()
            HookShowAlert()
            ApplyBubbleHide()
        end)
    end
end)
