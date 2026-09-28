-- Modules/QoL/BlockRequests.lua
-- Blocks incoming duel requests.

local function GetDB()
    if AklimeModDB and AklimeModDB.blockRequests then return AklimeModDB.blockRequests end
    return {}
end

local M = {}
AklimeMod_BlockRequests = M

function M:IsDuelBlocked()      return GetDB().blockDuels      == true end

function M:SetBlockDuels(v)
    GetDB().blockDuels = v and true or false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("DUEL_REQUESTED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "DUEL_REQUESTED" and GetDB().blockDuels then
        CancelDuel()
        StaticPopup_Hide("DUEL_REQUESTED")
    end
end)
