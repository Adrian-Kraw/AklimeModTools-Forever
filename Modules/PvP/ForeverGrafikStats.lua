-- Modules/PvP/ForeverGrafikStats.lua
-- FPS measurement for the graphics settings: a movable overlay, a before and
-- after comparison for every changed option and a benchmark per preset.
-- It only runs while the graphics feature is on and something needs the numbers.

local L = AklimeModL or {}

-- Frames are counted in buckets, so average and minimum come from the same data
local BUCKET_SECONDS    = 0.25
local WINDOW_BUCKETS    = 20     -- the last 5 seconds
local MIN_WINDOW_SECONDS = 1     -- shorter windows are too noisy
-- Settle time is waiting for shaders to load before the measurement starts
local COMPARE_SECONDS, COMPARE_SETTLE = 4, 1.5
local BENCH_SECONDS,   BENCH_SETTLE   = 10, 3

local FPS_GOOD, FPS_OK = 60, 30
local COLOR_GOOD = "ff40ff40"
local COLOR_OK   = "ffffd100"
local COLOR_BAD  = "ffff4040"
local CHANGE_OK_PERCENT  = -2
local CHANGE_BAD_PERCENT = -10

local OVERLAY_WIDTH  = 210
local OVERLAY_HEIGHT = 70
local OVERLAY_PAD    = 8
local OVERLAY_START  = { point = "TOPLEFT", x = 20, y = -200 }
local BENCH_BUTTON_HEIGHT = 24

local buckets = {}
local currentFrames, currentTime = 0, 0
local measurements = {}
local comparison, benchmark, overlay, lastComparison

local driver = CreateFrame("Frame")

-- ============================================================
-- Helpers
-- ============================================================
local function GetDB()
    return AklimeModDB and AklimeModDB.foreverGrafik
end

local function Print(text)
    print("|cFFFFD100Aklime Mod Tools:|r " .. text)
end

local function ColorFps(fps)
    local color = fps >= FPS_GOOD and COLOR_GOOD or fps >= FPS_OK and COLOR_OK or COLOR_BAD
    return ("|c%s%d|r"):format(color, math.floor(fps + 0.5))
end

-- A word instead of an arrow, because the game fonts have no glyph for arrows
local function To()
    return L["grafik_to"] or "to"
end

-- "62 to 55 FPS (-11 %)" with the change colored
local function FormatChange(before, after)
    local percent = (after - before) / before * 100
    local color = percent >= CHANGE_OK_PERCENT and COLOR_GOOD
        or percent >= CHANGE_BAD_PERCENT and COLOR_OK or COLOR_BAD
    local sign = percent >= 0 and "+" or "-"
    return ("%d %s %d FPS (|c%s%s%d %%|r)"):format(math.floor(before + 0.5), To(), math.floor(after + 0.5),
        color, sign, math.floor(math.abs(percent) + 0.5))
end

