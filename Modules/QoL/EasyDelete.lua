-- Modules/QoL/EasyDelete.lua
-- Streamlines the item delete-confirmation popups:
--
-- Case 1: DELETE_ITEM_CONFIRM (normal items)
--   Hide the edit box and enable the confirm button directly
--
-- Case 2: DELETE_GOOD_ITEM / DELETE_GOOD_QUEST_ITEM (valuable items)
--   Fill the required confirm text into the edit box automatically
--   so it no longer has to be typed by hand

local isSetup    = false
local linkDisplay = nil

-- Setup: FontString above the edit box of the delete popup
local function Setup()
    if isSetup then return end
    isSetup = true

    local popup = _G["StaticPopup1"]
    if not popup then return end

    linkDisplay = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    linkDisplay:SetPoint("CENTER", _G["StaticPopup1EditBox"])
    linkDisplay:Hide()

    popup:HookScript("OnHide", function()
        if linkDisplay then linkDisplay:Hide() end
    end)
end

-- Case 1: normal items. Hide the edit box, enable the button
local function HandleDeleteConfirm()
    local db = AklimeModDB and AklimeModDB.easyDelete
    if not db or db.skipDelete ~= true then return end
    local editBox = _G["StaticPopup1EditBox"]
    local btn1    = _G["StaticPopup1Button1"]
    if editBox and editBox:IsShown() then
        editBox:Hide()
        if btn1 then btn1:Enable() end
        local _, _, link = GetCursorInfo()
        if linkDisplay and link then
            linkDisplay:SetText(link)
            linkDisplay:Show()
        end
    end
end

-- Confirmation text for valuable item deletions/destructions.
-- Matched by substring on the (English, locale-independent) StaticPopup key
-- instead of an exact whitelist, so new Blizzard dialog variants (e.g. for
-- destroying a whole item stack) are covered without having to enumerate
-- every possible key by hand.
local function GetConfirmText(which)
    if not which then return nil end
    local w = which:upper()
    if w:find("DELETE") or w:find("DESTROY") then
        return DELETE_ITEM_CONFIRM_STRING
    end
    return nil
end

-- Helper: set text in the edit box and remove focus
local function FillEditBox(self, text)
    local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
    if editBox then
        editBox:SetText(text)
        editBox:ClearFocus()
        editBox:SetAutoFocus(false)
    end
end

-- Helper: hide the edit box and enable the OK button
local function BypassEditBox(self)
    C_Timer.After(0, function()
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local btn1    = self.button1
        if editBox and editBox:IsShown() then
            editBox:Hide()
            if btn1 then btn1:Enable() end
        end
    end)
end

-- Match a confirmation word wrapped in quotes inside a piece of dialog text.
-- Handles straight quotes and the typographic quotes localized clients use
-- (German „WORT", English "WORD"), so the word is found in any locale.
local function MatchQuotedWord(t)
    if not t then return nil end
    return t:match("'([^']+)'")
        or t:match('"([^"]+)"')
        or t:match("\226\128\158([^\226]+)\226\128\156")
        or t:match("\226\128\156([^\226]+)\226\128\157")
end

-- Extract the required confirmation word from the dialog.
-- Blizzard embeds it in quotes, e.g. „VERLERNEN" or "DESTROY".
-- Scans the main text first, then every other FontString of the popup, so it
-- still works when the hint sits in a separate region.
local function GetRequiredTextFromDialog(popup)
    local textEl = popup.text
    if textEl and textEl.GetText then
        local word = MatchQuotedWord(textEl:GetText())
        if word then return word end
    end
    for _, region in ipairs({ popup:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            local word = MatchQuotedWord(region:GetText())
            if word then return word end
        end
    end
    return nil
end

-- Cases 2-4: intercept popups and automate text entry
local function HookConfirmDialogs()
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup then
            hooksecurefunc(popup, "Show", function(self)
                local db = AklimeModDB and AklimeModDB.easyDelete
                if not db or not self then return end
                local which = self.which

                -- Confirm: delete or destroy valuable items
                if db.skipConfirm then
                    local fallback = GetConfirmText(which)
                    if fallback then
                        FillEditBox(self, GetRequiredTextFromDialog(self) or fallback)
                        return
                    end
                end

                -- Unlearn: forget a profession or skill
                if db.skipUnlearn and which == "UNLEARN_SKILL" then
                    local text = GetRequiredTextFromDialog(self)
                        or CONFIRM_UNLEARN_PROFESSION
                        or DELETE_ITEM_CONFIRM_STRING
                    FillEditBox(self, text)
                    return
                end
            end)
        end
    end
end

local easyDeleteFrame = CreateFrame("Frame")
easyDeleteFrame:RegisterEvent("ADDON_LOADED")
easyDeleteFrame:RegisterEvent("DELETE_ITEM_CONFIRM")
easyDeleteFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AklimeModTools" then
        Setup()
        HookConfirmDialogs()
    elseif event == "DELETE_ITEM_CONFIRM" then
        HandleDeleteConfirm()
    end
end)