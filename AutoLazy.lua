--[[
    AutoLazy v3.7.0
    Author & Maintainer: Fostercare5988
    Target: World of Warcraft 1.12.1 (Vanilla Enhanced Stack: ClassicAPI v1.14.0+, SuperWoW 2.2+, NamPower, UnitXP SP3, DXVK)
    Description: High-performance dungeon loot automation, continuous repeatable quest turn-ins, Floating Addon Tray, and Reversible System Bloat Suppression.
]]

-- Strict Engine Dependency Guard (Mandatory ClassicAPI v1.14.0+ & SuperWoW v2.2+)
local MIN_CLASSIC_API = 11400

if not (CLASSIC_API_VERSION and SUPERWOW_VERSION) or 
   (type(CLASSIC_API_VERSION) == "number" and CLASSIC_API_VERSION < MIN_CLASSIC_API) then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[AutoLazy Fatal Error]|r AutoLazy requires ClassicAPI (v1.14.0+) & SuperWoW (v2.2+)! Please ensure both DLLs are loaded.", 1, 0.2, 0.2)
    end
    return
end

local addonName = "AutoLazy"
local addonVersion = "3.7.0"

AutoLazy = {}

-- Standard library and engine upvalues for high-frequency execution
local string_find, string_lower = string.find, string.lower
local math_min, math_ceil, math_floor = math.min, math.ceil, math.floor
local table_insert, table_wipe = table.insert, table.wipe
local type, select, pairs, ipairs, getglobal = type, select, pairs, ipairs, getglobal

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
        itemDesc = "Scarabs & Idols",
        aliases = { "ruins of ahn'qiraj", "ahn'qiraj ruins", "aq20", "ruins of ahnqiraj" },
        defaultMode = "NEED",
    },
    {
        key = "Naxxramas",
        title = "Naxxramas",
        itemDesc = "Wartorn Scraps",
        aliases = { "naxxramas", "naxx" },
        defaultMode = "NEED",
    },
}

-- Granular Dungeon Items Definition Table (Icons, IDs, Rarity & Safe Defaults)
local DungeonItems = {
    ["The Black Morass"] = {
        { id = 50203, name = "Corrupted Sand", texture = "Interface\\Icons\\INV_enchant_dustsoul", quality = 2, defaultNeed = true },
    },
    ["Zul'Gurub"] = {
        { id = 19707, name = "Bijous", texture = "Interface\\Icons\\INV_Bijou_Gold", quality = 3, defaultNeed = true, key = "zg bijous" },
        { id = 19698, name = "Coins", texture = "Interface\\Icons\\INV_Misc_ArmorKit_11", quality = 2, defaultNeed = true, key = "zg coins" },
    },
    ["Ruins of Ahn'Qiraj"] = {
        { id = 20858, name = "Scarabs", texture = "Interface\\Icons\\INV_Scarab_Stone", quality = 2, defaultNeed = true, key = "aq20 scarabs" },
        { id = 20875, name = "Idols", texture = "Interface\\Icons\\INV_Misc_Idol_01", quality = 3, defaultNeed = false, key = "aq20 idols" },
    },
    ["Naxxramas"] = {
        { id = 22376, name = "Wartorn Cloth Scrap", texture = "Interface\\Icons\\INV_Misc_WartornScrap_Cloth", quality = 3, defaultNeed = true, key = "wartorn cloth scrap" },
        { id = 22373, name = "Wartorn Leather Scrap", texture = "Interface\\Icons\\INV_Misc_WartornScrap_Leather", quality = 3, defaultNeed = true, key = "wartorn leather scrap" },
        { id = 22374, name = "Wartorn Chain Scrap", texture = "Interface\\Icons\\INV_Misc_WartornScrap_Chain", quality = 3, defaultNeed = true, key = "wartorn chain scrap" },
        { id = 22375, name = "Wartorn Plate Scrap", texture = "Interface\\Icons\\INV_Misc_WartornScrap_Plate", quality = 3, defaultNeed = true, key = "wartorn plate scrap" },
    },
}

