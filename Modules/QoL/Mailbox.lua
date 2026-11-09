-- Modules/QoL/Mailbox.lua
-- Address book next to the mail compose window.
-- Contains your own characters only, one entry is added on each character login.
-- Clicking a contact sets the recipient automatically.
-- The character you sent mail to last is pinned to the top of the list.
-- The last recipient option remembers the last recipient per session.

local L = AklimeModL or {}

local ROW_H        = 22
local FRAME_W      = 235
local ROW_AREA_TOP = -78   -- pixel offset (negative) from the frame top to the first row
local ROW_AREA_BOT = 8     -- offset from the frame bottom to the last row
local MAX_ROWS     = 25    -- upper limit, actual count is computed from the height

-- Column layout inside a row (offsets from the row's left edge)
local COL_FIRST_W   = 88
local COL_LAST_X    = 94
local COL_LAST_W    = 84
local COL_FACTION_X = 184
local FACTION_ICON_SIZE = 16

local FACTION_ICONS = {
    Horde    = "Interface\\FriendsFrame\\PlusManz-Horde",
    Alliance = "Interface\\FriendsFrame\\PlusManz-Alliance",
}

-- ============================================================
-- DB access
-- ============================================================
local function GetDB()
    if AklimeModDB and AklimeModDB.mailbox then return AklimeModDB.mailbox end
    return {}
end

-- ============================================================
-- Helpers
-- ============================================================
local function GetClassColor(class)
    local tbl = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {}
    local c = tbl[class]
    if c then return c.r or 1, c.g or 1, c.b or 1 end
    return 1, 1, 1
end

-- There is only one realm. The server returns the last name where the realm
-- normally is, so UnitName gives the first name and the last name.
local function GetOwnName()
    local first, last = UnitName("player")
    return first or "", last or ""
end

local function BuildKey(first, last)
    if last == "" then return first end
    return first .. "-" .. last
end

-- Name as the player writes it in the mail recipient field
local function BuildFullName(first, last)
    if last == "" then return first end
    return first .. " " .. last
end

-- Recipient of the last sent mail, lowercase
local function GetLastSent()
    local text = GetDB().lastSent
    if type(text) ~= "string" or text == "" then return nil end
    return text:lower()
end

-- ============================================================
-- Module
-- ============================================================
local M = {}
AklimeMod_Mailbox = M

M.searchText = ""
M.sortKey    = "name"
M.sortAsc    = true
M.filtered   = {}
M.rows       = {}
M.offset     = 0
M.frame      = nil
M.scrollBar  = nil

-- ============================================================
-- Filtering and sorting
-- ============================================================
local function BuildFiltered()
    local contacts = GetDB().contacts or {}
    local needle   = M.searchText:lower()

    local myFirst, myLast = GetOwnName()
    local myFullName = BuildFullName(myFirst, myLast)

    local lastSent = GetLastSent()

    wipe(M.filtered)
    for key, rec in pairs(contacts) do
        local first = rec.name or key
        local last  = rec.last or ""
        local recipient = BuildFullName(first, last)
        -- Do not show your own character
        if recipient:lower() ~= myFullName:lower() then
            local match = needle == "" or recipient:lower():find(needle, 1, true)
            if match then
                local r, g, b = GetClassColor(rec.class)
                table.insert(M.filtered, {
                    key         = key,
                    name        = recipient,
                    first       = first,
                    last        = last,
                    faction     = rec.faction,
                    nameColored = ("|cff%02x%02x%02x%s|r"):format(r*255, g*255, b*255, first),
                    lastColored = ("|cff%02x%02x%02x%s|r"):format(r*255, g*255, b*255, last),
                    isLast      = lastSent ~= nil and recipient:lower() == lastSent,
                })
            end
        end
    end

    table.sort(M.filtered, function(a, b)
        -- Last recipient stays on top, no matter which column is sorted
        if a.isLast ~= b.isLast then return a.isLast end

        local av, bv
        if M.sortKey == "last" then
            av, bv = a.last:lower(), b.last:lower()
            if av == bv then av, bv = a.first:lower(), b.first:lower() end
        else
            av, bv = a.first:lower(), b.first:lower()
            if av == bv then av, bv = a.last:lower(), b.last:lower() end
        end
        if M.sortAsc then return av < bv else return av > bv end
    end)
end

-- ============================================================
-- Update rows
-- ============================================================
local function CalcVisibleRows()
    if not M.frame then return 0 end
    local h = M.frame:GetHeight()
    return math.max(0, math.floor((h - math.abs(ROW_AREA_TOP) - ROW_AREA_BOT) / ROW_H))
end

local function UpdateRows()
    if not M.frame or not M.frame:IsShown() then return end
    local visible = CalcVisibleRows()
    local total   = #M.filtered

    for i, row in ipairs(M.rows) do
        if i <= visible then
            local idx = i + M.offset
            if M.filtered[idx] then
                local rec = M.filtered[idx]
                row.nameText:SetText(rec.nameColored)
                row.realmText:SetText(rec.lastColored)
                local factionIcon = FACTION_ICONS[rec.faction]
                if factionIcon then
                    row.factionTex:SetTexture(factionIcon)
                    row.factionTex:Show()
                else
                    row.factionTex:Hide()
                end
                row.key    = rec.key
                row.rname  = rec.name
                row:Show()
            else
                row:Hide()
            end
        else
            row:Hide()
        end
    end

    if M.scrollUp and M.scrollDown then
        local maxOff = math.max(0, total - visible)
        if maxOff > 0 then
            M.scrollUp:Show()
            M.scrollDown:Show()
            M.scrollUp:SetEnabled(M.offset > 0)
            M.scrollDown:SetEnabled(M.offset < maxOff)
            -- Show track and thumb
            if M.scrollTrack and M.scrollThumb then
                M.scrollTrack:Show()
                local trackH = M.scrollTrack:GetHeight()
                if trackH and trackH > 0 then
                    local thumbH = math.max(16, math.floor((visible / total) * trackH))
                    local thumbY = math.floor((M.offset / maxOff) * (trackH - thumbH))
                    M.scrollThumb:SetHeight(thumbH)
                    M.scrollThumb:ClearAllPoints()
                    M.scrollThumb:SetPoint("TOPLEFT",  M.scrollTrack, "TOPLEFT",  3, -thumbY)
                    M.scrollThumb:SetPoint("TOPRIGHT", M.scrollTrack, "TOPRIGHT", -3, -thumbY)
                    M.scrollThumb:Show()
                end
            end
        else
            M.scrollUp:Hide()
            M.scrollDown:Hide()
            if M.scrollTrack then M.scrollTrack:Hide() end
            if M.scrollThumb then M.scrollThumb:Hide() end
        end
    end
end

-- ============================================================
-- Frame setup (lazy)
-- ============================================================
local function EnsureFrame()
    if M.frame then return end

    local f = CreateFrame("Frame", "AklimeMod_MailboxFrame", UIParent, "BackdropTemplate")
    f:SetWidth(FRAME_W)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    f:SetBackdropBorderColor(0.55, 0.45, 0.15, 1)
    f:Hide()

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -8)
    title:SetText(L["mailbox_title"])

    -- Search
    local sLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sLabel:SetPoint("TOPLEFT", 8, -30)
    sLabel:SetText(L["mailbox_search"])

    local sBox = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
    sBox:SetPoint("TOPLEFT", 50, -28)
    sBox:SetPoint("TOPRIGHT", -8, -28)
    sBox:SetHeight(20)
    sBox:SetAutoFocus(false)
    sBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if self.Instructions then
            self.Instructions:SetShown(text == "")
        end
        M.searchText = text
        BuildFiltered()
        M.offset = 0
        UpdateRows()
    end)
    sBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    M.searchBox = sBox

    -- Column header
    local function MakeHeader(label, sortKey, left, width)
        local btn = CreateFrame("Button", nil, f)
        btn:SetPoint("TOPLEFT", left, -52)
        btn:SetSize(width, 22)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.label:SetPoint("LEFT", 0, 0)
        btn.label:SetText(label)
        btn.sortKey = sortKey
        btn:SetScript("OnClick", function(self)
            if M.sortKey == self.sortKey then
                M.sortAsc = not M.sortAsc
            else
                M.sortKey = self.sortKey
                M.sortAsc = true
            end
            BuildFiltered()
            M.offset = 0
            UpdateRows()
        end)
        btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")
        return btn
    end
    M.nameHeader  = MakeHeader(L["mailbox_first_name"], "first", 6,   COL_FIRST_W)
    M.realmHeader = MakeHeader(L["mailbox_last_name"],  "last",  6 + COL_LAST_X, COL_LAST_W)

    -- Separator line
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  f, "TOPLEFT",  4, -75)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -75)
    line:SetColorTexture(0.4, 0.4, 0.4, 0.8)

    -- Scroll: arrow buttons (no template, no SecureScrollBar)
    local function MakeArrowBtn(isUp)
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(16, 16)
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Up")
        if not isUp then
            tex:SetTexCoord(0, 1, 1, 0)  -- flip vertically for the down arrow
        end
        tex:SetAllPoints()
        btn:SetNormalTexture(tex)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Highlight")
        if not isUp then hl:SetTexCoord(0, 1, 1, 0) end
        hl:SetAllPoints()
        btn:SetHighlightTexture(hl)
        return btn
    end

    local upBtn   = MakeArrowBtn(true)
    local downBtn = MakeArrowBtn(false)
    upBtn:SetPoint("TOPRIGHT",    f, "TOPRIGHT", -3, ROW_AREA_TOP)
    downBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, ROW_AREA_BOT)
    upBtn:SetScript("OnClick", function()
        if M.offset > 0 then
            M.offset = M.offset - 1
            UpdateRows()
        end
    end)
    downBtn:SetScript("OnClick", function()
        local maxOff = math.max(0, #M.filtered - CalcVisibleRows())
        if M.offset < maxOff then
            M.offset = M.offset + 1
            UpdateRows()
        end
    end)
    upBtn:Hide();  downBtn:Hide()
    M.scrollUp   = upBtn
    M.scrollDown = downBtn

    -- Scrollbar track between the arrows
    local track = CreateFrame("Frame", nil, f)
    track:SetWidth(16)
    track:SetPoint("TOP",    upBtn,   "BOTTOM", 0, 0)
    track:SetPoint("BOTTOM", downBtn, "TOP",    0, 0)
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    track:Hide()
    M.scrollTrack = track

    -- Thumb (as a frame so it can be dragged)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(10)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(0.5, 0.45, 0.2, 0.9)
    thumb:EnableMouse(true)

    local dragStartY, dragStartOffset = nil, nil

    thumb:SetScript("OnMouseDown", function()
        dragStartY      = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
        dragStartOffset = M.offset
    end)

    thumb:SetScript("OnMouseUp", function()
        dragStartY = nil
    end)

    thumb:SetScript("OnUpdate", function()
        if not dragStartY then return end
        local curY    = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
        local trackH  = M.scrollTrack:GetHeight()
        local thumbH  = thumb:GetHeight()
        local total   = #M.filtered
        local visible = CalcVisibleRows()
        local maxOff  = math.max(0, total - visible)
        if maxOff == 0 or trackH <= thumbH then return end
        local delta  = (dragStartY - curY) / (trackH - thumbH)
        local newOff = math.max(0, math.min(maxOff, math.floor(dragStartOffset + delta * maxOff + 0.5)))
        if newOff ~= M.offset then
            M.offset = newOff
            UpdateRows()
        end
    end)

    thumb:Hide()
    M.scrollThumb = thumb

    -- Mouse wheel
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        local maxOff = math.max(0, #M.filtered - CalcVisibleRows())
        M.offset = math.max(0, math.min(maxOff, M.offset - delta))
        UpdateRows()
    end)

    -- Pre-create rows
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  f, "TOPLEFT",  6,  ROW_AREA_TOP - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, ROW_AREA_TOP - (i - 1) * ROW_H)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nameText:SetPoint("LEFT", 0, 0)
        row.nameText:SetWidth(COL_FIRST_W)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)

        row.realmText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.realmText:SetPoint("LEFT", COL_LAST_X, 0)
        row.realmText:SetWidth(COL_LAST_W)
        row.realmText:SetJustifyH("LEFT")
        row.realmText:SetWordWrap(false)

        row.factionTex = row:CreateTexture(nil, "ARTWORK")
        row.factionTex:SetSize(FACTION_ICON_SIZE, FACTION_ICON_SIZE)
        row.factionTex:SetPoint("LEFT", COL_FACTION_X, 0)

        row:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                if not self.key then return end
                local key = self.key
                MenuUtil.CreateContextMenu(self, function(_, root)
                    root:CreateTitle(key)
                    root:CreateButton(L["mailbox_remove"], function()
                        local db = GetDB()
                        if db.contacts then
                            db.contacts[key] = nil
                            BuildFiltered()
                            M.offset = 0
                            UpdateRows()
                        end
                    end)
                end)
                return
            end
            if SendMailNameEditBox and self.key then
                SendMailNameEditBox:SetText(self.rname)
                SendMailNameEditBox:HighlightText(0, 0)
                SendMailNameEditBox:ClearFocus()
            end
        end)

        row:Hide()
        M.rows[i] = row
    end

    M.frame = f
