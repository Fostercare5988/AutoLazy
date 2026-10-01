--[[
    AutoLazy v3.7.0
    Author & Maintainer: Fostercare5988
    Target: World of Warcraft 1.12.1 (Vanilla Enhanced Stack: ClassicAPI v1.15.15+)
    Description: High-performance dungeon loot automation, continuous repeatable quest turn-ins, Floating Addon Tray, and Reversible System Bloat Suppression.
]]

-- Strict Engine Dependency Guard (Mandatory ClassicAPI v1.15.15+)
local MIN_CLASSIC_API = 11515

if type(CLASSIC_API_VERSION) ~= "number" or CLASSIC_API_VERSION < MIN_CLASSIC_API then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[AutoLazy Fatal Error]|r AutoLazy requires ClassicAPI (v1.15.15+)! Please ensure ClassicAPI.dll is loaded.", 1, 0.2, 0.2)
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
    },
    {
        key = "Zul'Gurub",
        title = "Zul'Gurub",
        itemDesc = "Coins & Bijous",
        aliases = { "zul'gurub", "zulgurub", "zg" },
    },
    {
        key = "Ruins of Ahn'Qiraj",
        title = "Ruins of Ahn'Qiraj",
        itemDesc = "Scarabs & Idols",
        aliases = { "ruins of ahn'qiraj", "ahn'qiraj ruins", "aq20", "ruins of ahnqiraj" },
    },
    {
        key = "Naxxramas",
        title = "Naxxramas",
        itemDesc = "Wartorn Scraps",
        aliases = { "naxxramas", "naxx" },
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

-- Hash Table of recognized Farm Items (Normalized lowercase -> Category Tag)
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
    ["dark iron scraps"]          = "Argent Dawn",
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
}

