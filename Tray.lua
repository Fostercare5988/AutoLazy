-- The minimap tray: the other addons' minimap buttons in one panel, opened by a
-- floating AutoLazy button. A collected button is moved under the panel, so the
-- panel's own visibility shows and hides them all; turned off, each goes back
-- to the minimap where its addon last put it.
local _, AL = ...
local db = AutoLazyDB

-- The client's own minimap buttons (Minimap.xml:176, 301, 521, 551) stay.
local STOCK = { MiniMapMeetingStoneFrame = true, MiniMapBattlefieldFrame = true, MinimapZoomIn = true,
    MinimapZoomOut = true }
-- Pirate Radio and Group Finder (OctoWoW FrameXML: EverlookBroadcastingCo.xml:29, LFT.xml:3).
local RADIO_LFG = { EBC_Minimap = true, LFTMinimapButton = true }
local CELL, COLUMNS, EDGE = 34, 4, 8

local buttons = {} -- collected, in the order found
local home = {}    -- button -> { the point its addon last gave it }
local strata = {}  -- button -> its own frame strata
local placing      -- our own SetPoint is running

local vault = CreateFrame("Frame") -- never shown: hidden buttons live here (no OnUpdate either)
vault:Hide()

local tray = CreateFrame("Frame", "AutoLazyTray", UIParent)
tray:Hide()
tray:SetFrameStrata("DIALOG")
tray:SetClampedToScreen(true)
tray:EnableMouse(true)
tray:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 } })
tray:SetBackdropColor(0, 0, 0, 0.9)
UISpecialFrames[#UISpecialFrames + 1] = "AutoLazyTray" -- Escape closes it

local launcher = CreateFrame("Button", "AutoLazyButton", UIParent)
launcher:SetWidth(32)
launcher:SetHeight(32)
launcher:SetFrameStrata("MEDIUM")
launcher:SetMovable(true)
launcher:SetClampedToScreen(true)
launcher:RegisterForDrag("LeftButton")
launcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
-- Until dragged; then the client keeps its place in layout-cache.txt per character.
-- UNVERIFIED: that the client saves a frame made by Lua at load (FostercareTweaks.md 4.10).
launcher:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -20)
local icon = launcher:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("CENTER", launcher, "CENTER", 0, 1)
local border = launcher:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(54)
border:SetHeight(54)
border:SetPoint("TOPLEFT", launcher, "TOPLEFT", 0, 0)
launcher:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
launcher:SetScript("OnDragStart", function() this:StartMoving() end)
launcher:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

-- The shown buttons in rows of four, the panel beside the launcher, away from the screen edge.
local function Layout()
    local n = 0
    placing = true
    for _, b in ipairs(buttons) do
        if b:GetParent() == tray and b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", tray, "TOPLEFT", EDGE + n % COLUMNS * CELL, -EDGE - math.floor(n / COLUMNS) * CELL)
            n = n + 1
        end
    end
    placing = nil
    tray:SetWidth(2 * EDGE + math.max(1, math.min(n, COLUMNS)) * CELL)
    tray:SetHeight(2 * EDGE + math.max(1, math.ceil(n / COLUMNS)) * CELL)
    local x, y = launcher:GetCenter()
    local v = y > UIParent:GetHeight() / 2 and "TOP" or "BOTTOM"
    local h = x > UIParent:GetWidth() / 2 and "RIGHT" or "LEFT"
    tray:ClearAllPoints()
    tray:SetPoint(v .. h, launcher, (v == "TOP" and "BOTTOM" or "TOP") .. h)
end

local opening
local function Relayout()
    if tray:IsShown() and not opening then Layout() end
end

launcher:SetScript("OnClick", function()
    if arg1 == "RightButton" then return AL.OpenPage() end
    if tray:IsShown() then return tray:Hide() end
    opening = true -- each button's OnShow fires as the panel shows
    tray:Show()
    opening = nil
    Layout()
end)

-- A click outside closes it, one frame later, so a menu a button opened still gets
-- its click (### GLOBAL_MOUSE_DOWN / GLOBAL_MOUSE_UP events: before the frame's OnMouseUp).
local function CloseUnlessOver()
    if not tray:IsMouseOver() and not launcher:IsMouseOver() then tray:Hide() end
end
tray:SetScript("OnShow", function() this:RegisterEvent("GLOBAL_MOUSE_UP") end)
tray:SetScript("OnHide", function() this:UnregisterEvent("GLOBAL_MOUSE_UP") end)
tray:SetScript("OnEvent", function() C_Timer.After(0, CloseUnlessOver) end)

-- Where a button lives now: hidden, in the tray, or on the minimap where its addon put it.
local function Place(b)
    placing = true
    if RADIO_LFG[b:GetName()] and db.hideRadioLfg then
        b:SetParent(vault)
    elseif db.tray then
        b:SetParent(tray)
        b:SetFrameStrata("DIALOG")
    else
        b:SetParent(Minimap)
        b:SetFrameStrata(strata[b])
        if home[b][1] then
            b:ClearAllPoints()
            b:SetPoint(unpack(home[b]))
        end
    end
    placing = nil
end

local function PlaceAll()
    for _, b in ipairs(buttons) do Place(b) end
    launcher:SetShown(db.tray)
    if db.tray then Relayout() else tray:Hide() end
end
AL.apply.tray, AL.apply.hideRadioLfg = PlaceAll, PlaceAll

-- An addon moving its button (a drag, a settings refresh) moves where it goes back to.
local function Moved(b, ...)
    if placing then return end
    home[b] = { ... }
    if b:GetParent() == tray then Relayout() end
end

local known = {}
local function Adopt(b)
    if not b or known[b] then return end
    local name = b:GetName()
    if not (RADIO_LFG[name] or (name and not STOCK[name] and b:IsObjectType("Button")
            and (b:IsMovable() or b:GetScript("OnDragStart")))) then return end -- map pins are neither
    known[b] = true
    buttons[#buttons + 1] = b
    home[b], strata[b] = { b:GetPoint(1) }, b:GetFrameStrata()
    hooksecurefunc(b, "SetPoint", Moved)
    b:HookScript("OnShow", Relayout)
    b:HookScript("OnHide", Relayout)
    Place(b)
    Relayout()
end

-- GAP: no way for addons to hand over their minimap buttons. A DLL should give the
-- addon compartment (AddonCompartmentFrame:RegisterAddon), or an event when a frame
-- gets a parent. Until then: the minimap's children once at login, and each named
-- Button made on the minimap after it, read a frame later once its addon set it up.
local ready
hooksecurefunc("CreateFrame", function(kind, name, parent)
    if ready and kind == "Button" and name and (parent == Minimap or parent == "Minimap") then
        C_Timer.After(0, function() Adopt(_G[name]) end)
    end
end)

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
    this:UnregisterEvent("PLAYER_LOGIN")
    for _, b in ipairs({ Minimap:GetChildren() }) do Adopt(b) end -- vanillaforge-ignore: D1, D2 (once)
    launcher:SetShown(db.tray)
    ready = true
end)