end

-- ============================================================
-- Visibility
-- ============================================================
function M:UpdateVisibility()
    if not self.frame then return end
    local db = GetDB()
    if not db.enabled
        or not MailFrame or not MailFrame:IsShown()
        or PanelTemplates_GetSelectedTab(MailFrame) ~= 2
    then
        self.frame:Hide()
        return
    end

    self.frame:SetHeight(MailFrame:GetHeight() or 430)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)

    BuildFiltered()
    M.offset = 0
    UpdateRows()
    self.frame:Show()
end

-- ============================================================
-- Add own character to contacts
-- ============================================================
-- Only AddSelf writes a class, so entries without one are former mail
-- recipients from earlier versions and get dropped.
-- Entries without a last name field are the old format and get dropped as well,
-- they are added again on the next login of that character.
local function PruneForeignContacts()
    local db = GetDB()
    if not db.contacts then return end
    for key, rec in pairs(db.contacts) do
        if not rec.class or rec.last == nil then db.contacts[key] = nil end
    end
end

local function AddSelf()
    local db = GetDB()
    db.contacts = db.contacts or {}
    local name, last = GetOwnName()
    if name == "" then return end
    local class = select(2, UnitClass("player")) or "PRIEST"
    local r, g, b = GetClassColor(class)
    local key = BuildKey(name, last)
    db.contacts[key] = db.contacts[key] or {}
    db.contacts[key].name  = name
    db.contacts[key].last  = last
    db.contacts[key].class = class
    db.contacts[key].faction = UnitFactionGroup("player")
    db.contacts[key].color = { r = r, g = g, b = b }