-- Average and minimum over the last buckets, nil while there is too little data
local function WindowStats(count)
    local frames, time, minFps = 0, 0, math.huge
    for i = math.max(1, #buckets - count + 1), #buckets do
        local bucket = buckets[i]
        frames = frames + bucket.frames
        time   = time + bucket.time
        minFps = math.min(minFps, bucket.frames / bucket.time)
    end
    if time < MIN_WINDOW_SECONDS then return nil end
    return frames / time, minFps
end

-- ============================================================
-- Measuring
-- ============================================================
local function OnBucket(bucket)
    for i = #measurements, 1, -1 do
        local m = measurements[i]
        if m.cancelled then
            table.remove(measurements, i)
        elseif m.settle > 0 then
            m.settle = m.settle - bucket.time
        else
            m.frames = m.frames + bucket.frames
            m.time   = m.time + bucket.time
            m.minFps = math.min(m.minFps, bucket.frames / bucket.time)
            if m.time >= m.duration then
                table.remove(measurements, i)
                m.callback(m.frames / m.time, m.minFps)
            end
        end
    end
end

local UpdateOverlay  -- defined below

local function OnUpdate(_, elapsed)
    currentFrames = currentFrames + 1
    currentTime   = currentTime + elapsed
    if currentTime < BUCKET_SECONDS then return end

    local bucket = { frames = currentFrames, time = currentTime }
    buckets[#buckets + 1] = bucket
    if #buckets > WINDOW_BUCKETS then table.remove(buckets, 1) end
    currentFrames, currentTime = 0, 0

    OnBucket(bucket)
    UpdateOverlay()
end

local function NeedsDriver()
    if #measurements > 0 then return true end
    local db = GetDB()
    return db and db.enabled and (db.showStats or db.compare)
end

-- Counting only runs while someone needs the numbers
local function UpdateDriver()
    if NeedsDriver() then
        driver:SetScript("OnUpdate", OnUpdate)
    else
        driver:SetScript("OnUpdate", nil)
        wipe(buckets)
        currentFrames, currentTime = 0, 0
    end
end

local function Measure(duration, settle, callback)
    local measurement = {
        duration = duration, settle = settle, callback = callback,
        frames = 0, time = 0, minFps = math.huge,
    }
    measurements[#measurements + 1] = measurement
    UpdateDriver()
    return measurement
end

-- ============================================================
-- Comparison before and after a change
-- ============================================================
-- Several changes of the same option in a row, for example while dragging a
-- slider, count as one: first old value to last new value.
local function StartComparison(key, label, fromText, toText)
    local db = GetDB()
    if not db or not db.enabled or not db.compare then return end

    if comparison and comparison.key == key then
        comparison.toText = toText
        comparison.measurement.cancelled = true
    else
        if comparison then comparison.measurement.cancelled = true end
        comparison = {
            key = key, label = label, fromText = fromText, toText = toText,
            before = WindowStats(WINDOW_BUCKETS),
        }
    end

    local current = comparison
    current.measurement = Measure(COMPARE_SECONDS, COMPARE_SETTLE, function(after)
        comparison = nil
        local change = current.label
        if current.fromText then
            change = ("%s %s %s %s"):format(current.label, current.fromText, To(), current.toText)
        end
        if current.before then
            lastComparison = ("%s: %s"):format(change, FormatChange(current.before, after))
        else
            lastComparison = (L["grafik_compare_nobefore"] or "%s: %d FPS"):format(change, math.floor(after + 0.5))
        end
        Print(lastComparison)
        UpdateOverlay()
    end)
end

-- ============================================================
-- Overlay
-- ============================================================
local function SavePosition(frame)
    local db = GetDB()
    if not db then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    db.statsPos = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function CreateOverlay()
    local frame = CreateFrame("Frame", "AklimeModFPSOverlay", UIParent, "BackdropTemplate")
    frame:SetSize(OVERLAY_WIDTH, OVERLAY_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    frame:SetBackdropBorderColor(0.8, 0.65, 0.1, 1)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    local db  = GetDB()
    local pos = db and db.statsPos
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        frame:SetPoint(OVERLAY_START.point, UIParent, OVERLAY_START.point, OVERLAY_START.x, OVERLAY_START.y)
    end

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.text:SetPoint("TOPLEFT", OVERLAY_PAD, -OVERLAY_PAD)
    frame.text:SetJustifyH("LEFT")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 1, 1)
    close:SetScript("OnClick", function()
        AklimeMod_ForeverGrafikStats.SetOverlayShown(false)
        if AklimeMod_RefreshRightToggles then AklimeMod_RefreshRightToggles() end
    end)

    -- Only visible during a benchmark
    frame.stop = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.stop:SetSize(70, 20)
    frame.stop:SetPoint("BOTTOMRIGHT", -5, 5)
    frame.stop:SetText(L["grafik_stop"] or "Stop")
    frame.stop:SetScript("OnClick", function() AklimeMod_ForeverGrafikStats.StopBenchmark() end)
    frame.stop:Hide()

    return frame
end

UpdateOverlay = function()
    if not overlay or not overlay:IsShown() then return end

    local fps = GetFramerate()
    local avg, minFps = WindowStats(WINDOW_BUCKETS)
    local _, _, latencyHome, latencyWorld = GetNetStats()

    local lines = {
        (L["grafik_fps_line"] or "FPS %s   avg %s   min %s"):format(
            ColorFps(fps), avg and ColorFps(avg) or "?", minFps and ColorFps(minFps) or "?"),
        (L["grafik_frametime"] or "Frame time %.1f ms"):format(fps > 0 and 1000 / fps or 0),
        (L["grafik_latency"] or "Latency %d / %d ms"):format(latencyHome, latencyWorld),
    }
    if benchmark then
        if benchmark.settle > 0 then
            lines[#lines + 1] = "|cffffd100" .. (L["grafik_bench_wait"] or "Benchmark starts in %d s"):format(math.ceil(benchmark.settle)) .. "|r"
        else
            lines[#lines + 1] = "|cffffd100" .. (L["grafik_bench_run"] or "Benchmark: %d / %d s"):format(math.floor(benchmark.time), benchmark.duration) .. "|r"
        end
    elseif comparison then
        lines[#lines + 1] = "|cff888888" .. (L["grafik_measuring"] or "Measuring %s"):format(comparison.label) .. "|r"
    elseif lastComparison then
        lines[#lines + 1] = lastComparison
    end

    overlay.text:SetText(table.concat(lines, "\n"))
    overlay.stop:SetShown(benchmark ~= nil)

    -- Room for the close button on the right and the stop button below
    local height = overlay.text:GetStringHeight() + OVERLAY_PAD * 2
    if benchmark then height = height + BENCH_BUTTON_HEIGHT end
    overlay:SetSize(math.max(OVERLAY_WIDTH, overlay.text:GetStringWidth() + OVERLAY_PAD * 4), height)
end

-- Shown while the feature is on and the display is wanted, or during a benchmark
local function Refresh()
    local db = GetDB()
    local show = db and db.enabled and (db.showStats or benchmark ~= nil)
    if show then
        overlay = overlay or CreateOverlay()
        overlay:Show()
        UpdateOverlay()
    elseif overlay then
        overlay:Hide()
    end

    -- Turning the feature off ends a running benchmark too
    if benchmark and not (db and db.enabled) then
        benchmark.cancelled = true
        benchmark = nil
    end
    UpdateDriver()
end

-- ============================================================
-- Benchmark
-- ============================================================
local function StopBenchmark()
    if not benchmark then return end
    benchmark.cancelled = true
    benchmark = nil
    Print(L["grafik_bench_cancelled"] or "Benchmark cancelled.")
    Refresh()
end

local function StartBenchmark()
    local db = GetDB()
    if benchmark or not db or not db.enabled then return end

    local presetKey = db.preset
    local generator = AklimeMod_ForeverGrafik
    Print(L["grafik_bench_start"] or "Benchmark starts in 3 seconds.")

    benchmark = Measure(BENCH_SECONDS, BENCH_SETTLE, function(avg, minFps)
        benchmark = nil
        local result = { avg = avg, min = minFps, time = date("%Y-%m-%d %H:%M"), zone = GetRealZoneText() }
        db.bench[presetKey] = result
        Print((L["grafik_bench_done"] or "Benchmark (%s, %s): avg %s FPS, min %s FPS"):format(
            generator.GetPresetLabel(presetKey), result.zone, ColorFps(avg), ColorFps(minFps)))

        -- Earlier results of other presets for comparison
        for key, other in pairs(db.bench) do
            if key ~= presetKey then
                print((L["grafik_bench_other"] or "  %s: avg %d, min %d FPS (%s, %s)"):format(
                    generator.GetPresetLabel(key), math.floor(other.avg + 0.5),
                    math.floor(other.min + 0.5), other.zone or "?", other.time))
            end
        end
        Refresh()
    end)
    Refresh()
end

local function ToggleBenchmark()
    if benchmark then StopBenchmark() else StartBenchmark() end
end

-- ============================================================
-- Events
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", Refresh)

-- ============================================================
-- API
-- ============================================================
AklimeMod_ForeverGrafikStats = {
    Refresh         = Refresh,
    StartComparison = StartComparison,
    StopBenchmark   = StopBenchmark,
    ToggleBenchmark = ToggleBenchmark,
    IsOverlayShown  = function() local db = GetDB(); return db and db.showStats end,
    SetOverlayShown = function(v)
        local db = GetDB()
        if db then db.showStats = v end
        Refresh()
    end,
    IsCompareEnabled  = function() local db = GetDB(); return db and db.compare end,
    SetCompareEnabled = function(v)
        local db = GetDB()
        if db then db.compare = v end
        UpdateDriver()
    end,
}
