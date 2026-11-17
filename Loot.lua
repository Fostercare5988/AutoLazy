-- Rolls on the farm items, bind-on-pickup warnings and the roll lines in chat.
local _, AL = ...
local db = AutoLazyDB

-- Each roll row: its first and last item ID, and the instances it rolls in
-- (GetInstanceInfo's name, from Map.dbc). AQ40's scarabs stay manual.
-- [SOURCE-VERIFIED] https://octowow.st/db/ (the IDs the old AutoLazy found and played)
local ROWS = {
    rollSand = { 50203, 50203, ["The Black Morass"] = true, ["Opening of the Dark Portal"] = true },
    rollBijous = { 19707, 19715, ["Zul'Gurub"] = true },
    rollCoins = { 19698, 19706, ["Zul'Gurub"] = true },
    rollScarabs = { 20858, 20865, ["Ruins of Ahn'Qiraj"] = true },
    rollScraps = { 22373, 22376, ["Naxxramas"] = true },
}
local rowOf = {} -- item ID -> roll row
for key, row in pairs(ROWS) do
    for id = row[1], row[2] do rowOf[id] = key end
end
local ROLL = { PASS = 0, NEED = 1, GREED = 2 } -- RollOnLoot's types; "MANUAL" is none

local looted = {} -- loot slots accepted in this loot window

local on = {}
function on.START_LOOT_ROLL(rollID)
    if not db.roll then return end
    local key = rowOf[GetLootRollItemID(rollID)]
    local roll = key and ROLL[db[key]]
    if roll and ROWS[key][(GetInstanceInfo())] then RollOnLoot(rollID, roll) end
end

-- UIParent shows these popups first: it registers the events at load (UIParent.lua:95, 127).
function on.CONFIRM_LOOT_ROLL(rollID, rollType)
    if not db.confirmBind then return end
    ConfirmLootRoll(rollID, rollType)
    StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID)
end

-- The LOOT_BIND popup accepts with LootSlot(slot) (StaticPopup.lua:609); once per slot.
function on.LOOT_BIND_CONFIRM(slot)
    if not db.confirmBind or looted[slot] then return end
    looted[slot] = true
    LootSlot(slot)
    StaticPopup_Hide("LOOT_BIND", slot)
end

function on.LOOT_CLOSED() table.wipe(looted) end

-- The roll lines, from the client's own strings (GlobalStrings.lua). The winner
-- (LOOT_ROLL_WON, _YOU_WON), items received and money are not among them.
local patterns = {}
for _, name in ipairs({ "START", "NEED", "NEED_SELF", "GREED", "GREED_SELF", "PASSED", "PASSED_SELF",
    "ROLLED", "ROLLED_SELF", "ROLLED_NEED", "ROLLED_NEED_SELF", "ROLLED_GREED", "ROLLED_GREED_SELF", "ALL_PASSED" }) do
    local p = string.gsub(_G["LOOT_ROLL_" .. name], "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    p = string.gsub(p, "%%s", ".+")
    patterns[#patterns + 1] = "^" .. string.gsub(p, "%%d", "%%d+") .. "$"
end

-- One event reaches every chat window: the last line's verdict is kept.
local lastText, lastHidden
-- GAP: no chat message filter. A DLL should give ChatFrame_AddMessageEventFilter(event, filter).
local function RollChatHidden(text)
    if text ~= lastText then
        lastText, lastHidden = text, false
        for i = 1, #patterns do
            if string.find(text, patterns[i]) then lastHidden = true; break end
        end
    end
    return lastHidden
end

local stock = ChatFrame_OnEvent
function ChatFrame_OnEvent(event)
    if event == "CHAT_MSG_LOOT" and db.hideRollChat then
        local _, text = GetCurrentChatEvent() -- the event's own text (### GetCurrentChatEvent())
        if text and RollChatHidden(text) then return end
    end
    return stock(event)
end

local events = CreateFrame("Frame")
for name in pairs(on) do events:RegisterEvent(name) end
events:SetScript("OnEvent", function(_, event, a1, a2) on[event](a1, a2) end)
