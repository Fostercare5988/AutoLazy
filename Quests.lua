-- Shift turn-ins: every complete quest at a quest giver, the biggest first;
-- offered turn-ins you carry the items for; the reward chosen last time.
-- Accepting a quest stays the player's.
local _, AL = ...
local db = AutoLazyDB

local npc, lastStep = nil, 0         -- the quest giver of our last step, and when
local offered                        -- the offered quest of our last pick
local refused = {}                   -- offered quests that asked to be accepted
local loading = {}                   -- quests whose objectives were asked for
local repeatNpc, repeatQuest         -- the last turn-in, by hand or by Shift
local completing                     -- the quest giver of the open reward page
local rewards = {}                   -- a reward page's choices -> the item chosen there

local function Shift() return IsLeftShiftKeyDown() or IsRightShiftKeyDown() end
local function Giver() return UnitGUID("npc") or UnitGUID("target") end
local function Step() npc, lastStep = Giver(), GetTime() end

-- A step is ours while Shift is down, or at the same quest giver within 2 s of our
-- last one. UNVERIFIED: that 2 s covers the server's answer.
local function Ours()
    if not db.shiftQuests then return false end
    return Shift() or (npc ~= nil and npc == Giver() and GetTime() - lastStep <= 2)
end

-- How many items a quest asks for; nil while its data is not cached.
-- With `carried`, nil also unless every objective is an item already in the bags.
local function Items(questID, carried)
    local details = C_QuestLog.GetQuestDetails(questID)
    if not details then
        if carried and not loading[questID] then
            loading[questID] = true
            C_QuestLog.RequestLoadQuestByID(questID)
        end
        return
    end
    local total, list = 0, details.requirements
    if carried and #list == 0 then return end
    for i = 1, #list do
        local need = list[i]
        if need.kind == "item" then
            if carried and C_Item.GetItemCount(need.id) < need.count then return end
            total = total + need.count
        elseif carried then
            return
        end
    end
    return total
end

-- The list's best quest: the last turn-in here first, then the most items; a tie
-- or no data keeps the list order.
local function Best(list, carried)
    local here = repeatNpc == Giver() and repeatQuest
    local best, bestIndex, bestItems
    for i = 1, #list do
        local quest = list[i]
        if (carried and not refused[quest.questID]) or (not carried and quest.isComplete) then
            local items = Items(quest.questID, carried)
            if quest.questID == here and (items or not carried) then items = math.huge end
            if (items or not carried) and (not best or (items or 0) > bestItems) then
                best, bestIndex, bestItems = quest.questID, i, items or 0
            end
        end
    end
    return best, bestIndex
end

-- `greeting`: a quest greeting window, picked by place in the list (the stock
-- selectors); else gossip, by quest ID (### C_GossipInfo.SelectActiveQuest).
local function Pick(greeting)
    local quest, index = Best(C_GossipInfo.GetActiveQuests(), false)
    if quest then
        offered = nil
        Step()
        if greeting then SelectActiveQuest(index) else C_GossipInfo.SelectActiveQuest(quest) end
        return
    end
    quest, index = Best(C_GossipInfo.GetAvailableQuests(), true)
    if quest then
        offered = quest
        Step()
        if greeting then SelectAvailableQuest(index) else C_GossipInfo.SelectAvailableQuest(quest) end
    end
end

-- What the reward page offers, as one key.
local function Choices(n)
    local key = ""
    for i = 1, n do key = key .. (GetQuestItemID("choice", i) or 0) .. ":" end
    return key
end

-- The player's own choice, and ours, is the one taken next time.
hooksecurefunc("GetQuestReward", function(choice)
    local n = GetNumQuestChoices()
    if choice and n > 1 then rewards[Choices(n)] = GetQuestItemID("choice", choice) end
end)

local on = {}
function on.GOSSIP_SHOW() if db.shiftQuests and Shift() then Pick(false) end end
function on.QUEST_GREETING() if db.shiftQuests and Shift() then Pick(true) end end

function on.QUEST_DATA_LOAD_RESULT(questID, success)
    if not loading[questID] then return end
    loading[questID] = nil
    if not success or not Ours() then return end
    if GossipFrame:IsVisible() then Pick(false) elseif QuestFrameGreetingPanel:IsVisible() then Pick(true) end
end

-- An accept page: the chain stops, and that offer is not picked again until it is turned in.
function on.QUEST_DETAIL()
    if offered and npc == Giver() and GetTime() - lastStep <= 2 then refused[offered] = true end
    offered = nil
end

function on.QUEST_PROGRESS()
    if Ours() and IsQuestCompletable() then Step(); CompleteQuest() end
end

function on.QUEST_COMPLETE()
    completing = Giver()
    if not Ours() then return end
    local n = GetNumQuestChoices()
    if n <= 1 then Step(); return GetQuestReward(n) end -- as QuestFrame.lua does: 0 with no choice
    local want = rewards[Choices(n)]
    for i = 1, n do
        if want and GetQuestItemID("choice", i) == want then Step(); return GetQuestReward(i) end
    end
end

function on.QUEST_TURNED_IN(questID)
    repeatNpc, repeatQuest = completing or Giver(), questID
    refused[questID] = nil
end

local events = CreateFrame("Frame")
for name in pairs(on) do events:RegisterEvent(name) end
events:SetScript("OnEvent", function(_, event, a1, a2) on[event](a1, a2) end)
