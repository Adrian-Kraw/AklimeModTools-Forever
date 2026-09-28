-- Modules/QoL/AutoSellJunk.lua
-- Automatically sells all gray items at the merchant.
-- Uses hooksecurefunc on MerchantFrame_UpdateMerchantInfo.
-- Called in a secure context once the merchant is loaded.

local function GetDB()
    return AklimeModDB and AklimeModDB.autoSellJunk
end

local sold = false  -- Run only once per merchant visit

local function DoSell()
    if sold then return end
    local db = GetDB()
    if not db or not db.enabled then return end
    sold = true
    C_MerchantFrame.SellAllJunkItems()
end

-- MerchantFrame_UpdateMerchantInfo runs in a secure context
-- and is called once the merchant is fully loaded
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", DoSell)

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")

frame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        sold = false
    elseif event == "MERCHANT_CLOSED" then
        sold = false
    end
end)

AklimeMod_AutoSellJunk = {
    IsEnabled  = function() local db = GetDB(); return db and db.enabled end,
    SetEnabled = function(v) local db = GetDB(); if db then db.enabled = v end end,
}