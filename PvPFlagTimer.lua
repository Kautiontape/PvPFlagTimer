-- PvP Flag Timer: the time left on your PvP flag, under the PvP crest on your
-- player frame.
--
-- The crest is painted by Blizzard's UnitFrameUtil.UpdateUnitPvPIndicator,
-- which both Blizzard's player frame and EllesmereUI's Blizzard-style frames
-- call with a table holding the crest texture (els.pvpIcon). A post-hook on
-- that function collects the player's crests, so nothing of EllesmereUI's own
-- is read or hooked. The timer shows only while the flag is counting down
-- (IsPVPTimerRunning): a flag you turned on with /pvp doesn't run out, so it
-- has no time to show.
--
-- Settings: a page of its own in the EllesmereUI panel (Plugin API), opened
-- with /pvptimer.

local ADDON = ...

local DEFAULTS = {
    size = 12,
    r = 1, g = 0.82, b = 0,   -- the gold of the level number
    x = 0, y = 0,
}

local db = DEFAULTS   -- the saved table from ADDON_LOADED on

local issecretvalue = issecretvalue or function() return false end

local function Chat(msg)
    print("|cff0cd29fPvP Flag Timer:|r " .. msg)
end

-------------------------------------------------------------------------------
--  The player's PvP crests
-------------------------------------------------------------------------------
local icons = setmetatable({}, { __mode = "k" })   -- crest texture -> true
local hooked = false

local function OnPaint(els, unit)
    if issecretvalue(unit) or unit ~= "player" then return end
    if type(els) ~= "table" then return end
    local icon = els.pvpIcon
    if type(icon) == "table" and icon.IsVisible then icons[icon] = true end
end

local function HookPainter()
    if hooked then return true end
    if type(UnitFrameUtil) ~= "table" or type(UnitFrameUtil.UpdateUnitPvPIndicator) ~= "function" then
        return false
    end
    hooksecurefunc(UnitFrameUtil, "UpdateUnitPvPIndicator", OnPaint)
    hooked = true
    return true
end
HookPainter()

-- The crest on screen now, if any (a hidden Blizzard player frame also gets painted).
local function ShownIcon()
    for icon in pairs(icons) do
        if icon:IsVisible() then return icon end
    end
end

-------------------------------------------------------------------------------
--  Display
-------------------------------------------------------------------------------
local holder = CreateFrame("Frame")
holder:SetSize(1, 1)
holder:Hide()
local text = holder:CreateFontString(nil, "OVERLAY")
text:SetPoint("TOP", holder, "TOP")

local anchoredTo
local testUntil = 0
local fontSet = false

local function ApplyFont()
    fontSet = true
    local path, flags, shadow = STANDARD_TEXT_FONT, "OUTLINE", false
    local E = EllesmereUI
    if E and E.GetFontPath then
        local ok, p = pcall(E.GetFontPath, "unitFrames")
        if ok and p then path = p end
        local ok2, f = pcall(E.GetFontOutlineFlag, "unitFrames")
        if ok2 and type(f) == "string" then flags = f end
        local ok3, s = pcall(E.GetFontUseShadow, "unitFrames")
        if ok3 then shadow = s and true or false end
    end
    text:SetFont(path, db.size, flags)
    if not text:GetFont() then
        text:SetFont(STANDARD_TEXT_FONT, db.size, "OUTLINE")
    end
    text:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
    text:SetTextColor(db.r, db.g, db.b)
end

-- Sits the holder under the crest. The crest's parent may be a secure unit
-- button, so the holder only changes parent out of combat.
local function Anchor(icon)
    if anchoredTo == icon then return true end
    if InCombatLockdown() then return false end
    local parent = icon:GetParent()
    holder:SetParent(parent)
    holder:SetFrameStrata(parent:GetFrameStrata())
    holder:SetFrameLevel(parent:GetFrameLevel() + 10)
    holder:ClearAllPoints()
    holder:SetPoint("TOP", icon, "BOTTOM", db.x, db.y)
    anchoredTo = icon
    return true
end

local function Reposition()
    if not anchoredTo then return end
    holder:ClearAllPoints()
    holder:SetPoint("TOP", anchoredTo, "BOTTOM", db.x, db.y)
end

-- Seconds left, rounded up (5:00 down to 0:01), or nil with no countdown.
local function SecondsLeft()
    local running = IsPVPTimerRunning()
    if issecretvalue(running) or not running then return nil end
    local ms = GetPVPTimer()
    if issecretvalue(ms) or type(ms) ~= "number" or ms <= 0 then return nil end
    return math.ceil(ms / 1000)
end

