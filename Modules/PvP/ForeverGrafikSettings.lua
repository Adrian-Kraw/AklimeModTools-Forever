-- Modules/PvP/ForeverGrafikSettings.lua
-- Graphics options of WoW Forever in one place, hidden ones included.
-- The player's own values are saved once as a backup at the first login.
-- While the feature is on, the selected preset or the own set (Custom) is
-- applied at every login. Presets are locked and never change the own set,
-- Copy to Custom turns a preset into the player's own set.
-- Turning the feature off or pressing Default brings the backup back.
-- CVar names, value ranges, linked CVars and presets follow the addon ForeverVisuals.

local L = AklimeModL or {}

-- Account settings reach the client late and can overwrite our values
local APPLY_DELAY   = 5
local REAPPLY_DELAY = 0.5   -- the graphics menu sets several CVars per slider
local TOLERANCE     = 0.001

local PRESET_CUSTOM  = "custom"
local PRESET_DEFAULT = "default"

-- Options per group in the order of the menu. Checkboxes use 0 and 1 like the
-- CVars do, so every option shares the same code path. offAtZero shows "Off"
-- instead of 0 on the slider. linked returns the CVars the game menu sets
-- together with an option, linkedCVars lists them for the backup.
-- conflictAddon names an addon that controls the option itself.
local GROUPS = {
    { key = "new", settings = {
        { cvar = "giQuality", kind = "slider", min = 1, max = 4, step = 1,
          linkedCVars = { "RenderFormat" },
          linked = function(value) return { RenderFormat = value >= 2 and 2 or 1 } end },
        { cvar = "volumeFog",      kind = "checkbox", min = 0, max = 1, step = 1 },
        { cvar = "volumeFogLevel", kind = "slider", min = 0, max = 4, step = 1 },
        { cvar = "sunShafts",      kind = "slider", min = 0, max = 2, step = 1, offAtZero = true },
        { cvar = "pbrLiquidDetail", kind = "slider", min = 0, max = 2, step = 1, offAtZero = true },
        { cvar = "bloomUserMult",  kind = "slider", min = 0, max = 1, step = 0.1, format = "%.1f" },
    } },
    { key = "image", settings = {
        { cvar = "Brightness", kind = "slider", min = 0, max = 100, step = 1 },
        { cvar = "Contrast",   kind = "slider", min = 0, max = 100, step = 1 },
    } },
    { key = "world", settings = {
        { cvar = "groundEffectDensity", kind = "slider", min = 16, max = 256, step = 16 },
        { cvar = "groundEffectDist",    kind = "slider", min = 40, max = 500, step = 10 },
        { cvar = "groundEffectFade",    kind = "slider", min = 0,  max = 500, step = 10 },
        { cvar = "weatherDensity",      kind = "slider", min = 0,  max = 3,   step = 1, offAtZero = true },
    } },
    { key = "lod", settings = {
        { cvar = "lodObjectCullSize",   kind = "slider", min = 0,  max = 30,  step = 1 },
        { cvar = "lodObjectFadeScale",  kind = "slider", min = 50, max = 300, step = 10 },
    } },
    { key = "view", settings = {
        { cvar = "cameraDistanceMaxZoomFactor", kind = "slider", min = 1, max = 4, step = 0.1, format = "%.1f" },
        { cvar = "ResampleAlwaysSharpen", kind = "checkbox", min = 0, max = 1, step = 1 },
        { cvar = "ResampleSharpness",     kind = "slider", min = 0, max = 1, step = 0.05, format = "%.2f" },
    } },
    { key = "classic", settings = {
        -- The sparkles only show while the outline mode is off (0). Turning them
        -- off sets the outline mode back to High (2).
        { cvar = "outlineModeShowLootEffectWhenDisabled", kind = "checkbox", min = 0, max = 1, step = 1,
          conflictAddon = "ForeverLootSparkles",
          linkedCVars = { "graphicsOutlineMode", "OutlineEngineMode", "raidGraphicsOutlineMode", "RAIDOutlineEngineMode" },
          linked = function(value)
              local outline = value == 1 and 0 or 2
              return {
                  graphicsOutlineMode = outline, OutlineEngineMode = outline,
                  raidGraphicsOutlineMode = outline, RAIDOutlineEngineMode = outline,
              }
          end },
    } },
    { key = "interact", settings = {
        -- On: icon on objects too, all around you, 15 yards. Off: game defaults.
        { cvar = "SoftTargetNameplateInteract", kind = "checkbox", min = 0, max = 1, step = 1,
          conflictAddon = "ForeverLootSparkles",
          linkedCVars = { "SoftTargetIconGameObject", "SoftTargetLowPriorityIcons",
                          "SoftTargetInteractArc", "SoftTargetInteractRange" },
          linked = function(value)
              local on = value == 1
              local function Default(cvar) return tonumber(C_CVar.GetCVarDefault(cvar)) or 0 end
              return {
                  SoftTargetIconGameObject   = on and 1  or Default("SoftTargetIconGameObject"),
                  SoftTargetLowPriorityIcons = on and 1  or Default("SoftTargetLowPriorityIcons"),
                  SoftTargetInteractArc      = on and 2  or Default("SoftTargetInteractArc"),
                  SoftTargetInteractRange    = on and 15 or Default("SoftTargetInteractRange"),
              }
          end },
    } },
}

