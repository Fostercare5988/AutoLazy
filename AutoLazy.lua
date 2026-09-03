--[[
    AutoLazy v3.4.0
    Author & Maintainer: Fostercare5988
    Target: World of Warcraft 1.12.1 (Vanilla Enhanced Stack: ClassicAPI v1.13.3+, SuperWoW 2.2+, NamPower, UnitXP SP3, DXVK)
    Description: High-performance dungeon loot automation, continuous repeatable quest turn-ins, Floating Addon Tray, and Reversible System Bloat Suppression.
]]

-- Strict Engine Dependency Guard (Mandatory ClassicAPI v1.13.3+ & SuperWoW v2.2+)
if not (CLASSIC_API_VERSION and SUPERWOW_VERSION) then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[AutoLazy Fatal Error]|r AutoLazy requires ClassicAPI.dll (v1.13.3+) & SuperWoW (v2.2+)! Please ensure both DLLs are loaded.", 1, 0.2, 0.2)
    end
    return
end

local addonName = "AutoLazy"
local addonVersion = "3.4.0"

AutoLazy = {}

-- 1.12.1 Binary Loot Roll Constants
local LOOT_ROLL_PASS  = 0
local LOOT_ROLL_NEED  = 1
local LOOT_ROLL_GREED = 2

-- Supported Dungeons Definition Table
local DungeonDefinitions = {
    {
        key = "The Black Morass",
        title = "The Black Morass",
        itemDesc = "Corrupted Sand",
        aliases = { "the black morass", "black morass", "opening of the dark portal", "dark portal" },
        defaultMode = "NEED",
    },
    {
        key = "Zul'Gurub",
        title = "Zul'Gurub",
        itemDesc = "Coins & Bijous",
        aliases = { "zul'gurub", "zulgurub", "zg" },
        defaultMode = "NEED",
    },
    {
        key = "Ruins of Ahn'Qiraj",
        title = "Ruins of Ahn'Qiraj",
        itemDesc = "Scarabs, Idols & Keys",
        aliases = { "ruins of ahn'qiraj", "ahn'qiraj ruins", "aq20", "ruins of ahnqiraj" },
        defaultMode = "NEED",
    },
}

-- $O(1)$ Hash Table of recognized Farm Items (Normalized lowercase -> Category Tag)
local FarmItemLookup = {
    -- The Black Morass
    ["corrupted sand"]            = "Corrupted Sand",

    -- Zul'Gurub (9 Tribal Coins)
    ["zulian coin"]               = "ZG Coin",
    ["razzashi coin"]             = "ZG Coin",
    ["hakkari coin"]              = "ZG Coin",
    ["sandfury coin"]             = "ZG Coin",
    ["skullsplitter coin"]        = "ZG Coin",
    ["bloodscalp coin"]           = "ZG Coin",
    ["gurubashi coin"]            = "ZG Coin",
    ["vilebranch coin"]           = "ZG Coin",
    ["witherbark coin"]           = "ZG Coin",

    -- Zul'Gurub (9 Hakkari Bijous)
    ["red hakkari bijou"]         = "ZG Bijou",
    ["blue hakkari bijou"]        = "ZG Bijou",
    ["yellow hakkari bijou"]      = "ZG Bijou",
    ["orange hakkari bijou"]      = "ZG Bijou",
    ["green hakkari bijou"]       = "ZG Bijou",
    ["purple hakkari bijou"]      = "ZG Bijou",
    ["bronze hakkari bijou"]      = "ZG Bijou",
    ["silver hakkari bijou"]      = "ZG Bijou",
    ["gold hakkari bijou"]        = "ZG Bijou",
    ["hakkari bijou"]             = "ZG Bijou",

    -- AQ20 (8 Scarab Tokens)
    ["stone scarab"]              = "AQ20 Scarab",
    ["gold scarab"]               = "AQ20 Scarab",
    ["silver scarab"]             = "AQ20 Scarab",
    ["bronze scarab"]             = "AQ20 Scarab",
    ["crystal scarab"]            = "AQ20 Scarab",
    ["clay scarab"]               = "AQ20 Scarab",
    ["bone scarab"]               = "AQ20 Scarab",
    ["ivory scarab"]              = "AQ20 Scarab",

    -- AQ20 (9 Token Idols - Excludes Druid Relic Idols)
    ["amber idol"]                = "AQ20 Idol",
    ["azure idol"]                = "AQ20 Idol",
    ["jasper idol"]               = "AQ20 Idol",
    ["obsidian idol"]             = "AQ20 Idol",
    ["onyx idol"]                 = "AQ20 Idol",
    ["primal idol"]               = "AQ20 Idol",
    ["vermilion idol"]            = "AQ20 Idol",
    ["alabaster idol"]            = "AQ20 Idol",
    ["lambent idol"]              = "AQ20 Idol",

    -- AQ20 Keys & Shards
    ["scarab coffer key"]         = "AQ20 Key/Shard",
    ["greater scarab coffer key"] = "AQ20 Key/Shard",
    ["large obsidian shard"]      = "AQ20 Key/Shard",
    ["small obsidian shard"]      = "AQ20 Key/Shard",
}

-- $O(1)$ Hash Table of Explicitly Blacklisted Items
local BlacklistItems = {
    ["fashion coin"]              = true,
    ["idol of the moon"]          = true,
    ["idol of rejuvenation"]      = true,
    ["idol of brutality"]         = true,
    ["idol of ferocity"]          = true,
    ["idol of health"]            = true,
}

local ItemEvaluationCache = {}

