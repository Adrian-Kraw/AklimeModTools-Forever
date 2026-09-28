-- Modules/QoL/BlockRequests.lua
-- Blocks incoming duel requests and pet battle duel requests.

local function GetDB()
    if AklimeModDB and AklimeModDB.blockRequests then return AklimeModDB.blockRequests end
    return {}
end

local M = {}
AklimeMod_BlockRequests = M

function M:IsDuelBlocked()      return GetDB().blockDuels      == true end
function M:IsPetBattleBlocked() return GetDB().blockPetBattles == true end

function M:SetBlockDuels(v)
    GetDB().blockDuels = v and true or false
end

function M:SetBlockPetBattles(v)
    GetDB().blockPetBattles = v and true or false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("DUEL_REQUESTED")
eventFrame:RegisterEvent("PET_BATTLE_PVP_DUEL_REQUESTED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "DUEL_REQUESTED" and GetDB().blockDuels then
        CancelDuel()
        StaticPopup_Hide("DUEL_REQUESTED")
    elseif event == "PET_BATTLE_PVP_DUEL_REQUESTED" and GetDB().blockPetBattles then
        C_PetBattles.CancelPVPDuel()
        StaticPopup_Hide("PET_BATTLE_PVP_DUEL_REQUESTED")
    end
end)
