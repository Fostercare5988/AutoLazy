-- Test runner concatenates this with the core in one Lua chunk.
-- Private transaction state and test helpers stay out of the shipped addon.
AutoLazy.ShouldSuppressLootMessage = ShouldSuppressLootMessage
AutoLazy.InitLootChatPatterns = InitLootChatPatterns
AutoLazy.ProcessGossip = ProcessGossip
AutoLazy.ProcessGreeting = ProcessGreeting
AutoLazy.TryQuestChain = TryQuestChain
AutoLazy.ShouldAutoQuest = ShouldAutoQuest
AutoLazy.MatchesRepeatableRequirement = function(title, questID)
    local matched, rep = MatchesRepeatableRequirement(title, questID)
    if matched then return true, rep end
    return false
end
AutoLazy.NormalizeTitle = NormalizeTitle
AutoLazy.MatchesGossipTurnIn = MatchesGossipTurnIn
AutoLazy.GetPlayerItemCount = GetPlayerItemCount
AutoLazy.SetQuestSessionActive = function(val) questSessionActive = val end
AutoLazy.GetQuestSessionActive = function() return questSessionActive end
AutoLazy.SetCurrentQuestSessionToken = function(val) currentQuestSessionToken = val end
AutoLazy.GetCurrentQuestSessionToken = function() return currentQuestSessionToken end
AutoLazy.SetActiveNpcGUID = function(val) activeNpcGUID = val end
AutoLazy.GetActiveNpcGUID = function() return activeNpcGUID end