local defaultDB = {
    Enabled = true,
    FarmOnly = true,
    AutoConfirmBop = true,
    AnnounceChat = true,
    SelectedTab = 1,
    ShowButton = true,
    ButtonPos = { x = nil, y = nil },
    Tweaks = {
        HideRadio = true,
        HideLfg   = true,
        CollapseAddons = true,
    },
    Dungeons = {
        ["The Black Morass"] = { Enabled = true, Mode = "NEED" },
        ["Zul'Gurub"] = { Enabled = true, Mode = "NEED" },
        ["Ruins of Ahn'Qiraj"] = { Enabled = true, Mode = "NEED" },
    },
    Quests = {
        Enabled = true,
        AutoAccept = true,
        AutoTurnIn = true,
        SafeRewards = true,
        AlwaysActive = false,
    },
}

local CachedDungeonKey = nil
local CachedDungeonCfg = nil
local CachedDungeonDef = nil

function AutoLazy_Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99[AutoLazy]|r " .. tostring(msg))
    end
end

local actionBtn = nil
local trayFrame = nil

local function InitDB()
    if not AutoLazyDB then AutoLazyDB = {} end

    if AutoLazyDB.Enabled == nil then AutoLazyDB.Enabled = defaultDB.Enabled end
    if AutoLazyDB.FarmOnly == nil then AutoLazyDB.FarmOnly = defaultDB.FarmOnly end
    if AutoLazyDB.AutoConfirmBop == nil then AutoLazyDB.AutoConfirmBop = defaultDB.AutoConfirmBop end
    if AutoLazyDB.AnnounceChat == nil then AutoLazyDB.AnnounceChat = defaultDB.AnnounceChat end
    if AutoLazyDB.SelectedTab == nil then AutoLazyDB.SelectedTab = defaultDB.SelectedTab end
    if AutoLazyDB.ShowButton == nil then AutoLazyDB.ShowButton = defaultDB.ShowButton end
    if not AutoLazyDB.ButtonPos then AutoLazyDB.ButtonPos = {} end

    if not AutoLazyDB.Tweaks then AutoLazyDB.Tweaks = {} end
    if AutoLazyDB.Tweaks.HideRadio == nil then AutoLazyDB.Tweaks.HideRadio = defaultDB.Tweaks.HideRadio end
    if AutoLazyDB.Tweaks.HideLfg == nil then AutoLazyDB.Tweaks.HideLfg = defaultDB.Tweaks.HideLfg end
    if AutoLazyDB.Tweaks.CollapseAddons == nil then AutoLazyDB.Tweaks.CollapseAddons = defaultDB.Tweaks.CollapseAddons end

    if not AutoLazyDB.Dungeons then AutoLazyDB.Dungeons = {} end
    for _, def in ipairs(DungeonDefinitions) do
        if not AutoLazyDB.Dungeons[def.key] then
            AutoLazyDB.Dungeons[def.key] = { Enabled = true, Mode = def.defaultMode }
        else
            if AutoLazyDB.Dungeons[def.key].Enabled == nil then AutoLazyDB.Dungeons[def.key].Enabled = true end
            if not AutoLazyDB.Dungeons[def.key].Mode then AutoLazyDB.Dungeons[def.key].Mode = def.defaultMode end
        end
    end

    if not AutoLazyDB.Quests then AutoLazyDB.Quests = {} end
    for qk, qv in pairs(defaultDB.Quests) do
        if AutoLazyDB.Quests[qk] == nil then AutoLazyDB.Quests[qk] = qv end
    end
end

local function MatchDungeonKey(zoneText)
    if not zoneText or zoneText == "" or not AutoLazyDB or not AutoLazyDB.Dungeons then return nil, nil, nil end
    local norm = string.lower(zoneText)

    for _, def in ipairs(DungeonDefinitions) do
        local cfg = AutoLazyDB.Dungeons[def.key]
        if cfg then
            local normKey = string.lower(def.key)
            if norm == normKey or string.find(norm, normKey, 1, true) or string.find(normKey, norm, 1, true) then
                return def.key, cfg, def
            end
            for _, alias in ipairs(def.aliases) do
                if norm == alias or string.find(norm, alias, 1, true) or string.find(alias, norm, 1, true) then
                    return def.key, cfg, def
                end
            end
        end
    end
    return nil, nil, nil
end

function AutoLazy_ResolveCurrentDungeon()
    if not AutoLazyDB then return nil, nil, nil end
    local rz = (GetRealZoneText and GetRealZoneText()) or ""
    local z  = (GetZoneText and GetZoneText()) or ""
    local sz = (GetSubZoneText and GetSubZoneText()) or ""
    local mz = (GetMinimapZoneText and GetMinimapZoneText()) or ""

    local key, cfg, def = MatchDungeonKey(rz)
    if key then return key, cfg, def end
    key, cfg, def = MatchDungeonKey(z)
    if key then return key, cfg, def end
    key, cfg, def = MatchDungeonKey(sz)
    if key then return key, cfg, def end
    key, cfg, def = MatchDungeonKey(mz)
    if key then return key, cfg, def end
    return nil, nil, nil
end

local function UpdateZoneCache()
    local prevKey = CachedDungeonKey
    CachedDungeonKey, CachedDungeonCfg, CachedDungeonDef = AutoLazy_ResolveCurrentDungeon()
    if prevKey ~= CachedDungeonKey and table.wipe then
        table.wipe(ItemEvaluationCache)
    end
end

function AutoLazy_IsFarmItem(itemName)
    if not itemName or itemName == "" then return false, nil end

    local cached = ItemEvaluationCache[itemName]
    if cached ~= nil then
        if cached == false then return false, nil end
        return true, cached
    end

    local lower = string.lower(itemName)
    if BlacklistItems[lower] or string.find(lower, "fashion coin", 1, true) then
        ItemEvaluationCache[itemName] = false
        return false, nil
    end

    local farmTag = FarmItemLookup[lower]
    if farmTag then
        ItemEvaluationCache[itemName] = farmTag
        return true, farmTag
    end

    if string.find(lower, "hakkari bijou", 1, true) or (string.find(lower, "bijou", 1, true) and not string.find(lower, "coin", 1, true)) then
        ItemEvaluationCache[itemName] = "ZG Bijou"
        return true, "ZG Bijou"
    end

    ItemEvaluationCache[itemName] = false
    return false, nil