-- Hash Table of Explicitly Blacklisted Items
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
    CleanRollChat = true,
    SelectedTab = 1,
    ShowButton = true,
    ButtonPos = { x = nil, y = nil },
    Tweaks = {
        HideRadio = true,
        HideLfg   = true,
        CollapseAddons = true,
    },
    ItemRules = {
        ["zg bijous"] = "NEED",
        ["zg coins"] = "NEED",
        ["aq20 scarabs"] = "NEED",
        ["aq20 idols"] = "MANUAL",
        ["corrupted sand"] = "NEED",
        ["wartorn cloth scrap"] = "NEED",
        ["wartorn leather scrap"] = "NEED",
        ["wartorn chain scrap"] = "NEED",
        ["wartorn plate scrap"] = "NEED",
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
    if AutoLazyDB.CleanRollChat == nil then AutoLazyDB.CleanRollChat = defaultDB.CleanRollChat end
    if AutoLazyDB.SelectedTab == nil then AutoLazyDB.SelectedTab = defaultDB.SelectedTab end
    if AutoLazyDB.ShowButton == nil then AutoLazyDB.ShowButton = defaultDB.ShowButton end
    if not AutoLazyDB.ButtonPos then AutoLazyDB.ButtonPos = {} end

    -- Purge obsolete config keys
    AutoLazyDB.AnnounceChat = nil
    AutoLazyDB.CleanLoot = nil
    AutoLazyDB.FarmOnly = nil

    if not AutoLazyDB.Tweaks then AutoLazyDB.Tweaks = {} end
    if AutoLazyDB.Tweaks.HideRadio == nil then AutoLazyDB.Tweaks.HideRadio = defaultDB.Tweaks.HideRadio end
    if AutoLazyDB.Tweaks.HideLfg == nil then AutoLazyDB.Tweaks.HideLfg = defaultDB.Tweaks.HideLfg end
    if AutoLazyDB.Tweaks.CollapseAddons == nil then AutoLazyDB.Tweaks.CollapseAddons = defaultDB.Tweaks.CollapseAddons end

    if not AutoLazyDB.ItemRules then AutoLazyDB.ItemRules = {} end
    for ruleKey in pairs(AutoLazyDB.ItemRules) do
        if defaultDB.ItemRules[ruleKey] == nil then AutoLazyDB.ItemRules[ruleKey] = nil end
    end
    local migratingLootRules = AutoLazyDB.LootRulesVersion ~= 2
    for dKey, items in pairs(DungeonItems) do
        local oldDungeon = AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[dKey]
        local oldFallback = oldDungeon and oldDungeon.NonNeedMode or "MANUAL"
        if oldFallback ~= "GREED" and oldFallback ~= "PASS" then oldFallback = "MANUAL" end
        local wasDisabled = oldDungeon and (oldDungeon.Enabled == false or oldDungeon.Mode == "OFF")
        for _, itm in ipairs(items) do
            local ruleKey = itm.key or string.lower(itm.name)
            local action = AutoLazyDB.ItemRules[ruleKey]
            if migratingLootRules then
                if wasDisabled then
                    action = "MANUAL"
                elseif action == true then
                    action = "NEED"
                elseif action == false then
                    action = oldFallback
                end
            end
            if action ~= "MANUAL" and action ~= "NEED" and action ~= "GREED" and action ~= "PASS" then
                action = defaultDB.ItemRules[ruleKey]
            end
            AutoLazyDB.ItemRules[ruleKey] = action
        end
    end
    AutoLazyDB.Dungeons = nil
    AutoLazyDB.LootRulesVersion = 2

    if not AutoLazyDB.Quests then AutoLazyDB.Quests = {} end
    for qk, qv in pairs(defaultDB.Quests) do
        if AutoLazyDB.Quests[qk] == nil then AutoLazyDB.Quests[qk] = qv end
    end
end

local function MatchDungeonKey(zoneText)
    if not zoneText or zoneText == "" then return nil, nil end
    local norm = string.lower(zoneText)

    for _, def in ipairs(DungeonDefinitions) do
        local normKey = string.lower(def.key)
        if norm == normKey or string.find(norm, normKey, 1, true) or string.find(normKey, norm, 1, true) then
            return def.key, def
        end
        for _, alias in ipairs(def.aliases) do
            if norm == alias or string.find(norm, alias, 1, true) or string.find(alias, norm, 1, true) then
                return def.key, def
            end
        end
    end
    return nil, nil
end

function AutoLazy_ResolveCurrentDungeon()
    if not AutoLazyDB then return nil, nil end
    local rz = (GetRealZoneText and GetRealZoneText()) or ""
    local z  = (GetZoneText and GetZoneText()) or ""
    local sz = (GetSubZoneText and GetSubZoneText()) or ""
    local mz = (GetMinimapZoneText and GetMinimapZoneText()) or ""

    local key, def = MatchDungeonKey(rz)
    if key then return key, def end
    key, def = MatchDungeonKey(z)
    if key then return key, def end
    key, def = MatchDungeonKey(sz)
    if key then return key, def end
    key, def = MatchDungeonKey(mz)
    if key then return key, def end
    return nil, nil
end

local function UpdateZoneCache()
    local prevKey = CachedDungeonKey
    CachedDungeonKey, CachedDungeonDef = AutoLazy_ResolveCurrentDungeon()
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
    if BlacklistItems[lower] then return nil end

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
local currentQuestSessionToken = 0
local activeNpcGUID = nil

local function ShouldAutoQuest()
    if not AutoLazyDB or not AutoLazyDB.Quests or not AutoLazyDB.Quests.Enabled then return false end
    if AutoLazyDB.Quests.AlwaysActive then return true end
    if questSessionActive then return true end
    return (IsShiftKeyDown and IsShiftKeyDown()) and true or false
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
        if AutoLazyDB and AutoLazyDB.Tweaks and AutoLazyDB.Tweaks.CollapseAddons == false then
            AutoLazy_CollapseAddons(false)
        else
            for _, btn in ipairs(DiscoveredAddonList) do
                if btn and btn.Hide then btn:Hide() end
            end
            trayFrame:Hide()
        end
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
if actionBtn.SetClampedToScreen then actionBtn:SetClampedToScreen(true) end

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
    local cleanRollStatus = AutoLazyDB.CleanRollChat and "|cFF00FF00ON|r" or "|cFFFF2020OFF|r"
    local questMode = (AutoLazyDB.Quests and AutoLazyDB.Quests.AlwaysActive) and "Always" or "Shift-Click"
    local questStatus = (AutoLazyDB.Quests and AutoLazyDB.Quests.Enabled) and ("|cFF00FF00ON (" .. questMode .. ")|r") or "|cFFFF2020OFF|r"
    AutoLazy_Print("Listed item auto-roll: " .. masterStatus .. " | BoP confirmation: " .. bopStatus .. " | Clean Roll: " .. cleanRollStatus .. " | Quests: " .. questStatus)

    local currentZone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "Unknown"
    if CachedDungeonKey then
        AutoLazy_Print("Current Zone: |cFF00FF00" .. currentZone .. "|r (Listed items: " .. (CachedDungeonDef and CachedDungeonDef.title or CachedDungeonKey) .. ")")
    else
        AutoLazy_Print("Current Zone: |cFFFF8080" .. currentZone .. "|r (No listed items here)")
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

--------------------------------------------------------------------------------
-- Clean Group Loot Roll Presentation
--------------------------------------------------------------------------------

local ROLL_FORMAT_KEYS = {
    "LOOT_ROLL_START",
    "LOOT_ROLL_NEED",
    "LOOT_ROLL_NEED_SELF",
    "LOOT_ROLL_GREED",
    "LOOT_ROLL_GREED_SELF",
    "LOOT_ROLL_PASSED",
    "LOOT_ROLL_PASSED_SELF",
    "LOOT_ROLL_ROLLED",
    "LOOT_ROLL_ROLLED_SELF",
    "LOOT_ROLL_ROLLED_NEED",
    "LOOT_ROLL_ROLLED_NEED_SELF",
    "LOOT_ROLL_ROLLED_GREED",
    "LOOT_ROLL_ROLLED_GREED_SELF",
    "LOOT_ROLL_ALL_PASSED",
}

local suppressedLootPatterns = nil

local function FormatToPattern(fmt)
    if not fmt or type(fmt) ~= "string" then return nil end
    local p = string.gsub(fmt, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = string.gsub(p, "%%%d+%$s", ".+")
    p = string.gsub(p, "%%%d+%$d", "%%d+")
    p = string.gsub(p, "%%s", ".+")
    p = string.gsub(p, "%%d", "%%d+")
    return "^" .. p .. "$"
end

local function InitLootChatPatterns()
    if suppressedLootPatterns then return end
    suppressedLootPatterns = {}
    for i = 1, #ROLL_FORMAT_KEYS do
        local key = ROLL_FORMAT_KEYS[i]
        local fmt = getglobal(key)
        if fmt and type(fmt) == "string" then
            local pat = FormatToPattern(fmt)
            if pat then
                table_insert(suppressedLootPatterns, pat)
            end
        end
    end
end

local function ShouldSuppressLootMessage(msg)
    if not AutoLazyDB or not AutoLazyDB.CleanRollChat then return false end
    if not msg or type(msg) ~= "string" then return false end
    if not suppressedLootPatterns then InitLootChatPatterns() end
    for i = 1, #suppressedLootPatterns do
        if string_find(msg, suppressedLootPatterns[i]) then
            return true
        end
    end
    return false
end

local orig_ChatFrame_OnEvent = nil
local function HookChatFrameEvents()
    if orig_ChatFrame_OnEvent then return end
    if type(ChatFrame_OnEvent) ~= "function" then return end
    orig_ChatFrame_OnEvent = ChatFrame_OnEvent
    ChatFrame_OnEvent = function(event)
        if event == "CHAT_MSG_LOOT" and arg1 then
            if ShouldSuppressLootMessage(arg1) then
                return
            end
        end
        return orig_ChatFrame_OnEvent(event)
    end
end

AutoLazy.ShouldSuppressLootMessage = ShouldSuppressLootMessage
AutoLazy.InitLootChatPatterns = InitLootChatPatterns

-- Zul'Gurub Bijou itemIDs (19707 to 19715)
local ZG_BIJOUS = { 19707, 19708, 19709, 19710, 19711, 19712, 19713, 19714, 19715 }

local RepeatableTurnIns = {
    -- Argent Dawn (Scourgestones, Materials, Writs)
    { quest = "minion",            item = 12840, minCount = 20 }, -- Minion's Scourgestone
    { quest = "invader",           item = 12841, minCount = 10 }, -- Invader's Scourgestone
    { quest = "corruptor",         item = 12843, minCount = 1 },  -- Corruptor's Scourgestone
    { quest = "dragon scale",      item = 13920, minCount = 1 },  -- Healthy Dragon Scale
    { quest = "bone fragments",    item = 22526, minCount = 30 }, -- Bone Fragments
    { quest = "crypt fiend parts", item = 22525, minCount = 30 }, -- Crypt Fiend Parts
    { quest = "core of elements",  item = 22527, minCount = 30 }, -- Core of Elements
    { quest = "savage frond",      item = 22529, minCount = 30 }, -- Savage Frond
    { quest = "dark iron scraps",  item = 22528, minCount = 30 }, -- Dark Iron Scraps
    { quest = "craftsman",         item = "craftsman's writ", minCount = 1 },

    -- Winterspring E'ko (Witch Doctor Mau'ari)
    { quest = "frostsaber e'ko",   item = 12430, minCount = 3 },
    { quest = "winterfall e'ko",   item = 12431, minCount = 3 },
    { quest = "shardtooth e'ko",   item = 12432, minCount = 3 },
    { quest = "wildkin e'ko",      item = 12433, minCount = 3 },
    { quest = "chillwind e'ko",    item = 12434, minCount = 3 },
    { quest = "ice thistle e'ko",  item = 12435, minCount = 3 },
    { quest = "frostmaul e'ko",    item = 12436, minCount = 3 },

    -- Thorium Brotherhood
    { quest = "dark iron residue",                      item = 18945, minCount = 4 },
    { quest = "dark iron ore",                          item = 11370, minCount = 10 },
    {
        quest = "via heavy leather",
        requires = {
            { item = 4234,  count = 10 }, -- Heavy Leather
            { item = 11371, count = 2 },  -- Incendosaur Scale
            { item = 3857,  count = 1 },  -- Coal
        },
    },
    {
        quest = "via iron",
        requires = {
            { item = 3575,  count = 4 },  -- Iron Bar
            { item = 11371, count = 2 },  -- Incendosaur Scale
            { item = 3857,  count = 1 },  -- Coal
        },
    },
    {
        quest = "via kingsblood",
        requires = {
            { item = 3356,  count = 4 },  -- Kingsblood
            { item = 11371, count = 2 },  -- Incendosaur Scale
            { item = 3857,  count = 1 },  -- Coal
        },
    },
    { quest = "fiery core",                             item = 17010, minCount = 1 },
    { quest = "lava core",                              item = 17011, minCount = 1 },
    { quest = "blood of the mountain",                  item = 11382, minCount = 1 },
    { quest = "core leather",                           item = 17012, minCount = 2 },

    -- Cenarion Circle (Silithus)
    { quest = "encrypted twilight text", item = 20404, minCount = 10 },
    { quest = "secret communication",     item = 20404, minCount = 10 },
    { quest = "abyssal crest",           item = 20513, minCount = 3 },
    { quest = "abyssal signet",          item = 20514, minCount = 3 },
    { quest = "abyssal scepter",         item = 20515, minCount = 1 },

    -- Timbermaw Hold
    { quest = "deadwood headdress feather", item = 21377, minCount = 5 },
    { quest = "winterfall spirit bead",     item = 21383, minCount = 5 },

    -- Zandalar Tribe / Zul'Gurub (Yojamba Isle)
    {
        quest = "zulian",
        requires = {
            { item = 19698, count = 1 }, -- Zulian Coin
            { item = 19699, count = 1 }, -- Razzashi Coin
            { item = 19700, count = 1 }, -- Hakkari Coin
        },
    },
    {
        quest = "sandfury",
        requires = {
            { item = 19701, count = 1 }, -- Sandfury Coin
            { item = 19702, count = 1 }, -- Skullsplitter Coin
            { item = 19703, count = 1 }, -- Bloodscalp Coin
        },
    },
    {
        quest = "gurubashi",
        requires = {
            { item = 19704, count = 1 }, -- Gurubashi Coin
            { item = 19705, count = 1 }, -- Vilebranch Coin
            { item = 19706, count = 1 }, -- Witherbark Coin
        },
    },
    { quest = "hakkari bijou", item = ZG_BIJOUS, minCount = 1 },

    -- Un'Goro Crater
    { quest = "morrowgrain", item = 11040, minCount = 10 },
    { quest = "bloodpetal",  item = 11042, minCount = 15 },

    -- Cloth Donations
    { quest = "runecloth", item = 14047, minCount = 20 },

    -- Alterac Valley
    { quest = "armor scrap",         item = 17422, minCount = 20 },
    { quest = "soldier's blood",     item = 17306, minCount = 1 },
    { quest = "soldiers blood",      item = 17306, minCount = 1 },
    { quest = "lieutenant's flesh",  item = 17423, minCount = 1 },
    { quest = "ram hide",            item = 17643, minCount = 10 },
    { quest = "frostwolf hide",      item = 17642, minCount = 10 },
    { quest = "irondeep supplies",   item = 17424, minCount = 10 },
    { quest = "coldtooth supplies",  item = 17425, minCount = 10 },

    -- Custom / World (OctoWoW)
    -- Quest 40739: "The Tel'Abim Banana Transmutation"
    {
        questID = 40739,
        questTitle = "the tel'abim banana transmutation",
        requires = {
            { item = 60954, count = 3 },
            { item = 11176, count = 1 },
        },
    },
    -- Quest 40740: "Tel'Abim Banana Transmutations!"
    {
        questID = 40740,
        questTitle = "tel'abim banana transmutations!",
        requires = {
            { item = 60954, count = 15 },
            { item = 11176, count = 5 },
        },
    },
}

local GossipTurnInKeywords = {
    -- Lokhtos Darkbargainer (BRD)
    { match = "dark iron residue",     item = 18945, minCount = 4 },
    { match = "dark iron ore",         item = 11370, minCount = 10 },
    { match = "blood of the mountain", item = 11382, minCount = 1 },
    { match = "fiery core",            item = 17010, minCount = 1 },
    { match = "lava core",             item = 17011, minCount = 1 },
    { match = "core leather",          item = 17012, minCount = 2 },

    -- Altar of Zanza (ZG Bijou destruction)
    { match = "red hakkari bijou",    item = 19707, minCount = 1 },
    { match = "blue hakkari bijou",   item = 19708, minCount = 1 },
    { match = "yellow hakkari bijou", item = 19709, minCount = 1 },
    { match = "orange hakkari bijou", item = 19710, minCount = 1 },
    { match = "green hakkari bijou",  item = 19711, minCount = 1 },
    { match = "purple hakkari bijou", item = 19712, minCount = 1 },
    { match = "bronze hakkari bijou", item = 19713, minCount = 1 },
    { match = "silver hakkari bijou", item = 19714, minCount = 1 },
    { match = "gold hakkari bijou",   item = 19715, minCount = 1 },
    { match = "destroy",              item = ZG_BIJOUS, minCount = 1 },

    -- Alterac Valley
    { match = "armor scrap",        item = 17422, minCount = 20 },
    { match = "soldier's blood",    item = 17306, minCount = 1 },
    { match = "soldiers blood",     item = 17306, minCount = 1 },
    { match = "lieutenant's flesh", item = 17423, minCount = 1 },

    -- Submenu Openers
    { match = "scourgestone",   opener = true },
    { match = "twilight text",  opener = true },
    { match = "craftsman's writ", opener = true },
    { match = "turn in",        opener = true },
}

local function GetPlayerItemCount(target)
    if not target then return 0 end
    local targetType = type(target)
    if targetType == "number" then
        return C_Item.GetItemCount(target) or 0
    elseif targetType == "table" then
        local total = 0
        for i = 1, #target do
            total = total + (C_Item.GetItemCount(target[i]) or 0)
        end
        return total
    elseif targetType == "string" then
        if target == "" then return 0 end
        return C_Item.GetItemCount(target) or 0
    end
    return 0
end

local function NormalizeTitle(title)
    if not title or type(title) ~= "string" then return nil end
    local s = string.lower(title)
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s ~= "" and s or nil
end

local function MatchesRepeatableRequirement(title, questID)
    if type(title) == "table" then
        questID = title.questID
        title = title.title
    end
    local normTitle = NormalizeTitle(title)
    for _, rep in ipairs(RepeatableTurnIns) do
        local matched = false
        if questID then
            if rep.questID and rep.questID == questID then
                matched = true
            elseif not rep.questID and rep.quest and normTitle then
                if string.find(normTitle, rep.quest, 1, true) then
                    matched = true
                end
            end
        else
            if rep.questTitle and normTitle then
                if rep.questTitle == normTitle then
                    matched = true
                end
            elseif not rep.questID and rep.quest and normTitle then
                if string.find(normTitle, rep.quest, 1, true) then
                    matched = true
                end
            end
        end

        if matched then
            if rep.requires then
                local satisfied = true
                for i = 1, #rep.requires do
                    local req = rep.requires[i]
                    local count = C_Item.GetItemCount(req.item) or 0
                    if count < req.count then
                        satisfied = false
                        break
                    end
                end
                if satisfied then
                    return true, rep
                end
            elseif rep.item then
                local count = GetPlayerItemCount(rep.item)
                if count >= (rep.minCount or 1) then
                    return true, rep
                end
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
    local hasWaitingQuests = false

    -- 1. Active Quests (Turn-In)
    if AutoLazyDB.Quests.AutoTurnIn then
        local active = C_GossipInfo.GetActiveQuests()
        if active and #active > 0 then
            local completed = {}
            for i = 1, #active do
                local q = active[i]
                if q and q.questID and (q.isComplete == true or q.isComplete == 1) then
                    table_insert(completed, q)
                end
            end

            -- Priority 1: Repeatable turn-ins matching player inventory in bags
            for i = 1, #completed do
                local q = completed[i]
                if q.title and MatchesRepeatableRequirement(q.title, q.questID) then
                    C_GossipInfo.SelectActiveQuest(q.questID)
                    return "ACTION"
                end
            end

            -- Priority 2: Unambiguous single completed quest
            if #completed == 1 and completed[1] and completed[1].questID then
                C_GossipInfo.SelectActiveQuest(completed[1].questID)
                return "ACTION"
            elseif #completed > 1 then
                hasWaitingQuests = true
            end
        end

        -- Priority 3: Direct Gossip Turn-Ins (e.g. Altar of Zanza Bijous, Lokhtos Dark Iron, AV Scraps)
        local options = C_GossipInfo.GetOptions()
        if options and #options > 0 then
            for i = 1, #options do
                local opt = options[i]
                local optName = opt.name or opt.title
                if optName and MatchesGossipTurnIn(optName) then
                    if opt.gossipOptionID then
                        C_GossipInfo.SelectOption(opt.gossipOptionID)
                    else
                        C_GossipInfo.SelectOptionByIndex(i)
                    end
                    return "ACTION"
                end
            end
        end
    end

    -- 2. Available Quests (Accept)
    if AutoLazyDB.Quests.AutoAccept then
        local avail = C_GossipInfo.GetAvailableQuests()
        if avail and #avail > 0 then
            -- Priority 1: Repeatable turn-ins matching player inventory in bags
            for i = 1, #avail do
                local q = avail[i]
                if q and q.questID and q.title and MatchesRepeatableRequirement(q.title, q.questID) then
                    C_GossipInfo.SelectAvailableQuest(q.questID)
                    return "ACTION"
                end
            end

            -- Priority 2: Exactly 1 available quest
            if #avail == 1 and avail[1] and avail[1].questID then
                C_GossipInfo.SelectAvailableQuest(avail[1].questID)
                return "ACTION"
            elseif #avail > 1 then
                hasWaitingQuests = true
            end
        end
    end

    if hasWaitingQuests then
        return "WAITING"
    end
    return false
end

local function ProcessGreeting()
    if not ShouldAutoQuest() then return false end
    local hasWaitingQuests = false

    if AutoLazyDB.Quests.AutoTurnIn and GetNumActiveQuests and GetActiveTitle and SelectActiveQuest then
        local numActive = GetNumActiveQuests()
        if numActive and numActive > 0 then
            local completed = {}
            for i = 1, numActive do
                local title, isComplete = GetActiveTitle(i)
                if isComplete == 1 or isComplete == true then
                    table_insert(completed, { index = i, title = title })
                end
            end

            -- Priority 1: Repeatable turn-ins matching player inventory in bags
            for i = 1, #completed do
                if completed[i].title and MatchesRepeatableRequirement(completed[i].title) then
                    SelectActiveQuest(completed[i].index)
                    return "ACTION"
                end
            end

            -- Priority 2: Exactly 1 completed quest
            if #completed == 1 then
                SelectActiveQuest(completed[1].index)
                return "ACTION"
            elseif #completed > 1 then
                hasWaitingQuests = true
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
                        return "ACTION"
                    end
                end
            end

            -- Priority 2: Exactly 1 available quest
            if numAvail == 1 then
                SelectAvailableQuest(1)
                return "ACTION"
            elseif numAvail > 1 then
                hasWaitingQuests = true
            end
        end
    end

    if hasWaitingQuests then
        return "WAITING"
    end
    return false
end

local function DelayedStartupSync()
    AutoLazy_ApplySystemIconToggles()
    if AutoLazy_CollapseAddons then AutoLazy_CollapseAddons() end
end

local function TryQuestChain(token)
    if token and token ~= currentQuestSessionToken then return end
    if not (GossipFrame and GossipFrame:IsShown()) and not (QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown()) then
        questSessionActive = false
        activeNpcGUID = nil
        return
    end
    local currentGuid = (UnitGUID and (UnitGUID("npc") or UnitGUID("target"))) or nil
    if activeNpcGUID and currentGuid and currentGuid ~= activeNpcGUID then
        questSessionActive = false
        activeNpcGUID = nil
        return
    end

    local res = false
    if GossipFrame and GossipFrame:IsShown() then
        res = ProcessGossip()
    elseif QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown() then
        res = ProcessGreeting()
    end

    if res == false then
        questSessionActive = false
        activeNpcGUID = nil
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
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
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
        HookChatFrameEvents()
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
        if not AutoLazyDB or not AutoLazyDB.Enabled or not CachedDungeonKey then
            return
        end

        local rollId = a1
        if not rollId then return end

        local texture, name, count, quality, bindOnPickup = GetLootRollItemInfo(rollId)
        local itemLink = GetLootRollItemLink(rollId) or (name and ("[" .. name .. "]")) or ("Item #" .. rollId)

        -- Strict Gate: AutoLazy ONLY rolls on the explicitly configured tedious items
        local action = AutoLazy_GetItemRule(name)
        if not action or action == "MANUAL" then
            return
        end

        local rollType = nil
        local actionName = nil

        if action == "NEED" then
            rollType = LOOT_ROLL_NEED
            actionName = "|cFFFF8000Need|r"
        elseif action == "GREED" then
            rollType = LOOT_ROLL_GREED
            actionName = "|cFF00FF00Greed|r"
        elseif action == "PASS" then
            rollType = LOOT_ROLL_PASS
            actionName = "|cFF808080Passed|r"
        end

        if rollType ~= nil then
            RollOnLoot(rollId, rollType)
        end

    elseif ev == "CONFIRM_LOOT_ROLL" then
        if not AutoLazyDB or not AutoLazyDB.Enabled or not AutoLazyDB.AutoConfirmBop then return end
        local rollId = a1
        local rollType = a2
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

    elseif ev == "PLAYER_TARGET_CHANGED" then
        local currentGuid = (UnitGUID and (UnitGUID("npc") or UnitGUID("target"))) or nil
        if activeNpcGUID and currentGuid ~= activeNpcGUID then
            questSessionActive = false
            activeNpcGUID = nil
            currentQuestSessionToken = currentQuestSessionToken + 1
        end

    -- Continuous Shift+Click Quest Handlers
    elseif ev == "GOSSIP_SHOW" then
        activeNpcGUID = (UnitGUID and (UnitGUID("npc") or UnitGUID("target"))) or nil
        currentQuestSessionToken = currentQuestSessionToken + 1
        if AutoLazyDB and AutoLazyDB.Quests and AutoLazyDB.Quests.Enabled then
            if AutoLazyDB.Quests.AlwaysActive or IsShiftKeyDown() then
                questSessionActive = true
            end
        end
        ProcessGossip()

    elseif ev == "GOSSIP_CLOSED" then
        local token = currentQuestSessionToken
        C_Timer.After(0.5, function()
            if token == currentQuestSessionToken then
                if not (GossipFrame and GossipFrame:IsShown()) and not (QuestFrame and QuestFrame:IsShown()) then
                    questSessionActive = false
                    activeNpcGUID = nil
                end
            end
        end)

    elseif ev == "QUEST_GREETING" then
        activeNpcGUID = (UnitGUID and (UnitGUID("npc") or UnitGUID("target"))) or nil
        currentQuestSessionToken = currentQuestSessionToken + 1
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
            local token = currentQuestSessionToken
            C_Timer.After(0.08, function()
                TryQuestChain(token)
            end)
        else
            questSessionActive = false
            activeNpcGUID = nil
            currentQuestSessionToken = currentQuestSessionToken + 1
        end
    end
end)

