-- Modules/QoL/TodoList.lua
-- Persistent ToDo list. Invoke with: /akm todo
-- Stored in AklimeModDB.todoList.items = { "Text1", "Text2", ... }

local L = AklimeModL or {}

local M = {}
AklimeMod_TodoList = M

local DEFAULT_W = 280
local DEFAULT_H = 360
local MIN_W     = 200
local MIN_H     = 200
local MAX_W     = 540
local MAX_H     = 700
local ITEM_H    = 26
local PAD       = 10
local MAX_ITEMS = 50

local GOLD   = { 0.80, 0.65, 0.10, 1 }
local GOLD_D = { 0.80, 0.65, 0.10, 0.5 }
local BG     = { 0.07, 0.07, 0.08, 0.96 }

local mainFrame, listContent, scrollFrame, editBox, emptyLabel, editBg
local itemRows = {}

-- ============================================================
-- DB
-- ============================================================

local function GetDB()
    if AklimeModDB and AklimeModDB.todoList then return AklimeModDB.todoList end
    return {}
end

local function GetItems()
    local db = GetDB()
    db.items = db.items or {}
    return db.items
end

-- ============================================================
-- Helpers
-- ============================================================

local function MakeSeparator(parent, r, g, b, a)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function ApplyBackdrop(f, edgeColor)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(BG[1], BG[2], BG[3], BG[4])
    if edgeColor then
        f:SetBackdropBorderColor(edgeColor[1], edgeColor[2], edgeColor[3], edgeColor[4])
    end
end

-- ============================================================
-- List
-- ============================================================

local function GetListContentWidth()
    if not mainFrame then return DEFAULT_W - PAD * 2 - 20 end
    return mainFrame:GetWidth() - PAD * 2 - 20
end

