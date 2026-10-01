"""Regression and integration tests for AutoLazy.
Requires lupa Lua 5.1.
Run: python -B tests/test_autolazy.py [directory-containing-lupa]
"""
from pathlib import Path
import re
import sys
import unittest

if len(sys.argv) > 1:
    sys.path.insert(0, sys.argv.pop(1))
from lupa.lua51 import LuaRuntime

AUTOLAZY_DIR = Path(__file__).resolve().parents[1]
AUTOLAZY_SOURCE = (AUTOLAZY_DIR / "AutoLazy.lua").read_text(encoding="utf-8")
AUTOLAZY_GUI_SOURCE = (AUTOLAZY_DIR / "AutoLazy_GUI.lua").read_text(encoding="utf-8")
AUTOLAZY_TOC = (AUTOLAZY_DIR / "AutoLazy.toc").read_text(encoding="utf-8")
README_SOURCE = (AUTOLAZY_DIR / "README.md").read_text(encoding="utf-8")
USER_GUIDE_SOURCE = (AUTOLAZY_DIR / "docs" / "USER_GUIDE.md").read_text(encoding="utf-8")


def create_autolazy_runtime(extra_lua=""):
    lua = LuaRuntime(unpack_returned_tuples=True)
    setup = """
        table.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
        CLASSIC_API_VERSION = 11515
        chatMessages = {}
        DEFAULT_CHAT_FRAME = {
            AddMessage = function(self, msg)
                table.insert(chatMessages, msg)
            end
        }
        UIParent = {}
        Minimap = {}
        UISpecialFrames = {}
        SlashCmdList = {}
        timers = {}
        C_Timer = {
            After = function(sec, cb)
                table.insert(timers, { delay = sec, callback = cb })
            end
        }
        CreateFrame = function(frameType, name, parent, template)
            local f = {
                name = name,
                parent = parent,
                scripts = {},
                SetScript = function(self, scr, handler) self.scripts[scr] = handler end,
                RegisterEvent = function(self, ev) end,
                IsObjectType = function(self, t) return true end,
                IsShown = function(self) return false end,
                Show = function(self) end,
                Hide = function(self) end,
                ClearAllPoints = function(self) end,
                SetPoint = function(self, ...) end,
                SetWidth = function(self, w) end,
                SetHeight = function(self, h) end,
                SetFrameStrata = function(self, s) end,
                SetMovable = function(self, m) end,
                SetToplevel = function(self, t) end,
                SetBackdrop = function(self, b) end,
                SetBackdropColor = function(self, ...) end,
                SetBackdropBorderColor = function(self, ...) end,
                SetHighlightTexture = function(self, t) end,
                SetNormalTexture = function(self, t) end,
                SetPushedTexture = function(self, t) end,
                SetDisabledTexture = function(self, t) end,
                EnableMouse = function(self, e) end,
                RegisterForDrag = function(self, ...) end,
                RegisterForClicks = function(self, ...) end,
                CreateFontString = function(self) return { SetPoint = function() end, SetText = function() end, SetJustifyH = function() end } end,
                CreateTexture = function(self) return { SetPoint = function() end, SetTexture = function() end, SetWidth = function() end, SetHeight = function() end } end,
            }
            if name then _G[name] = f end
            return f
        end
        function getglobal(n) return _G[n] end
        C_GossipInfo = {
            GetActiveQuests = function() return {} end,
            SelectActiveQuest = function(id) end,
            GetOptions = function() return {} end,
            SelectOption = function(id) end,
            GetAvailableQuests = function() return {} end,
            SelectAvailableQuest = function(id) end,
        }
        LOOT_ROLL_NEED = "%s has selected Need for: %s"
        LOOT_ROLL_NEED_SELF = "You have selected Need for: %s"
        LOOT_ROLL_GREED = "%s has selected Greed for: %s"
        LOOT_ROLL_GREED_SELF = "You have selected Greed for: %s"
        LOOT_ROLL_PASSED = "%s passed on: %s"
        LOOT_ROLL_PASSED_SELF = "You passed on: %s"
        LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s"
        LOOT_ROLL_ROLLED_GREED = "Greed Roll - %d for %s by %s"
        LOOT_ROLL_ALL_PASSED = "Everyone passed on: %s"
        LOOT_ROLL_WON = "%s won: %s"
        LOOT_ROLL_YOU_WON = "You won: %s"
    """
    lua.execute(setup + "\n" + extra_lua)
    lua.execute(AUTOLAZY_SOURCE)
    event_frame = lua.globals().AutoLazy_EventFrame
    if event_frame and event_frame.scripts and event_frame.scripts["OnEvent"]:
        event_frame.scripts["OnEvent"](event_frame, "ADDON_LOADED", "AutoLazy")
    return lua


