-- AutoLazy minimap tray, WoW 1.12.1 Build 5875 / ClassicAPI 1.15.15+.
-- Discovery uses Lua references only. Never enumerate the engine frame tree.
-- Native parents and foreign click/hover/drag scripts remain untouched.
if not AutoLazy then return end

local Tray = {}
AutoLazy.Tray = Tray
local records, byFrame, created = {}, {}, {}
local opened, scanning, refreshPending = false, false, false
local fullScanPending, registryDirty = false, false
local layoutPending, closing = false, false
local serial, openEpoch = 0, 0
local backdrop, launcher
local Refresh, Layout, Reconcile

local excluded = {
    UIParent = true, WorldFrame = true, Minimap = true,
    MinimapCluster = true, MinimapBackdrop = true, MinimapZoomIn = true,
    MinimapZoomOut = true, GameTimeFrame = true, TimeManagerClockButton = true,
    MiniMapTrackingFrame = true, MiniMapTracking = true,
    MiniMapMeetingStoneFrame = true, MiniMapMailFrame = true,
    MiniMapBattlefieldFrame = true, MiniMapWorldMapButton = true,
    MiniMapPing = true, MinimapZoneTextButton = true, MinimapToggleButton = true,
    TicketStatusFrame = true, TicketStatusFrameButton = true, WorldStateFrame = true,
    MinimapZoneText = true, MinimapToggle = true, MinimapBorderTop = true,
    MinimapBorder = true, MiniMapTrackingBorder = true, MiniMapTrackingIcon = true,
    MiniMapMailIcon = true, MiniMapMailBorder = true, MiniMapBattlefieldIcon = true,
    MiniMapBattlefieldBorder = true, MiniMapMeetingStoneIcon = true,
    FCTweaksMinimapClock = true, MinimapClock = true,
}
local known = {
    AtlasButton = true, AtlasMinimapButton = true, pfQuestIcon = true,
    ItemRack_IconFrame = true, TrinketMenu_IconFrame = true,
    SW_IconFrame = true, AutoBG_QuickQueueButton = true,
}
local radioNames = {
    EBC_Minimap = true, PirateRadioMinimapButton = true, RadioMinimapButton = true,
    BBRadioMinimapButton = true, BBPR_MinimapButton = true, Radio_MinimapButton = true,
    TWRadioMinimapButton = true, TW_RadioMinimapButton = true,
    TurtleRadioMinimapButton = true, TWBBRadioMinimapButton = true,
    BootyBayRadioMinimapButton = true,
}
local lfgNames = {
    LFTMinimapButton = true, LFT_MinimapButton = true, TW_LFGBtn = true,
    TWLFG_Minimap = true, TWLFG_MinimapButton = true, MiniMapLFGFrame = true,
    LFGMinimapButton = true, TurtleLFGMinimapButton = true,
    GroupFinderMinimapButton = true,
}

local function BlockedName(name)
    if not name then return false end
    local lower = string.lower(name)
    return excluded[name] or string.find(lower, "^autolazy") or
        string.find(lower, "dropdown") or string.find(lower, "tooltip") or
        string.find(lower, "^pfminimappin%d") or string.find(lower, "^pfmappin%d") or
        string.find(lower, "^worldstate") or
        string.find(lower, "^ticketstatus") or string.find(lower, "^gametime")
end

local function FrameReference(frame)
    -- WoW frame proxies are tables with a native userdata in slot zero.
    -- pcall can catch a Lua error; it cannot catch a native access violation.
    return type(frame) == "table" and type(rawget(frame, 0)) == "userdata" and
        type(frame.GetObjectType) == "function" and type(frame.GetPoint) == "function"
end

local function MinimapRoot(frame)
    return frame ~= nil and (frame == Minimap or frame == MinimapCluster or frame == MinimapBackdrop)
end

