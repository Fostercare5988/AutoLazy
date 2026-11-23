-- AutoLazy: farm-item rolls, bind-on-pickup warnings, quiet roll chat, Shift
-- turn-ins and one tray for the minimap buttons. Its page in ClassicAPI's
-- Settings window (AddOn Options, /autolazy, or /al when no other addon has it).
-- Doc headings are ClassicAPI's docs/API.md; "FrameXML" is the client's own code.
if not CLASSIC_API_VERSION then error("AutoLazy needs ClassicAPI.", 0) end

local _, AL = ...
AutoLazyDB = AutoLazyDB or {} -- restored first: LoadSavedVariablesFirst
local db = AutoLazyDB

-- The page in play order: a section header, a switch { key, label, tip, default },
-- or a roll choice { key, label, tip, default, true }.
local PAGE = {
    "Loot",
    { "roll", "Auto-roll farm items", "Inside their instance, rolls on the items below the way you choose. Every other item is left to you.", true },
    { "rollSand", "Corrupted Sand", "The Black Morass.", "PASS", true },
    { "rollBijous", "Bijous", "Zul'Gurub.", "NEED", true },
    { "rollCoins", "Coins", "Zul'Gurub.", "NEED", true },
    { "rollScarabs", "Scarabs", "Ruins of Ahn'Qiraj.", "MANUAL", true },
    { "rollScraps", "Wartorn Scraps", "Naxxramas: cloth, leather, chain and plate.", "MANUAL", true },
    { "confirmBind", "Accept bind-on-pickup", "Accepts the \"will bind to you\" warning when you loot or roll, anywhere.", true },
    { "hideRollChat", "Hide roll spam", "Roll lines leave chat. The winner, the items you receive and money stay.", true },
    "Quests",
    { "shiftQuests", "Shift turn-ins", "Hold Shift when a quest giver opens: every complete quest is turned in, the biggest first, and turn-ins you carry the items for are done too. A reward is taken when there is one, or the one you chose last time. Accepting a quest stays yours.", true },
    "Minimap",
    { "tray", "Minimap tray", "The other addons' minimap buttons move into one panel, opened by the AutoLazy button. Drag the button to move it; right-click it for this page.", true },
    { "hideRadioLfg", "Hide Pirate Radio and Group Finder", "Their minimap buttons are gone, tray included.", true },
}

-- Fill the defaults now (the features start before the window registers the page),
-- and clear every saved key no row owns (KNOWN_PATTERNS KP-64).
local owned = {}
for _, row in ipairs(PAGE) do
    if type(row) == "table" then
        owned[row[1]] = true
        if db[row[1]] == nil then db[row[1]] = row[4] end
    end
end
for key in pairs(db) do if not owned[key] then db[key] = nil end end

-- What a row runs when its value changes: AL.apply[key](). The rest is read where it is used.
AL.apply = {}

local function RollChoices()
    local choices = Settings.CreateControlTextContainer()
    choices:Add("MANUAL", "Manual")
    choices:Add("NEED", "Need")
    choices:Add("GREED", "Greed")
    choices:Add("PASS", "Pass")
    return choices:GetData()
end
local function Rolling() return db.roll end

local category
SettingsRegistrar:AddRegistrant(function()
    local layout, rollRow
    category, layout = Settings.RegisterVerticalLayoutCategory("AutoLazy")
    for _, row in ipairs(PAGE) do
        if type(row) == "string" then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(row))
        else
            local key, name, tip, default, choice = row[1], row[2], row[3], row[4], row[5]
            local kind = choice and Settings.VarType.String or Settings.VarType.Boolean
            local setting = Settings.RegisterAddOnSetting(category, "AutoLazy_" .. key, key, db, kind, name, default)
            if AL.apply[key] then setting:SetValueChangedCallback(AL.apply[key]) end
            if choice then
                Settings.CreateDropdown(category, setting, RollChoices, tip):SetParentInitializer(rollRow, Rolling)
            else
                local made = Settings.CreateCheckbox(category, setting, tip)
                if key == "roll" then rollRow = made end
            end
        end
    end
    Settings.RegisterAddOnCategory(category)
end)

function AL.OpenPage()
    if category then Settings.OpenToCategory(category:GetID()) end
end

-- /autolazy always; /al too, unless another addon claims it (AtlasLoot does). The chat
-- box runs the first match in SlashCmdList's hash order (FrameXML ChatFrame.lua:2235),
-- so a shared command picks a winner by chance. Asked at login, once every addon is in.
SLASH_AUTOLAZY1 = "/autolazy"
SlashCmdList.AUTOLAZY = AL.OpenPage

local function Claimed(command)
    for key in pairs(SlashCmdList) do
        local i = 1
        while key ~= "AUTOLAZY" and _G["SLASH_" .. key .. i] do
            if strlower(_G["SLASH_" .. key .. i]) == command then return true end
            i = i + 1
        end
    end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
    this:UnregisterEvent("PLAYER_LOGIN")
    if not Claimed("/al") then SLASH_AUTOLAZY2 = "/al" end
end)
