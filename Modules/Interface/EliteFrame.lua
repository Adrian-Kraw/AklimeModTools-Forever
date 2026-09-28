-- Modules/Interface/EliteFrame.lua
-- Exact values for the elite/rare portrait styles:
--
-- mode 1: Rare Silver       → Atlas: Boss-Rare-Silver,    80x78,  TOPLEFT(10.5,-10),  normal
-- mode 2: Boss Silver Wing  → Atlas: Boss-Gold-Winged,    99x80,  TOPLEFT(-9,-9),     desaturated
-- mode 3: Boss Gold Wing    → Atlas: Boss-Gold-Winged,    99x80,  TOPLEFT(-9,-9),     normal
-- mode 4: Elite Gold        → Atlas: Boss-Gold,           80x78,  TOPLEFT(10.5,-10),  normal
-- All: SetTexCoord(1,0,0,1) mirrored

local MODES = {
    silver     = { atlas="UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver", w=80, h=78, x=10.5, y=-10, desaturated=false },
    silverWing = { atlas="UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", w=99, h=80, x=-9,   y=-9,  desaturated=true  },
    goldWing   = { atlas="UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", w=99, h=80, x=-9,   y=-9,  desaturated=false },
    gold       = { atlas="UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold",        w=80, h=78, x=10.5, y=-10, desaturated=false },
}

local playerElite = nil

local function GetOrCreateTexture()
    if playerElite then return playerElite end
    local container = PlayerFrame and PlayerFrame.PlayerFrameContainer
    if not container then return nil end
    playerElite = container:CreateTexture(nil, "OVERLAY", nil, 6)
    playerElite:SetTexCoord(1, 0, 0, 1)
    playerElite:Hide()
    return playerElite
end

function AklimeMod_ApplyEliteFrame(style)
    if not AklimeModDB.eliteFrame.enabled then return end
    style = style or AklimeModDB.eliteFrame.style
    if not style then return end

    local mode = MODES[style]
    if not mode then return end

    local tex = GetOrCreateTexture()
    if not tex then return end

    tex:SetAtlas(mode.atlas, false)
    tex:SetSize(mode.w, mode.h)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", PlayerFrame.PlayerFrameContainer, "TOPLEFT", mode.x, mode.y)
    tex:SetDesaturated(mode.desaturated)

    -- Coloring via the Colorizer skin "Elite Frame" (Addons group).
    -- Done here instead of in the skin itself, so style changes and later
    -- activation carry the color automatically.
    local C = AklimeMod_Colorizer
    if C and C.IsEnabled and C:IsEnabled("eliteFrame") then
        local r, g, b, a = C:GetColor("eliteFrame", "main")
        tex:SetDesaturated(true)
        tex:SetVertexColor(r, g, b, a)
    else
        tex:SetVertexColor(1, 1, 1, 1)
    end
    tex:Show()
end

function AklimeMod_RemoveEliteFrame()
    if playerElite then playerElite:Hide() end
end