-- Presets only name the options they change. Blizzard Default is handled in code.
local PRESETS = {
    { key = "performance", values = {
        groundEffectDensity = 32, groundEffectDist = 70, groundEffectFade = 60, weatherDensity = 1,
        lodObjectCullSize = 19, lodObjectFadeScale = 90, ResampleAlwaysSharpen = 0,
        giQuality = 1, volumeFog = 1, volumeFogLevel = 1, sunShafts = 0, pbrLiquidDetail = 0,
    } },
    { key = "balanced", values = {
        groundEffectDensity = 128, groundEffectDist = 200, groundEffectFade = 180, weatherDensity = 2,
        lodObjectCullSize = 14, lodObjectFadeScale = 150,
        cameraDistanceMaxZoomFactor = 2.6, ResampleAlwaysSharpen = 1,
        giQuality = 2, volumeFog = 1, volumeFogLevel = 3, sunShafts = 1, pbrLiquidDetail = 1,
    } },
    { key = "max", values = {
        groundEffectDensity = 256, groundEffectDist = 500, groundEffectFade = 370, weatherDensity = 3,
        lodObjectCullSize = 8, lodObjectFadeScale = 200,
        cameraDistanceMaxZoomFactor = 4.0, ResampleAlwaysSharpen = 1,
        giQuality = 4, volumeFog = 1, volumeFogLevel = 4, sunShafts = 2, pbrLiquidDetail = 2, bloomUserMult = 1,
    } },
    { key = "classic", values = {
        giQuality = 1, volumeFog = 0, sunShafts = 0, pbrLiquidDetail = 0, bloomUserMult = 0,
    } },
    { key = "modern", values = {
        giQuality = 4, volumeFog = 1, volumeFogLevel = 4, sunShafts = 2, pbrLiquidDetail = 2, bloomUserMult = 1,
    } },
    { key = PRESET_DEFAULT },
}

local presetsByKey = {}
for _, preset in ipairs(PRESETS) do presetsByKey[preset.key] = preset end

-- Changes made in combat wait until the fight is over (cvar -> text)
local pending = {}
local reapplyQueued = false
local backupChecked = false   -- the backup is completed once per session

-- ============================================================
-- Helpers
-- ============================================================
local function GetDB()
    return AklimeModDB and AklimeModDB.foreverGrafik
end

local function IsEnabled()
    local db = GetDB()
    return db and db.enabled
end

-- GetCVar returns nil for a CVar this client does not know
local function IsAvailable(cvar)
    return C_CVar.GetCVar(cvar) ~= nil
end

local function IsConflicted(def)
    return def.conflictAddon ~= nil and C_AddOns.IsAddOnLoaded(def.conflictAddon)
end

local function ForEachSetting(callback)
    for _, group in ipairs(GROUPS) do
        for _, def in ipairs(group.settings) do callback(def) end
    end
end

local function RoundToStep(value, step)
    local rounded = math.floor(value / step + 0.5) * step
    -- 0.30000000000000004 becomes 0.3
    return tonumber(("%.3f"):format(rounded))
end

-- 4 becomes "4", 0.3 becomes "0.3"
local function ToCVarText(value)
    if value == math.floor(value) then
        return tostring(math.floor(value))
    end
    local text = ("%.3f"):format(value):gsub("0+$", ""):gsub("%.$", "")
    return text
end

local function RefreshMenu()
    if AklimeMod_RefreshRightToggles then AklimeMod_RefreshRightToggles() end
end

local function StatsCall(name, ...)
    local stats = AklimeMod_ForeverGrafikStats
    if stats then return stats[name](...) end
end

-- ============================================================
-- Apply
-- ============================================================
local function ApplyValue(cvar, value)
    local currentText = C_CVar.GetCVar(cvar)
    -- Unknown CVars are left alone
    if currentText == nil then return end
    local current = tonumber(currentText)
    if current and math.abs(current - value) <= TOLERANCE then return end

    local text = ToCVarText(value)
    if InCombatLockdown() then
        pending[cvar] = text
        return
    end
    C_CVar.SetCVar(cvar, text)
end