class AutoLazyTests(unittest.TestCase):
    # ==================================================
    # LOOT REQUIREMENTS (Cases 1 - 8)
    # ==================================================
    def test_01_and_02_loot_need_greed_pass_and_numeric_rolls_suppressed(self):
        """1 & 2: Group Need/Greed/Pass selections and numeric rolls are suppressed, winner unsuppressed."""
        lua = create_autolazy_runtime()
        g = lua.globals()
        suppress = g.AutoLazy.ShouldSuppressLootMessage

        # Need / Greed / Pass selections
        self.assertTrue(suppress("Bob has selected Need for: [Staff of Jordan]"))
        self.assertTrue(suppress("You have selected Need for: [Staff of Jordan]"))
        self.assertTrue(suppress("Charlie has selected Greed for: [Staff of Jordan]"))
        self.assertTrue(suppress("You have selected Greed for: [Staff of Jordan]"))
        self.assertTrue(suppress("Alice passed on: [Staff of Jordan]"))
        self.assertTrue(suppress("You passed on: [Staff of Jordan]"))

        # Numeric rolls and summary lines
        self.assertTrue(suppress("Need Roll - 88 for [Staff of Jordan] by Bob"))
        self.assertTrue(suppress("Greed Roll - 45 for [Staff of Jordan] by Charlie"))
        self.assertTrue(suppress("Everyone passed on: [Staff of Jordan]"))

        # Winner lines are NOT suppressed so native client renders them directly
        self.assertFalse(suppress("Bob won: [Staff of Jordan]"))
        self.assertFalse(suppress("You won: [Staff of Jordan]"))

        # When CleanRollChat is disabled, intermediate chatter is unsuppressed
        g.AutoLazyDB.CleanRollChat = False
        self.assertFalse(suppress("Bob has selected Need for: [Staff of Jordan]"))
        self.assertFalse(suppress("Need Roll - 88 for [Staff of Jordan] by Bob"))

    def test_03_loot_final_winner_shown_natively(self):
        """3: Native winner message is preserved with full item link and winner name."""
        lua = create_autolazy_runtime()
        g = lua.globals()
        suppress = g.AutoLazy.ShouldSuppressLootMessage

        # Blizzard native winner lines pass through unsuppressed
        self.assertFalse(suppress("WinnerBob won: |cff0070dd|Hitem:19723:0:0:0|h[Primal Hakkari Aegis]|h|r"))
        self.assertFalse(suppress("You won: |cff0070dd|Hitem:19723:0:0:0|h[Primal Hakkari Aegis]|h|r"))

    def test_04_loot_all_pass_produces_no_winner_line(self):
        """4: When all players pass, intermediate line is suppressed."""
        lua = create_autolazy_runtime()
        g = lua.globals()
        suppress = g.AutoLazy.ShouldSuppressLootMessage

        self.assertTrue(suppress("Everyone passed on: [Staff of Jordan]"))

    def test_05_and_06_direct_item_and_money_loot_preserved(self):
        """5 & 6: Direct item loot and money messages are preserved."""
        lua = create_autolazy_runtime()
        g = lua.globals()
        suppress = g.AutoLazy.ShouldSuppressLootMessage

        # Direct item loot
        self.assertFalse(suppress("You receive loot: [Staff of Jordan]."))
        self.assertFalse(suppress("Bob receives loot: [Staff of Jordan]."))
        self.assertFalse(suppress("You receive item: [Peacebloom]x2."))

        # Money loot
        self.assertFalse(suppress("You loot 15 Silver, 30 Copper."))
        self.assertFalse(suppress("Your share of the loot is 12 Copper."))

    def test_07_and_08_clean_roll_chat_toggle_and_obsolete_config_purged(self):
        """7 & 8: CleanRollChat toggle is wired, old CleanLoot and AnnounceChat are purged."""
        lua = create_autolazy_runtime()
        g = lua.globals()
        db = g.AutoLazyDB

        self.assertTrue(db.CleanRollChat)
        self.assertIsNone(db.CleanLoot)
        self.assertIsNone(db.AnnounceChat)

        # Verify slash command /al clean toggles CleanRollChat
        cmd_fn = g.SlashCmdList["AUTOLAZY"]
        cmd_fn("clean")
        self.assertFalse(db.CleanRollChat)
        cmd_fn("cleanroll")
        self.assertTrue(db.CleanRollChat)

        # Verify own-roll chat announcement code is removed from START_LOOT_ROLL
        self.assertNotIn('AutoLazy_Print(actionName .. " on " .. itemLink', AUTOLAZY_SOURCE)
        self.assertNotIn("AnnounceChat = true", AUTOLAZY_SOURCE)
        self.assertNotIn("CleanLoot = true", AUTOLAZY_SOURCE)

    # ==================================================
    # DEPENDENCY REQUIREMENTS (Cases 9 - 10)
    # ==================================================
    def test_09_and_10_no_superwow_or_unitxp_dependency_claims(self):
        """9 & 10: Zero SuperWoW or UnitXP dependencies remain in code or metadata."""
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("""
            CLASSIC_API_VERSION = 11515
            SUPERWOW_VERSION = nil
            started = false
        """)
        start = AUTOLAZY_SOURCE.index("local MIN_CLASSIC_API = 11515")
        end = AUTOLAZY_SOURCE.index("local addonName", start)
        guard_chunk = AUTOLAZY_SOURCE[start:end] + "\nstarted = true\n"
        lua.execute(guard_chunk)
        self.assertTrue(lua.globals().started)

        # Below minimum ClassicAPI fails
        lua2 = LuaRuntime(unpack_returned_tuples=True)
        lua2.execute("""
            CLASSIC_API_VERSION = 11514
            started = false
            DEFAULT_CHAT_FRAME = { AddMessage = function() end }
        """)
        lua2.execute(guard_chunk)
        self.assertFalse(lua2.globals().started)

        # Zero references across all project files
        pattern = re.compile(r"SUPERWOW_VERSION|SuperWoW|UnitXP", re.IGNORECASE)
        self.assertIsNone(pattern.search(AUTOLAZY_TOC), "AutoLazy.toc contains stale engine dependencies")
        self.assertIsNone(pattern.search(AUTOLAZY_SOURCE), "AutoLazy.lua contains stale engine dependencies")
        self.assertIsNone(pattern.search(AUTOLAZY_GUI_SOURCE), "AutoLazy_GUI.lua contains stale engine dependencies")
        self.assertIsNone(pattern.search(README_SOURCE), "README.md contains stale engine dependencies")
        self.assertIsNone(pattern.search(USER_GUIDE_SOURCE), "USER_GUIDE.md contains stale engine dependencies")

    # ==================================================
    # GUI REQUIREMENTS (Cases 11 - 14)
    # ==================================================
    def test_11_12_13_clean_roll_chat_present_alerts_and_dungeon_reset_removed(self):
        """11, 12, 13: Clean Roll Chat is present in Tab 2; Chat Roll Alerts and Reset This Dungeon are removed."""
        self.assertIn("AutoLazy_OptCleanRollChat", AUTOLAZY_GUI_SOURCE)
        self.assertIn("Clean Roll Chat", AUTOLAZY_GUI_SOURCE)

        self.assertNotIn("AutoLazy_OptChat", AUTOLAZY_GUI_SOURCE)
        self.assertNotIn("Chat Roll Alerts", AUTOLAZY_GUI_SOURCE)

        self.assertNotIn("AutoLazy_BtnResetDefaults", AUTOLAZY_GUI_SOURCE)
        self.assertNotIn("Reset This Dungeon", AUTOLAZY_GUI_SOURCE)

    def test_14_reset_button_position_intact(self):
        """14: Reset Button Position functionality remains intact."""
        lua = create_autolazy_runtime()
        g = lua.globals()

        self.assertTrue(callable(g.AutoLazy_ResetActionButtonPos))
        g.AutoLazyDB.ButtonPos = {"x": 500, "y": 200}
        g.AutoLazy_ResetActionButtonPos()
        self.assertIsNone(g.AutoLazyDB.ButtonPos.x)
        self.assertIsNone(g.AutoLazyDB.ButtonPos.y)

        # Check /al resetpos slash command
        cmd_fn = g.SlashCmdList["AUTOLAZY"]
        cmd_fn("resetpos")
        self.assertIn("AutoLazy button position reset to top right.", list(g.chatMessages.values())[-1])

    # ==================================================
    # QUEST REQUIREMENTS (Cases 15 - 22)
    # ==================================================
    def test_15_one_ordinary_available_quest_auto_selects_safely(self):
        """15: Exactly one ordinary available quest is auto-selected safely."""
        extra = """
            selectedQuestID = nil
            C_GossipInfo.GetAvailableQuests = function()
                return { { questID = 42, title = "The Only Quest" } }
            end
            C_GossipInfo.SelectAvailableQuest = function(id)
                selectedQuestID = id
            end
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()

        g.AutoLazy.SetQuestSessionActive(True)
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "ACTION")
        self.assertEqual(g.selectedQuestID, 42)

    def test_16_multiple_ordinary_available_quests_do_not_select_first(self):
        """16: Multiple ordinary available quests do NOT auto-select quest 1 and wait for user."""
        extra = """
            selectedQuestID = nil
            C_GossipInfo.GetAvailableQuests = function()
                return {
                    { questID = 101, title = "Quest Alpha" },
                    { questID = 102, title = "Quest Beta" },
                    { questID = 103, title = "Quest Gamma" },
                }
            end
            C_GossipInfo.SelectAvailableQuest = function(id)
                selectedQuestID = id
            end
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()

        g.AutoLazy.SetQuestSessionActive(True)
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "WAITING")
        self.assertIsNone(g.selectedQuestID)

    def test_17_multiple_quests_manual_select_keeps_session_alive_and_accepts(self):
        """17: Manual selection of quest #2 keeps session alive and QUEST_DETAIL auto-accepts."""
        extra = """
            accepted = false
            function AcceptQuest()
                accepted = true
            end
            C_GossipInfo.GetAvailableQuests = function()
                return {
                    { questID = 101, title = "Quest Alpha" },
                    { questID = 102, title = "Quest Beta" },
                }
            end
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()
        ef = g.AutoLazy_EventFrame

        # User holds Shift when opening Gossip on NPC
        lua.execute("function IsShiftKeyDown() return true end")
        ef.scripts["OnEvent"](ef, "GOSSIP_SHOW")

        self.assertTrue(g.AutoLazy.GetQuestSessionActive())

        # ProcessGossip waited for user choice
        # Now user releases Shift and clicks Quest #2
        lua.execute("function IsShiftKeyDown() return false end")

        # GOSSIP_CLOSED fires when Gossip hides
        ef.scripts["OnEvent"](ef, "GOSSIP_CLOSED")

        # Session must survive during transition
        self.assertTrue(g.AutoLazy.GetQuestSessionActive())

        # QUEST_DETAIL fires for the chosen quest
        ef.scripts["OnEvent"](ef, "QUEST_DETAIL")
        self.assertTrue(g.accepted)

    def test_18_deterministic_repeatable_matching_auto_selects_even_when_not_first(self):
        """18: Deterministic repeatable quest auto-selects correctly even when not first in list."""
        extra = """
            selectedQuestID = nil
            C_GossipInfo.GetAvailableQuests = function()
                return {
                    { questID = 101, title = "Ordinary Quest" },
                    { questID = 202, title = "Minion's Scourgestones" },
                    { questID = 103, title = "Another Quest" },
                }
            end
            C_GossipInfo.SelectAvailableQuest = function(id)
                selectedQuestID = id
            end
            C_Item = {
                GetItemCount = function(id)
                    if id == 12840 then
                        return 20
                    end
                    return 0
                end
            }
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()

        g.AutoLazy.SetQuestSessionActive(True)
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "ACTION")
        self.assertEqual(g.selectedQuestID, 202)

    def test_19_multiple_ordinary_completed_quests_not_blindly_redirected(self):
        """19: Multiple ordinary completed quests are not blindly redirected to the first one."""
        extra = """
            selectedActiveID = nil
            C_GossipInfo.GetActiveQuests = function()
                return {
                    { questID = 301, title = "A Donation of Wool", isComplete = true },
                    { questID = 302, title = "A Donation of Silk", isComplete = true },
                }
            end
            C_GossipInfo.SelectActiveQuest = function(id)
                selectedActiveID = id
            end
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()

        g.AutoLazy.SetQuestSessionActive(True)
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "WAITING")
        self.assertIsNone(g.selectedActiveID)

    def test_20_selected_completed_quest_progress_and_reward_automation(self):
        """20: Selected completed quest proceeds through QUEST_PROGRESS and QUEST_COMPLETE."""
        extra = """
            completed = false
            rewardChosen = nil
            function IsQuestCompletable() return true end
            function CompleteQuest() completed = true end
            function GetNumQuestChoices() return 0 end
            function GetQuestReward(idx) rewardChosen = idx or 0 end
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()
        ef = g.AutoLazy_EventFrame

        g.AutoLazy.SetQuestSessionActive(True)

        ef.scripts["OnEvent"](ef, "QUEST_PROGRESS")
        self.assertTrue(g.completed)

        ef.scripts["OnEvent"](ef, "QUEST_COMPLETE")
        self.assertEqual(g.rewardChosen, 0)

    def test_21_reward_safety_pauses_on_multiple_choices(self):
        """21: Reward Safety pauses automation when multiple gear rewards exist."""
        extra = """
            rewardChosen = nil
            function GetNumQuestChoices() return 3 end
            function GetQuestReward(idx) rewardChosen = idx or 0 end
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()
        ef = g.AutoLazy_EventFrame

        g.AutoLazy.SetQuestSessionActive(True)

        # SafeRewards = true -> must pause
        g.AutoLazyDB.Quests.SafeRewards = True
        ef.scripts["OnEvent"](ef, "QUEST_COMPLETE")
        self.assertIsNone(g.rewardChosen)
        self.assertIn("Please choose your reward manually.", list(g.chatMessages.values())[-1])

        # SafeRewards = false -> takes choice 1
        g.AutoLazyDB.Quests.SafeRewards = False
        ef.scripts["OnEvent"](ef, "QUEST_COMPLETE")
        self.assertEqual(g.rewardChosen, 1)

    def test_22_stale_timer_cannot_act_on_another_npc(self):
        """22: Stale timer and session tokens cannot act on another NPC."""
        extra = """
            currentTargetGUID = "0xNPC1"
            function UnitGUID(unit)
                return currentTargetGUID
            end
            gossipCalls = 0
            C_GossipInfo = {
                GetActiveQuests = function() return {} end,
                GetOptions = function() return {} end,
                GetAvailableQuests = function()
                    gossipCalls = gossipCalls + 1
                    return {}
                end,
                SelectAvailableQuest = function(id) end,
            }
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()
        ef = g.AutoLazy_EventFrame

        # Session starts on NPC1
        lua.execute("function IsShiftKeyDown() return true end")
        ef.scripts["OnEvent"](ef, "GOSSIP_SHOW")
        token1 = g.AutoLazy.GetCurrentQuestSessionToken()
        self.assertEqual(g.AutoLazy.GetActiveNpcGUID(), "0xNPC1")
        self.assertTrue(g.AutoLazy.GetQuestSessionActive())
        initialCalls = g.gossipCalls

        # Player targets NPC2
        g.currentTargetGUID = "0xNPC2"
        ef.scripts["OnEvent"](ef, "PLAYER_TARGET_CHANGED")

        # Session is invalidated
        self.assertFalse(g.AutoLazy.GetQuestSessionActive())
        self.assertIsNone(g.AutoLazy.GetActiveNpcGUID())
        self.assertNotEqual(g.AutoLazy.GetCurrentQuestSessionToken(), token1)

        # Delayed callback with stale token1 fires
        g.AutoLazy.TryQuestChain(token1)
        self.assertEqual(g.gossipCalls, initialCalls)

    # ==================================================
    # UTILITY TESTS
    # ==================================================
    def test_blacklist_rejection(self):
        """Class relics and fashion coins must be rejected."""
        lua = create_autolazy_runtime()
        g = lua.globals()

        # Farm items match
        self.assertEqual(g.AutoLazy_GetItemRule("Zulian Coin"), "NEED")
        self.assertEqual(g.AutoLazy_GetItemRule("Stone Scarab"), "NEED")
        self.assertEqual(g.AutoLazy_GetItemRule("Corrupted Sand"), "NEED")

        # Blacklisted relics and tokens rejected
        self.assertIsNone(g.AutoLazy_GetItemRule("Idol of Rejuvenation"))
        self.assertIsNone(g.AutoLazy_GetItemRule("Idol of Brutality"))
        self.assertIsNone(g.AutoLazy_GetItemRule("Idol of the Moon"))
        self.assertIsNone(g.AutoLazy_GetItemRule("Fashion Coin"))

    def test_get_player_item_count_modern_item_ids_and_arrays(self):
        """Player item count supports single itemID, itemID arrays, and repeatable matching."""
        extra = """
            C_Item = {
                GetItemCount = function(id)
                    if id == 12840 then return 20 end
                    if id == 19707 then return 3 end -- Red Hakkari Bijou
                    return 0
                end
            }
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()

        # Single item ID lookup
        self.assertEqual(g.AutoLazy.GetPlayerItemCount(12840), 20)

        # Table / list of item IDs (any ZG bijou)
        self.assertEqual(g.AutoLazy.GetPlayerItemCount(lua.eval("{ 19707, 19708, 19709 }")), 3)

        # MatchesRepeatableRequirement using exact item IDs
        self.assertTrue(g.AutoLazy.MatchesRepeatableRequirement("Minion's Scourgestones"))
        self.assertTrue(g.AutoLazy.MatchesRepeatableRequirement("Hakkari Bijou"))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Invader's Scourgestone"))

    def test_close_tray_restores_when_collapse_addons_false(self):
        """Tray restores button states when collapse is disabled."""
        lua = create_autolazy_runtime()
        g = lua.globals()
        lua.execute("""
            AutoLazyDB.Tweaks.CollapseAddons = false
            AutoLazy_ButtonTray.isShown = true
            AutoLazy_ButtonTray.IsShown = function(self) return self.isShown end
            AutoLazy_ButtonTray.Hide = function(self) self.isShown = false end
            testBtnState = { shown = false }
            AutoLazy_CollapseAddons = function(enable)
                if not enable then
                    testBtnState.shown = true
                    AutoLazy_ButtonTray:Hide()
                end
            end
        """)
        g.AutoLazy_CloseTray()
        self.assertTrue(g.testBtnState.shown)
        self.assertFalse(g.AutoLazy_ButtonTray.isShown)

    def test_gossip_turn_in_keywords_and_bijous(self):
        """Direct gossip turn-ins match exact item IDs including ZG bijou destruction."""
        extra = """
            C_Item = {
                GetItemCount = function(id)
                    if id == 18945 then return 4 end -- Dark iron residue
                    if id == 19708 then return 1 end -- Blue Hakkari Bijou
                    return 0
                end
            }
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()

        # Lokhtos dark iron turn-in
        self.assertTrue(g.AutoLazy.MatchesGossipTurnIn("Turn in dark iron residue"))

        # ZG Altar of Zanza destroy bijou
        self.assertTrue(g.AutoLazy.MatchesGossipTurnIn("I wish to destroy a Blue Hakkari Bijou"))
        self.assertTrue(g.AutoLazy.MatchesGossipTurnIn("Destroy bijous"))

        # Submenu openers
        self.assertTrue(g.AutoLazy.MatchesGossipTurnIn("I want to turn in Scourgestones"))

    def test_get_player_item_count_direct_c_item(self):
        """GetPlayerItemCount delegates directly to C_Item.GetItemCount for numbers, tables, and strings."""
        extra = """
            c_item_calls = {}
            C_Item = {
                GetItemCount = function(target)
                    table.insert(c_item_calls, target)
                    if target == 60954 then return 3 end
                    if target == 12840 then return 10 end
                    if target == 12841 then return 5 end
                    if target == "bloodfang tail" then return 5 end
                    return 0
                end
            }
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()

        # Number target
        c1 = g.AutoLazy.GetPlayerItemCount(60954)
        self.assertEqual(c1, 3)

        # Table target (sums counts)
        c2 = g.AutoLazy.GetPlayerItemCount(lua.table_from([12840, 12841]))
        self.assertEqual(c2, 15)

        # String target (retained name-based fallback)
        c3 = g.AutoLazy.GetPlayerItemCount("craftsman's writ")
        self.assertEqual(c3, 0)

        # Nil / empty
        self.assertEqual(g.AutoLazy.GetPlayerItemCount(None), 0)
        self.assertEqual(g.AutoLazy.GetPlayerItemCount(""), 0)

    def test_telabim_repeatable_multi_item_requirements_and_bloodfang_removal(self):
        """Test questID isolation, multi-item requirements, wrong ID rejection, and bloodfang removal."""
        inventory = {}
        def set_inv(bananas, dust):
            inventory.clear()
            inventory[60954] = bananas
            inventory[11176] = dust

        extra = """
            C_Item = {
                GetItemCount = function(id)
                    return inv_counts[id] or 0
                end
            }
        """
        lua = create_autolazy_runtime(extra)
        g = lua.globals()
        g.inv_counts = inventory

        q40739_title = "The Tel'Abim Banana Transmutation"
        q40740_title = "Tel'Abim Banana Transmutations!"

        # 1. 40739 with 3 bananas + 1 dust -> qualifies
        set_inv(3, 1)
        m39, r39 = g.AutoLazy.MatchesRepeatableRequirement(q40739_title, 40739)
        self.assertTrue(m39)
        self.assertEqual(r39.questID, 40739)
        self.assertEqual(r39.requires[1].item, 60954)
        self.assertEqual(r39.requires[1].count, 3)
        self.assertEqual(r39.requires[2].item, 11176)
        self.assertEqual(r39.requires[2].count, 1)

        # 2. 40740 with 3 bananas + 1 dust -> does NOT qualify
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, 40740))

        # 3. 40740 with 15 bananas + 5 dust -> qualifies
        set_inv(15, 5)
        m40, r40 = g.AutoLazy.MatchesRepeatableRequirement(q40740_title, 40740)
        self.assertTrue(m40)
        self.assertEqual(r40.questID, 40740)
        self.assertEqual(r40.requires[1].count, 15)
        self.assertEqual(r40.requires[2].count, 5)

        # 4. 40739 with 15 bananas + 5 dust -> qualifies only when evaluating questID 40739
        m39_b, r39_b = g.AutoLazy.MatchesRepeatableRequirement(q40739_title, 40739)
        self.assertTrue(m39_b)
        self.assertEqual(r39_b.questID, 40739)
        self.assertEqual(r39_b.requires[1].count, 3)

        # 5. Wrong questID with identical/similar title -> must NOT match ID-based rule
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, 99999))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, 99999))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, None))

        # 6. No Dream Dust -> neither qualifies
        set_inv(15, 0)
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, 40739))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, 40740))

        set_inv(3, 0)
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, 40739))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, 40740))

        # 7. Legacy title-based matching works when questID not in rule (e.g. Scourgestones)
        set_inv(0, 0)
        inventory[12840] = 20
        m_scourge, r_scourge = g.AutoLazy.MatchesRepeatableRequirement("Minion's Scourgestones")
        self.assertTrue(m_scourge)
        self.assertEqual(r_scourge.item, 12840)

        # 8. Bloodfang Tail rule removed (not supported by OctoWoW DB)
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Bloodfang Tail Turn-in"))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("bloodfang tail"))

        # 9. ProcessGossip selects 40739 over 40740 when only 40739 requirements are met
        set_inv(3, 1)
        selected_id = []
        g.C_GossipInfo.SelectAvailableQuest = lambda qid: selected_id.append(qid)
        g.C_GossipInfo.GetAvailableQuests = lambda: lua.table_from([
            lua.table_from({"questID": 40740, "title": q40740_title}),
            lua.table_from({"questID": 40739, "title": q40739_title}),
        ])
        g.AutoLazy.SetQuestSessionActive(True)
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "ACTION")
        self.assertEqual(selected_id, [40739])

    def test_clean_roll_chat_gui_checkbox_and_status(self):
        """Clean roll chat syncs to GUI checkbox and reflects in status output."""
        lua = create_autolazy_runtime()
        g = lua.globals()

        g.AutoLazy_PrintStatus()
        all_msgs1 = "\n".join(list(g.chatMessages.values()))
        self.assertIn("Clean Roll: |cFF00FF00ON|r", all_msgs1)

        g.AutoLazyDB.CleanRollChat = False
        g.AutoLazy_PrintStatus()
        all_msgs2 = "\n".join(list(g.chatMessages.values()))
        self.assertIn("Clean Roll: |cFFFF2020OFF|r", all_msgs2)


if __name__ == "__main__":
    unittest.main()
