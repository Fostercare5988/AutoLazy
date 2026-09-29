"""Regression and integration tests for AutoLazy.
Requires lupa Lua 5.1.
Run: python -B tests/test_autolazy.py [directory-containing-lupa]
"""
from pathlib import Path
import sys
import unittest

if len(sys.argv) > 1:
    sys.path.insert(0, sys.argv.pop(1))
from lupa.lua51 import LuaRuntime

AUTOLAZY_DIR = Path(__file__).resolve().parents[1]
AUTOLAZY_SOURCE = (AUTOLAZY_DIR / "AutoLazy.lua").read_text(encoding="utf-8")

class AutoLazyTests(unittest.TestCase):
    def test_blacklist_rejection(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("""
            CLASSIC_API_VERSION = 11515
            SUPERWOW_VERSION = "2.2"
            AutoLazyDB = {
                Enabled = true,
                ItemRules = {
                    ["zg bijous"] = "NEED",
                    ["zg coins"] = "NEED",
                    ["aq20 scarabs"] = "NEED",
                    ["aq20 idols"] = "NEED",
                    ["corrupted sand"] = "NEED",
                }
            }
            string_find = string.find
            string_lower = string.lower
        """)
        # Extract tables and AutoLazy_GetItemRule
        start = AUTOLAZY_SOURCE.index("local BlacklistItems = {")
        end = AUTOLAZY_SOURCE.index("local questSessionActive = false", start)
        lua.execute(AUTOLAZY_SOURCE[start:end])

        g = lua.globals()
        # Farm items must match
        self.assertEqual(g.AutoLazy_GetItemRule("Zulian Coin"), "NEED")
        self.assertEqual(g.AutoLazy_GetItemRule("Stone Scarab"), "NEED")
        self.assertEqual(g.AutoLazy_GetItemRule("Corrupted Sand"), "NEED")
        self.assertEqual(g.AutoLazy_GetItemRule("Amber Idol"), "NEED")

        # Class relics and fashion coins must be rejected even though they contain "idol" or "coin"
        self.assertIsNone(g.AutoLazy_GetItemRule("Idol of Rejuvenation"))
        self.assertIsNone(g.AutoLazy_GetItemRule("Idol of Brutality"))
        self.assertIsNone(g.AutoLazy_GetItemRule("Idol of the Moon"))
        self.assertIsNone(g.AutoLazy_GetItemRule("Fashion Coin"))

    def test_get_player_item_count_fallback_on_partial_name(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("""
            string_find = string.find
            string_lower = string.lower
            -- Simulate GetItemCount existing in ClassicAPI environment
            -- but returning 0 for substring queries
            function GetItemCount(target)
                if target == "Red Hakkari Bijou" then return 3 end
                return 0
            end
            -- Mock container with 3 Red and 2 Blue Hakkari Bijous
            local bagSlots = {
                [0] = {
                    { link = "|cff1eff00[Red Hakkari Bijou]|r", count = 3 },
                    { link = "|cff1eff00[Blue Hakkari Bijou]|r", count = 2 },
                }
            }
            function GetContainerNumSlots(bag)
                return bag == 0 and #bagSlots[0] or 0
            end
            function GetContainerItemLink(bag, slot)
                return bagSlots[bag] and bagSlots[bag][slot] and bagSlots[bag][slot].link or nil
            end
            function GetContainerItemInfo(bag, slot)
                return nil, bagSlots[bag][slot].count
            end
        """)
        start = AUTOLAZY_SOURCE.index("local function GetPlayerItemCount(targetItem)")
        end = AUTOLAZY_SOURCE.index("local function MatchesRepeatableRequirement(title)", start)
        chunk = AUTOLAZY_SOURCE[start:end].replace("local function GetPlayerItemCount", "function GetPlayerItemCount")
        lua.execute(chunk)

        g = lua.globals()
        # Querying exact item uses GetItemCount
        self.assertEqual(g.GetPlayerItemCount("Red Hakkari Bijou"), 3)
        # Querying substring "bijou" must fall through to bag scan and sum to 5 (3 red + 2 blue)
        count = g.GetPlayerItemCount("bijou")
        self.assertEqual(count, 5)

    def test_quest_session_ownership_and_retry_invalidation(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("""
            currentQuestSessionToken = 0
            activeNpcGUID = "0xNPC1"
            questSessionActive = true
            GossipFrame = { IsShown = function(self) return true end }
            QuestFrameGreetingPanel = { IsShown = function(self) return false end }
            currentTargetGUID = "0xNPC1"
            function UnitGUID(unit)
                return currentTargetGUID
            end
            gossipProcessedCount = 0
            function ProcessGossip()
                gossipProcessedCount = gossipProcessedCount + 1
                return true
            end
            function ProcessGreeting()
                return true
            end
        """)
        # We will inject the updated TryQuestChain and verify token gating
        start = AUTOLAZY_SOURCE.index("local function TryQuestChain(")
        end = AUTOLAZY_SOURCE.index("-- Main Event Frame", start)
        chunk = AUTOLAZY_SOURCE[start:end].replace("local function TryQuestChain", "function TryQuestChain")
        lua.execute(chunk)

        g = lua.globals()
        # Scenario 1: Same NPC, matching token -> TryQuestChain succeeds and processes
        token1 = g.currentQuestSessionToken
        g.TryQuestChain(token1)
        self.assertEqual(g.gossipProcessedCount, 1)

        # Scenario 2: Target changes before deferred timer executes
        g.currentTargetGUID = "0xNPC2" # switched to another NPC
        g.TryQuestChain(token1) # called with old token and mismatched target GUID
        # Must NOT process gossip for the new NPC, and must reset session!
        self.assertEqual(g.gossipProcessedCount, 1)
        self.assertFalse(g.questSessionActive)

    def test_close_tray_restores_when_collapse_addons_false(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("""
            AutoLazyDB = {
                Tweaks = { CollapseAddons = false }
            }
            Minimap = { name = "Minimap" }
            btnState = {
                parent = Minimap,
                point = "CENTER",
                x = 10,
                y = 20,
                shown = true,
                alpha = 1,
            }
            testBtn = {
                _alOrigState = {
                    parent = Minimap,
                    point = "CENTER",
                    relativeTo = Minimap,
                    relativePoint = "CENTER",
                    xOfs = 10,
                    yOfs = 20,
                    alpha = 1,
                },
                SetParent = function(self, p) btnState.parent = p end,
                GetParent = function(self) return btnState.parent end,
                ClearAllPoints = function(self) end,
                SetPoint = function(self, pt, rel, relPt, x, y)
                    btnState.point = pt; btnState.x = x; btnState.y = y
                end,
                SetAlpha = function(self, a) btnState.alpha = a end,
                Show = function(self) btnState.shown = true end,
                Hide = function(self) btnState.shown = false end,
            }
            DiscoveredAddonList = { testBtn }
            trayShown = true
            trayFrame = {
                IsShown = function(self) return trayShown end,
                Hide = function(self) trayShown = false end,
            }
            function AutoLazy_CollapseAddons(enable)
                if not enable then
                    for _, btn in ipairs(DiscoveredAddonList) do
                        btn:SetParent(btn._alOrigState.parent)
                        btn:SetPoint(btn._alOrigState.point, btn._alOrigState.relativeTo, btn._alOrigState.relativePoint, btn._alOrigState.xOfs, btn._alOrigState.yOfs)
                        btn:Show()
                    end
                    trayFrame:Hide()
                end
            end
        """)
        start = AUTOLAZY_SOURCE.index("function AutoLazy_CloseTray()")
        end = AUTOLAZY_SOURCE.index("function AutoLazy_OpenTray()", start)
        lua.execute(AUTOLAZY_SOURCE[start:end])

        g = lua.globals()
        # In tray, parent is trayFrame
        g.testBtn.SetParent(g.testBtn, g.trayFrame)
        # Now close tray with CollapseAddons = false
        g.AutoLazy_CloseTray()
        # Button must be restored to Minimap parent, shown, and tray hidden
        self.assertEqual(g.btnState.parent.name, "Minimap")
        self.assertTrue(g.btnState.shown)
        self.assertFalse(g.trayShown)

if __name__ == "__main__":
    unittest.main()
