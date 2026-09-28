-- Modules/QoL/Merchant.lua
-- Shows 20 items per merchant page instead of 10 (2 columns of 10).

local ITEMS_PER_PAGE_EXPANDED = 20
local ORIGINAL_ITEMS_PER_PAGE = _G.MERCHANT_ITEMS_PER_PAGE or 10

-- One panel across the bottom of the widened frame, holding two rows. The
-- upper row carries the paging on the left and the buttons on the right, the
-- lower row carries gold at the left with the merchant currencies after it.
-- All Y values are measured from the bottom edge of the merchant frame.
local BAR_INSET_X    = 8
local BLOCK_TOP_Y    = 86
local BLOCK_BOTTOM_Y = 5
local BAR_PADDING_X  = 12
-- Vertical centre of the two rows, everything in a row is centred on it
local BUTTON_ROW_Y   = 58
local CURRENCY_ROW_Y = 20
-- Separator lines: the horizontal one between the two rows, the vertical one
-- centred in the upper row, running from the panel edge down onto it
local ROW_DIVIDER_Y   = 35
local DIVIDER_TOP_PAD = 6
-- Fixed width of the gold column, so the currencies never jump
local GOLD_COLUMN_W  = 150
-- Column width for one currency. A token button is about 50 wide
local TOKEN_COLUMN_W = 78
-- Distance to the right edge and gap between the buttons of the upper row
local BOTTOM_ROW_PAD = 24
local BOTTOM_ROW_GAP = 14
-- Space reserved for the buyback slot. Its own width grows with the name of
-- the last sold item, anchoring it on the right would make the icons wander
local BUYBACK_BLOCK_W = 130
-- Least space kept for the label of a paging button. The button itself is only
-- the arrow, its text sticks out beside it and would cover the page number
local PAGE_LABEL_MIN = 56

-- The buttons of the bottom row, from the right edge inwards
local BOTTOM_ROW_BUTTONS = {
    "MerchantSellAllJunkButton",
    "MerchantGuildBankRepairButton",
    "MerchantRepairAllButton",
    "MerchantRepairItemButton",
}

-- How many token buttons the merchant frame provides. Blizzard raised that
-- number in the past, so it is read from the game instead of hardcoded.
local function MaxCurrencies()
    return _G.MAX_MERCHANT_CURRENCIES or 4
end

local function GetDB()
    if AklimeModDB and AklimeModDB.merchant then return AklimeModDB.merchant end
    return { enabled = false }
end

-- Everything Blizzard draws at the bottom, replaced by the single panel. The
-- bottom border is cut for the original window width and ends in the middle of
-- the widened frame, which is what made the bottom look split.
local BLIZZARD_BOTTOM = {
    "MerchantMoneyBg", "MerchantMoneyInset",
    "MerchantExtraCurrencyBg", "MerchantExtraCurrencyInset",
    "MerchantFrameBottomLeftBorder", "MerchantFrameBottomRightBorder",
    -- Light background of the buyback tab, which does not fit the merchant tab
    "BuybackBG",
}