local function ApplySetting(def, value)
    if IsConflicted(def) then return end
    ApplyValue(def.cvar, value)
    if def.linked then
        for cvar, linkedValue in pairs(def.linked(value)) do
            ApplyValue(cvar, linkedValue)
        end
    end
end

-- Options that another addon controls. Their CVars are left alone completely.
local function GetConflictedCVars()
    local skipped = {}
    ForEachSetting(function(def)
        if IsConflicted(def) then
            skipped[def.cvar] = true
            for _, cvar in ipairs(def.linkedCVars or {}) do skipped[cvar] = true end
        end
    end)
    return skipped
end

-- Presets only change the options they name
local function ApplyPresetValues(preset)
    ForEachSetting(function(def)
        local value = preset.values and preset.values[def.cvar]
        if value ~= nil and IsAvailable(def.cvar) then ApplySetting(def, value) end
    end)
end

-- ============================================================
-- Backup
-- ============================================================
-- Only while no value of ours can be in the game: the feature is off, or it is
-- on with the own set and nothing was chosen for this option.
local function MayStore(db, def)
    if not db.enabled then return true end
    return db.preset == PRESET_CUSTOM and db.custom[def.cvar] == nil
end

-- Created at the first login, saved values are never overwritten. Options that
-- a later version adds get their value saved the next time this runs, as long
-- as the game still holds the player's own value for them.
local function CreateBackup()
    local db = GetDB()
    if not db then return end

    db.backup = db.backup or {}
    local backup = db.backup
    local function Store(cvar)
        local value = C_CVar.GetCVar(cvar)
        if backup[cvar] == nil and value ~= nil then backup[cvar] = value end
    end
    ForEachSetting(function(def)
        if not MayStore(db, def) then return end
        Store(def.cvar)
        for _, cvar in ipairs(def.linkedCVars or {}) do Store(cvar) end
    end)
end

local function RestoreBackup()
    local db = GetDB()
    if not db or not db.backup then return end
    local skipped = GetConflictedCVars()
    for cvar, text in pairs(db.backup) do
        local value = tonumber(text)
        if value and not skipped[cvar] then ApplyValue(cvar, value) end
    end
end

-- ============================================================
-- Own set (Custom)
-- ============================================================
-- The saved values overlaid with the player's own changes. An option that
-- matches its saved value is left to the backup, so the game gets exactly the
-- saved values back, linked CVars included.
local function BuildCustomTarget(db)
    local skipped = GetConflictedCVars()
    local target = {}
    for cvar, text in pairs(db.backup or {}) do
        local value = tonumber(text)
        if value and not skipped[cvar] then target[cvar] = value end
    end

    ForEachSetting(function(def)
        local own = db.custom[def.cvar]
        if own == nil or IsConflicted(def) or not IsAvailable(def.cvar) then return end
        local saved = tonumber(db.backup and db.backup[def.cvar])
        if saved and math.abs(own - saved) <= TOLERANCE then return end

        target[def.cvar] = own
        if def.linked then
            for cvar, linkedValue in pairs(def.linked(own)) do target[cvar] = linkedValue end
        end
    end)
    return target
end

local function ApplyCustom()
    local db = GetDB()
    for cvar, value in pairs(BuildCustomTarget(db)) do ApplyValue(cvar, value) end
end

-- The feature is on: apply what the selected preset or the own set says
local function ApplyAll()
    local db = GetDB()
    if not db then return end

    if db.preset == PRESET_CUSTOM then
        -- An empty own set means nothing was chosen, the game keeps what it has
        if next(db.custom) then ApplyCustom() end
    elseif presetsByKey[db.preset] then
        ApplyPresetValues(presetsByKey[db.preset])
    end
end

-- The own set is emptied, every option shows the saved value again
local function ResetToBackup()
    local db = GetDB()
    if not db or not db.backup then return end
    wipe(db.custom)
    db.preset = PRESET_CUSTOM
    RestoreBackup()
end

-- ============================================================
-- Values for the menu
-- ============================================================
-- Presets are locked, the options only move while the own set is selected
local function IsLocked(def)
    local db = GetDB()
    return not db or not db.enabled or db.preset ~= PRESET_CUSTOM or IsConflicted(def)
end

-- In the own set an option shows its own value, else the saved one. With a
-- preset it shows what the game has right now.
local function GetValue(def)
    local db = GetDB()
    if db and db.enabled and db.preset == PRESET_CUSTOM then
        local own = db.custom[def.cvar]
        if own ~= nil then return own end
        local saved = tonumber(db.backup and db.backup[def.cvar])
        if saved then return saved end
    end
    return tonumber(C_CVar.GetCVar(def.cvar)) or def.min
end

local function FormatValue(def, value)
    if value == nil then return "?" end
    if def.offAtZero and value == 0 then
        return L["grafik_off"] or "Off"
    end
    return def.format and def.format:format(value) or tostring(value)
end

