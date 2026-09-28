-- Modules/Mouse/MouseEffects.lua

local Mouse = {}
local runner = CreateFrame("Frame")
local ring, lastX, lastY, lastScale
local pool, active = {}, 0
local allTrail = {}
local acc, lastTrailX, lastTrailY = 0, nil, nil

local TRAIL_PRESETS = {
    low = { cap = 20, interval = 0.028, distanceSq = 36, duration = 0.35, size = 22 },
    medium = { cap = 40, interval = 0.018, distanceSq = 16, duration = 0.45, size = 26 },
    high = { cap = 80, interval = 0.012, distanceSq = 9, duration = 0.60, size = 30 },
    ultra = { cap = 120, interval = 0.008, distanceSq = 4, duration = 0.70, size = 34 },
}

local function DB()
    AklimeModDB.mouseEffects = AklimeModDB.mouseEffects or {}
    return AklimeModDB.mouseEffects
end

local function ClassColor()
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

local function EnsureRing()
    if ring then return ring end
    ring = CreateFrame("Frame", "AklimeModMouseRingFrame", UIParent)
    ring:SetFrameStrata("TOOLTIP")
    ring:SetSize(76, 76)
    ring.tex = ring:CreateTexture(nil, "ARTWORK")
    ring.tex:SetAllPoints()
    ring.tex:SetAtlas("ArtifactsFX-YellowRing")
    ring.tex:SetBlendMode("ADD")
    ring.dot = ring:CreateTexture(nil, "OVERLAY")
    ring.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    ring.dot:SetSize(4, 4)
    ring.dot:SetPoint("CENTER")
    ring:Hide()
    return ring
end

local function StyleRing()
    local db = DB()
    local f = EnsureRing()
    local size = db.size or 76
    f:SetSize(size, size)
    local r, g, b = ClassColor()
    if db.classColor == false then
        local color = db.customColor or {}
        r, g, b = color.r or 1, color.g or 0.82, color.b or 0
    end
    if db.hideRing then
        f.tex:Hide()
    else
        f.tex:Show()
        f.tex:SetVertexColor(r, g, b, db.alpha or 0.9)
    end
    f.dot:SetVertexColor(r, g, b, 1)
    if db.hideDot then f.dot:Hide() else f.dot:Show() end
end

local function TrailPreset()
    return TRAIL_PRESETS[DB().trailPreset or "medium"] or TRAIL_PRESETS.medium
end

local function NewTrail()
    local tex = UIParent:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\Cooldown\\star4")
    tex:SetBlendMode("ADD")
    tex:SetSize(26, 26)
    local ag = tex:CreateAnimationGroup()
    ag:SetScript("OnFinished", function()
        tex:Hide()
        active = active - 1
        pool[#pool + 1] = tex
    end)
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.75)
    fade:SetToAlpha(0)
    fade:SetDuration(0.45)
    local scale = ag:CreateAnimation("Scale")
    scale:SetScale(0.35, 0.35)
    scale:SetDuration(0.45)
    tex.anim = ag
    tex.fade = fade
    tex.scale = scale
    tex:Hide()
    allTrail[#allTrail + 1] = tex
    return tex
end

local function HideAllTrail()
    wipe(pool)
    active = 0
    for _, tex in ipairs(allTrail) do
        if tex.anim then tex.anim:Stop() end
        tex:Hide()
        pool[#pool + 1] = tex
    end
end

local function EnsurePool()
    local cap = TrailPreset().cap
    while active + #pool < cap do
        pool[#pool + 1] = NewTrail()
    end
end

local function SpawnTrail(x, y, scale)
    local db = DB()
    local preset = TrailPreset()
    local cap = preset.cap
    if active >= cap then return end
    if #pool == 0 then EnsurePool() end
    local tex = table.remove(pool)
    if not tex then return end
    active = active + 1
    local r, g, b = ClassColor()
    local a = 0.85
    if db.trailClassColor == false then
        r, g, b, a = Mouse.GetTrailColor()
    end
    tex:SetVertexColor(r, g, b, a)
    tex:SetSize(preset.size, preset.size)
    if tex.fade then tex.fade:SetDuration(preset.duration) end
    if tex.scale then tex.scale:SetDuration(preset.duration) end
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    tex.anim:Stop()
    tex.anim:Play()
    tex:Show()
end

local function ShouldShowRing()
    local db = DB()
    if not db.enabled then return false end
    if db.onlyCombat and not UnitAffectingCombat("player") then return false end
    if db.onlyRightClick and not IsMouseButtonDown("RightButton") then return false end
    return true
end

local function ShouldShowTrail()
    local db = DB()
    if not db.trail then return false end
    if db.trailOnlyCombat and not UnitAffectingCombat("player") then return false end
    return true
end

local function OnUpdate(_, elapsed)
    local wantRing, wantTrail = ShouldShowRing(), ShouldShowTrail()
    if not wantRing and not wantTrail then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if wantRing then
        local f = EnsureRing()
        if lastX ~= x or lastY ~= y or lastScale ~= scale then
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
            lastX, lastY, lastScale = x, y, scale
        end
        if not f:IsShown() then f:Show() end
    elseif ring then
        ring:Hide()
    end
    if wantTrail then
        acc = acc + elapsed
        local preset = TrailPreset()
        local dx = lastTrailX and (x - lastTrailX) or 999
        local dy = lastTrailY and (y - lastTrailY) or 999
        if acc >= preset.interval and (dx * dx + dy * dy) > preset.distanceSq then
            acc = 0
            lastTrailX, lastTrailY = x, y
            SpawnTrail(x, y, scale)
        end
    end
end

local function UpdateRunner()
    local db = DB()
    if db.enabled or db.trail then
        StyleRing()
        EnsurePool()
        runner:SetScript("OnUpdate", OnUpdate)
    else
        runner:SetScript("OnUpdate", nil)
        if ring then ring:Hide() end
        HideAllTrail()
        lastX, lastY, lastScale = nil, nil, nil
        lastTrailX, lastTrailY = nil, nil
    end
end

function Mouse.IsEnabled()
    local db = DB()
    return db.enabled == true or db.trail == true
end
function Mouse.SetEnabled(v)
    local db = DB()
    db.enabled = v and true or false
    if not v then db.trail = false end
    UpdateRunner()
end
function Mouse.Get(key) return DB()[key] == true end
function Mouse.Set(key, v) DB()[key] = v and true or false; UpdateRunner() end
function Mouse.GetSize() return DB().size or 76 end
function Mouse.SetSize(size) DB().size = size; UpdateRunner() end
function Mouse.GetTrailPreset() return DB().trailPreset or "medium" end
function Mouse.SetTrailPreset(preset) DB().trailPreset = preset or "medium"; UpdateRunner() end
function Mouse.GetCustomColor()
    local color = DB().customColor or {}
    return color.r or 1, color.g or 0.82, color.b or 0, color.a or 0.9
end
function Mouse.SetCustomColor(r, g, b, a)
    DB().customColor = { r = r or 1, g = g or 0.82, b = b or 0, a = a or 0.9 }
    DB().classColor = false
    UpdateRunner()
end
function Mouse.GetTrailColor()
    local color = DB().customTrailColor or {}
    return color.r or 1, color.g or 0.82, color.b or 0, color.a or 0.85
end
function Mouse.SetTrailColor(r, g, b, a)
    DB().customTrailColor = { r = r or 1, g = g or 0.82, b = b or 0, a = a or 0.85 }
    DB().trailClassColor = false
    UpdateRunner()
end
function Mouse.Apply() UpdateRunner() end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", UpdateRunner)

AklimeMod_MouseEffects = Mouse