local function BlizzardPanels()
    local panels = {}
    for _, name in ipairs(BLIZZARD_BOTTOM) do
        local frame = _G[name]
        if frame then panels[#panels + 1] = frame end
    end
    return panels
end

-- ============================================================
-- Cache helpers
-- ============================================================

local cache = {}

local function SaveFrame(key, frame)
    if not frame or not frame.GetNumPoints then return end
    local points = {}
    for i = 1, frame:GetNumPoints() do
        local point, relTo, relPoint, x, y = frame:GetPoint(i)
        points[#points + 1] = { point, relTo, relPoint, x, y }
    end
    cache[key] = {
        width  = frame.GetWidth  and frame:GetWidth()  or nil,
        height = frame.GetHeight and frame:GetHeight() or nil,
        level  = frame.GetFrameLevel and frame:GetFrameLevel() or nil,
        points = points,
    }
end

local function RestoreFrame(key, frame)
    local data = cache[key]
    if not data or not frame then return end
    frame:ClearAllPoints()
    for _, p in ipairs(data.points) do
        frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
    if data.width  and frame.SetWidth  then frame:SetWidth(data.width)   end
    if data.height and frame.SetHeight then frame:SetHeight(data.height) end
    if data.level  and frame.SetFrameLevel then frame:SetFrameLevel(data.level) end
end

local function CacheAll()
    SaveFrame("merchantFrame",          MerchantFrame)
    SaveFrame("prevPageButton",         MerchantPrevPageButton)
    SaveFrame("pageText",               MerchantPageText)
    SaveFrame("nextPageButton",         MerchantNextPageButton)
    SaveFrame("buyBackItem",            _G.MerchantBuyBackItem)
    for _, name in ipairs(BOTTOM_ROW_BUTTONS) do SaveFrame(name, _G[name]) end
    SaveFrame("moneyBg",                _G.MerchantMoneyBg)
    SaveFrame("moneyInset",             _G.MerchantMoneyInset)
    SaveFrame("moneyFrame",             _G.MerchantMoneyFrame)
    SaveFrame("extraCurrencyInset",     _G.MerchantExtraCurrencyInset)
    SaveFrame("extraCurrencyBg",        _G.MerchantExtraCurrencyBg)
    for i = 1, MaxCurrencies() do
        local btn = _G["MerchantToken" .. i]
        if btn then SaveFrame("token" .. i, btn) end
    end
end

local function RestoreAll()
    RestoreFrame("merchantFrame",      MerchantFrame)
    RestoreFrame("prevPageButton",     MerchantPrevPageButton)
    RestoreFrame("pageText",           MerchantPageText)
    RestoreFrame("nextPageButton",     MerchantNextPageButton)
    RestoreFrame("buyBackItem",        _G.MerchantBuyBackItem)
    for _, name in ipairs(BOTTOM_ROW_BUTTONS) do RestoreFrame(name, _G[name]) end
    RestoreFrame("moneyBg",            _G.MerchantMoneyBg)
    RestoreFrame("moneyInset",         _G.MerchantMoneyInset)
    RestoreFrame("moneyFrame",         _G.MerchantMoneyFrame)
    RestoreFrame("extraCurrencyInset", _G.MerchantExtraCurrencyInset)
    RestoreFrame("extraCurrencyBg",    _G.MerchantExtraCurrencyBg)
    -- The bar replaces Blizzard's two panels, so they have to come back
    for _, frame in ipairs(BlizzardPanels()) do frame:Show() end
    for i = 1, MaxCurrencies() do
        local btn = _G["MerchantToken" .. i]
        if btn then RestoreFrame("token" .. i, btn) end
    end
    cache = {}
end

-- ============================================================
-- Layout functions
-- ============================================================

local M = {}
AklimeMod_Merchant = M

M.enabled = false
M.hooked  = false

local function RebuildMerchantFrame()
    if not MerchantFrame then return end
    MerchantFrame:SetWidth(696)
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        if not _G["MerchantItem" .. i] then
            CreateFrame("Frame", "MerchantItem" .. i, MerchantFrame, "MerchantItemTemplate")
        end
    end
end

local function UpdateSlotPositions()
    if not M.enabled or not MerchantFrame then return end
    local vertSpacing  = -16
    local horizSpacing = 12
    local perColumn    = ORIGINAL_ITEMS_PER_PAGE

    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local slot = _G["MerchantItem" .. i]
        if slot then
            slot:Show()
            if (i % perColumn) == 1 then
                if i == 1 then
                    slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 24, -70)
                else
                    slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - (perColumn - 1))], "TOPRIGHT", 12, 0)
                end
            elseif (i % 2) == 1 then
                slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 2)], "BOTTOMLEFT", 0, vertSpacing)
            else
                slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 1)], "TOPRIGHT", horizSpacing, 0)
            end
        end
    end

    local numItems = securecall("GetMerchantNumItems")
    if numItems and numItems <= MERCHANT_ITEMS_PER_PAGE then
        if MerchantPageText       then MerchantPageText:Show() end
        if MerchantPrevPageButton then MerchantPrevPageButton:Show(); MerchantPrevPageButton:Disable() end
        if MerchantNextPageButton then MerchantNextPageButton:Show(); MerchantNextPageButton:Disable() end
    end
end

-- Buyback uses the same grid as the merchant tab. Its own wider spacing was
-- built for the narrow window and pushed the last row under the bottom panel.
local function UpdateBuyBackSlotPositions()
    if not M.enabled or not MerchantFrame then return end
    local vertSpacing  = -16
    local horizSpacing = 12
    local perRow       = 4

    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local slot = _G["MerchantItem" .. i]
        if slot then
            if i > BUYBACK_ITEMS_PER_PAGE then
                slot:Hide()
            else
                if i == 1 then
                    slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 24, -70)
                elseif (i % perRow) == 1 then
                    slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - perRow)], "BOTTOMLEFT", 0, vertSpacing)
                else
                    slot:SetPoint("TOPLEFT", _G["MerchantItem" .. (i - 1)], "TOPRIGHT", horizSpacing, 0)
                end
            end
        end
    end
end

local currencyBar

-- Frame levels are set by hand throughout. A child frame on the same level as
-- its parent has no defined drawing order against the parent's own textures,
-- which is what let Blizzard's bottom art show through the panel.
local function PanelLevel()
    return (MerchantFrame and MerchantFrame:GetFrameLevel() or 0) + 1