local function ReadPoints(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do
        local point, relative, relativePoint, x, y = frame:GetPoint(i)
        -- Keep every anchor, including nil/default relative arguments.
        points[i] = { point, relative, relativePoint, x, y, n = 5 }
    end
    return points
end

local function AnchoredToMinimap(frame)
    for i = 1, frame:GetNumPoints() do
        local _, relative = frame:GetPoint(i)
        if type(relative) == "string" then relative = getglobal(relative) end
        if MinimapRoot(relative) then return true end
    end
    return false
end

local function RegionVisual(region, borderOnly)
    if not region or type(region.GetTexture) ~= "function" then return false end
    local texture = region:GetTexture()
    if type(texture) ~= "string" or texture == "" then return false end
    if not borderOnly then return true end
    return string.find(string.lower(texture), "minimap%-trackingborder") ~= nil
end

local function HasVisual(frame, borderOnly)
    if frame.GetNormalTexture and RegionVisual(frame:GetNormalTexture(), borderOnly) then
        return true
    end
    local regions = { frame:GetRegions() }
    for i = 1, table.getn(regions) do
        if RegionVisual(regions[i], borderOnly) then return true end
    end
    return false
end

local function Candidate(frame)
    if not FrameReference(frame) then return false end
    local name = frame:GetName()
    if BlockedName(name) then return false end
    -- [SOURCE-VERIFIED] pfQuest/map.lua: clickable quest/map nodes are
    -- Button frames too; their node data identifies map content, not a hub.
    if rawget(frame, "minimap") and rawget(frame, "node") then return false end
    if not frame:IsObjectType("Button") then return false end
    local width, height = frame:GetWidth(), frame:GetHeight()
    if width < 16 or height < 16 or width > 64 or height > 64 then return false end
    if not frame:GetScript("OnClick") and not frame:GetScript("OnMouseUp") then return false end
    if not HasVisual(frame, false) then return false end
    if name and (known[name] or radioNames[name] or lfgNames[name] or
        string.find(name, "^LibDBIcon10_")) then return true end
    local parent = frame:GetParent()
    if MinimapRoot(parent) or AnchoredToMinimap(frame) then return true end
    -- UIParent icons need the specific launcher border; an arbitrary
    -- action button or map pin is not identified by size alone.
    return parent == UIParent and (HasVisual(frame, true) or name and
        string.find(string.lower(name), "minimap") ~= nil)
end

local function QueueLayout()
    if layoutPending or not opened then return end
    layoutPending = true
    C_Timer.After(0, function()
        layoutPending = false
        if opened then Reconcile() end
    end)
end

local function Guard(record, callback)
    local previous = record.busy
    record.busy = true
    local ok, err = pcall(callback)
    record.busy = previous
    if not ok then error(err, 0) end
end

local function Capture(frame)
    return {
        points = ReadPoints(frame), width = frame:GetWidth(), height = frame:GetHeight(),
        alpha = frame:GetAlpha(), strata = frame:GetFrameStrata(), level = frame:GetFrameLevel(),
        mouse = frame:IsMouseEnabled(), shown = frame:IsShown() and true or false,
    }
end

local function NativePoints(node)
    local methods, source = node.methods, node.source
    methods.ClearAllPoints(node.frame)
    node.methods.SetWidth(node.frame, source.width)
    node.methods.SetHeight(node.frame, source.height)
    for i = 1, table.getn(source.points) do
        local point = source.points[i]
        methods.SetPoint(node.frame, unpack(point, 1, point.n))
    end
end

local function NativeProperties(node)
    local frame, source, methods = node.frame, node.source, node.methods
    methods.SetAlpha(frame, source.alpha)
    methods.SetFrameStrata(frame, source.strata)
    methods.SetFrameLevel(frame, source.level)
    methods.EnableMouse(frame, source.mouse)
end

local function WantsVisible(record)
    for i = 1, table.getn(record.nodes) do
        local node = record.nodes[i]
        if not (node.source and node.source.shown or
            not node.source and node.frame:IsShown()) then return false end
    end
    return true
end

local function ApplyDock(record)
    if not record.x then return end
    local root = record.nodes[1]
    for i = 1, table.getn(record.nodes) do
        local node = record.nodes[i]
        if not node.frame:IsShown() then node.methods.Show(node.frame) end
        if node.frame:GetFrameStrata() ~= "DIALOG" then node.methods.SetFrameStrata(node.frame, "DIALOG") end
        if node.frame:GetFrameLevel() ~= 20 + i then node.methods.SetFrameLevel(node.frame, 20 + i) end
        if node.frame:GetAlpha() ~= node.source.alpha then node.methods.SetAlpha(node.frame, node.source.alpha) end
        if not node.frame:IsMouseEnabled() then node.methods.EnableMouse(node.frame, true) end
    end
    -- Native OnShow handlers may re-anchor themselves. Position after those
    -- handlers finish, within the same Lua dispatch and before rendering.
    local ratio = backdrop:GetEffectiveScale() / root.frame:GetEffectiveScale()
    root.methods.ClearAllPoints(root.frame)
    -- Dimensions must be explicit after clearing possibly size-defining anchors.
    root.methods.SetWidth(root.frame, root.source.width)
    root.methods.SetHeight(root.frame, root.source.height)
    root.methods.SetPoint(root.frame, "CENTER", backdrop, "TOPLEFT",
        record.x * ratio, record.y * ratio)
end

local propertyNames = {
    SetAlpha = "alpha", SetFrameStrata = "strata", SetFrameLevel = "level",
    EnableMouse = "mouse", SetWidth = "width", SetHeight = "height",
}
local methodNames = {
    "Show", "Hide", "SetShown", "ClearAllPoints", "SetPoint", "SetWidth",
    "SetHeight", "SetAlpha", "SetFrameStrata", "SetFrameLevel", "EnableMouse",
}

local function WrapNode(record, node)
    local frame = node.frame
    node.methods, node.ownMethods, node.wrappers = {}, {}, {}
    for i = 1, table.getn(methodNames) do
        local name = methodNames[i]
        node.methods[name] = frame[name]
        node.ownMethods[name] = rawget(frame, name)
    end
    for i = 1, table.getn(methodNames) do
        local name = methodNames[i]
        local original = node.methods[name]
        local wrapper
        wrapper = function(self, ...)
            if self ~= frame or record.busy or record.mode == "idle" or
                node.wrappers[name] ~= wrapper then
                return original(self, unpack(arg, 1, arg.n))
            end
            if name == "Show" or name == "Hide" or name == "SetShown" then
                local show = name == "Show" or (name == "SetShown" and arg[1])
                show = show and true or false
                if node.source.shown ~= show then
                    node.source.shown = show
                    QueueLayout()
                elseif node.ownMethods[name] or rawget(frame, name) ~= wrapper then
                    -- A foreign override may also change scale or presentation,
                    -- even when the requested visibility is unchanged.
                    QueueLayout()
                end
                if record.mode == "hidden" then return end
                if show then return node.methods.Show(self) end
                return node.methods.Hide(self)
            end
            local property = propertyNames[name]
            if property then
                node.source[property] = arg[1]
                if record.mode == "docked" then
                    QueueLayout()
                    -- Tray owns presentation until it closes. Underlying
                    -- addon requests are retained for subsequent restoration.
                    return
                end
                return original(self, unpack(arg, 1, arg.n))
            end
            if node ~= record.nodes[1] or record.mode ~= "docked" then
                original(self, unpack(arg, 1, arg.n))
                node.source.points = ReadPoints(self)
                node.source.width, node.source.height = self:GetWidth(), self:GetHeight()
                return
            end
            local args = arg
            Guard(record, function()
                -- Execute the native overload against normal anchors, then
                -- read the native result. No guessed SetPoint normalization.
                NativePoints(node)
                original(self, unpack(args, 1, args.n))
                node.source.points = ReadPoints(self)
                node.source.width, node.source.height = self:GetWidth(), self:GetHeight()
                ApplyDock(record)
            end)
        end
        node.wrappers[name] = wrapper
        frame[name] = wrapper
    end
    if not node.hooked then
        node.hooked = true
        -- Covers cached native Show/SetShown calls that bypass Lua wrappers.
        -- ClassicAPI HookScript preserves the addon's original handler.
        frame:HookScript("OnShow", function()
            if record.busy or record.mode == "idle" then return end
            node.source.shown = true
            if record.mode == "hidden" then
                Guard(record, function() record.nodes[1].methods.Hide(record.frame) end)
            end
            QueueLayout()
        end)
        frame:HookScript("OnHide", function()
            if record.busy or record.mode == "idle" then return end
            -- IsShown is independent of ancestor visibility. An ancestor
            -- being hidden must not overwrite the addon's own preference.
            if not frame:IsShown() then node.source.shown = false end
            QueueLayout()
        end)
    end
end

local function Activate(record)
    for i = 1, table.getn(record.nodes) do
        local node = record.nodes[i]
        node.source = Capture(node.frame)
        WrapNode(record, node)
    end
end

local function Restore(record, release)
    Guard(record, function()
        -- Restore root before child properties: native frame-level changes
        -- can propagate to descendants.
        for i = 1, table.getn(record.nodes) do
            local node = record.nodes[i]
            NativePoints(node)
            NativeProperties(node)
        end
        for i = 1, table.getn(record.nodes) do
            local node = record.nodes[i]
            if release and node.source.shown then node.methods.Show(node.frame)
            elseif release then node.methods.Hide(node.frame) end
        end
        if not release then record.nodes[1].methods.Hide(record.frame) end
    end)
    record.x, record.y = nil, nil
    if release then
        record.mode = "idle"
        for i = 1, table.getn(record.nodes) do
            local node = record.nodes[i]
            for name, wrapper in pairs(node.wrappers) do
                -- Do not erase another addon's later hook or method override.
                if rawget(node.frame, name) == wrapper then
                    rawset(node.frame, name, node.ownMethods[name])
                end
            end
            node.source = nil
        end
    end
end

local function Enroll(frame, kind, child)
    if byFrame[frame] then return byFrame[frame] end
    -- Reject incomplete/unsupported proxies before installing any wrappers.
    -- This validation catches Lua errors only, never native pointer faults.
    if not pcall(Capture, frame) then return nil end
    if child and not pcall(Capture, child) then return nil end
    serial = serial + 1
    local record = {
        frame = frame, kind = kind or "addon", mode = "idle", nodes = {},
        name = frame:GetName() or string.format("Anonymous %04d", serial),
        key = frame:GetName() or child and child:GetName(),
    }
    record.nodes[1] = { frame = frame }
    if child and child ~= frame then record.nodes[2] = { frame = child } end
    for i = 1, table.getn(record.nodes) do byFrame[record.nodes[i].frame] = record end
    table.insert(records, record)
    registryDirty = true
    return record
end

local function TryEnroll(frame)
    if byFrame[frame] or not FrameReference(frame) then return end
    local ok, valid = pcall(Candidate, frame)
    if not ok or not valid then return end
    local name = frame:GetName()
    Enroll(frame, radioNames[name] and "radio" or lfgNames[name] and "lfg" or "addon")
end

local function Scan(full)
    if scanning then return end
    scanning = true
    -- [SOURCE-VERIFIED] AtlasLoot.xml: container owns visibility/position;
    -- the named child owns the native input scripts.
    local atlas, atlasClick = getglobal("AtlasLootMinimapButtonFrame"), getglobal("AtlasLootMinimapButton")
    if FrameReference(atlas) and FrameReference(atlasClick) and
        atlasClick:GetParent() == atlas and not byFrame[atlasClick] then
        Enroll(atlas, "addon", atlasClick)
    end
    for name in pairs(radioNames) do
        local frame = getglobal(name)
        if FrameReference(frame) then Enroll(frame, "radio") end
    end
    for name in pairs(lfgNames) do
        local frame = getglobal(name)
        if FrameReference(frame) then Enroll(frame, "lfg") end
    end
    if full then
        -- Lifecycle discovery only. Opening the tray and observing a newly
        -- created button must never rescan the client-wide global namespace.
        local candidates, seen = {}, {}
        for name, frame in pairs(_G) do
            -- Reject nonframes with Lua-only checks before string work. Keep
            -- excluded names ahead of any proxy method lookup/native call.
            if type(name) == "string" and type(frame) == "table" and
                type(rawget(frame, 0)) == "userdata" and not BlockedName(name) and
                FrameReference(frame) and not byFrame[frame] and not seen[frame] then
                seen[frame] = true
                table.insert(candidates, frame)
            end
        end
        for i = 1, table.getn(candidates) do TryEnroll(candidates[i]) end
    end
    for frame in pairs(created) do TryEnroll(frame) end
    table.wipe(created)
    if registryDirty then
        table.sort(records, function(a, b) return a.name < b.name end)
        registryDirty = false
    end
    scanning = false
end

local function CollapseEnabled()
    return AutoLazyDB and AutoLazyDB.Tweaks and AutoLazyDB.Tweaks.CollapseAddons ~= false
end

local function SystemHidden(record)
    local tweaks = AutoLazyDB and AutoLazyDB.Tweaks
    return record.forcedHidden or tweaks and
        (record.kind == "radio" and tweaks.HideRadio or record.kind == "lfg" and tweaks.HideLfg)
end

local function IsKept(record)
    local tweaks = AutoLazyDB and AutoLazyDB.Tweaks
    if record.key then
        return tweaks and tweaks.KeepOnMinimap and tweaks.KeepOnMinimap[record.key] == true
    end
    -- An unnamed frame has no identity that can safely survive a reload.
    return record.kept == true
end

local labelSuffixes = {
    "_minimapbuttonframe", "minimapbuttonframe", "_minimapbutton", "minimapbutton",
    "_iconframe", "iconframe", "_minimapicon", "minimapicon", "_minimap", "minimap",
    "_icon", "icon",
}
local function LauncherLabel(record)
    if record.kind == "radio" then return "Pirate Radio" end
    if record.kind == "lfg" then return "Group Finder" end
    local label = record.key or record.name
    label = string.gsub(label, "^LibDBIcon10_", "")
    local lower = string.lower(label)
    for i = 1, table.getn(labelSuffixes) do
        local suffix = labelSuffixes[i]
        if string.len(label) > string.len(suffix) and string.sub(lower, -string.len(suffix)) == suffix then
            label = string.sub(label, 1, string.len(label) - string.len(suffix))
            break
        end
    end
    return string.gsub(label, "_", " ")
end

local function ActiveRecords()
    local active = {}
    for i = 1, table.getn(records) do
        local record = records[i]
        if not IsKept(record) and not SystemHidden(record) and WantsVisible(record) then
            table.insert(active, record)
        end
    end
    return active
end

Layout = function(active)
    local count = table.getn(active)
    if count == 0 then Tray.Close(); return end
    local cols, cell, margin = math.min(count, 4), 36, 7
    for i = 1, count do
        local node = active[i].nodes[1]
        local ratio = node.frame:GetEffectiveScale() / backdrop:GetEffectiveScale()
        cell = math.max(cell, node.source.width * ratio + 8, node.source.height * ratio + 8)
    end
    backdrop:SetWidth(margin * 2 + cols * cell)
    backdrop:SetHeight(margin * 2 + math.ceil(count / cols) * cell)
    backdrop:ClearAllPoints()
    local x, y = launcher:GetCenter()
    local ratio = launcher:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local right = x and x * ratio > UIParent:GetWidth() / 2
    local top = not y or y * ratio > UIParent:GetHeight() / 2
    local corner = (top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT")
    local relative = (top and "BOTTOM" or "TOP") .. (right and "RIGHT" or "LEFT")
    backdrop:SetPoint(corner, launcher, relative, 0, top and -5 or 5)
    backdrop:Show()
    for i = 1, count do
        local record = active[i]
        record.x = margin + ((i - 1) % cols + 0.5) * cell
        record.y = -(margin + (math.floor((i - 1) / cols) + 0.5) * cell)
        Guard(record, function() ApplyDock(record) end)
    end
end

Reconcile = function()
    if not AutoLazyDB or not AutoLazyDB.Tweaks then return end
    for i = 1, table.getn(records) do
        local record = records[i]
        local mode = "idle"
        if SystemHidden(record) then mode = "hidden"
        elseif not IsKept(record) and (CollapseEnabled() or opened) then
            mode = opened and WantsVisible(record) and "docked" or "hidden"
        end
        if record.mode == "idle" and mode ~= "idle" then Activate(record) end
        local previous = record.mode
        record.mode = mode
        if mode == "idle" and previous ~= "idle" then Restore(record, true)
        elseif mode == "hidden" and previous == "docked" then Restore(record, false)
        elseif mode == "hidden" then
            Guard(record, function()
                if record.frame:IsShown() then record.nodes[1].methods.Hide(record.frame) end
            end)
        end
    end
    if opened then Layout(ActiveRecords()) end
end

Refresh = function(full)
    if not AutoLazyDB or not AutoLazyDB.Tweaks then return end
    Scan(full)
    Reconcile()
    if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
end

local function QueueRefresh(full)
    if full then fullScanPending = true end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        local full = fullScanPending
        fullScanPending = false
        Refresh(full)
    end)
end

function Tray.Register(frame, child)
    if not FrameReference(frame) or BlockedName(frame:GetName()) then return false end
    if child and (not FrameReference(child) or child:GetParent() ~= frame or byFrame[child]) then
        return false
    end
    if not Enroll(frame, "addon", child) then return false end
    QueueRefresh()
    return true
end

-- Settings read only the registry. They must never trigger global discovery.
function Tray.GetEntries()
    local entries = {}
    for i = 1, table.getn(records) do
        local record = records[i]
        record.label = record.label or LauncherLabel(record)
        entries[i] = {
            frame = record.frame, key = record.key, label = record.label,
            kept = IsKept(record) and true or false, hidden = SystemHidden(record) and true or false,
        }
    end
    return entries
end

function Tray.SetKept(frameOrName, keep)
    local tweaks = AutoLazyDB and AutoLazyDB.Tweaks
    if not tweaks then return false end
    local record = byFrame[frameOrName]
    local key = record and record.key or type(frameOrName) == "string" and frameOrName
    if key and key ~= "" then
        if type(tweaks.KeepOnMinimap) ~= "table" then tweaks.KeepOnMinimap = {} end
        tweaks.KeepOnMinimap[key] = keep and true or nil
    elseif record then record.kept = keep and true or false
    else return false end
    Reconcile()
    if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    return true
end

function Tray.Close()
    if closing then return end
    closing, opened = true, false
    openEpoch = openEpoch + 1
    backdrop:Hide()
    Reconcile()
    closing = false
end

function Tray.Open()
    opened = true
    openEpoch = openEpoch + 1
    Reconcile()
    if not opened then AutoLazy_Print("No icons are available in the tray.") end
end

function Tray.Toggle()
    if opened then Tray.Close() else Tray.Open() end
end

function AutoLazy_CollapseAddons(enable)
    if enable ~= nil and AutoLazyDB and AutoLazyDB.Tweaks then
        AutoLazyDB.Tweaks.CollapseAddons = enable and true or false
    end
    if not CollapseEnabled() then Tray.Close() end
    Reconcile()
end

function AutoLazy_FindAddonButtons()
    Scan(true)
    local active, result = ActiveRecords(), {}
    for i = 1, table.getn(active) do result[i] = active[i].frame end
    return result
end

function AutoLazy_ApplySystemIconToggles() Reconcile() end
AutoLazy_OpenTray, AutoLazy_CloseTray, AutoLazy_ToggleTray = Tray.Open, Tray.Close, Tray.Toggle
Tray.Rescan = function() Refresh(true) end
AutoLazy.IsRadioFrame = function(frame)
    return FrameReference(frame) and radioNames[frame:GetName()] == true
end
AutoLazy.IsLfgFrame = function(frame)
    return FrameReference(frame) and lfgNames[frame:GetName()] == true
end
AutoLazy.IsValidAddonButton = function(frame)
    local ok, valid = pcall(Candidate, frame)
    return ok and valid and not AutoLazy.IsRadioFrame(frame) and not AutoLazy.IsLfgFrame(frame)
end
AutoLazy.IsAnchoredToMinimap = function(frame)
    if not FrameReference(frame) then return false end
    local ok, valid = pcall(AnchoredToMinimap, frame)
    return ok and valid
end
AutoLazy.SetFrameSuppressed = function(frame, hide)
    if not FrameReference(frame) or BlockedName(frame:GetName()) then return end
    local record = Enroll(frame)
    if not record then return end
    record.forcedHidden = hide and true or false
    Reconcile()
end

backdrop = CreateFrame("Frame", "AutoLazy_ButtonTray", UIParent)
backdrop:SetFrameStrata("DIALOG")
backdrop:SetFrameLevel(10)
backdrop:EnableMouse(false)
backdrop:SetClampedToScreen(true)
backdrop:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true,
    tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
backdrop:SetBackdropColor(0.06, 0.06, 0.08, 0.90)
backdrop:SetBackdropBorderColor(0.35, 0.35, 0.40, 0.85)
backdrop:Hide()
backdrop:SetScript("OnHide", Tray.Close)
table.insert(UISpecialFrames, "AutoLazy_ButtonTray")

launcher = CreateFrame("Button", "AutoLazy_ActionBtn", UIParent)
launcher:SetWidth(31)
launcher:SetHeight(31)
launcher:SetFrameStrata("MEDIUM")
launcher:SetToplevel(true)
launcher:EnableMouse(true)
launcher:SetMovable(true)
launcher:SetClampedToScreen(true)
launcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
launcher:RegisterForDrag("LeftButton")
launcher:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local icon = launcher:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("CENTER", launcher, "CENTER", 1, 0)
local border = launcher:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(53)
border:SetHeight(53)
border:SetPoint("TOPLEFT", launcher, "TOPLEFT", 0, 0)

function AutoLazy_UpdateActionButton()
    if not AutoLazyDB then return end
    if AutoLazyDB.ShowButton == false then launcher:Hide(); Tray.Close(); return end
    launcher:ClearAllPoints()
    local position = AutoLazyDB.ButtonPos
    if position and position.x and position.y then
        launcher:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", position.x, position.y)
    else launcher:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -180, -20) end
    launcher:Show()