end

local function ShouldAutoQuest()
    if not AutoLazyDB or not AutoLazyDB.Quests or not AutoLazyDB.Quests.Enabled then return false end
    if AutoLazyDB.Quests.AlwaysActive then return true end
    return IsShiftKeyDown()
end

--------------------------------------------------
-- SAFE SYSTEM BUTTON SUPPRESSION & RESTORATION
--------------------------------------------------
local BlizzardCoreFrames = {
    ["Minimap"] = true, ["MinimapBackdrop"] = true, ["MinimapCluster"] = true,
    ["MiniMapTrackingFrame"] = true, ["MiniMapTracking"] = true, ["MiniMapMailFrame"] = true,
    ["MiniMapMailIcon"] = true, ["MiniMapBattlefieldFrame"] = true, ["MiniMapBattlefieldIcon"] = true,
    ["MinimapZoomIn"] = true, ["MinimapZoomOut"] = true, ["GameTimeFrame"] = true,
    ["MiniMapPing"] = true, ["MinimapZoneTextButton"] = true, ["MinimapZoneText"] = true,
    ["MinimapToggleButton"] = true, ["MinimapToggle"] = true, ["MinimapBorderTop"] = true,
    ["TimeManagerClockButton"] = true, ["MiniMapWorldMapButton"] = true,
    ["AutoLazy_ActionBtn"] = true, ["AutoLazy_ButtonTray"] = true,
    ["AutoLazy_OptionsFrame"] = true, ["UIParent"] = true,
}

local RADIO_NAMES = { "radio", "bbpr", "pirate", "bbradio", "tune", "station", "broadcast" }
local RADIO_TEX   = { "radio", "pirate", "bbpr", "bbradio", "inv_helmet_66", "ability_rogue_disguise", "inv_misc_bandana" }
local RADIO_TEXT  = { "radio", "pirate", "tune in", "tune out", "booty bay", "station" }
local LFG_NAMES   = { "tw_lfg", "twlfg", "meetingstone", "groupfinder", "lfgminimap", "lftminimap" }
local LFG_TEX     = { "lfg", "lft", "meetingstone", "eye" }

local function MatchesFrameKeywords(f, nameKeywords, texKeywords, textKeywords)
    if not f then return false end
    local name = f:GetName()
    if name then
        if BlizzardCoreFrames[name] or string.find(name, "AutoLazy") then return false end
        local lName = string.lower(name)
        if string.find(lName, "zonetext") or string.find(lName, "toggle") or string.find(lName, "border") or
           string.find(lName, "backdrop") or string.find(lName, "cluster") then
            return false
        end
        if nameKeywords then
            for i = 1, #nameKeywords do
                if string.find(lName, nameKeywords[i]) then return true end
            end
        end
    end

    if texKeywords and f.GetNormalTexture then
        local norm = f:GetNormalTexture()
        if norm and norm.GetTexture then
            local tex = norm:GetTexture()
            if tex and type(tex) == "string" then
                local lTex = string.lower(tex)
                for i = 1, #texKeywords do
                    if string.find(lTex, texKeywords[i]) then return true end
                end
            end
        end
    end

    if (texKeywords or textKeywords) and f.GetRegions then
        local function InspectRegions(r, ...)
            if not r then return false end
            if texKeywords and r.GetTexture then
                local tex = r:GetTexture()
                if tex and type(tex) == "string" then
                    local lTex = string.lower(tex)
                    for i = 1, #texKeywords do
                        if string.find(lTex, texKeywords[i]) then return true end
                    end
                end
            end
            if textKeywords and r.GetText then
                local txt = r:GetText()
                if txt and type(txt) == "string" then
                    local lTxt = string.lower(txt)
                    for i = 1, #textKeywords do
                        if string.find(lTxt, textKeywords[i]) then return true end
                    end
                end
            end
            return InspectRegions(...)
        end
        if InspectRegions(f:GetRegions()) then return true end
    end
    return false
end

local function IsRadioFrame(f) return MatchesFrameKeywords(f, RADIO_NAMES, RADIO_TEX, RADIO_TEXT) end
local function IsLfgFrame(f) return MatchesFrameKeywords(f, LFG_NAMES, LFG_TEX, nil) end

local function SetFrameSuppressed(frame, hide)
    if not frame then return end

    if not frame._alOrigState then
        local numPoints = (frame.GetNumPoints and frame:GetNumPoints()) or 0
        local point, relTo, relPoint, xOfs, yOfs = nil, nil, nil, 0, 0
        if numPoints > 0 and frame.GetPoint then
            point, relTo, relPoint, xOfs, yOfs = frame:GetPoint(1)
        end
        frame._alOrigState = {
            parent = frame:GetParent(),
            point = point or "TOPRIGHT",
            relativeTo = relTo or frame:GetParent() or Minimap,
            relativePoint = relPoint or "TOPRIGHT",
            xOfs = xOfs or 0,
            yOfs = yOfs or 0,
            alpha = (frame.GetAlpha and frame:GetAlpha()) or 1,
        }
    end

    if hide then
        frame:SetAlpha(0)
        if frame.EnableMouse then frame:EnableMouse(false) end
        frame:Hide()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000)

        if not frame._alSuppressedHook then
            frame._alSuppressedHook = true
            local origShow = frame.Show
            frame.Show = function(self)
                local isSuppressed = false
                if AutoLazyDB and AutoLazyDB.Tweaks then
                    if IsRadioFrame(self) and AutoLazyDB.Tweaks.HideRadio then isSuppressed = true
                    elseif IsLfgFrame(self) and AutoLazyDB.Tweaks.HideLfg then isSuppressed = true end
                end
                if isSuppressed then return end
                if origShow then origShow(self) end
            end
        end
    else
        if frame._alOrigState then
            if frame._alOrigState.parent and frame.SetParent then frame:SetParent(frame._alOrigState.parent) end
            frame:ClearAllPoints()
            if frame._alOrigState.relativeTo then
                frame:SetPoint(frame._alOrigState.point, frame._alOrigState.relativeTo, frame._alOrigState.relativePoint, frame._alOrigState.xOfs, frame._alOrigState.yOfs)
            else
                frame:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
            end
            frame:SetAlpha(frame._alOrigState.alpha or 1)
        else
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
            frame:SetAlpha(1)
        end
        if frame.EnableMouse then frame:EnableMouse(true) end
        frame:Show()
    end