end

local function ContentLevel()
    return PanelLevel() + 2
end

local function Raise(frame)
    if frame and frame.SetFrameLevel then frame:SetFrameLevel(ContentLevel()) end
end

-- Room a paging button needs beside its arrow for its own label
local function PageLabelWidth(btn)
    local fs = btn and btn.GetFontString and btn:GetFontString()
    local w  = fs and fs:GetStringWidth() or 0
    return math.max(w + 12, PAGE_LABEL_MIN)
end

local function RebuildPageButtonPositions()
    local prev    = MerchantPrevPageButton
    local text    = MerchantPageText
    local nextBtn = MerchantNextPageButton
    if not prev or not MerchantFrame then return end

    -- ClearAllPoints first. Leaving Blizzard's own anchor in place gives the
    -- widgets two anchors, which pulls them apart and can squash the page text
    Raise(prev)
    prev:ClearAllPoints()
    prev:SetPoint("LEFT", MerchantFrame, "BOTTOMLEFT", BOTTOM_ROW_PAD, BUTTON_ROW_Y)

    -- The page number is a text region of the merchant frame and would sit
    -- under the panel. It is moved onto the panel instead of being copied, so
    -- the game keeps updating the text that is actually on screen.
    if text then
        if currencyBar and text:GetParent() ~= currencyBar then
            text:SetParent(currencyBar)
        end
        text:ClearAllPoints()
        text:SetPoint("LEFT", prev, "RIGHT", PageLabelWidth(prev), 0)
    end

    if nextBtn then
        Raise(nextBtn)
        nextBtn:ClearAllPoints()
        nextBtn:SetPoint("LEFT", text or prev, "RIGHT", PageLabelWidth(nextBtn), 0)
    end
end

-- Buyback slot, sell junk and the repair buttons form one row at the right,
-- all centred on the same line
local function RebuildBottomRowPositions()
    if not M.enabled or not MerchantFrame then return end

    local item = _G.MerchantBuyBackItem
    if item then
        Raise(item)
        item:ClearAllPoints()
        item:SetPoint("LEFT", MerchantFrame, "BOTTOMRIGHT",
            -(BOTTOM_ROW_PAD + BUYBACK_BLOCK_W), BUTTON_ROW_Y)
    end

    -- Every button hangs on the frame, never on its neighbour. The game anchors
    -- the sell junk button to the repair button itself, and a chain among them
    -- would close a circle that the game refuses to resolve.
    local offset = BOTTOM_ROW_PAD + BUYBACK_BLOCK_W
    for _, name in ipairs(BOTTOM_ROW_BUTTONS) do
        local btn = _G[name]
        if btn and btn:IsShown() then
            offset = offset + BOTTOM_ROW_GAP
            Raise(btn)
            btn:ClearAllPoints()
            btn:SetPoint("RIGHT", MerchantFrame, "BOTTOMRIGHT", -offset, BUTTON_ROW_Y)
            offset = offset + (btn:GetWidth() or 0)
        end
    end
end

local function EnsureCurrencyBar()
    if currencyBar or not MerchantFrame then return currencyBar end

    currencyBar = CreateFrame("Frame", "AklimeModMerchantCurrencyBar", MerchantFrame, "BackdropTemplate")
    currencyBar:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    currencyBar:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    currencyBar:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    currencyBar.divider = currencyBar:CreateTexture(nil, "ARTWORK")
    currencyBar.divider:SetColorTexture(0.4, 0.4, 0.4, 0.7)
    currencyBar.divider:SetHeight(1)

    currencyBar.dividerV = currencyBar:CreateTexture(nil, "ARTWORK")
    currencyBar.dividerV:SetColorTexture(0.4, 0.4, 0.4, 0.7)
    currencyBar.dividerV:SetWidth(1)

    return currencyBar
end

local function RebuildPanel()
    if not M.enabled or not MerchantFrame then return nil end

    for _, frame in ipairs(BlizzardPanels()) do frame:Hide() end

    local bar = EnsureCurrencyBar()
    if not bar then return nil end
    bar:SetFrameLevel(PanelLevel())
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT",     MerchantFrame, "BOTTOMLEFT",   BAR_INSET_X, BLOCK_TOP_Y)
    bar:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -BAR_INSET_X, BLOCK_BOTTOM_Y)
    bar:Show()

    local dividerY = ROW_DIVIDER_Y - BLOCK_BOTTOM_Y
    bar.divider:ClearAllPoints()
    bar.divider:SetPoint("BOTTOMLEFT",  bar, "BOTTOMLEFT",   BAR_PADDING_X, dividerY)
    bar.divider:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -BAR_PADDING_X, dividerY)

    bar.dividerV:ClearAllPoints()
    bar.dividerV:SetPoint("TOP",    bar, "TOP",    0, -DIVIDER_TOP_PAD)
    bar.dividerV:SetPoint("BOTTOM", bar, "BOTTOM", 0, dividerY)

    return bar