local function RefreshList()
    for _, row in ipairs(itemRows) do row:Hide() end
    itemRows = {}

    local items = GetItems()
    local w     = GetListContentWidth()

    for i, text in ipairs(items) do
        local row = CreateFrame("Frame", nil, listContent)
        row:SetHeight(ITEM_H)
        row:SetPoint("TOPLEFT",  listContent, "TOPLEFT",  0, -(i - 1) * ITEM_H)
        row:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -(i - 1) * ITEM_H)

        -- Hover-Highlight
        local hl = row:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0)

        -- Checkbox
        local cb = CreateFrame("Button", nil, row)
        cb:SetSize(14, 14)
        cb:SetPoint("LEFT", 4, 0)

        local cbBorder = cb:CreateTexture(nil, "BACKGROUND")
        cbBorder:SetAllPoints()
        cbBorder:SetColorTexture(0.35, 0.35, 0.35, 1)

        local cbInner = cb:CreateTexture(nil, "ARTWORK")
        cbInner:SetPoint("TOPLEFT",     2, -2)
        cbInner:SetPoint("BOTTOMRIGHT", -2, 2)
        cbInner:SetColorTexture(BG[1], BG[2], BG[3], 1)

        row:SetScript("OnEnter", function()
            hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.08)
            cbBorder:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
            cbInner:SetColorTexture(0.18, 0.14, 0.03, 1)
        end)
        row:SetScript("OnLeave", function()
            hl:SetColorTexture(1, 1, 1, 0)
            cbBorder:SetColorTexture(0.35, 0.35, 0.35, 1)
            cbInner:SetColorTexture(BG[1], BG[2], BG[3], 1)
        end)
        row:EnableMouse(true)

        local idx = i
        cb:SetScript("OnClick", function()
            table.remove(GetItems(), idx)
            RefreshList()
        end)
        -- Click on the whole row = same action
        row:SetScript("OnMouseUp", function(_, btn)
            if btn == "LeftButton" then
                table.remove(GetItems(), idx)
                RefreshList()
            end
        end)

        -- Text
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT",  cb,  "RIGHT", 6, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        lbl:SetText(text)

        -- Divider (except after the last item)
        if i < #items then
            local sep = MakeSeparator(row, 0.15, 0.15, 0.15, 1)
            sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  4, 0)
            sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
        end

        table.insert(itemRows, row)
    end

    listContent:SetHeight(math.max(#items * ITEM_H, 1))
    if listContent then listContent:SetWidth(math.max(GetListContentWidth(), 80)) end
    if emptyLabel then emptyLabel:SetShown(#items == 0) end

    -- Show the scrollbar only when content is larger than the visible area
    C_Timer.After(0, function()
        local sb = _G["AklimeModTodoScrollScrollBar"]
        if sb then sb:SetShown(scrollFrame:GetVerticalScrollRange() > 0) end
    end)
end

-- ============================================================
-- Frame
-- ============================================================

local function BuildFrame()
    if mainFrame then return end

    local db = GetDB()

    mainFrame = CreateFrame("Frame", "AklimeModTodoFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(db.w or DEFAULT_W, db.h or DEFAULT_H)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    mainFrame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        local d = GetDB()
        d.x, d.y = left, top
    end)
    mainFrame:SetFrameStrata("DIALOG")
    ApplyBackdrop(mainFrame, GOLD)
    mainFrame:Hide()

    tinsert(UISpecialFrames, "AklimeModTodoFrame")

    -- Restore saved position/size
    if db.x and db.y then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.x, db.y)
    end

    -- Title row
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -13)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    title:SetText("ToDo")

    local titleSep = MakeSeparator(mainFrame, GOLD_D[1], GOLD_D[2], GOLD_D[3], GOLD_D[4])
    titleSep:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  8, -32)
    titleSep:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -8, -32)

    -- Item count (top right, before the close button)
    local countLbl = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countLbl:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -32, -14)
    -- updated in RefreshList (optional feature, not required)

    -- Close-Button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

    -- ScrollFrame
    scrollFrame = CreateFrame("ScrollFrame", "AklimeModTodoScroll", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",      PAD,        -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PAD - 16,    58)

    listContent = CreateFrame("Frame", nil, scrollFrame)
    listContent:SetWidth(math.max(DEFAULT_W - PAD * 2 - 20, 80))
    listContent:SetHeight(1)
    scrollFrame:SetScrollChild(listContent)

    emptyLabel = listContent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("TOP", 0, -24)
    emptyLabel:SetText(L["todo_empty"] or "No entries")
    emptyLabel:Hide()

    -- Divider above the input area
    local inputSep = MakeSeparator(mainFrame, GOLD_D[1], GOLD_D[2], GOLD_D[3], GOLD_D[4])
    inputSep:SetPoint("BOTTOMLEFT",  mainFrame, "BOTTOMLEFT",   8, 54)
    inputSep:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -8, 54)

    -- Edit box background
    editBg = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    editBg:SetHeight(26)
    editBg:SetPoint("BOTTOMLEFT",  mainFrame, "BOTTOMLEFT",   PAD,  26)
    editBg:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PAD,  26)
    editBg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editBg:SetBackdropColor(0.04, 0.04, 0.05, 1)
    editBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)

    editBox = CreateFrame("EditBox", nil, editBg)
    editBox:SetPoint("TOPLEFT",     editBg, "TOPLEFT",     5, -4)
    editBox:SetPoint("BOTTOMRIGHT", editBg, "BOTTOMRIGHT", -5,  4)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetMaxLetters(200)
    editBox:SetScript("OnEditFocusGained", function()
        editBg:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    end)
    editBox:SetScript("OnEditFocusLost", function()
        editBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        local text = strtrim(self:GetText() or "")
        if text ~= "" then
            local items = GetItems()
            if #items < MAX_ITEMS then
                table.insert(items, text)
                RefreshList()
                scrollFrame:SetVerticalScroll(scrollFrame:GetVerticalScrollRange())
            end
        end
        self:SetText("")
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    -- Hint text
    local hint = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOM", 0, 8)
    hint:SetText(L["todo_hint"] or "Enter = Add    |    Click = Done")

    -- Resize-Handle
    local resizeHandle = CreateFrame("Button", nil, mainFrame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnMouseDown", function()
        local left, top = mainFrame:GetLeft(), mainFrame:GetTop()
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        mainFrame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
        local d = GetDB()
        d.w, d.h = mainFrame:GetSize()
        -- Update listContent width and rebuild the list
        listContent:SetWidth(math.max(mainFrame:GetWidth() - PAD * 2 - 20, 80))
        RefreshList()
    end)

    -- Adjust listContent width to the window size (continuously during resize)
    mainFrame:SetScript("OnSizeChanged", function(self, w)
        if listContent then
            listContent:SetWidth(math.max(w - PAD * 2 - 20, 80))
        end
    end)
end

-- ============================================================
-- API
-- ============================================================

function M:Toggle()
    BuildFrame()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        RefreshList()
        mainFrame:Show()
    end
end