AutoLazy.DungeonDefinitions = DungeonDefinitions
AutoLazy.DungeonItems = DungeonItems
AutoLazy_DungeonDefinitions = DungeonDefinitions
AutoLazy_DungeonItems = DungeonItems

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

    -- Naxxramas (Tier 3 Wartorn Scraps)
    ["wartorn cloth scrap"]       = "Wartorn Scrap",
    ["wartorn leather scrap"]     = "Wartorn Scrap",
    ["wartorn chain scrap"]       = "Wartorn Scrap",
    ["wartorn plate scrap"]       = "Wartorn Scrap",

    -- Argent Dawn (Repeatable Hand-in Materials)
    ["bone fragments"]            = "Argent Dawn",
    ["crypt fiend parts"]         = "Argent Dawn",
    ["core of elements"]          = "Argent Dawn",
    ["savage frond"]              = "Argent Dawn",
    ["somber hourglass"]          = "Argent Dawn",
    ["healthy dragon scale"]      = "Argent Dawn",
    ["fiery core"]                = "Molten Core",
    ["lava core"]                 = "Molten Core",
    ["core leather"]              = "Molten Core",

    -- Cenarion Circle (Silithus)
    ["encrypted twilight text"]   = "Twilight Text",
    ["twilight cultist cowl"]     = "Twilight Cultist",
    ["twilight cultist mantle"]   = "Twilight Cultist",
    ["twilight cultist robe"]     = "Twilight Cultist",
    ["abyssal crest"]             = "Cenarion Token",
    ["abyssal signet"]            = "Cenarion Token",
    ["abyssal scepter"]           = "Cenarion Token",

    -- Timbermaw Hold
    ["deadwood headdress feather"]= "Timbermaw",
    ["winterfall spirit beads"]   = "Timbermaw",
    ["water elemental core"]      = "Timbermaw",

    -- Winterspring E'ko
    ["winterfall e'ko"]           = "Winterspring E'ko",
    ["frostmaul e'ko"]            = "Winterspring E'ko",
    ["shardtooth e'ko"]           = "Winterspring E'ko",
    ["frostsaber e'ko"]           = "Winterspring E'ko",
    ["wildkin e'ko"]              = "Winterspring E'ko",
    ["chillwind e'ko"]            = "Winterspring E'ko",
    ["ice thistle e'ko"]          = "Winterspring E'ko",

    -- Un'Goro Crater
    ["un'goro soil"]              = "Un'Goro Soil",
    ["morrowgrain"]               = "Morrowgrain",
    ["bloodpetal sprout"]         = "Bloodpetal",

    -- Alterac Valley
    ["armor scraps"]              = "AV Scraps",
    ["stormpike soldier's blood"] = "AV Blood",
    ["stormpike lieutenant's flesh"] = "AV Flesh",
    ["darkspear soldier's blood"] = "AV Blood",
    ["frostwolf soldier's blood"] = "AV Blood",
    ["frostwolf lieutenant's flesh"] = "AV Flesh",
    ["alterac ram hide"]          = "AV Hide",
    ["frostwolf hide"]            = "AV Hide",
    ["irondeep supplies"]         = "AV Supplies",
    ["coldtooth supplies"]        = "AV Supplies",

    -- Custom / World Turn-ins
    ["tel'abim banana"]           = "Tel'Abim",
    ["bloodfang tail"]            = "Bloodfang",
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
        ["The Black Morass"] = { Enabled = true, Mode = "NEED", NonNeedMode = "MANUAL" },
        ["Zul'Gurub"] = { Enabled = true, Mode = "NEED", NonNeedMode = "MANUAL" },
        ["Ruins of Ahn'Qiraj"] = { Enabled = true, Mode = "NEED", NonNeedMode = "MANUAL" },
        ["Naxxramas"] = { Enabled = true, Mode = "NEED", NonNeedMode = "MANUAL" },
    },
    ItemRules = {
        ["zg bijous"] = true,
        ["zg coins"] = true,
        ["aq20 scarabs"] = true,
        ["aq20 idols"] = false,
        ["corrupted sand"] = true,
        ["wartorn cloth scrap"] = true,
        ["wartorn leather scrap"] = true,
        ["wartorn chain scrap"] = true,
        ["wartorn plate scrap"] = true,
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
    if AutoLazyDB.AutoConfirmBop == nil then AutoLazyDB.AutoConfirmBop = defaultDB.AutoConfirmBop end
    if AutoLazyDB.AnnounceChat == nil then AutoLazyDB.AnnounceChat = defaultDB.AnnounceChat end
    if AutoLazyDB.SelectedTab == nil then AutoLazyDB.SelectedTab = defaultDB.SelectedTab end
    if AutoLazyDB.ShowButton == nil then AutoLazyDB.ShowButton = defaultDB.ShowButton end
    if not AutoLazyDB.ButtonPos then AutoLazyDB.ButtonPos = {} end

    -- Cleanup legacy settings and removed dungeon/item records
    AutoLazyDB.FarmOnly = nil
    if AutoLazyDB.Dungeons then
        AutoLazyDB.Dungeons["Scholomance"] = nil
        AutoLazyDB.Dungeons["Stratholme"] = nil
        AutoLazyDB.Dungeons["Blackrock Depths"] = nil
    end
    if AutoLazyDB.ItemRules then
        AutoLazyDB.ItemRules["dark rune"] = nil
        AutoLazyDB.ItemRules["skin of shadow"] = nil
        AutoLazyDB.ItemRules["corruptor's scourgestone"] = nil
        AutoLazyDB.ItemRules["invader's scourgestone"] = nil
        AutoLazyDB.ItemRules["minion's scourgestone"] = nil
        AutoLazyDB.ItemRules["relic coffer key"] = nil
        AutoLazyDB.ItemRules["aq20 keys"] = nil
    end

    if not AutoLazyDB.Tweaks then AutoLazyDB.Tweaks = {} end
    if AutoLazyDB.Tweaks.HideRadio == nil then AutoLazyDB.Tweaks.HideRadio = defaultDB.Tweaks.HideRadio end
    if AutoLazyDB.Tweaks.HideLfg == nil then AutoLazyDB.Tweaks.HideLfg = defaultDB.Tweaks.HideLfg end
    if AutoLazyDB.Tweaks.CollapseAddons == nil then AutoLazyDB.Tweaks.CollapseAddons = defaultDB.Tweaks.CollapseAddons end

    if not AutoLazyDB.Dungeons then AutoLazyDB.Dungeons = {} end
    for _, def in ipairs(DungeonDefinitions) do
        if not AutoLazyDB.Dungeons[def.key] then
            AutoLazyDB.Dungeons[def.key] = { Enabled = true, Mode = def.defaultMode, NonNeedMode = "MANUAL" }
        else
            if AutoLazyDB.Dungeons[def.key].Enabled == nil then AutoLazyDB.Dungeons[def.key].Enabled = true end
            if not AutoLazyDB.Dungeons[def.key].Mode then AutoLazyDB.Dungeons[def.key].Mode = def.defaultMode end
            if not AutoLazyDB.Dungeons[def.key].NonNeedMode then AutoLazyDB.Dungeons[def.key].NonNeedMode = "MANUAL" end
        end
    end

    if not AutoLazyDB.ItemRules then AutoLazyDB.ItemRules = {} end
    for dKey, items in pairs(DungeonItems) do
        for _, itm in ipairs(items) do
            local ruleKey = itm.key or string.lower(itm.name)
            if AutoLazyDB.ItemRules[ruleKey] == nil then
                AutoLazyDB.ItemRules[ruleKey] = itm.defaultNeed
            end
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

function AutoLazy_GetItemRule(itemName)
    if not itemName or itemName == "" or not AutoLazyDB or not AutoLazyDB.ItemRules then
        return nil
    end
    local lower = string_lower(itemName)

    -- Direct specific item name match
    if AutoLazyDB.ItemRules[lower] ~= nil then
        return AutoLazyDB.ItemRules[lower]
    end

    -- Category lookups
    if string_find(lower, "bijou", 1, true) then
        return AutoLazyDB.ItemRules["zg bijous"]
    elseif string_find(lower, "coin", 1, true) and (string_find(lower, "zulian", 1, true) or string_find(lower, "razzashi", 1, true) or string_find(lower, "hakkari", 1, true) or string_find(lower, "sandfury", 1, true) or string_find(lower, "skullsplitter", 1, true) or string_find(lower, "bloodscalp", 1, true) or string_find(lower, "gurubashi", 1, true) or string_find(lower, "vilebranch", 1, true) or string_find(lower, "witherbark", 1, true)) then
        return AutoLazyDB.ItemRules["zg coins"]
    elseif string_find(lower, "scarab", 1, true) and not string_find(lower, "key", 1, true) then
        return AutoLazyDB.ItemRules["aq20 scarabs"]
    elseif string_find(lower, "idol", 1, true) and not BlacklistItems[lower] then
        return AutoLazyDB.ItemRules["aq20 idols"]
    elseif string_find(lower, "wartorn", 1, true) and string_find(lower, "scrap", 1, true) then
        if string_find(lower, "cloth", 1, true) then
            return AutoLazyDB.ItemRules["wartorn cloth scrap"]
        elseif string_find(lower, "leather", 1, true) then
            return AutoLazyDB.ItemRules["wartorn leather scrap"]
        elseif string_find(lower, "chain", 1, true) then
            return AutoLazyDB.ItemRules["wartorn chain scrap"]
        elseif string_find(lower, "plate", 1, true) then
            return AutoLazyDB.ItemRules["wartorn plate scrap"]
        end
    end

    return nil
end

local questSessionActive = false

local function ShouldAutoQuest()
    if not AutoLazyDB or not AutoLazyDB.Quests or not AutoLazyDB.Quests.Enabled then return false end
    if AutoLazyDB.Quests.AlwaysActive then return true end
    if questSessionActive then return true end
    return not not IsShiftKeyDown()
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

local function InspectRegionsIter(texKeywords, textKeywords, ...)
    local count = select("#", ...)
    for i = 1, count do
        local r = select(i, ...)
        if r then
            if texKeywords and r.GetTexture then
                local tex = r:GetTexture()
                if tex and type(tex) == "string" then
                    local lTex = string_lower(tex)
                    for k = 1, #texKeywords do
                        if string_find(lTex, texKeywords[k]) then return true end
                    end
                end
            end
            if textKeywords and r.GetText then
                local txt = r:GetText()
                if txt and type(txt) == "string" then
                    local lTxt = string_lower(txt)
                    for k = 1, #textKeywords do
                        if string_find(lTxt, textKeywords[k]) then return true end
                    end
                end
            end
        end
    end
    return false
end

local function MatchesFrameKeywords(f, nameKeywords, texKeywords, textKeywords)
    if not f then return false end
    local name = f:GetName()
    if name then
        if BlizzardCoreFrames[name] or string_find(name, "AutoLazy") then return false end
        local lName = string_lower(name)
        if string_find(lName, "zonetext") or string_find(lName, "toggle") or string_find(lName, "border") or
           string_find(lName, "backdrop") or string_find(lName, "cluster") then
            return false
        end
        if nameKeywords then
            for i = 1, #nameKeywords do
                if string_find(lName, nameKeywords[i]) then return true end
            end
        end
    end

    if texKeywords and f.GetNormalTexture then
        local norm = f:GetNormalTexture()
        if norm and norm.GetTexture then
            local tex = norm:GetTexture()
            if tex and type(tex) == "string" then
                local lTex = string_lower(tex)
                for i = 1, #texKeywords do
                    if string_find(lTex, texKeywords[i]) then return true end
                end
            end
        end
    end

    if (texKeywords or textKeywords) and f.GetRegions then
        if InspectRegionsIter(texKeywords, textKeywords, f:GetRegions()) then return true end
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
local ActiveButtonList = {}
local trayFrame
local actionBtn

local KNOWN_RADIO_FRAMES = {
    "RadioMinimapButton", "PirateRadioMinimapButton", "BBRadioMinimapButton",
    "BBPR_MinimapButton", "Radio_MinimapButton", "TWRadioMinimapButton",
    "TW_RadioMinimapButton", "TurtleRadioMinimapButton", "TWBBRadio",
    "TWBBRadioMinimapButton", "BBRadio_MinimapButton", "BootyBayRadio",
    "BootyBayRadioMinimapButton", "RadioIcon", "TW_RadioIcon", "RadioBtn", "TW_RadioBtn",
}

local KNOWN_LFG_FRAMES = {
    "TW_LFGBtn", "TWLFG_Minimap", "TWLFG_MinimapButton", "LFTMinimapButton",
    "LFT_MinimapButton", "MiniMapMeetingStoneFrame", "MiniMapLFGFrame",
    "LFGMinimapButton", "TurtleLFGMinimapButton", "GroupFinderMinimapButton",
}

local function ScanChildrenForBloat(hideRadio, hideLfg, ...)
    local count = select("#", ...)
    for i = 1, count do
        local child = select(i, ...)
        if child then
            local cName = child:GetName() or ""
            if not BlizzardCoreFrames[cName] then
                if IsRadioFrame(child) then
                    SetFrameSuppressed(child, hideRadio)
                elseif IsLfgFrame(child) then
                    SetFrameSuppressed(child, hideLfg)
                end
            end
        end
    end
end

function AutoLazy_ApplySystemIconToggles()
    if not AutoLazyDB or not AutoLazyDB.Tweaks then return end
    local hideRadio = (AutoLazyDB.Tweaks.HideRadio == true)
    local hideLfg   = (AutoLazyDB.Tweaks.HideLfg == true)

    for i = 1, #KNOWN_RADIO_FRAMES do
        local rf = getglobal(KNOWN_RADIO_FRAMES[i])
        if rf then SetFrameSuppressed(rf, hideRadio) end
    end

    for i = 1, #KNOWN_LFG_FRAMES do
        local lf = getglobal(KNOWN_LFG_FRAMES[i])
        if lf then SetFrameSuppressed(lf, hideLfg) end
    end

    if Minimap and Minimap.GetChildren then ScanChildrenForBloat(hideRadio, hideLfg, Minimap:GetChildren()) end
    if MinimapBackdrop and MinimapBackdrop.GetChildren then ScanChildrenForBloat(hideRadio, hideLfg, MinimapBackdrop:GetChildren()) end
    if MinimapCluster and MinimapCluster.GetChildren then ScanChildrenForBloat(hideRadio, hideLfg, MinimapCluster:GetChildren()) end
    if trayFrame and trayFrame.GetChildren then ScanChildrenForBloat(hideRadio, hideLfg, trayFrame:GetChildren()) end

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
local function InspectContentRegionsIter(...)
    local count = select("#", ...)
    for i = 1, count do
        local r1 = select(i, ...)
        if r1 then
            if r1.GetTexture then
                local tex = r1:GetTexture()
                if tex and type(tex) == "string" and tex ~= "" and not string_find(string_lower(tex), "tooltip") then
                    return true
                end
            end
            if r1.GetText then
                local txt = r1:GetText()
                if txt and type(txt) == "string" and txt ~= "" then return true end
            end
        end
    end
    return false
end

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
        if InspectContentRegionsIter(f:GetRegions()) then return true end
    end
    return false
end

local function IsValidAddonButton(f)
    if not f or not f:IsObjectType("Button") then return false end
    local name = f:GetName()
    if name then
        if BlizzardCoreFrames[name] or string_find(name, "AutoLazy") then return false end
        local lower = string_lower(name)
        if string_find(lower, "aura") or string_find(lower, "buff") or string_find(lower, "debuff") or
           string_find(lower, "cooldown") or string_find(lower, "combat") or string_find(lower, "action") or
           string_find(lower, "spell") or string_find(lower, "icon_") or string_find(lower, "condition") or
           string_find(lower, "close") or string_find(lower, "play") or string_find(lower, "targetframe") then
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

local EXPLICIT_ADDON_BUTTONS = {
    "AtlasLootMinimapButtonFrame", "AtlasLootMinimapButton", "pfQuestIcon", "DoiteAurasMinimapButton",
    "TrinketMenu_IconFrame", "BagnonMinimapButton", "AutoBG_QuickQueueButton", "TWThreatMinimapButton",
    "shootyepgpMinimapButton", "sepgpMinimapButton", "WIM3MinimapButton", "SuperAPIOptionsMinimapButton",
    "EasyPoisonsMinimapButton", "ModernMapMarkersMinimapButton", "ShaguDPSMinimapButton", "BigWigsMinimapButton",
}

local function RegisterAddonButton(f, isExplicit)
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
        table_insert(DiscoveredAddonList, f)
    end
end

local function ScanChildrenForAddons(...)
    local count = select("#", ...)
    for i = 1, count do
        local child = select(i, ...)
        if child and child:IsObjectType("Button") then
            RegisterAddonButton(child, false)
        end
    end
end

function AutoLazy_FindAddonButtons()
    for _, kName in ipairs(EXPLICIT_ADDON_BUTTONS) do
        local f = getglobal(kName)
        if f and HasRenderableVisual(f) then RegisterAddonButton(f, true) end
    end

    if Minimap and Minimap.GetChildren then ScanChildrenForAddons(Minimap:GetChildren()) end
    if MinimapBackdrop and MinimapBackdrop.GetChildren then ScanChildrenForAddons(MinimapBackdrop:GetChildren()) end
    if MinimapCluster and MinimapCluster.GetChildren then ScanChildrenForAddons(MinimapCluster:GetChildren()) end
    if trayFrame and trayFrame.GetChildren then ScanChildrenForAddons(trayFrame:GetChildren()) end

    table_wipe(ActiveButtonList)
    for _, btn in ipairs(DiscoveredAddonList) do
        if HasRenderableVisual(btn) then
            local isSuppressed = false
            if AutoLazyDB and AutoLazyDB.Tweaks then
                if AutoLazyDB.Tweaks.HideRadio and IsRadioFrame(btn) then isSuppressed = true; SetFrameSuppressed(btn, true)
                elseif AutoLazyDB.Tweaks.HideLfg and IsLfgFrame(btn) then isSuppressed = true; SetFrameSuppressed(btn, true) end
            end
            if not isSuppressed then table_insert(ActiveButtonList, btn) end
        end
    end
    return ActiveButtonList
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

-- Allow dismissing with ESC key
table_insert(UISpecialFrames, "AutoLazy_ButtonTray")
trayFrame:SetScript("OnHide", function()
    AutoLazy_CloseTray()
end)

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

actionBtn:SetScript("OnDragStart", function() actionBtn:StartMoving() end)
actionBtn:SetScript("OnDragStop", function()
    actionBtn:StopMovingOrSizing()
    if AutoLazyDB then
        AutoLazyDB.ButtonPos = AutoLazyDB.ButtonPos or {}
        AutoLazyDB.ButtonPos.x = actionBtn:GetLeft()
        AutoLazyDB.ButtonPos.y = actionBtn:GetBottom()
    end
end)

actionBtn:SetScript("OnClick", function(self, btn)
    local clickBtn = btn or arg1
    if clickBtn == "RightButton" then AutoLazy_ToggleGUI() else AutoLazy_ToggleTray() end
end)

actionBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(actionBtn, "ANCHOR_LEFT")
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
    local bopStatus = AutoLazyDB.AutoConfirmBop and "|cFF00FF00ON|r" or "|cFFFF2020OFF|r"
    local questMode = (AutoLazyDB.Quests and AutoLazyDB.Quests.AlwaysActive) and "Always" or "Shift-Click"
    local questStatus = (AutoLazyDB.Quests and AutoLazyDB.Quests.Enabled) and ("|cFF00FF00ON (" .. questMode .. ")|r") or "|cFFFF2020OFF|r"
    AutoLazy_Print("Dungeon Auto-Loot: " .. masterStatus .. " | BoP: " .. bopStatus .. " | Quests: " .. questStatus)

    local currentZone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "Unknown"
    if CachedDungeonKey and CachedDungeonCfg and CachedDungeonCfg.Enabled then
        local nonNeed = CachedDungeonCfg.NonNeedMode or "MANUAL"
        AutoLazy_Print("Current Zone: |cFF00FF00" .. currentZone .. "|r (Active: " .. (CachedDungeonDef and CachedDungeonDef.title or CachedDungeonKey) .. " | Non-Need: |cFFFFD100" .. nonNeed .. "|r)")
    else
        AutoLazy_Print("Current Zone: |cFFFF8080" .. currentZone .. "|r (Auto-Loot inactive here)")
    end
end

local STATIC_POPUPS = { StaticPopup1, StaticPopup2, StaticPopup3, StaticPopup4 }

local function DismissConfirmPopups(rollId)
    if rollId and StaticPopup_Hide then StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollId) end
    if StaticPopup_Hide then StaticPopup_Hide("CONFIRM_LOOT_ROLL") end
    for i = 1, 4 do
        local popup = STATIC_POPUPS[i] or getglobal("StaticPopup" .. i)
        if popup and popup:IsShown() and popup.which == "CONFIRM_LOOT_ROLL" then popup:Hide() end
    end