end

local function RebuildTokenPositions()
    if not M.enabled or not MerchantFrame then return end

    -- Gold always holds the first column. The game hides it at merchants that
    -- take no gold, which would let the currencies slide to the left edge.
    local moneyFrame = _G.MerchantMoneyFrame
    if moneyFrame then
        Raise(moneyFrame)
        moneyFrame:ClearAllPoints()
        moneyFrame:SetPoint("LEFT", MerchantFrame, "BOTTOMLEFT",
            BAR_INSET_X + BAR_PADDING_X, CURRENCY_ROW_Y)
        moneyFrame:Show()
    end

    local currencies = { GetMerchantCurrencies() }
    MerchantFrame.numCurrencies = #currencies

    -- Fixed columns, running to the right from the end of the gold column.
    -- Always the same width, so two currencies are not spread over the whole
    -- bar. Only when there are too many for the row do the columns shrink.
    local count = math.min(#currencies, MaxCurrencies())
    local usable = MerchantFrame:GetWidth() - (2 * BAR_INSET_X) - (2 * BAR_PADDING_X) - GOLD_COLUMN_W
    local step = TOKEN_COLUMN_W
    if count > 0 and usable / count < step then
        step = usable / count
    end

    for i = 1, count do
        local btn = _G["MerchantToken" .. i]
        if btn then
            Raise(btn)
            btn:ClearAllPoints()
            -- Centered in its column. The amount and the icon sit right
            -- aligned inside the button, left aligning them looks ragged
            btn:SetPoint("CENTER", MerchantFrame, "BOTTOMLEFT",
                BAR_INSET_X + BAR_PADDING_X + GOLD_COLUMN_W + ((i - 0.5) * step),
                CURRENCY_ROW_Y)
        end
    end
end

local function RebuildBottomArea()
    if not RebuildPanel() then return end
    RebuildPageButtonPositions()
    RebuildBottomRowPositions()
    RebuildTokenPositions()
end

local function ApplyAll()
    RebuildMerchantFrame()
    RebuildBottomArea()
    if MerchantFrame and MerchantFrame:IsShown() then
        UpdateSlotPositions()
        UpdateBuyBackSlotPositions()
    end
end

-- ============================================================
-- API
-- ============================================================

function M:Enable()
    if self.enabled then return end

    CacheAll()

    self.enabled = true
    _G.MERCHANT_ITEMS_PER_PAGE = ITEMS_PER_PAGE_EXPANDED

    if not self.hooked then
        -- The game rebuilds the bottom of the window on every update and would
        -- otherwise put its own panels, the tokens and the buttons back
        hooksecurefunc("MerchantFrame_UpdateRepairButtons", RebuildBottomRowPositions)
        -- Runs on its own on money and currency events, and puts the gold
        -- display back into the right corner when a merchant takes no currency
        if type(_G.MerchantFrame_UpdateCurrencyAmounts) == "function" then
            hooksecurefunc("MerchantFrame_UpdateCurrencyAmounts", RebuildTokenPositions)
        end
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
            UpdateSlotPositions()
            RebuildBottomArea()
        end)
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
            UpdateBuyBackSlotPositions()
            RebuildBottomArea()
        end)
        self.hooked = true
    end

    ApplyAll()
end

function M:Disable()
    if not self.enabled then return end
    self.enabled = false
    _G.MERCHANT_ITEMS_PER_PAGE = ORIGINAL_ITEMS_PER_PAGE

    -- Hide extra slots
    for i = ORIGINAL_ITEMS_PER_PAGE + 1, ITEMS_PER_PAGE_EXPANDED do
        local slot = _G["MerchantItem" .. i]
        if slot then slot:Hide() end
    end

    -- Restore original positions
    if currencyBar then currencyBar:Hide() end
    if MerchantPageText then
        MerchantPageText:SetParent(MerchantFrame)
        MerchantPageText:Show()
    end
    RestoreAll()

    -- Blizzard repositions item slots 1-10 itself
    if MerchantFrame and MerchantFrame:IsShown() then
        if MerchantFrame_UpdateMerchantInfo then MerchantFrame_UpdateMerchantInfo() end
    end
end

function M:IsEnabled()
    return self.enabled == true
end

-- ============================================================
-- Init
-- ============================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("MERCHANT_SHOW")
initFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if GetDB().enabled then M:Enable() end
    elseif event == "MERCHANT_SHOW" then
        if M.enabled then ApplyAll() end
    end
end)