local function ToggleCleanRollChat()
    AutoLazyDB.CleanRollChat = not AutoLazyDB.CleanRollChat
    AutoLazy_Print("Clean Roll Chat: " .. (AutoLazyDB.CleanRollChat and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"))
    if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
end

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
        AutoLazy_Print("Listed item auto-roll is now " .. (AutoLazyDB.Enabled and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    on = function() AutoLazyDB.Enabled = true; AutoLazy_Print("Listed item auto-roll is now |cFF00FF00ENABLED|r."); if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end end,
    off = function() AutoLazyDB.Enabled = false; AutoLazy_Print("Listed item auto-roll is now |cFFFF2020DISABLED|r."); if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end end,

    clean = ToggleCleanRollChat,
    cleanroll = ToggleCleanRollChat,

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
        AutoLazy_Print("Commands: /al, /al tray, /al collapse, /al resetpos, /al btn, /al radio, /al lfg, /al toggle, /al clean, /al quest, /al turnin, /al accept, /al always, /al status")
    end
end

-- Initialize presentation hooks if chat frame is already loaded
HookChatFrameEvents()

-- Export module internals for verified test suite validation
AutoLazy.ProcessGossip = ProcessGossip
AutoLazy.ProcessGreeting = ProcessGreeting
AutoLazy.TryQuestChain = TryQuestChain
AutoLazy.ShouldAutoQuest = ShouldAutoQuest
AutoLazy.MatchesRepeatableRequirement = MatchesRepeatableRequirement
AutoLazy.NormalizeTitle = NormalizeTitle
AutoLazy.MatchesGossipTurnIn = MatchesGossipTurnIn
AutoLazy.GetPlayerItemCount = GetPlayerItemCount
AutoLazy.SetQuestSessionActive = function(val) questSessionActive = val end
AutoLazy.GetQuestSessionActive = function() return questSessionActive end
AutoLazy.SetCurrentQuestSessionToken = function(val) currentQuestSessionToken = val end
AutoLazy.GetCurrentQuestSessionToken = function() return currentQuestSessionToken end
AutoLazy.SetActiveNpcGUID = function(val) activeNpcGUID = val end
AutoLazy.GetActiveNpcGUID = function() return activeNpcGUID end