end

local RepeatableTurnIns = {
    -- Argent Dawn (Scourgestones, Materials, Writs)
    { quest = "minion", item = "minion's scourgestone", minCount = 20 },
    { quest = "invader", item = "invader's scourgestone", minCount = 10 },
    { quest = "corruptor", item = "corruptor's scourgestone", minCount = 5 },
    { quest = "healthy dragon scale", item = "healthy dragon scale", minCount = 1 },
    { quest = "bone fragments", item = "bone fragments", minCount = 30 },
    { quest = "crypt fiend parts", item = "crypt fiend parts", minCount = 30 },
    { quest = "core of elements", item = "core of elements", minCount = 30 },
    { quest = "savage frond", item = "savage frond", minCount = 30 },
    { quest = "somber hourglass", item = "somber hourglass", minCount = 30 },
    { quest = "dark rune", item = "dark rune", minCount = 1 },
    { quest = "craftsman", item = "craftsman's writ", minCount = 1 },

    -- Winterspring E'ko (Witch Doctor Mau'ari)
    { quest = "winterfall e'ko", item = "winterfall e'ko", minCount = 10 },
    { quest = "frostmaul e'ko", item = "frostmaul e'ko", minCount = 10 },
    { quest = "shardtooth e'ko", item = "shardtooth e'ko", minCount = 10 },
    { quest = "frostsaber e'ko", item = "frostsaber e'ko", minCount = 10 },
    { quest = "wildkin e'ko", item = "wildkin e'ko", minCount = 10 },
    { quest = "chillwind e'ko", item = "chillwind e'ko", minCount = 10 },
    { quest = "ice thistle e'ko", item = "ice thistle e'ko", minCount = 10 },

    -- Thorium Brotherhood
    { quest = "dark iron residue", item = "dark iron residue", minCount = 4 },
    { quest = "dark iron ore", item = "dark iron ore", minCount = 10 },
    { quest = "restoring fiery flux via heavy leather", item = "heavy leather", minCount = 2 },
    { quest = "restoring fiery flux via iron", item = "iron bar", minCount = 4 },
    { quest = "restoring fiery flux via coal", item = "coal", minCount = 1 },
    { quest = "restoring fiery flux via incendosaur scale", item = "incendosaur scale", minCount = 2 },
    { quest = "fiery core", item = "fiery core", minCount = 1 },
    { quest = "lava core", item = "lava core", minCount = 1 },
    { quest = "blood of the mountain", item = "blood of the mountain", minCount = 1 },
    { quest = "core leather", item = "core leather", minCount = 2 },

    -- Cenarion Circle (Silithus)
    { quest = "encrypted twilight text", item = "encrypted twilight text", minCount = 10 },
    { quest = "secret communication", item = "encrypted twilight text", minCount = 10 },
    { quest = "abyssal crest", item = "abyssal crest", minCount = 3 },
    { quest = "abyssal signet", item = "abyssal signet", minCount = 3 },
    { quest = "abyssal scepter", item = "abyssal scepter", minCount = 3 },

    -- Timbermaw Hold
    { quest = "deadwood headdress feather", item = "deadwood headdress feather", minCount = 5 },
    { quest = "winterfall spirit bead", item = "winterfall spirit beads", minCount = 5 },
    { quest = "water elemental core", item = "water elemental core", minCount = 1 },

    -- Zandalar Tribe / Zul'Gurub
    { quest = "zulian", item = "zulian coin", minCount = 1 },
    { quest = "sandfury", item = "sandfury coin", minCount = 1 },
    { quest = "gurubashi", item = "gurubashi coin", minCount = 1 },
    { quest = "hakkari bijou", item = "bijou", minCount = 1 },

    -- Un'Goro Crater
    { quest = "morrowgrain", item = "morrowgrain", minCount = 10 },
    { quest = "bloodpetal", item = "bloodpetal sprout", minCount = 15 },

    -- Cloth Donations
    { quest = "runecloth", item = "runecloth", minCount = 20 },

    -- Alterac Valley
    { quest = "armor scrap", item = "armor scraps", minCount = 20 },
    { quest = "soldier's blood", item = "soldier's blood", minCount = 5 },
    { quest = "soldiers blood", item = "soldiers blood", minCount = 5 },
    { quest = "lieutenant's flesh", item = "lieutenant's flesh", minCount = 1 },
    { quest = "ram hide", item = "alterac ram hide", minCount = 20 },
    { quest = "frostwolf hide", item = "frostwolf hide", minCount = 20 },
    { quest = "irondeep supplies", item = "irondeep supplies", minCount = 10 },
    { quest = "coldtooth supplies", item = "coldtooth supplies", minCount = 10 },

    -- Custom / World
    { quest = "tel'abim banana", item = "tel'abim banana", minCount = 5 },
    { quest = "telabim banana", item = "tel'abim banana", minCount = 5 },
    { quest = "bloodfang tail", item = "bloodfang tail", minCount = 5 },
}