end

function AutoLazy_ResetActionButtonPos()
    if not AutoLazyDB then return end
    AutoLazyDB.ButtonPos = {}
    AutoLazy_UpdateActionButton()
    AutoLazy_Print("AutoLazy button position reset to top right.")
end

launcher:SetScript("OnDragStart", function() Tray.Close(); launcher:StartMoving() end)
launcher:SetScript("OnDragStop", function()
    launcher:StopMovingOrSizing()
    if AutoLazyDB then
        AutoLazyDB.ButtonPos = { x = launcher:GetLeft(), y = launcher:GetBottom() }
    end
end)
launcher:SetScript("OnClick", function(_, button)
    if (button or arg1) == "RightButton" then AutoLazy_ToggleGUI() else Tray.Toggle() end
end)
launcher:SetScript("OnEnter", function()
    GameTooltip:SetOwner(launcher, "ANCHOR_LEFT")
    GameTooltip:AddLine("AutoLazy", 1, 1, 1)
    GameTooltip:AddLine("Left-click: Toggle Addon Tray", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Right-click: Open AutoLazy Options", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
launcher:SetScript("OnLeave", function() GameTooltip:Hide() end)

local controller = CreateFrame("Frame", "AutoLazy_TrayController", UIParent)
controller:RegisterEvent("ADDON_LOADED")
controller:RegisterEvent("VARIABLES_LOADED")
controller:RegisterEvent("PLAYER_ENTERING_WORLD")
controller:RegisterEvent("ZONE_CHANGED_NEW_AREA")
controller:RegisterEvent("GLOBAL_MOUSE_UP")
controller:SetScript("OnEvent", function(_, eventName)
    local ev = eventName or event
    if ev == "GLOBAL_MOUSE_UP" then
        if not opened or backdrop:IsMouseOver() or launcher:IsMouseOver() then return end
        -- Dismiss on release, after native click-up handlers. Closing on a
        -- down event could hide an addon's child menu before its click-up.
        local epoch = openEpoch
        C_Timer.After(0, function() if opened and openEpoch == epoch then Tray.Close() end end)
    else
        QueueRefresh(ev ~= "ZONE_CHANGED_NEW_AREA")
        if ev == "VARIABLES_LOADED" or ev == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.5, function() QueueRefresh(true) end)
            C_Timer.After(2, function() QueueRefresh(true) end)
        end
    end
end)

-- Observe future Lua-created buttons, including anonymous launchers. A
-- return-preserving wrapper is needed: hooksecurefunc does not expose results.
local originalCreateFrame = CreateFrame
CreateFrame = function(...)
    local frameType, name = arg[1], arg[2]
    local frame = originalCreateFrame(unpack(arg, 1, arg.n))
    if frameType == "Button" and not BlockedName(name) then
        created[frame] = true
        QueueRefresh()
    end
    return frame
end