end

local DiscoveredAddonList = {}
local DiscoveredAddonSet = {}

function AutoLazy_ApplySystemIconToggles()
    if not AutoLazyDB or not AutoLazyDB.Tweaks then return end
    local hideRadio = (AutoLazyDB.Tweaks.HideRadio == true)
    local hideLfg   = (AutoLazyDB.Tweaks.HideLfg == true)

    local knownRadio = {
        "RadioMinimapButton", "PirateRadioMinimapButton", "BBRadioMinimapButton",
        "BBPR_MinimapButton", "Radio_MinimapButton", "TWRadioMinimapButton",
        "TW_RadioMinimapButton", "TurtleRadioMinimapButton", "TWBBRadio",
        "TWBBRadioMinimapButton", "BBRadio_MinimapButton", "BootyBayRadio",
        "BootyBayRadioMinimapButton", "RadioIcon", "TW_RadioIcon", "RadioBtn", "TW_RadioBtn",
    }
    for i = 1, #knownRadio do
        local rf = getglobal(knownRadio[i])
        if rf then SetFrameSuppressed(rf, hideRadio) end
    end

    local knownLfg = {
        "TW_LFGBtn", "TWLFG_Minimap", "TWLFG_MinimapButton", "LFTMinimapButton",
        "LFT_MinimapButton", "MiniMapMeetingStoneFrame", "MiniMapLFGFrame",
        "LFGMinimapButton", "TurtleLFGMinimapButton", "GroupFinderMinimapButton",
    }
    for i = 1, #knownLfg do
        local lf = getglobal(knownLfg[i])
        if lf then SetFrameSuppressed(lf, hideLfg) end
    end

    local function ScanChildrenForBloat(child, ...)
        if not child then return end
        if not BlizzardCoreFrames[child:GetName() or ""] then
            if IsRadioFrame(child) then SetFrameSuppressed(child, hideRadio)
            elseif IsLfgFrame(child) then SetFrameSuppressed(child, hideLfg) end
        end
        return ScanChildrenForBloat(...)
    end

    local parents = { Minimap, MinimapBackdrop, MinimapCluster, trayFrame }
    for i = 1, #parents do
        local parent = parents[i]
        if parent and parent.GetChildren then
            ScanChildrenForBloat(parent:GetChildren())
        end
    end

    for _, btn in ipairs(DiscoveredAddonList) do
        if btn then
            if IsRadioFrame(btn) then SetFrameSuppressed(btn, hideRadio)
            elseif IsLfgFrame(btn) then SetFrameSuppressed(btn, hideLfg) end
        end
    end
end

--------------------------------------------------
-- STRICT ADDON BUTTON SCANNER (ZERO LEAKS & NO GAPS)
--------------------------------------------------
local function HasRenderableVisual(f)
    if not f then return false end
    if f.GetNormalTexture then
        local norm = f:GetNormalTexture()
        if norm and norm.GetTexture then
            local tex = norm:GetTexture()
            if tex and type(tex) == "string" and tex ~= "" then return true end
        end
    end
    if f.GetRegions then
        local regions = { f:GetRegions() }
        for _, r in ipairs(regions) do
            if r and r.GetTexture then
                local tex = r:GetTexture()
                if tex and type(tex) == "string" and tex ~= "" and not string.find(string.lower(tex), "tooltip") then
                    return true
                end
            end
            if r and r.GetText then
                local txt = r:GetText()
                if txt and type(txt) == "string" and txt ~= "" then return true end
            end
        end
    end
    return false
end

local function IsValidAddonButton(f)
    if not f or not f:IsObjectType("Button") then return false end
    local name = f:GetName()
    if name then
        if BlizzardCoreFrames[name] or string.find(name, "AutoLazy") then return false end
        local lower = string.lower(name)
        if string.find(lower, "aura") or string.find(lower, "buff") or string.find(lower, "debuff") or
           string.find(lower, "cooldown") or string.find(lower, "combat") or string.find(lower, "action") or
           string.find(lower, "spell") or string.find(lower, "icon_") or string.find(lower, "condition") or
           string.find(lower, "close") or string.find(lower, "play") or string.find(lower, "targetframe") then
            if name ~= "DoiteAurasMinimapButton" then return false end
        end
    end

    if IsRadioFrame(f) or IsLfgFrame(f) then return false end

    local w, h = f:GetWidth(), f:GetHeight()
    if w and h and w > 0 and h > 0 then
        if w > 54 or h > 54 or w < 16 or h < 16 then return false end
    end

    return HasRenderableVisual(f)
end