local GossipTurnInKeywords = {
    -- Lokhtos Darkbargainer (BRD)
    { match = "dark iron residue", item = "dark iron residue", minCount = 4 },
    { match = "dark iron ore", item = "dark iron ore", minCount = 10 },
    { match = "blood of the mountain", item = "blood of the mountain", minCount = 1 },
    { match = "fiery core", item = "fiery core", minCount = 1 },
    { match = "lava core", item = "lava core", minCount = 1 },
    { match = "core leather", item = "core leather", minCount = 2 },

    -- Altar of Zanza (ZG Bijou destruction)
    { match = "red hakkari bijou", item = "red hakkari bijou", minCount = 1 },
    { match = "blue hakkari bijou", item = "blue hakkari bijou", minCount = 1 },
    { match = "yellow hakkari bijou", item = "yellow hakkari bijou", minCount = 1 },
    { match = "orange hakkari bijou", item = "orange hakkari bijou", minCount = 1 },
    { match = "green hakkari bijou", item = "green hakkari bijou", minCount = 1 },
    { match = "purple hakkari bijou", item = "purple hakkari bijou", minCount = 1 },
    { match = "bronze hakkari bijou", item = "bronze hakkari bijou", minCount = 1 },
    { match = "silver hakkari bijou", item = "silver hakkari bijou", minCount = 1 },
    { match = "gold hakkari bijou", item = "gold hakkari bijou", minCount = 1 },
    { match = "destroy", item = "bijou", minCount = 1 },

    -- Alterac Valley
    { match = "armor scrap", item = "armor scraps", minCount = 20 },
    { match = "soldier's blood", item = "soldier's blood", minCount = 5 },
    { match = "soldiers blood", item = "soldiers blood", minCount = 5 },
    { match = "lieutenant's flesh", item = "lieutenant's flesh", minCount = 1 },

    -- Submenu Openers
    { match = "scourgestone", opener = true },
    { match = "twilight text", opener = true },
    { match = "craftsman's writ", opener = true },
    { match = "turn in", opener = true },
}

