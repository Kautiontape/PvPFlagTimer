-- Stubbed WoW API tests for PvPFlagTimer.lua under lua5.1:
--   lua5.1 tests/harness.lua PvPFlagTimer.lua
local path = arg[1]
local unpack = unpack

local now = 100
function GetTime() return now end
local timerRunning, timerMS, flagged = false, 301000, false
function IsPVPTimerRunning() return timerRunning end
function GetPVPTimer() return timerMS end
function UnitIsPVP() return flagged end
local combat = false
function InCombatLockdown() return combat end
function issecretvalue() return false end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
SlashCmdList = {}
local printed = {}
function print(...) local s = table.concat({ ... }, " "); printed[#printed + 1] = s; io.write("  chat: ", s, "\n") end
local tickers = {}
C_Timer = { NewTicker = function(_, fn) tickers[#tickers + 1] = fn end }
function hooksecurefunc(t, method, hook)
    local orig = t[method]
    t[method] = function(...) local r = { orig(...) }; hook(...); return unpack(r) end
end

-- Regions/frames
local function Region(kind, parent)
    local r = { kind = kind, parent = parent, shown = true, points = {} }
    function r:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function r:IsShown() return self.shown end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:GetParent() return self.parent end
    function r:SetParent(p) self.parent = p end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:ClearAllPoints() self.points = {} end
    function r:SetSize() end
    function r:GetFrameStrata() return "MEDIUM" end
    function r:SetFrameStrata(s) self.strata = s end
    function r:GetFrameLevel() return self.level or 5 end
    function r:SetFrameLevel(l) self.level = l end
    function r:CreateFontString()
        local fs = Region("fs", self)
        function fs:SetFont(p, s, f) self.font = { p, s, f } end
        function fs:GetFont() if self.font then return unpack(self.font) end end
        function fs:SetShadowOffset() end
        function fs:SetTextColor(r, g, b) self.color = { r, g, b } end
        function fs:SetFormattedText(fmt, ...)
            assert(self.font, "font not set before text")
            self.text = fmt:format(...)
        end
        self.fs = fs
        return fs
    end
    function r:RegisterEvent() end
    function r:RegisterUnitEvent() end
    function r:SetScript(_, fn) self.onEvent = fn end
    return r
end
local createdFrames = {}
function CreateFrame() local fr = Region("frame"); fr.shown = true; createdFrames[#createdFrames + 1] = fr; return fr end

-- Blizzard's painter: shows the crest when flagged.
UnitFrameUtil = { UpdateUnitPvPIndicator = function(els, unit) if flagged then els.pvpIcon:Show() else els.pvpIcon:Hide() end end }

-- Ellesmere's player frame and a hidden Blizzard PlayerFrame, both painted.
local euiFrame = Region("frame"); euiFrame.shown = true
local euiCrest = Region("tex", euiFrame)
local blizzFrame = Region("frame"); blizzFrame.shown = false
local blizzCrest = Region("tex", blizzFrame)
local targetCrest = Region("tex", euiFrame)

local registered
EllesmereUI = {
    RegisterPlugin = function(id, spec) registered = { id = id, spec = spec }; return true end,
    OpenPlugin = function(id) print("OpenPlugin " .. id) return true end,
    GetFontPath = function(key) assert(key == "unitFrames"); return "Fonts\\Expressway.ttf" end,
    GetFontOutlineFlag = function() return "OUTLINE, SLUG" end,
    GetFontUseShadow = function() return false end,
}

assert(loadfile(path))("PvPFlagTimer")
local evf = createdFrames[#createdFrames]   -- the events frame is created last
local holder = createdFrames[1]
local text = holder.fs
local function Fire(ev, ...) evf.onEvent(evf, ev, ...) end
local function Paint()
    UnitFrameUtil.UpdateUnitPvPIndicator({ pvpIcon = euiCrest }, "player", true)
    UnitFrameUtil.UpdateUnitPvPIndicator({ pvpIcon = blizzCrest }, "player", true)
    UnitFrameUtil.UpdateUnitPvPIndicator({ pvpIcon = targetCrest }, "target", false)
end

-- Events before login must not draw text without a font.
Fire("ADDON_LOADED", "PvPFlagTimer")
Fire("PLAYER_FLAGS_CHANGED")
Fire("PLAYER_LOGIN")
assert(#tickers == 1, "ticker started")
Paint()
tickers[1]()
assert(not holder:IsShown(), "hidden when not flagged")

-- Manually flagged (/pvp on): no countdown -> nothing shown
flagged = true; Paint(); tickers[1]()
assert(not holder:IsShown(), "permanent flag shows nothing")

-- Toggle off: countdown 5:00 -> shown under the Ellesmere crest (Blizzard frame hidden)
timerRunning, timerMS = true, 299500
Fire("PLAYER_FLAGS_CHANGED")
assert(holder:IsShown(), "shown while counting down")
assert(holder.parent == euiFrame, "parented to the visible crest's frame")
assert(holder.points[1][2] == euiCrest, "anchored to the Ellesmere crest")
assert(text.text == "5:00", "rounded up: " .. tostring(text.text))
assert(text.font[1] == "Fonts\\Expressway.ttf", "Ellesmere unit frame font")
timerMS = 61001; tickers[1](); assert(text.text == "1:02", text.text)
timerMS = 400; tickers[1](); assert(text.text == "0:01", text.text)

-- Flag drops
timerRunning, flagged = false, false; Paint(); Fire("UNIT_FACTION", "player")
assert(not holder:IsShown(), "hidden after flag drops")

-- Settings: offsets move it, size/color restyle
local spec = registered.spec
assert(registered.id == "PvPFlagTimer" and spec.label == "PvP Flag Timer")
local rows = {}
EllesmereUI.Widgets = {
    SectionHeader = function(_, _, text) rows[#rows + 1] = "H:" .. text; return {}, 40 end,
    DualRow = function(_, _, _, l, r)
        rows[#rows + 1] = l.type .. ":" .. l.text .. " | " .. r.type .. ":" .. r.text
        assert(l.getValue() ~= nil and r.getValue() ~= nil)
        if l.type == "slider" then l.setValue(l.text == "Text Size" and 16 or 5) end
        if r.type == "slider" then r.setValue(-3) end
        if r.type == "colorpicker" then r.setValue(1, 0, 0) end
        return {}, 50
    end,
}
local h = spec.modules[1].buildPage("Timer", {}, -10)
print("page height " .. h .. ": " .. table.concat(rows, "; "))
assert(PvPFlagTimerDB.size == 16 and PvPFlagTimerDB.x == 5 and PvPFlagTimerDB.y == -3 and PvPFlagTimerDB.g == 0)
assert(text.font[2] == 16 and text.color[1] == 1 and text.color[2] == 0, "restyled")
local p = holder.points[1]; assert(p[4] == 5 and p[5] == -3, "offsets applied")

-- Test command: shows a sample while not flagged, then clears
SlashCmdList.PVPFLAGTIMER("test")
assert(holder:IsShown() and text.text == "0:15", "test sample " .. tostring(text.text))
now = now + 16; tickers[1]()
assert(not holder:IsShown(), "test clears itself")

-- Combat: a first anchor waits for combat to end
-- (simulate a fresh crest on a new frame while in combat)
local newFrame = Region("frame"); newFrame.shown = true
local newCrest = Region("tex", newFrame)
euiFrame.shown = false
flagged, timerRunning, timerMS = true, true, 100000
UnitFrameUtil.UpdateUnitPvPIndicator({ pvpIcon = newCrest }, "player", true)
combat = true; tickers[1]()
assert(not holder:IsShown(), "no reparent in combat")
combat = false; Fire("PLAYER_REGEN_ENABLED")
assert(holder:IsShown() and holder.parent == newFrame, "anchors after combat")

spec.modules[1].onReset()
assert(PvPFlagTimerDB.size == 12 and PvPFlagTimerDB.x == 0, "reset")
SlashCmdList.PVPFLAGTIMER("check")
SlashCmdList.PVPFLAGTIMER("")
print("ALL OK")