local function ClampToSetting(def, value)
    return math.max(def.min, math.min(def.max, RoundToStep(value, def.step)))
end

-- The player moved an option of the own set: apply it and measure the FPS change
local function SetValue(def, value)
    local db = GetDB()
    if not db or IsLocked(def) then return end

    local old = GetValue(def)
    db.custom[def.cvar] = ClampToSetting(def, value)
    ApplyCustom()

    local new = GetValue(def)
    if old ~= new then
        StatsCall("StartComparison", def.cvar, L["grafik_" .. def.cvar] or def.cvar,
            FormatValue(def, old), FormatValue(def, new))
    end
end

-- What the selected preset sets right now becomes the player's own set
local function CopyToCustom()
    local db = GetDB()
    if not db or not db.enabled or db.preset == PRESET_CUSTOM then return end

    wipe(db.custom)
    ForEachSetting(function(def)
        if IsAvailable(def.cvar) then db.custom[def.cvar] = ClampToSetting(def, GetValue(def)) end
    end)
    db.preset = PRESET_CUSTOM
end

-- ============================================================
-- Presets
-- ============================================================
local function GetPresetLabel(key)
    return L["grafik_preset_" .. key] or key
end

local function GetPresetOptions()
    local options = { { value = PRESET_CUSTOM, label = GetPresetLabel(PRESET_CUSTOM) } }
    for _, preset in ipairs(PRESETS) do
        options[#options + 1] = { value = preset.key, label = GetPresetLabel(preset.key) }
    end
    return options
end

-- Blizzard Default: the game's own values, nothing is reapplied afterwards
local function ApplyBlizzardDefault()
    ForEachSetting(function(def)
        local value = tonumber(C_CVar.GetCVarDefault(def.cvar))
        if value and IsAvailable(def.cvar) then ApplySetting(def, value) end
    end)
end

local function ApplyPreset(key)
    local db = GetDB()
    if not db or not db.enabled then return end
    if key ~= PRESET_CUSTOM and not presetsByKey[key] then return end

    db.preset = key
    if key == PRESET_CUSTOM then
        ApplyCustom()
    elseif key == PRESET_DEFAULT then
        ApplyBlizzardDefault()
    else
        ApplyPresetValues(presetsByKey[key])
    end
    StatsCall("StartComparison", "preset", L["grafik_preset"] .. " " .. GetPresetLabel(key))
end

-- ============================================================
-- Events
-- ============================================================
local function OnLoginSettled()
    CreateBackup()
    if IsEnabled() then ApplyAll() end
end

-- Blizzard's graphics menu overwrites some values, for example grass and weather
local function QueueReapply()
    if reapplyQueued then return end
    reapplyQueued = true
    C_Timer.After(REAPPLY_DELAY, function()
        reapplyQueued = false
        if IsEnabled() then ApplyAll() end
        RefreshMenu()
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    local db = GetDB()
    if not db then return end

    if event == "PLAYER_REGEN_ENABLED" then
        for cvar, text in pairs(pending) do C_CVar.SetCVar(cvar, text) end
        wipe(pending)
    elseif event == "CVAR_UPDATE" then
        local name = type(arg1) == "string" and arg1:lower() or ""
        if db.enabled and db.protect and (name:find("^graphics") or name:find("^raidgraphics")) then
            QueueReapply()
        end
    else
        -- The backup is checked at the first loading screen of a session, so
        -- it is complete at every login. While the feature is on, the values
        -- are applied after every loading screen.
        if backupChecked and not db.enabled then return end
        backupChecked = true
        C_Timer.After(APPLY_DELAY, OnLoginSettled)
    end
end)

-- ============================================================
-- API
-- ============================================================
AklimeMod_ForeverGrafik = {
    GROUPS           = GROUPS,
    IsEnabled        = function() return IsEnabled() end,
    SetEnabled       = function(v)
        local db = GetDB()
        if not db then return end
        -- The backup must exist before the first value is applied
        if v then CreateBackup() end
        db.enabled = v
        if v then ApplyAll() else RestoreBackup() end
        StatsCall("Refresh")
    end,
    IsAvailable      = IsAvailable,
    IsLocked         = IsLocked,
    GetValue         = GetValue,
    SetValue         = SetValue,
    FormatValue      = FormatValue,
    ResetToBackup    = ResetToBackup,
    CopyToCustom     = CopyToCustom,
    GetPreset        = function() local db = GetDB(); return db and db.preset or PRESET_CUSTOM end,
    GetPresetLabel   = GetPresetLabel,
    GetPresetOptions = GetPresetOptions,
    ApplyPreset      = ApplyPreset,
    IsProtected      = function() local db = GetDB(); return db and db.protect end,
    SetProtected     = function(v) local db = GetDB(); if db then db.protect = v end end,
}