local function GetPlayerItemCount(targetItem)
    if not targetItem or targetItem == "" then return 0 end
    if GetItemCount then
        return GetItemCount(targetItem) or 0
    end
    local targetLower = string_lower(targetItem)
    local total = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, _, name = string_find(link, "%[(.+)%]")
                    if name and string_find(string_lower(name), targetLower, 1, true) then
                        local _, count = GetContainerItemInfo(bag, slot)
                        total = total + (count or 1)
                    end
                end
            end
        end
    end
    return total
end

local function MatchesRepeatableRequirement(title)
    if not title or title == "" then return false end
    local lowerTitle = string.lower(title)
    for _, rep in ipairs(RepeatableTurnIns) do
        if string.find(lowerTitle, rep.quest, 1, true) then
            local count = GetPlayerItemCount(rep.item)
            if count >= rep.minCount then
                return true, rep
            end
        end
    end
    return false
end

local function MatchesGossipTurnIn(text)
    if not text or text == "" then return false end
    local lowerText = string.lower(text)
    for _, g in ipairs(GossipTurnInKeywords) do
        if string.find(lowerText, g.match, 1, true) then
            if g.opener then
                return true
            elseif g.item then
                local count = GetPlayerItemCount(g.item)
                if count >= (g.minCount or 1) then
                    return true
                end
            end
        end
    end
    return false
