--[[
    AutoLazy v1.0.0
    Author & Maintainer: Fostercare5988
    Target: World of Warcraft 1.12.1 (Vanilla Enhanced Stack: ClassicAPI v1.15.15+)
    Description: Dungeon loot automation, Shift-click quest turn-ins, and a reversible minimap addon tray.
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

AutoLazy = {}

-- Standard library and engine upvalues for high-frequency execution
local string_find, string_lower = string.find, string.lower
local table_insert = table.insert
local type, pairs, ipairs, getglobal = type, pairs, ipairs, getglobal

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
-- [SOURCE-VERIFIED] Item identities: https://octowow.st/db/
local DungeonItems = {
    ["The Black Morass"] = {
        { id = 50203, name = "Corrupted Sand", texture = "Interface\\Icons\\INV_enchant_dustsoul", quality = 2, defaultNeed = true },
    },
    ["Zul'Gurub"] = {
        { id = 19707, lastID = 19715, name = "Bijous", texture = "Interface\\Icons\\INV_Bijou_Gold", quality = 3, defaultNeed = true, key = "zg bijous" },
        { id = 19698, lastID = 19706, name = "Coins", texture = "Interface\\Icons\\INV_Misc_ArmorKit_11", quality = 2, defaultNeed = true, key = "zg coins" },
    },
    ["Ruins of Ahn'Qiraj"] = {
        { id = 20858, lastID = 20865, name = "Scarabs", texture = "Interface\\Icons\\INV_Scarab_Stone", quality = 2, defaultNeed = true, key = "aq20 scarabs" },
        { id = 20866, lastID = 20873, name = "Idols", texture = "Interface\\Icons\\INV_Misc_Idol_01", quality = 3, defaultNeed = false, key = "aq20 idols" },
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

    -- AQ20 (8 Scarab Tokens)
    ["stone scarab"]              = "AQ20 Scarab",
    ["gold scarab"]               = "AQ20 Scarab",
    ["silver scarab"]             = "AQ20 Scarab",
    ["bronze scarab"]             = "AQ20 Scarab",
    ["crystal scarab"]            = "AQ20 Scarab",
    ["clay scarab"]               = "AQ20 Scarab",
    ["bone scarab"]               = "AQ20 Scarab",
    ["ivory scarab"]              = "AQ20 Scarab",

    -- AQ20 (8 Token Idols - Excludes Druid Relic Idols)
    ["amber idol"]                = "AQ20 Idol",
    ["azure idol"]                = "AQ20 Idol",
    ["jasper idol"]               = "AQ20 Idol",
    ["obsidian idol"]             = "AQ20 Idol",
    ["onyx idol"]                 = "AQ20 Idol",
    ["vermillion idol"]           = "AQ20 Idol",
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

local FarmRuleKeys = {
    ["ZG Coin"] = "zg coins", ["ZG Bijou"] = "zg bijous",
    ["AQ20 Scarab"] = "aq20 scarabs", ["AQ20 Idol"] = "aq20 idols",
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
    Tweaks = {
        HideRadio = false,
        HideLfg   = false,
        CollapseAddons = true,
    },
    ItemRules = {},
    Quests = {
        Enabled = true,
        AutoTurnIn = true,
        SafeRewards = true,
    },
}

local RuleDungeons, RuleItems = {}, {}
for dungeon, items in pairs(DungeonItems) do
    for _, item in ipairs(items) do
        local key = item.key or string_lower(item.name)
        defaultDB.ItemRules[key] = item.defaultNeed and "NEED" or "MANUAL"
        RuleDungeons[key] = dungeon
        -- These token groups have contiguous IDs; specific items have one ID.
        for id = item.id, item.lastID or item.id do RuleItems[id] = key end
    end
end

local CachedDungeonKey = nil
local CachedDungeonDef = nil

function AutoLazy_Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99[AutoLazy]|r " .. tostring(msg))
    end
end

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
    if type(AutoLazyDB.Tweaks.KeepOnMinimap) ~= "table" then AutoLazyDB.Tweaks.KeepOnMinimap = {} end
    for name, keep in pairs(AutoLazyDB.Tweaks.KeepOnMinimap) do
        -- Persist identities only; retain choices for addons not loaded yet.
        if type(name) ~= "string" or name == "" or keep ~= true then
            AutoLazyDB.Tweaks.KeepOnMinimap[name] = nil
        end
    end

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
    AutoLazyDB.Quests.AutoAccept = nil
    AutoLazyDB.Quests.AlwaysActive = nil
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

    ItemEvaluationCache[itemName] = false
    return false, nil
end

local function GetItemRuleKey(itemName)
    if not itemName or itemName == "" then return nil end
    local lower = string_lower(itemName)
    -- Only catalogued names qualify. Shared words cannot opt gear into a rule.
    if RuleDungeons[lower] then return lower end
    return FarmRuleKeys[FarmItemLookup[lower]]
end

function AutoLazy_GetItemRule(itemName)
    if not AutoLazyDB or not AutoLazyDB.ItemRules then return nil end
    local key = GetItemRuleKey(itemName)
    return key and AutoLazyDB.ItemRules[key]
end

local questSessionActive = false
local currentQuestSessionToken = 0
local activeNpcGUID = nil

local function ShouldAutoQuest()
    if not AutoLazyDB or not AutoLazyDB.Quests or not AutoLazyDB.Quests.Enabled then return false end
    if questSessionActive then return true end
    return (IsShiftKeyDown and IsShiftKeyDown()) and true or false
end

local function StartQuestSession()
    activeNpcGUID = (UnitGUID and (UnitGUID("npc") or UnitGUID("target"))) or nil
    currentQuestSessionToken = currentQuestSessionToken + 1
    questSessionActive = AutoLazyDB and AutoLazyDB.Quests and
        AutoLazyDB.Quests.Enabled and IsShiftKeyDown() and true or false
end

function AutoLazy_PrintStatus()
    if not AutoLazyDB then InitDB() end
    UpdateZoneCache()

    local masterStatus = AutoLazyDB.Enabled and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"
    local bopStatus = AutoLazyDB.AutoConfirmBop and "|cFF00FF00ON|r" or "|cFFFF2020OFF|r"
    local cleanRollStatus = AutoLazyDB.CleanRollChat and "|cFF00FF00ON|r" or "|cFFFF2020OFF|r"
    local questStatus = (AutoLazyDB.Quests and AutoLazyDB.Quests.Enabled) and "|cFF00FF00ON (Shift-click turn-ins)|r" or "|cFFFF2020OFF|r"
    AutoLazy_Print("Auto-roll: " .. masterStatus .. " | Auto-confirm loot: " .. bopStatus .. " | Hide loot roll spam: " .. cleanRollStatus .. " | Quests: " .. questStatus)

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
local lastLootMessage, lastLootSuppressed

local function FormatToPattern(fmt)
    if not fmt or type(fmt) ~= "string" then return nil end
    local parts, cursor = {}, 1
    while true do
        -- Parse placeholders before escaping literal text, including %% and
        -- localized numbered forms such as %2$s. Never emit capture references.
        local first, last, spec = string.find(fmt, "%%[%d%$]*([sd%%])", cursor)
        local literal = string.sub(fmt, cursor, first and first - 1 or string.len(fmt))
        parts[#parts + 1] = string.gsub(literal, "([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
        if not first then break end
        parts[#parts + 1] = spec == "s" and ".+" or spec == "d" and "%d+" or "%%"
        cursor = last + 1
    end
    return "^" .. table.concat(parts) .. "$"
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
    -- The same event is dispatched to each chat frame. Retain one result,
    -- not a growing message history, and check the user's setting first.
    if msg == lastLootMessage then return lastLootSuppressed end
    if not suppressedLootPatterns then InitLootChatPatterns() end
    local suppressed = false
    for i = 1, #suppressedLootPatterns do
        if string_find(msg, suppressedLootPatterns[i]) then
            suppressed = true
            break
        end
    end
    lastLootMessage, lastLootSuppressed = msg, suppressed
    return suppressed
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
    -- Caverns of Time (Dronormu - Corrupted Sand: 10x bulk prioritized over 1x)
    {
        questID = 40341,
        quest = "sand in bulk",
        item = 50203,
        minCount = 10,
    },
    {
        questID = 40340,
        quest = "corrupted sand",
        item = 50203,
        minCount = 1,
    },
    -- Quest 40740: "Tel'Abim Banana Transmutations!" (15x bulk prioritized over 3x)
    {
        questID = 40740,
        questTitle = "tel'abim banana transmutations!",
        requires = {
            { item = 60954, count = 15 },
            { item = 11176, count = 5 },
        },
    },
    -- Quest 40739: "The Tel'Abim Banana Transmutation" (3x)
    {
        questID = 40739,
        questTitle = "the tel'abim banana transmutation",
        requires = {
            { item = 60954, count = 3 },
            { item = 11176, count = 1 },
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

    -- Caverns of Time (Dronormu - Corrupted Sand)
    { match = "sand in bulk",          item = 50203, minCount = 10 },
    { match = "corrupted sand",        item = 50203, minCount = 1 },

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
    for priority, rep in ipairs(RepeatableTurnIns) do
        local matched = false
        if questID and rep.questID then
            if rep.questID == questID then
                matched = true
            end
        elseif rep.questTitle and normTitle then
            if rep.questTitle == normTitle then
                matched = true
            end
        elseif rep.quest and normTitle then
            if string.find(normTitle, rep.quest, 1, true) then
                matched = true
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
                    return true, rep, priority
                end
            elseif rep.item then
                local count = GetPlayerItemCount(rep.item)
                if count >= (rep.minCount or 1) then
                    return true, rep, priority
                end
            end
        end
    end
    return false
end

local function PreferredRepeatable(completed)
    local selected, bestPriority
    for i = 1, #completed do
        local quest = completed[i]
        if quest.title then
            local matched, _, priority = MatchesRepeatableRequirement(quest.title, quest.questID)
            if matched and (not bestPriority or priority < bestPriority) then
                selected, bestPriority = quest, priority
                if priority == 1 then break end
            end
        end
    end
    return selected
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

            -- One requirement check per quest, retaining repeatable priority.
            local preferred = PreferredRepeatable(completed)
            if preferred then
                C_GossipInfo.SelectActiveQuest(preferred.questID)
                return "ACTION"
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

            local preferred = PreferredRepeatable(completed)
            if preferred then
                SelectActiveQuest(preferred.index)
                return "ACTION"
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

    if hasWaitingQuests then
        return "WAITING"
    end
    return false
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
        pcall(AutoLazy_ApplySystemIconToggles)

    elseif ev == "PLAYER_ENTERING_WORLD" then
        UpdateZoneCache()
        pcall(AutoLazy_ApplySystemIconToggles)

    elseif ev == "ZONE_CHANGED_NEW_AREA" or ev == "ZONE_CHANGED" then
        UpdateZoneCache()

    elseif ev == "START_LOOT_ROLL" then
        if not AutoLazyDB or not AutoLazyDB.Enabled or not CachedDungeonKey then
            return
        end

        local rollId = a1
        if not rollId then return end

        -- Strict Gate: AutoLazy ONLY rolls on the explicitly configured tedious items
        -- [SOURCE-VERIFIED] ClassicAPI 1.15.15 supplies a direct roll item ID.
        -- No localized-name matching, link parsing or item-cache request.
        local key = RuleItems[GetLootRollItemID(rollId)]
        local action = key and AutoLazyDB.ItemRules[key]
        if not action or action == "MANUAL" or RuleDungeons[key] ~= CachedDungeonKey then
            return
        end

        local rollType = nil

        if action == "NEED" then
            rollType = LOOT_ROLL_NEED
        elseif action == "GREED" then
            rollType = LOOT_ROLL_GREED
        elseif action == "PASS" then
            rollType = LOOT_ROLL_PASS
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
        if activeNpcGUID then
            local currentGuid = (UnitGUID and (UnitGUID("npc") or UnitGUID("target"))) or nil
            if currentGuid ~= activeNpcGUID then
                questSessionActive = false
                activeNpcGUID = nil
                currentQuestSessionToken = currentQuestSessionToken + 1
            end
        end

    -- Shift-initiated quest turn-ins; accepting quests remains manual.
    elseif ev == "GOSSIP_SHOW" then
        StartQuestSession()
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
        StartQuestSession()
        ProcessGreeting()

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
    AutoLazy_Print("Hide loot roll spam: " .. (AutoLazyDB.CleanRollChat and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"))
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
        AutoLazy_Print("Shift-click Quest Turn-ins: " .. (AutoLazyDB.Quests.Enabled and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
    turnin = function()
        AutoLazyDB.Quests.AutoTurnIn = not AutoLazyDB.Quests.AutoTurnIn
        AutoLazy_Print("Auto Turn-In: " .. (AutoLazyDB.Quests.AutoTurnIn and "|cFF00FF00ENABLED|r" or "|cFFFF2020DISABLED|r"))
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
        AutoLazy_Print("Auto-confirm loot: " .. (AutoLazyDB.AutoConfirmBop and "|cFF00FF00ON|r" or "|cFFFF2020OFF|r"))
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end,
}

SLASH_AUTOLAZY1 = "/autolazy"
SLASH_AUTOLAZY2 = "/al"
SlashCmdList["AUTOLAZY"] = function(msg)
    if not AutoLazyDB then InitDB() end
    local _, _, cmd = string_find(msg or "", "^%s*(%S+)%s*(.-)$")
    cmd = string_lower(cmd or "")

    if slashToggles[cmd] then
        slashToggles[cmd]()
    elseif cmd == "" or cmd == "gui" or cmd == "menu" or cmd == "config" or cmd == "options" then
        if AutoLazy_ToggleGUI then AutoLazy_ToggleGUI() else AutoLazy_PrintStatus() end
    else
        AutoLazy_Print("Commands: /al, /al tray, /al collapse, /al resetpos, /al btn, /al radio, /al lfg, /al toggle, /al clean, /al quest, /al turnin, /al status")
    end
end

-- Initialize presentation hooks if chat frame is already loaded
HookChatFrameEvents()