function AutoLazy_FindAddonButtons()
    local function RegisterButton(f, isExplicit)
        if not f or not f:IsObjectType("Button") then return end
        if not isExplicit and not IsValidAddonButton(f) then return end
        if AutoLazyDB and AutoLazyDB.Tweaks then
            if AutoLazyDB.Tweaks.HideRadio and IsRadioFrame(f) then return end
            if AutoLazyDB.Tweaks.HideLfg and IsLfgFrame(f) then return end
        end

        if not DiscoveredAddonSet[f] then
            DiscoveredAddonSet[f] = true
            if not f._alOrigState then
                local numPoints = (f.GetNumPoints and f:GetNumPoints()) or 0
                local point, relTo, relPoint, xOfs, yOfs = nil, nil, nil, 0, 0
                if numPoints > 0 and f.GetPoint then point, relTo, relPoint, xOfs, yOfs = f:GetPoint(1) end
                f._alOrigState = {
                    parent = f:GetParent(), point = point or "CENTER",
                    relativeTo = relTo or f:GetParent() or Minimap, relativePoint = relPoint or "CENTER",
                    xOfs = xOfs or 0, yOfs = yOfs or 0, alpha = (f.GetAlpha and f:GetAlpha()) or 1,
                }
            end
            table.insert(DiscoveredAddonList, f)
        end
    end

    local ExplicitAddons = {
        "AtlasLootMinimapButtonFrame", "AtlasLootMinimapButton", "pfQuestIcon", "DoiteAurasMinimapButton",
        "TrinketMenu_IconFrame", "BagnonMinimapButton", "AutoBG_QuickQueueButton", "TWThreatMinimapButton",
        "shootyepgpMinimapButton", "sepgpMinimapButton", "WIM3MinimapButton", "SuperAPIOptionsMinimapButton",
        "EasyPoisonsMinimapButton", "ModernMapMarkersMinimapButton", "ShaguDPSMinimapButton", "BigWigsMinimapButton",
    }
    for _, kName in ipairs(ExplicitAddons) do
        local f = getglobal(kName)
        if f and HasRenderableVisual(f) then RegisterButton(f, true) end
    end

    local function ScanChildrenForAddons(child, ...)
        if not child then return end
        if child:IsObjectType("Button") then RegisterButton(child, false) end
        return ScanChildrenForAddons(...)
    end

    local parents = { Minimap, MinimapBackdrop, MinimapCluster, trayFrame }
    for i = 1, #parents do
        local parent = parents[i]
        if parent and parent.GetChildren then
            ScanChildrenForAddons(parent:GetChildren())
        end
    end

    local activeList = {}
    for _, btn in ipairs(DiscoveredAddonList) do
        if HasRenderableVisual(btn) then
            local isSuppressed = false
            if AutoLazyDB and AutoLazyDB.Tweaks then
                if AutoLazyDB.Tweaks.HideRadio and IsRadioFrame(btn) then isSuppressed = true; SetFrameSuppressed(btn, true)
                elseif AutoLazyDB.Tweaks.HideLfg and IsLfgFrame(btn) then isSuppressed = true; SetFrameSuppressed(btn, true) end
            end
            if not isSuppressed then table.insert(activeList, btn) end
        end
    end
    return activeList
end

--------------------------------------------------
-- AUTOLAZY FLOATING BUTTON & ADDON TRAY
--------------------------------------------------
trayFrame = CreateFrame("Frame", "AutoLazy_ButtonTray", UIParent)
trayFrame:SetFrameStrata("HIGH")
trayFrame:SetToplevel(true)
trayFrame:EnableMouse(true)
trayFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 }
})
trayFrame:SetBackdropColor(0.08, 0.08, 0.12, 0.94)
trayFrame:SetBackdropBorderColor(0.85, 0.70, 0.20, 0.90)
trayFrame:Hide()

local trayTitle = trayFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
trayTitle:SetPoint("TOP", trayFrame, "TOP", 0, -8)
trayTitle:SetText("|cFFFFD100Addons|r")

function AutoLazy_CloseTray()
    if trayFrame:IsShown() then
        for _, btn in ipairs(DiscoveredAddonList) do
            if btn and btn.Hide then btn:Hide() end
        end
        trayFrame:Hide()
    end
end

function AutoLazy_OpenTray()
    if not actionBtn then return end
    AutoLazy_ApplySystemIconToggles()

    local buttons = AutoLazy_FindAddonButtons()
    local count = #buttons
    if count == 0 then
        AutoLazy_Print("No user addon buttons found to display in tray.")
        return
    end

    local cols = math.min(count, 4)
    if cols < 2 then cols = 2 end
    local rows = math.ceil(count / cols)

    local iconSize, pad, marginX, topMargin, botMargin = 32, 8, 12, 28, 14
    local trayW = marginX * 2 + cols * iconSize + (cols - 1) * pad
    local trayH = topMargin + botMargin + rows * iconSize + (rows - 1) * pad

    trayFrame:SetWidth(trayW)
    trayFrame:SetHeight(trayH)

    local btnX = actionBtn:GetCenter()
    local screenW = UIParent:GetWidth()
    trayFrame:ClearAllPoints()
    if btnX and btnX > (screenW / 2) then
        trayFrame:SetPoint("TOPRIGHT", actionBtn, "BOTTOMLEFT", -6, 6)
    else
        trayFrame:SetPoint("TOPLEFT", actionBtn, "BOTTOMRIGHT", 6, 6)
    end

    for i, btn in ipairs(buttons) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = marginX + col * (iconSize + pad)
        local y = -(topMargin + row * (iconSize + pad))

        btn:ClearAllPoints()
        btn:SetParent(trayFrame)
        btn:SetFrameStrata("HIGH")
        btn:SetPoint("TOPLEFT", trayFrame, "TOPLEFT", x, y)
        btn:SetAlpha(1)
        btn:Show()
    end
    trayFrame:Show()
end

function AutoLazy_ToggleTray()
    if trayFrame:IsShown() then AutoLazy_CloseTray() else AutoLazy_OpenTray() end
end