end

local function ProcessGossip()
    if not ShouldAutoQuest() then return false end

    -- 1. Try ClassicAPI C_GossipInfo (Native C++ Modern API)
    if C_GossipInfo and C_GossipInfo.GetActiveQuests and C_GossipInfo.SelectActiveQuest then
        if AutoLazyDB.Quests.AutoTurnIn then
            local active = C_GossipInfo.GetActiveQuests()
            if active and #active > 0 then
                -- Priority 1: Priority to explicitly completed quests (e.g. Winterfall E'ko, Scourgestones)
                for i = 1, #active do
                    local q = active[i]
                    if q and q.questID and q.isComplete then
                        C_GossipInfo.SelectActiveQuest(q.questID)
                        return true
                    end
                end
                -- Priority 2: Exactly 1 quest offered and not incomplete
                if #active == 1 and active[1] and active[1].questID and active[1].isComplete ~= false then
                    C_GossipInfo.SelectActiveQuest(active[1].questID)
                    return true
                end
            end

            -- Priority 3: Direct Gossip Turn-Ins (e.g. Altar of Zanza Bijous, Lokhtos Dark Iron, AV Scraps)
            if C_GossipInfo.GetOptions and (C_GossipInfo.SelectOption or SelectGossipOption) then
                local options = C_GossipInfo.GetOptions()
                if options and #options > 0 then
                    for i = 1, #options do
                        local opt = options[i]
                        local optName = opt.name or opt.title
                        if optName and MatchesGossipTurnIn(optName) then
                            if C_GossipInfo.SelectOption and opt.gossipOptionID then
                                C_GossipInfo.SelectOption(opt.gossipOptionID)
                            else
                                SelectGossipOption(i)
                            end
                            return true
                        end
                    end
                end
            end
        end

        if AutoLazyDB.Quests.AutoAccept and C_GossipInfo.GetAvailableQuests and C_GossipInfo.SelectAvailableQuest then
            local avail = C_GossipInfo.GetAvailableQuests()
            if avail and #avail > 0 then
                -- Priority 1: Repeatable turn-ins matching player inventory in bags (ignores isTrivial)
                for i = 1, #avail do
                    local q = avail[i]
                    if q and q.questID and q.title and MatchesRepeatableRequirement(q.title) then
                        C_GossipInfo.SelectAvailableQuest(q.questID)
                        return true
                    end
                end
                -- Priority 2: Non-trivial available quests
                for i = 1, #avail do
                    local q = avail[i]
                    if q and q.questID and not q.isTrivial then
                        C_GossipInfo.SelectAvailableQuest(q.questID)
                        return true
                    end
                end
                -- Priority 3: Fallback to first offered available quest
                if avail[1] and avail[1].questID then
                    C_GossipInfo.SelectAvailableQuest(avail[1].questID)
                    return true
                end
            end
        end

    -- 2. Fallback to Vanilla 1.12.1 Gossip APIs
    else
        if AutoLazyDB.Quests.AutoTurnIn and GetGossipActiveQuests and SelectGossipActiveQuest then
            local activeQuests = { GetGossipActiveQuests() }
            local numActive = (GetNumGossipActiveQuests and GetNumGossipActiveQuests()) or 0
            if numActive == 0 and #activeQuests > 0 then
                numActive = math.floor(#activeQuests / 4)
            end
            if numActive > 0 then
                for k = 1, numActive do
                    local base = (k - 1) * 4
                    local title = activeQuests[base + 1]
                    local isComplete = activeQuests[base + 4]
                    if title and isComplete then
                        SelectGossipActiveQuest(k)
                        return true
                    end
                end
                if numActive == 1 and activeQuests[1] then
                    SelectGossipActiveQuest(1)
                    return true
                end
            end

            -- Direct Gossip Turn-Ins (Vanilla Fallback)
            if GetGossipOptions and SelectGossipOption then
                local gOptions = { GetGossipOptions() }
                local numG = (GetNumGossipOptions and GetNumGossipOptions()) or 0
                if numG == 0 and #gOptions > 0 then
                    numG = math.floor(#gOptions / 2)
                end
                if numG > 0 then
                    for k = 1, numG do
                        local text = gOptions[(k - 1) * 2 + 1]
                        if text and MatchesGossipTurnIn(text) then
                            SelectGossipOption(k)
                            return true
                        end
                    end
                end
            end
        end

        if AutoLazyDB.Quests.AutoAccept and GetGossipAvailableQuests and SelectGossipAvailableQuest then
            local availQuests = { GetGossipAvailableQuests() }
            local numAvail = (GetNumGossipAvailableQuests and GetNumGossipAvailableQuests()) or 0
            if numAvail == 0 and #availQuests > 0 then
                numAvail = math.floor(#availQuests / 3)
            end
            if numAvail > 0 then
                -- Priority 1: Repeatable turn-ins matching player inventory
                for k = 1, numAvail do
                    local base = (k - 1) * 3
                    local title = availQuests[base + 1]
                    if title and MatchesRepeatableRequirement(title) then
                        SelectGossipAvailableQuest(k)
                        return true
                    end
                end
                -- Priority 2: Non-trivial available quests
                for k = 1, numAvail do
                    local base = (k - 1) * 3
                    local title = availQuests[base + 1]
                    local isTrivial = availQuests[base + 3]
                    if title and not isTrivial then
                        SelectGossipAvailableQuest(k)
                        return true
                    end
                end
                -- Priority 3: Fallback
                SelectGossipAvailableQuest(1)
                return true
            end
        end
    end

    return false
end

local function ProcessGreeting()
    if not ShouldAutoQuest() then return false end

    if AutoLazyDB.Quests.AutoTurnIn and GetNumActiveQuests and GetActiveTitle and SelectActiveQuest then
        local numActive = GetNumActiveQuests()
        if numActive and numActive > 0 then
            for i = 1, numActive do
                local title, isComplete = GetActiveTitle(i)
                if isComplete then
                    SelectActiveQuest(i)
                    return true
                end
            end
            if numActive == 1 then
                SelectActiveQuest(1)
                return true
            end
        end
    end

    if AutoLazyDB.Quests.AutoAccept and GetNumAvailableQuests and SelectAvailableQuest then
        local numAvail = GetNumAvailableQuests()
        if numAvail and numAvail > 0 then
            -- Priority 1: Repeatable matching bag inventory
            if GetAvailableTitle then
                for i = 1, numAvail do
                    local title = GetAvailableTitle(i)
                    if title and MatchesRepeatableRequirement(title) then
                        SelectAvailableQuest(i)
                        return true
                    end
                end
            end
            -- Priority 2: Select first available quest
            SelectAvailableQuest(1)
            return true
        end
    end

    return false
end

local function DelayedStartupSync()
    AutoLazy_ApplySystemIconToggles()
    if AutoLazy_CollapseAddons then AutoLazy_CollapseAddons() end
end

local function TryQuestChain()
    if GossipFrame and GossipFrame:IsShown() then
        ProcessGossip()
    elseif QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown() then
        ProcessGreeting()
    else
        questSessionActive = false
    end
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
EventFrame:RegisterEvent("GOSSIP_CLOSED")
EventFrame:RegisterEvent("QUEST_GREETING")
EventFrame:RegisterEvent("QUEST_DETAIL")
EventFrame:RegisterEvent("QUEST_PROGRESS")
EventFrame:RegisterEvent("QUEST_COMPLETE")
EventFrame:RegisterEvent("QUEST_FINISHED")

EventFrame:SetScript("OnEvent", function(self, ev_arg, a1_arg, a2_arg)
    local ev = ev_arg or event
    local a1 = a1_arg or arg1
    local a2 = a2_arg or arg2

    if (ev == "ADDON_LOADED" and a1 == addonName) or ev == "VARIABLES_LOADED" then
        InitDB()
        UpdateZoneCache()
        AutoLazy_UpdateActionButton()
        AutoLazy_ApplySystemIconToggles()
        AutoLazy_CollapseAddons()

        -- Native C++ Hardware Timers (Zero OnUpdate startup bloat)
        C_Timer.After(1.0, DelayedStartupSync)
        C_Timer.After(2.5, DelayedStartupSync)

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

        -- Strict Gate: AutoLazy ONLY rolls on the explicitly configured tedious items
        local autoNeed = AutoLazy_GetItemRule(name)
        if autoNeed == nil then
            return
        end

        local rollType = nil
        local actionName = nil

        if autoNeed == true then
            rollType = LOOT_ROLL_NEED
            actionName = "|cFFFF8000Need|r"
        else
            local nonNeedMode = CachedDungeonCfg.NonNeedMode or "MANUAL"
            if nonNeedMode == "GREED" then
                rollType = LOOT_ROLL_GREED
                actionName = "|cFF00FF00Greed|r"
            elseif nonNeedMode == "PASS" then
                rollType = LOOT_ROLL_PASS
                actionName = "|cFF808080Passed|r"
            else
                -- MANUAL (Skip): Leave the loot roll on screen for manual player choice
                return
            end
        end

        if rollType ~= nil then
            RollOnLoot(rollId, rollType)
            if AutoLazyDB.AnnounceChat then
                AutoLazy_Print(actionName .. " on " .. itemLink .. " (" .. (CachedDungeonDef and CachedDungeonDef.title or CachedDungeonKey) .. ")")
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
                local popup = STATIC_POPUPS[i] or getglobal("StaticPopup" .. i)
                if popup and popup:IsShown() and popup.which == "LOOT_BIND" then popup:Hide() end
            end
        end

    -- Continuous Shift+Click Quest Handlers
    elseif ev == "GOSSIP_SHOW" then
        if AutoLazyDB and AutoLazyDB.Quests and AutoLazyDB.Quests.Enabled then
            if AutoLazyDB.Quests.AlwaysActive or IsShiftKeyDown() then
                questSessionActive = true
            end
        end
        ProcessGossip()

    elseif ev == "GOSSIP_CLOSED" then
        questSessionActive = false

    elseif ev == "QUEST_GREETING" then
        if AutoLazyDB and AutoLazyDB.Quests and AutoLazyDB.Quests.Enabled then
            if AutoLazyDB.Quests.AlwaysActive or IsShiftKeyDown() then
                questSessionActive = true
            end
        end
        ProcessGreeting()

    elseif ev == "QUEST_DETAIL" then
        if ShouldAutoQuest() and AutoLazyDB.Quests.AutoAccept then AcceptQuest() end

    elseif ev == "QUEST_PROGRESS" then
        if ShouldAutoQuest() and AutoLazyDB.Quests.AutoTurnIn and IsQuestCompletable() then CompleteQuest() end

    elseif ev == "QUEST_COMPLETE" then
        if ShouldAutoQuest() and AutoLazyDB.Quests.AutoTurnIn then
            local choices = GetNumQuestChoices()
            if not choices or choices == 0 then
                GetQuestReward()
            elseif choices == 1 then
                GetQuestReward(1)
            elseif not AutoLazyDB.Quests.SafeRewards then
                GetQuestReward(1)
            else
                AutoLazy_Print("Quest ready for turn-in: Please choose your reward manually.")
            end
        end

    elseif ev == "QUEST_FINISHED" then
        -- Fast chain-trigger for repeatable turn-ins (e.g. E'ko, Scourgestones, Bijous, Dark Iron Residue)
        if ShouldAutoQuest() then
            C_Timer.After(0.05, TryQuestChain)
            C_Timer.After(0.15, TryQuestChain)
        else
            questSessionActive = false
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

    quest = function()
        AutoLazyDB.Quests.Enabled = not AutoLazyDB.Quests.Enabled
        local questMode = AutoLazyDB.Quests.AlwaysActive and "Always Active" or "Shift-Click"
        AutoLazy_Print("Quest Automation: " .. (AutoLazyDB.Quests.Enabled and ("|cFF00FF00ENABLED (" .. questMode .. ")|r") or "|cFFFF2020DISABLED|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    turnin = function()
        AutoLazyDB.Quests.AutoTurnIn = not AutoLazyDB.Quests.AutoTurnIn
        AutoLazy_Print("Auto Turn-In: " .. (AutoLazyDB.Quests.AutoTurnIn and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    accept = function()
        AutoLazyDB.Quests.AutoAccept = not AutoLazyDB.Quests.AutoAccept
        AutoLazy_Print("Auto Accept: " .. (AutoLazyDB.Quests.AutoAccept and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    always = function()
        AutoLazyDB.Quests.AlwaysActive = not AutoLazyDB.Quests.AlwaysActive
        AutoLazy_Print("Always Active (No Shift): " .. (AutoLazyDB.Quests.AlwaysActive and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED (Requires Shift)|r"))
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
    local _, _, cmd = string_find(msg or "", "^%s*(%S+)%s*(.-)$")
    cmd = string_lower(cmd or "")

    if slashToggles[cmd] then
        slashToggles[cmd]()
    elseif cmd == "" or cmd == "gui" or cmd == "menu" or cmd == "config" or cmd == "options" then
        if AutoLazy_ToggleGUI then AutoLazy_ToggleGUI() else AutoLazy_PrintStatus() end
    else
        AutoLazy_Print("Commands: /al, /al tray, /al collapse, /al resetpos, /al btn, /al radio, /al lfg, /al toggle, /al quest, /al turnin, /al accept, /al always, /al status")
    end
end