local function Update()
    local now = GetTime()
    local secs = SecondsLeft()
    local testing = now < testUntil
    if testing then secs = math.ceil(testUntil - now) end
    local icon = ShownIcon()
    -- A test shows on whichever crest we hold, shown or not, so it can be
    -- placed while you aren't flagged.
    if testing and not icon then icon = anchoredTo or next(icons) end
    if not secs or not icon or not Anchor(icon) then
        holder:Hide()
        return
    end
    if not fontSet then ApplyFont() end
    text:SetFormattedText("%d:%02d", math.floor(secs / 60), secs % 60)
    holder:Show()
end

-------------------------------------------------------------------------------
--  Saved settings
-------------------------------------------------------------------------------
local function FillDefaults(saved)
    for k, v in pairs(DEFAULTS) do
        if saved[k] == nil then saved[k] = v end
    end
    return saved
end

local function Restyle()
    ApplyFont()
    Reposition()
    Update()
end

local function ResetSettings()
    PvPFlagTimerDB = PvPFlagTimerDB or {}
    wipe(PvPFlagTimerDB)
    db = FillDefaults(PvPFlagTimerDB)
    Restyle()
    local E = EllesmereUI
    local key = E and E.GetPluginModuleKey and E.GetPluginModuleKey(ADDON, "Timer")
    if key and E.GetActiveModule and E:GetActiveModule() == key and E.RefreshPage then
        E:RefreshPage()
    end
end

-------------------------------------------------------------------------------
--  EllesmereUI plugin page
-------------------------------------------------------------------------------
local function BuildPage(pageName, parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h = W:SectionHeader(parent, "TIMER TEXT", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "slider", text = "Text Size", min = 8, max = 24, step = 1,
          getValue = function() return db.size end,
          setValue = function(v) db.size = v; Restyle() end },
        { type = "colorpicker", text = "Color",
          getValue = function() return db.r, db.g, db.b end,
          setValue = function(r, g, b) db.r, db.g, db.b = r, g, b; Restyle() end })
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "slider", text = "X Offset", min = -40, max = 40, step = 1,
          getValue = function() return db.x end,
          setValue = function(v) db.x = v; Restyle() end },
        { type = "slider", text = "Y Offset", min = -40, max = 40, step = 1,
          getValue = function() return db.y end,
          setValue = function(v) db.y = v; Restyle() end })
    y = y - h
    return math.abs(y)
end

local function RegisterPlugin()
    if not (EllesmereUI and EllesmereUI.RegisterPlugin) then return end
    EllesmereUI.RegisterPlugin(ADDON, {
        label = "PvP Flag Timer",
        modules = {
            {
                key = "Timer",
                title = "PvP Flag Timer",
                description = "The time left on your PvP flag, under the PvP crest on your player frame. "
                    .. "It shows while the flag counts down; a flag you turned on with /pvp doesn't run out. "
                    .. "Type /pvptimer test to see it while you place it.",
                pages = { "Timer" },
                buildPage = BuildPage,
                onReset = ResetSettings,
            },
        },
    })
end
RegisterPlugin()

-------------------------------------------------------------------------------
--  Slash command
-------------------------------------------------------------------------------
local function Check()
    local n, shown = 0, 0
    for icon in pairs(icons) do
        n = n + 1
        if icon:IsVisible() then shown = shown + 1 end
    end
    local function plain(v)
        if issecretvalue(v) then return "secret" end
        return tostring(v)
    end
    Chat(("crest painter hooked: %s; player crests found: %d (%d on screen)")
        :format(hooked and "yes" or "no (UnitFrameUtil.UpdateUnitPvPIndicator missing)", n, shown))
    Chat(("UnitIsPVP: %s; IsPVPTimerRunning: %s; GetPVPTimer: %s ms")
        :format(plain(UnitIsPVP("player")), plain(IsPVPTimerRunning()), plain(GetPVPTimer())))
end

SLASH_PVPFLAGTIMER1 = "/pvptimer"
SlashCmdList.PVPFLAGTIMER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "check" then
        Check()
    elseif msg == "test" then
        if not next(icons) then
            Chat("no PvP crest found yet. Flag for PvP once (/pvp) so your frame paints it, then try again.")
            return
        end
        testUntil = GetTime() + 15
        Update()
        Chat("showing a 15 second sample.")
    elseif msg == "reset" then
        ResetSettings()
        Chat("settings reset.")
    elseif EllesmereUI and EllesmereUI.OpenPlugin then
        if InCombatLockdown() then Chat("the settings open after combat.") return end
        EllesmereUI.OpenPlugin(ADDON)
    else
        Chat("the settings page needs EllesmereUI. /pvptimer check | test | reset")
    end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_FLAGS_CHANGED")
f:RegisterUnitEvent("UNIT_FACTION", "player")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            PvPFlagTimerDB = PvPFlagTimerDB or {}
            db = FillDefaults(PvPFlagTimerDB)
        end
        return
    elseif event == "PLAYER_LOGIN" then
        HookPainter()
        ApplyFont()
        C_Timer.NewTicker(0.5, Update)
    end
    Update()
end)