end

-- ============================================================
-- Remember recipient on send
-- ============================================================
local lastRecipient = nil
local sendHooked    = false

local function CaptureRecipient()
    if not SendMailNameEditBox then return end
    local text = SendMailNameEditBox:GetText()
    if not text or text == "" then return end
    lastRecipient = text
    GetDB().lastSent = text
end

local function RestoreRecipient()
    local db = GetDB()
    if not db.rememberLastRecipient then return end
    if not SendMailNameEditBox then return end
    if lastRecipient and lastRecipient ~= "" then
        SendMailNameEditBox:SetText(lastRecipient)
        SendMailNameEditBox:HighlightText(0, 0)
    end
end

local function HookSendMail()
    if sendHooked then return end
    if type(SendMailFrame_SendMail) ~= "function" then return end
    if type(SendMailFrame_Reset)    ~= "function" then return end
    hooksecurefunc("SendMailFrame_SendMail", CaptureRecipient)
    hooksecurefunc("SendMailFrame_Reset",    RestoreRecipient)
    sendHooked = true
end

-- ============================================================
-- Tab-Hook + MailFrame-Hide-Hook
-- ============================================================
local tabHooked     = false
local mailHideHooked = false

local function HookMailFrameHide()
    if mailHideHooked then return end
    if not MailFrame then return end
    MailFrame:HookScript("OnHide", function()
        if M.frame then M.frame:Hide() end
    end)
    mailHideHooked = true