function AutoLazy_CollapseAddons(enable)
    if not AutoLazyDB or not AutoLazyDB.Tweaks then return end
    if enable == nil then enable = (AutoLazyDB.Tweaks.CollapseAddons ~= false) end

    if enable then
        local buttons = AutoLazy_FindAddonButtons()
        if not trayFrame:IsShown() then
            for _, btn in ipairs(buttons) do
                if btn and btn.Hide then btn:Hide() end
            end
        end
    else
        for _, btn in ipairs(DiscoveredAddonList) do
            if btn and btn._alOrigState then
                if btn._alOrigState.parent and btn.SetParent then btn:SetParent(btn._alOrigState.parent) end
                btn:ClearAllPoints()
                if btn._alOrigState.relativeTo then
                    btn:SetPoint(btn._alOrigState.point, btn._alOrigState.relativeTo, btn._alOrigState.relativePoint, btn._alOrigState.xOfs, btn._alOrigState.yOfs)
                else
                    btn:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
                end
                btn:SetAlpha(btn._alOrigState.alpha or 1)
                btn:Show()
            end
        end
        if trayFrame:IsShown() then trayFrame:Hide() end
    end
end

--------------------------------------------------
-- AUTOLAZY FLOATING DRAGGABLE BUTTON
--------------------------------------------------
actionBtn = CreateFrame("Button", "AutoLazy_ActionBtn", UIParent)
actionBtn:SetWidth(33); actionBtn:SetHeight(33)
actionBtn:SetFrameStrata("MEDIUM")
actionBtn:SetToplevel(true)
actionBtn:EnableMouse(true)
actionBtn:SetMovable(true)
actionBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
actionBtn:RegisterForDrag("LeftButton", "RightButton")
actionBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local btnIcon = actionBtn:CreateTexture(nil, "BACKGROUND")
btnIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
btnIcon:SetWidth(20); btnIcon:SetHeight(20)
btnIcon:SetPoint("CENTER", actionBtn, "CENTER", 0, 0)

local btnBorder = actionBtn:CreateTexture(nil, "OVERLAY")
btnBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
btnBorder:SetWidth(54); btnBorder:SetHeight(54)
btnBorder:SetPoint("TOPLEFT", actionBtn, "TOPLEFT", 0, 0)

function AutoLazy_UpdateActionButton()
    if not AutoLazyDB then InitDB() end
    if AutoLazyDB.ShowButton == false then
        actionBtn:Hide()
        AutoLazy_CloseTray()
        return
    end

    actionBtn:ClearAllPoints()
    if AutoLazyDB.ButtonPos and AutoLazyDB.ButtonPos.x and AutoLazyDB.ButtonPos.y then
        actionBtn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", AutoLazyDB.ButtonPos.x, AutoLazyDB.ButtonPos.y)
    else
        actionBtn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -180, -20)
    end
    actionBtn:Show()
end

function AutoLazy_ResetActionButtonPos()
    if not AutoLazyDB then InitDB() end
    AutoLazyDB.ButtonPos = { x = nil, y = nil }
    AutoLazy_UpdateActionButton()
    AutoLazy_Print("AutoLazy button position reset to top right.")
end

actionBtn:SetScript("OnDragStart", function() this:StartMoving() end)
actionBtn:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    if AutoLazyDB then
        AutoLazyDB.ButtonPos = AutoLazyDB.ButtonPos or {}
        AutoLazyDB.ButtonPos.x = this:GetLeft()
        AutoLazyDB.ButtonPos.y = this:GetBottom()
    end
end)

actionBtn:SetScript("OnClick", function()
    if arg1 == "RightButton" then AutoLazy_ToggleGUI() else AutoLazy_ToggleTray() end
end)

actionBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("AutoLazy", 1, 1, 1)
    GameTooltip:AddLine("|cFFFFD100Left-Click:|r Toggle Addon Tray", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("|cFFFFD100Right-Click:|r Open AutoLazy Options", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("|cFF888888Click & Drag to move anywhere on screen|r", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
actionBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

function AutoLazy_PrintStatus()
    if not AutoLazyDB then InitDB() end
    UpdateZoneCache()

    local masterStatus = AutoLazyDB.Enabled and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"
    local farmStatus = AutoLazyDB.FarmOnly and "|cFFFFD100Farm Items ONLY|r (Gear ignored)" or "|cFF00FF00All Items|r"
    local bopStatus = AutoLazyDB.AutoConfirmBop and "|cFF00FF00ON|r" or "|cFFFF2020OFF|r"
    local questStatus = (AutoLazyDB.Quests and AutoLazyDB.Quests.Enabled) and "|cFF00FF00ON (Shift-Click)|r" or "|cFFFF2020OFF|r"
    AutoLazy_Print("Dungeon Auto-Loot: " .. masterStatus .. " | Filter: " .. farmStatus .. " | BoP: " .. bopStatus .. " | Quests: " .. questStatus)

    local currentZone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "Unknown"
    if CachedDungeonKey and CachedDungeonCfg and CachedDungeonCfg.Enabled then
        AutoLazy_Print("Current Zone: |cFF00FF00" .. currentZone .. "|r (Active -> Mode: |cFFFFD100" .. CachedDungeonCfg.Mode .. "|r)")
    else
        AutoLazy_Print("Current Zone: |cFFFF8080" .. currentZone .. "|r (Auto-Loot inactive here)")
    end
end

local function DismissConfirmPopups(rollId)
    if rollId and StaticPopup_Hide then StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollId) end
    if StaticPopup_Hide then StaticPopup_Hide("CONFIRM_LOOT_ROLL") end
    for i = 1, 4 do
        local popup = getglobal("StaticPopup" .. i)
        if popup and popup:IsShown() and popup.which == "CONFIRM_LOOT_ROLL" then popup:Hide() end
    end
end

local function ProcessGossip()
    if not ShouldAutoQuest() then return false end
    if C_GossipInfo and C_GossipInfo.GetActiveQuests then
        if AutoLazyDB.Quests.AutoTurnIn then
            local active = C_GossipInfo.GetActiveQuests()
            if active and #active > 0 then
                C_GossipInfo.SelectActiveQuest(1)
                return true
            end
        end
        if AutoLazyDB.Quests.AutoAccept then
            local avail = C_GossipInfo.GetAvailableQuests()
            if avail and #avail > 0 then
                C_GossipInfo.SelectAvailableQuest(1)
                return true
            end
        end
    else
        if AutoLazyDB.Quests.AutoTurnIn then
            local activeTitle = GetGossipActiveQuests()
            if activeTitle then
                SelectGossipActiveQuest(1)
                return true
            end
        end
        if AutoLazyDB.Quests.AutoAccept then
            local availTitle = GetGossipAvailableQuests()
            if availTitle then
                SelectGossipAvailableQuest(1)
                return true
            end
        end
    end
    return false
end

local function ProcessGreeting()
    if not ShouldAutoQuest() then return false end
    if AutoLazyDB.Quests.AutoTurnIn then
        local numActive = GetNumActiveQuests()
        if numActive and numActive > 0 then
            SelectActiveQuest(1)
            return true
        end
    end
    if AutoLazyDB.Quests.AutoAccept then
        local numAvail = GetNumAvailableQuests()
        if numAvail and numAvail > 0 then
            SelectAvailableQuest(1)
            return true
        end
    end
    return false
end

-- Main Event Frame
local EventFrame = CreateFrame("Frame", "AutoLazy_EventFrame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("VARIABLES_LOADED")
EventFrame:RegisterEvent("START_LOOT_ROLL")
EventFrame:RegisterEvent("CONFIRM_LOOT_ROLL")
EventFrame:RegisterEvent("LOOT_BIND_CONFIRM")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventFrame:RegisterEvent("ZONE_CHANGED")
EventFrame:RegisterEvent("GOSSIP_SHOW")
EventFrame:RegisterEvent("QUEST_GREETING")
EventFrame:RegisterEvent("QUEST_DETAIL")
EventFrame:RegisterEvent("QUEST_PROGRESS")
EventFrame:RegisterEvent("QUEST_COMPLETE")
EventFrame:RegisterEvent("QUEST_FINISHED")

EventFrame:SetScript("OnEvent", function()
    local ev, a1, a2 = event, arg1, arg2

    if (ev == "ADDON_LOADED" and a1 == addonName) or ev == "VARIABLES_LOADED" then
        InitDB()
        UpdateZoneCache()
        AutoLazy_UpdateActionButton()
        AutoLazy_ApplySystemIconToggles()
        AutoLazy_CollapseAddons()

        -- Native C++ Hardware Timers (Zero OnUpdate startup bloat)
        C_Timer.After(1.0, function()
            AutoLazy_ApplySystemIconToggles()
            if AutoLazy_CollapseAddons then AutoLazy_CollapseAddons() end
        end)
        C_Timer.After(2.5, function()
            AutoLazy_ApplySystemIconToggles()
            if AutoLazy_CollapseAddons then AutoLazy_CollapseAddons() end
        end)

    elseif ev == "PLAYER_ENTERING_WORLD" or ev == "ZONE_CHANGED_NEW_AREA" or ev == "ZONE_CHANGED" then
        UpdateZoneCache()
        AutoLazy_ApplySystemIconToggles()
        AutoLazy_CollapseAddons()

    elseif ev == "START_LOOT_ROLL" then
        if not AutoLazyDB or not AutoLazyDB.Enabled or not CachedDungeonKey or not CachedDungeonCfg or not CachedDungeonCfg.Enabled or CachedDungeonCfg.Mode == "OFF" then
            return
        end

        local rollId = a1
        if not rollId then return end

        local texture, name, count, quality, bindOnPickup = GetLootRollItemInfo(rollId)
        local itemLink = GetLootRollItemLink(rollId) or (name and ("[" .. name .. "]")) or ("Item #" .. rollId)

        local isFarm, farmTag = AutoLazy_IsFarmItem(name)
        if AutoLazyDB.FarmOnly and not isFarm then return end

        local rollType = (CachedDungeonCfg.Mode == "NEED" and LOOT_ROLL_NEED) or (CachedDungeonCfg.Mode == "GREED" and LOOT_ROLL_GREED) or (CachedDungeonCfg.Mode == "PASS" and LOOT_ROLL_PASS)
        local actionName = (CachedDungeonCfg.Mode == "NEED" and "|cFFFF8000Need|r") or (CachedDungeonCfg.Mode == "GREED" and "|cFF00FF00Greed|r") or "|cFF808080Passed|r"

        if rollType ~= nil then
            RollOnLoot(rollId, rollType)
            if AutoLazyDB.AnnounceChat then
                local tag = farmTag and (" [" .. farmTag .. "]") or ""
                AutoLazy_Print(actionName .. " on " .. itemLink .. tag .. " (" .. CachedDungeonDef.title .. ")")
            end
        end

    elseif ev == "CONFIRM_LOOT_ROLL" then
        if not AutoLazyDB or not AutoLazyDB.Enabled or not AutoLazyDB.AutoConfirmBop then return end
        local rollId = a1
        local rollType = a2 or ((CachedDungeonCfg and CachedDungeonCfg.Mode == "NEED") and LOOT_ROLL_NEED or LOOT_ROLL_GREED)
        if rollId and rollType then
            ConfirmLootRoll(rollId, rollType)
            DismissConfirmPopups(rollId)
        end

    elseif ev == "LOOT_BIND_CONFIRM" then
        if not AutoLazyDB or not AutoLazyDB.Enabled or not AutoLazyDB.AutoConfirmBop then return end
        local slot = a1
        if slot and ConfirmLootSlot then
            ConfirmLootSlot(slot)
            if StaticPopup_Hide then StaticPopup_Hide("LOOT_BIND") end
            for i = 1, 4 do
                local popup = getglobal("StaticPopup" .. i)
                if popup and popup:IsShown() and popup.which == "LOOT_BIND" then popup:Hide() end
            end
        end

    -- Continuous Shift+Click Quest Handlers
    elseif ev == "GOSSIP_SHOW" then
        ProcessGossip()

    elseif ev == "QUEST_GREETING" then
        ProcessGreeting()

    elseif ev == "QUEST_DETAIL" then
        if ShouldAutoQuest() and AutoLazyDB.Quests.AutoAccept then AcceptQuest() end

    elseif ev == "QUEST_PROGRESS" then
        if ShouldAutoQuest() and AutoLazyDB.Quests.AutoTurnIn and IsQuestCompletable() then CompleteQuest() end

    elseif ev == "QUEST_COMPLETE" then
        if ShouldAutoQuest() and AutoLazyDB.Quests.AutoTurnIn then
            local choices = GetNumQuestChoices()
            if not choices or choices <= 1 or not AutoLazyDB.Quests.SafeRewards then
                GetQuestReward(1)
            else
                AutoLazy_Print("Quest ready for turn-in: Please choose your reward manually.")
            end
        end

    elseif ev == "QUEST_FINISHED" then
        -- Fast chain-trigger for repeatable turn-ins (e.g. E'ko, Scourgestones, Bijous, Dark Iron Residue)
        if ShouldAutoQuest() then
            C_Timer.After(0.06, function()
                if GossipFrame and GossipFrame:IsShown() then
                    ProcessGossip()
                elseif QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown() then
                    ProcessGreeting()
                end
            end)
        end
    end
end)

-- Data-Driven Slash Command Dispatcher
local slashToggles = {
    tray = function() AutoLazy_ToggleTray() end,
    bag = function() AutoLazy_ToggleTray() end,
    collapse = function()
        AutoLazyDB.Tweaks.CollapseAddons = not AutoLazyDB.Tweaks.CollapseAddons
        if AutoLazy_CollapseAddons then AutoLazy_CollapseAddons(AutoLazyDB.Tweaks.CollapseAddons) end
        AutoLazy_Print("Collapse Addons into Tray: " .. (AutoLazyDB.Tweaks.CollapseAddons and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    resetpos = function() AutoLazy_ResetActionButtonPos() end,
    reset = function() AutoLazy_ResetActionButtonPos() end,
    toggle = function()
        AutoLazyDB.Enabled = not AutoLazyDB.Enabled
        AutoLazy_Print("Dungeon Auto-Loot is now " .. (AutoLazyDB.Enabled and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    on = function() AutoLazyDB.Enabled = true; AutoLazy_Print("Dungeon Auto-Loot is now |cFF00FF00ENABLED|r."); if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end end,
    off = function() AutoLazyDB.Enabled = false; AutoLazy_Print("Dungeon Auto-Loot is now |cFFFF2020DISABLED|r."); if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end end,
    farm = function()
        AutoLazyDB.FarmOnly = not AutoLazyDB.FarmOnly
        AutoLazy_Print("Farm Items Only: " .. (AutoLazyDB.FarmOnly and "|cFF00FF00ON (Gear ignored)|r" or "|cFFFF2020OFF (All items)|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    quest = function()
        AutoLazyDB.Quests.Enabled = not AutoLazyDB.Quests.Enabled
        AutoLazy_Print("Quest Automation: " .. (AutoLazyDB.Quests.Enabled and "|cFF00FF00ENABLED (Shift-Click)|r" or "|cFFFF2020DISABLED|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    btn = function()
        AutoLazyDB.ShowButton = not AutoLazyDB.ShowButton
        AutoLazy_UpdateActionButton()
        AutoLazy_Print("AutoLazy Button: " .. (AutoLazyDB.ShowButton and "|cFF00FF00SHOWN|r" or "|cFFFF2020HIDDEN|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    radio = function()
        AutoLazyDB.Tweaks.HideRadio = not AutoLazyDB.Tweaks.HideRadio
        AutoLazy_ApplySystemIconToggles()
        AutoLazy_Print("Hide Booty Bay Radio: " .. (AutoLazyDB.Tweaks.HideRadio and "|cFF00FF00ENABLED (Hidden)|r" or "|cFFFF2020DISABLED (Shown)|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    lfg = function()
        AutoLazyDB.Tweaks.HideLfg = not AutoLazyDB.Tweaks.HideLfg
        AutoLazy_ApplySystemIconToggles()
        AutoLazy_Print("Hide Group Finder: " .. (AutoLazyDB.Tweaks.HideLfg and "|cFF00FF00ENABLED (Hidden)|r" or "|cFFFF2020DISABLED (Shown)|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    status = function() AutoLazy_PrintStatus() end,
    bop = function()
        AutoLazyDB.AutoConfirmBop = not AutoLazyDB.AutoConfirmBop
        AutoLazy_Print("Auto-Confirm BoP: " .. (AutoLazyDB.AutoConfirmBop and "|cFF00FF00ON|r" or "|cFFFF2020OFF|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    chat = function()
        AutoLazyDB.AnnounceChat = not AutoLazyDB.AnnounceChat
        AutoLazy_Print("Chat Roll Alerts: " .. (AutoLazyDB.AnnounceChat and "|cFF00FF00ON|r" or "|cFFFF2020OFF|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
}

SLASH_AUTOLAZY1 = "/autolazy"
SLASH_AUTOLAZY2 = "/al"
SLASH_AUTOLAZY3 = "/ar"
SlashCmdList["AUTOLAZY"] = function(msg)
    if not AutoLazyDB then InitDB() end
    local _, _, cmd = string.find(msg or "", "^%s*(%S+)%s*(.-)$")
    cmd = string.lower(cmd or "")

    if slashToggles[cmd] then
        slashToggles[cmd]()
    elseif cmd == "" or cmd == "gui" or cmd == "menu" or cmd == "config" or cmd == "options" then
        if AutoLazy_ToggleGUI then AutoLazy_ToggleGUI() else AutoLazy_PrintStatus() end
    else
        AutoLazy_Print("Commands: /al, /al tray, /al collapse, /al resetpos, /al btn, /al radio, /al lfg, /al toggle, /al farm, /al quest, /al status")
    end
end
