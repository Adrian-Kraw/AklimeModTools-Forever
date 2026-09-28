-- Modules/QoL/AutoRepair.lua

local L = AklimeModL or {}

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD   = 10000

-- Forever has no GetCoinTextureString anymore, Blizzard replaced it with
-- MoneyFormatterUtil. The old function stays as fallback for other clients.
local function FormatCoins(copper)
    if MoneyFormatterUtil and MoneyFormatterPresets then
        return MoneyFormatterUtil.FormatMoney(copper, MoneyFormatterPresets.Compact)
    end
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    return string.format("%dg %ds %dc",
        math.floor(copper / COPPER_PER_GOLD),
        math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER),
        copper % COPPER_PER_SILVER)
end

local repairFrame = CreateFrame("Frame")
repairFrame:RegisterEvent("MERCHANT_SHOW")
repairFrame:SetScript("OnEvent", function()
    if not AklimeModDB or not AklimeModDB.autoRepair.enabled then return end
    if not CanMerchantRepair() then return end

    local cost = GetRepairAllCost()
    if not cost or cost == 0 then return end

    if AklimeModDB.autoRepair.useGuild then
        local gw = GetGuildBankWithdrawMoney()
        if IsInGuild() and gw and (gw == -1 or gw >= cost) then
            RepairAllItems(1)
            print("|cFF00CCFFAklime Mod Tools:|r " .. L["repair_guild_done"] .. FormatCoins(cost))
            return
        end
    end

    if AklimeModDB.autoRepair.useGold then
        if GetMoney() >= cost then
            RepairAllItems()
            print("|cFF00CCFFAklime Mod Tools:|r " .. L["repair_done"] .. FormatCoins(cost))
        else
            print("|cFFFF4444Aklime Mod Tools:|r " .. L["repair_no_gold"])
        end
    end
end)