end

local function HookMailTabs()
    if tabHooked then return end
    if type(MailFrameTab_OnClick) ~= "function" then return end
    hooksecurefunc("MailFrameTab_OnClick", function()
        if M.frame then M:UpdateVisibility() end
    end)
    tabHooked = true
end

-- ============================================================
-- API
-- ============================================================
function M:IsEnabled()
    return GetDB().enabled == true
end

function M:IsRememberLastRecipient()
    return GetDB().rememberLastRecipient == true
end

function M:SetEnabled(v)
    GetDB().enabled = v and true or false
    if v then
        PruneForeignContacts()
        AddSelf()
        EnsureFrame()
        HookMailTabs()
        HookMailFrameHide()
        self:UpdateVisibility()
    else
        if self.frame then self.frame:Hide() end
    end
end

function M:SetRememberLastRecipient(v)
    GetDB().rememberLastRecipient = v and true or false
    if not v then lastRecipient = nil end
end

function M:ClearContacts()
    local db = GetDB()
    db.contacts = {}
    wipe(M.filtered)
    M.offset = 0
    UpdateRows()
end

-- ============================================================
-- Event-Handling
-- ============================================================
local mailEventFrame = CreateFrame("Frame")
mailEventFrame:RegisterEvent("MAIL_SHOW")
mailEventFrame:RegisterEvent("MAIL_CLOSED")
mailEventFrame:RegisterEvent("ADDON_LOADED")
mailEventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_MailFrame" then HookSendMail() end
        return
    end
    if event == "MAIL_SHOW" then
        HookSendMail()
        HookMailFrameHide()
        HookMailTabs()
        EnsureFrame()
        RunNextFrame(function()
            if MailFrame and MailFrame:IsShown() then
                M:UpdateVisibility()
            end
        end)
    elseif event == "MAIL_CLOSED" then
        lastRecipient = nil
        if M.frame then M.frame:Hide() end
    end
end)

-- ============================================================
-- Init
-- ============================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    local db = GetDB()
    if db.enabled then
        PruneForeignContacts()
        AddSelf()
        EnsureFrame()
        HookMailTabs()
        HookMailFrameHide()
    end
    self:UnregisterEvent("PLAYER_LOGIN")
end)
