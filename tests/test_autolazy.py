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
                GetName = function(self) return self.name end,
                GetParent = function(self) return self.parent end,
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
                SetAlpha = function(self, a) self.alpha = a end,
                GetAlpha = function(self) return self.alpha or 1 end,
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
        LOOT_ROLL_START = "Rolling started on: %s"
        LOOT_ROLL_NEED = "%s has selected Need for: %s"
        LOOT_ROLL_NEED_SELF = "You have selected Need for: %s"
        LOOT_ROLL_GREED = "%s has selected Greed for: %s"
        LOOT_ROLL_GREED_SELF = "You have selected Greed for: %s"
        LOOT_ROLL_PASSED = "%s passed on: %s"
        LOOT_ROLL_PASSED_SELF = "You passed on: %s"
        LOOT_ROLL_ROLLED = "%s rolls a %d on: %s"
        LOOT_ROLL_ROLLED_SELF = "You roll a %d on: %s"
        LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s"
        LOOT_ROLL_ROLLED_NEED_SELF = "You roll a %d (Need) on: %s"
        LOOT_ROLL_ROLLED_GREED = "Greed Roll - %d for %s by %s"
        LOOT_ROLL_ROLLED_GREED_SELF = "You roll a %d (Greed) on: %s"
        LOOT_ROLL_ALL_PASSED = "Everyone passed on: %s"
        LOOT_ROLL_WON = "%s won: %s"
        LOOT_ROLL_YOU_WON = "You won: %s"
        LOOT_ROLL_WON_NO_SPAM_NEED = "%1$s won: %3$s |cff818181(Need - %2$d)|r"
        LOOT_ROLL_WON_NO_SPAM_GREED = "%1$s won: %3$s |cff818181(Greed - %2$d)|r"
        LOOT_ROLL_YOU_WON_NO_SPAM_NEED = "You won: %2$s |cff818181(Need - %1$d)|r"
        LOOT_ROLL_YOU_WON_NO_SPAM_GREED = "You won: %2$s |cff818181(Greed - %1$d)|r"
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

        # Start roll
        self.assertTrue(suppress("Rolling started on: [Staff of Jordan]"))

        # Need / Greed / Pass selections
        self.assertTrue(suppress("Bob has selected Need for: [Staff of Jordan]"))
        self.assertTrue(suppress("You have selected Need for: [Staff of Jordan]"))
        self.assertTrue(suppress("Charlie has selected Greed for: [Staff of Jordan]"))
        self.assertTrue(suppress("You have selected Greed for: [Staff of Jordan]"))
        self.assertTrue(suppress("Alice passed on: [Staff of Jordan]"))
        self.assertTrue(suppress("You passed on: [Staff of Jordan]"))

        # Intermediate numeric rolls and summary lines
        self.assertTrue(suppress("Bob rolls a 87 on: [Staff of Jordan]"))
        self.assertTrue(suppress("You roll a 42 on: [Staff of Jordan]"))
        self.assertTrue(suppress("Need Roll - 88 for [Staff of Jordan] by Bob"))
        self.assertTrue(suppress("You roll a 88 (Need) on: [Staff of Jordan]"))
        self.assertTrue(suppress("Greed Roll - 45 for [Staff of Jordan] by Charlie"))
        self.assertTrue(suppress("You roll a 45 (Greed) on: [Staff of Jordan]"))
        self.assertTrue(suppress("Everyone passed on: [Staff of Jordan]"))

        # Winner lines are NOT suppressed so native client renders them directly
        self.assertFalse(suppress("Bob won: [Staff of Jordan]"))
        self.assertFalse(suppress("You won: [Staff of Jordan]"))
        self.assertFalse(suppress("Bob won: [Staff of Jordan] |cff818181(Need - 88)|r"))
        self.assertFalse(suppress("Bob won: [Staff of Jordan] |cff818181(Greed - 45)|r"))
        self.assertFalse(suppress("You won: [Staff of Jordan] |cff818181(Need - 88)|r"))
        self.assertFalse(suppress("You won: [Staff of Jordan] |cff818181(Greed - 45)|r"))

        # When CleanRollChat is disabled, intermediate chatter is unsuppressed
        g.AutoLazyDB.CleanRollChat = False
        self.assertFalse(suppress("Rolling started on: [Staff of Jordan]"))
        self.assertFalse(suppress("Bob has selected Need for: [Staff of Jordan]"))
        self.assertFalse(suppress("Bob rolls a 87 on: [Staff of Jordan]"))
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

    def test_tray_full_interactivity_and_dismisser(self):
        """Addon Tray enables mouse on buttons and dismisser closes tray."""
        lua = create_autolazy_runtime(r"""
            testBtn = CreateFrame("Button", "AtlasLootMinimapButton", Minimap)
            testBtn.GetWidth = function() return 32 end
            testBtn.GetHeight = function() return 32 end
            testBtn.GetNormalTexture = function() return { GetTexture = function() return "Interface\\Icons\\INV_Box_01" end } end
        """)
        g = lua.globals()
        lua.execute(AUTOLAZY_SOURCE)
        lua.execute(r"""
            AutoLazy_TrayDismisser.Show = function(self) self.isShown = true end
            AutoLazy_TrayDismisser.Hide = function(self) self.isShown = false end
            AutoLazy_TrayDismisser.IsShown = function(self) return self.isShown == true end
            AutoLazy_ButtonTray.Show = function(self) self.isShown = true end
            AutoLazy_ButtonTray.Hide = function(self) self.isShown = false end
            AutoLazy_ButtonTray.IsShown = function(self) return self.isShown == true end

            AutoLazy_OpenTray()
            dismisserShown = AutoLazy_TrayDismisser:IsShown()
            AutoLazy_TrayDismisser.scripts.OnClick()
            trayHiddenAfterClick = not AutoLazy_ButtonTray:IsShown()
        """)
        self.assertTrue(g.dismisserShown, "Dismisser must show when tray opens")
        self.assertTrue(g.trayHiddenAfterClick, "Clicking dismisser must close tray")

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

        # 5. QUEST_GREETING path (questID is None): exact normalized title fallback
        # 40739 with 15 bananas + 5 dust matches 40739 rule
        m_greet39, r_greet39 = g.AutoLazy.MatchesRepeatableRequirement(q40739_title, None)
        self.assertTrue(m_greet39)
        self.assertEqual(r_greet39.questID, 40739)

        # 40740 with 15 bananas + 5 dust matches 40740 rule
        m_greet40, r_greet40 = g.AutoLazy.MatchesRepeatableRequirement(q40740_title, None)
        self.assertTrue(m_greet40)
        self.assertEqual(r_greet40.questID, 40740)

        # Wrong questID with identical/similar title -> must NOT match ID-based rule
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, 99999))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, 99999))

        # Generic / partial title without questID must NOT match (no fuzzy alias conflation)
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Tel'Abim Banana", None))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("The Tel'Abim Banana", None))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("tel'abim banana", None))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("banana", None))

        # QUEST_GREETING with only 3 bananas + 1 dust qualifies 40739 but NOT 40740
        set_inv(3, 1)
        self.assertTrue(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, None))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, None))

        # 6. No Dream Dust -> neither qualifies
        set_inv(15, 0)
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, 40739))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, 40740))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, None))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, None))

        set_inv(3, 0)
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, 40739))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, 40740))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40739_title, None))
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement(q40740_title, None))

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

        # 10. ProcessGreeting selects 40739 over 40740 via exact title fallback when only 40739 met
        set_inv(3, 1)
        selected_greet_idx = []
        g.GetNumAvailableQuests = lambda: 2
        g.GetAvailableTitle = lambda idx: [q40740_title, q40739_title][idx - 1]
        g.SelectAvailableQuest = lambda idx: selected_greet_idx.append(idx)
        g.AutoLazy.SetQuestSessionActive(True)
        res_greet = g.AutoLazy.ProcessGreeting()
        self.assertEqual(res_greet, "ACTION")
        self.assertEqual(selected_greet_idx, [2])

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

    def test_winterspring_eko_repeatable_requirements(self):
        """Winterspring E'ko requirements match 3x items with correct item IDs."""
        import collections
        inventory = collections.defaultdict(int)
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

        # 1. 3 Winterfall E'ko (item 12431) qualifies Winterfall E'ko, NOT Frostmaul
        inventory[12431] = 3
        m_wf, r_wf = g.AutoLazy.MatchesRepeatableRequirement("Winterfall E'ko")
        self.assertTrue(m_wf)
        self.assertEqual(r_wf.item, 12431)
        self.assertEqual(r_wf.minCount, 3)

        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Frostmaul E'ko"))

        # 2. 2 Winterfall E'ko fails minCount of 3
        inventory[12431] = 2
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Winterfall E'ko"))

        # 3. 3 Frostmaul E'ko (item 12436) qualifies Frostmaul E'ko, NOT Winterfall
        inventory.clear()
        inventory[12436] = 3
        m_fm2, r_fm2 = g.AutoLazy.MatchesRepeatableRequirement("Frostmaul E'ko")
        self.assertTrue(m_fm2)
        self.assertEqual(r_fm2.item, 12436)
        self.assertEqual(r_fm2.minCount, 3)
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Winterfall E'ko"))

        # 4. In ProcessGossip with Mau'ari offering Frostmaul and Winterfall:
        # Player has 3 Winterfall E'ko -> selects Winterfall E'ko (4802), never Frostmaul
        inventory.clear()
        inventory[12431] = 3
        selected_id = []
        g.C_GossipInfo.SelectAvailableQuest = lambda qid: selected_id.append(qid)
        g.C_GossipInfo.GetAvailableQuests = lambda: lua.table_from([
            lua.table_from({"questID": 4806, "title": "Frostmaul E'ko"}),
            lua.table_from({"questID": 4802, "title": "Winterfall E'ko"}),
        ])
        g.AutoLazy.SetQuestSessionActive(True)
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "ACTION")
        self.assertEqual(selected_id, [4802])

    def test_audited_repeatable_turnin_requirements(self):
        """Audited repeatable turn-ins match canonical 1.12 item counts and multi-item recipes."""
        import collections
        inventory = collections.defaultdict(int)
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

        # 1. Corruptor's Scourgestone: requires 1 (was wrongly 5)
        inventory[12843] = 1
        m_corr, r_corr = g.AutoLazy.MatchesRepeatableRequirement("Corruptor's Scourgestones")
        self.assertTrue(m_corr)
        self.assertEqual(r_corr.minCount, 1)

        # 2. Dark Iron Scraps: requires 30 (item 22528)
        inventory.clear()
        inventory[22528] = 30
        m_scraps, r_scraps = g.AutoLazy.MatchesRepeatableRequirement("Dark Iron Scraps")
        self.assertTrue(m_scraps)
        self.assertEqual(r_scraps.item, 22528)
        self.assertEqual(r_scraps.minCount, 30)

        # 3. Abyssal Scepter: requires 1 (was wrongly 3)
        inventory.clear()
        inventory[20515] = 1
        m_scep, r_scep = g.AutoLazy.MatchesRepeatableRequirement("Abyssal Scepters")
        self.assertTrue(m_scep)
        self.assertEqual(r_scep.minCount, 1)

        # 4. AV Ram Hide / Frostwolf Hide: requires 10 (was wrongly 20)
        inventory.clear()
        inventory[17643] = 10
        m_hide, r_hide = g.AutoLazy.MatchesRepeatableRequirement("Alterac Ram Hide")
        self.assertTrue(m_hide)
        self.assertEqual(r_hide.minCount, 10)
        inventory[17643] = 9
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Alterac Ram Hide"))

        # 5. ZG 3-coin requirement: requires 1 Zulian (19698) + 1 Razzashi (19699) + 1 Hakkari (19700)
        inventory.clear()
        inventory[19698] = 2 # 2 Zulian coins, but 0 Razzashi / Hakkari -> must FAIL
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Zulian, Razzashi, and Hakkari Coins"))
        inventory[19699] = 1
        inventory[19700] = 1 # Now has 1 of each -> must SUCCEED
        m_zg, _ = g.AutoLazy.MatchesRepeatableRequirement("Zulian, Razzashi, and Hakkari Coins")
        self.assertTrue(m_zg)

        # 6. Thorium Brotherhood Fiery Flux: Heavy Leather (10) + Incendosaur Scale (2) + Coal (1)
        inventory.clear()
        inventory[4234] = 10 # 10 Heavy leather alone -> must FAIL
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Restoring Fiery Flux Supplies via Heavy Leather"))
        inventory[11371] = 2 # 2 scales
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Restoring Fiery Flux Supplies via Heavy Leather")) # missing coal
        inventory[3857] = 1  # 1 coal -> all 3 satisfied -> must SUCCEED
        m_flux, _ = g.AutoLazy.MatchesRepeatableRequirement("Restoring Fiery Flux Supplies via Heavy Leather")
        self.assertTrue(m_flux)

        # 7. Fiery Flux via Iron (4 iron bar + 2 scales + 1 coal)
        inventory.clear()
        inventory[3575] = 4
        inventory[11371] = 2
        inventory[3857] = 1
        m_iron, _ = g.AutoLazy.MatchesRepeatableRequirement("Restoring Fiery Flux Supplies via Iron")
        self.assertTrue(m_iron)

        # 8. Fiery Flux via Kingsblood (4 kingsblood + 2 scales + 1 coal)
        inventory.clear()
        inventory[3356] = 4
        inventory[11371] = 2
        inventory[3857] = 1
        m_kb, _ = g.AutoLazy.MatchesRepeatableRequirement("Restoring Fiery Flux Supplies via Kingsblood")
        self.assertTrue(m_kb)

        # 9. Purged fake quests must not match
        inventory.clear()
        inventory[12739] = 30 # Dalson Cabinet Key
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Somber Hourglass"))
        inventory.clear()
        inventory[5466] = 1 # Scorpid Stinger
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Water Elemental Core"))
        inventory.clear()
        inventory[20520] = 1 # Dark Rune
        self.assertFalse(g.AutoLazy.MatchesRepeatableRequirement("Dark Rune"))

    def test_corrupted_sand_1x_and_10x_turnin_priority(self):
        """Corrupted Sand supports 10x bulk (40341) and 1x single (40340), prioritizing 10x when count >= 10."""
        import collections
        inventory = collections.defaultdict(int)
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

        selected_id = []
        g.C_GossipInfo.SelectAvailableQuest = lambda qid: selected_id.append(qid)
        # Dronormu offers single turn-in first in list, bulk second
        g.C_GossipInfo.GetAvailableQuests = lambda: lua.table_from([
            lua.table_from({"questID": 40340, "title": "Corrupted Sand"}),
            lua.table_from({"questID": 40341, "title": "Sand in Bulk"}),
        ])
        g.AutoLazy.SetQuestSessionActive(True)

        # Case 1: Player has 15 Corrupted Sand (50203) -> must prioritize 10x bulk (40341)
        inventory[50203] = 15
        selected_id.clear()
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "ACTION")
        self.assertEqual(selected_id, [40341])

        # Case 2: Player has 5 Corrupted Sand -> cannot do bulk, must select 1x (40340)
        inventory[50203] = 5
        selected_id.clear()
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "ACTION")
        self.assertEqual(selected_id, [40340])

        # Case 3: Player has 0 Corrupted Sand -> cannot turn in either, pauses safely
        inventory[50203] = 0
        selected_id.clear()
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "WAITING")
        self.assertEqual(selected_id, [])

        # Case 4: Direct gossip text matching
        inventory[50203] = 10
        self.assertTrue(g.AutoLazy.MatchesGossipTurnIn("Sand in Bulk"))
        inventory[50203] = 1
        self.assertFalse(g.AutoLazy.MatchesGossipTurnIn("Sand in Bulk"))
        self.assertTrue(g.AutoLazy.MatchesGossipTurnIn("Purify Corrupted Sand"))

    def test_menu_tab_renamed_to_loot(self):
        """Part 1: Menu Tab 2 is named 'Loot' (not 'Loot & Dungeons')."""
        self.assertIn('btnTab2:SetText("Loot")', AUTOLAZY_GUI_SOURCE)
        self.assertNotIn('btnTab2:SetText("Loot & Dungeons")', AUTOLAZY_GUI_SOURCE)

    def test_octowow_pirate_radio_and_lft_buttons_handling(self):
        """Part 2: EBC_Minimap and LFTMinimapButton are correctly classified and excluded from Addon Tray."""
        lua = create_autolazy_runtime(r"""
            ebc = CreateFrame("Button", "EBC_Minimap", Minimap)
            ebc.point = "TOPLEFT"
            ebc.xOfs = -20
            ebc.yOfs = -36
            ebc.GetPoint = function(self, idx) return self.point, Minimap, nil, self.xOfs, self.yOfs end
            ebc.GetNumPoints = function(self) return 1 end
            ebc.GetParent = function(self) return Minimap end
            ebc.GetWidth = function(self) return 33 end
            ebc.GetHeight = function(self) return 33 end
            ebc.GetRegions = function(self)
                return {
                    GetTexture = function() return "Interface\\Icons\\INV_Gizmo_GoblinBoomBox_01" end,
                    GetObjectType = function() return "Texture" end,
                }
            end

            lft = CreateFrame("Button", "LFTMinimapButton", Minimap)
            lft.point = "LEFT"
            lft.xOfs = -22
            lft.yOfs = -14
            lft.GetPoint = function(self, idx) return self.point, Minimap, nil, self.xOfs, self.yOfs end
            lft.GetNumPoints = function(self) return 1 end
            lft.GetParent = function(self) return Minimap end
            lft.GetWidth = function(self) return 33 end
            lft.GetHeight = function(self) return 33 end
            lft.GetRegions = function(self)
                return {
                    GetTexture = function() return "Interface\\FrameXML\\LFT\\images\\eye\\battlenetworking0" end,
                    GetObjectType = function() return "Texture" end,
                }
            end
        """)
        lua.execute(AUTOLAZY_SOURCE)

        res = lua.execute(r"""
            local isRadio = AutoLazy.IsRadioFrame(ebc)
            local isLfg = AutoLazy.IsLfgFrame(lft)
            local validEbc = AutoLazy.IsValidAddonButton(ebc)
            local validLft = AutoLazy.IsValidAddonButton(lft)
            return isRadio, isLfg, validEbc, validLft
        """)
        isRadio, isLfg, validEbc, validLft = res
        self.assertTrue(isRadio, "EBC_Minimap must be recognized by IsRadioFrame")
        self.assertTrue(isLfg, "LFTMinimapButton must be recognized by IsLfgFrame")
        self.assertFalse(validEbc, "EBC_Minimap must NOT be treated as a generic addon button")
        self.assertFalse(validLft, "LFTMinimapButton must NOT be treated as a generic addon button")

        lua.execute(r"""
            AutoLazyDB.Tweaks.HideRadio = true
            AutoLazyDB.Tweaks.HideLfg = true
            AutoLazy.SetFrameSuppressed(ebc, true)
            AutoLazy.SetFrameSuppressed(lft, true)

            AutoLazyDB.Tweaks.HideRadio = false
            AutoLazyDB.Tweaks.HideLfg = false
            AutoLazy.SetFrameSuppressed(ebc, false)
            AutoLazy.SetFrameSuppressed(lft, false)
        """)
        st_ebc = lua.eval("ebc._alOrigState")
        st_lft = lua.eval("lft._alOrigState")
        self.assertEqual(st_ebc["point"], "TOPLEFT")
        self.assertEqual(st_ebc["relativePoint"], "TOPLEFT")
        self.assertEqual(st_ebc["xOfs"], -20)
        self.assertEqual(st_ebc["yOfs"], -36)

        self.assertEqual(st_lft["point"], "LEFT")
        self.assertEqual(st_lft["relativePoint"], "LEFT")
        self.assertEqual(st_lft["xOfs"], -22)
        self.assertEqual(st_lft["yOfs"], -14)

    def test_universal_dynamic_minimap_button_discovery(self):
        """Dynamic scanner identifies minimap buttons regardless of addon name, parentage (Minimap/UIParent), or keywords."""
        lua = create_autolazy_runtime(r"""
            -- Button 1: ItemRack_IconFrame (contains "icon_", parent is Minimap)
            btn_itemrack = CreateFrame("Button", "ItemRack_IconFrame", Minimap)
            btn_itemrack.GetWidth = function() return 32 end
            btn_itemrack.GetHeight = function() return 32 end
            btn_itemrack.GetNormalTexture = function() return { GetTexture = function() return "Interface\\AddOns\\ItemRack\\ItemRack-Icon" end } end

            -- Button 2: SpellAlertMinimapButton (contains "spell", but is a minimap button)
            btn_spell = CreateFrame("Button", "SpellAlertMinimapButton", Minimap)
            btn_spell.GetWidth = function() return 32 end
            btn_spell.GetHeight = function() return 32 end
            btn_spell.GetNormalTexture = function() return { GetTexture = function() return "Interface\\Icons\\Spell_Fire_Fireball" end } end

            -- Button 3: SmartBuffMinimapButton (contains "buff", but is a minimap button)
            btn_buff = CreateFrame("Button", "SmartBuffMinimapButton", Minimap)
            btn_buff.GetWidth = function() return 32 end
            btn_buff.GetHeight = function() return 32 end
            btn_buff.GetNormalTexture = function() return { GetTexture = function() return "Interface\\Icons\\Spell_Nature_Rejuvenation" end } end

            -- Button 4: Parented to UIParent, anchored to Minimap
            btn_uiparent_anchored = CreateFrame("Button", "CustomGuildAddonBtn", UIParent)
            btn_uiparent_anchored.GetWidth = function() return 32 end
            btn_uiparent_anchored.GetHeight = function() return 32 end
            btn_uiparent_anchored.GetPoint = function() return "CENTER", Minimap, "CENTER", 10, -20 end
            btn_uiparent_anchored.GetNumPoints = function() return 1 end
            btn_uiparent_anchored.GetNormalTexture = function() return { GetTexture = function() return "Interface\\Icons\\INV_Misc_QuestionMark" end } end

            -- Button 5: Parented to UIParent with circular tracking border
            btn_uiparent_border = CreateFrame("Button", "CustomCircularBtn", UIParent)
            btn_uiparent_border.GetWidth = function() return 32 end
            btn_uiparent_border.GetHeight = function() return 32 end
            btn_uiparent_border.GetRegions = function()
                return {
                    GetTexture = function() return "Interface\\Minimap\\MiniMap-TrackingBorder" end,
                    GetObjectType = function() return "Texture" end,
                }
            end

            -- Button 6: Standard UI action button parented to UIParent (MUST BE REJECTED)
            btn_action = CreateFrame("Button", "ActionButton1", UIParent)
            btn_action.GetWidth = function() return 36 end
            btn_action.GetHeight = function() return 36 end
            btn_action.GetPoint = function() return "BOTTOM", UIParent, "BOTTOM", 0, 0 end
            btn_action.GetNumPoints = function() return 1 end
            btn_action.GetNormalTexture = function() return { GetTexture = function() return "Interface\\Icons\\Ability_Warrior_Charge" end } end

            -- Button 7: Close button on a dialog (MUST BE REJECTED)
            btn_close = CreateFrame("Button", "CustomDialogCloseButton", UIParent)
            btn_close.GetWidth = function() return 24 end
            btn_close.GetHeight = function() return 24 end
            btn_close.GetPoint = function() return "TOPRIGHT", UIParent, "TOPRIGHT", -10, -10 end
            btn_close.GetNumPoints = function() return 1 end
            btn_close.GetNormalTexture = function() return { GetTexture = function() return "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" end } end
        """)
        lua.execute(AUTOLAZY_SOURCE)

        res = lua.execute(r"""
            return AutoLazy.IsValidAddonButton(btn_itemrack),
                   AutoLazy.IsValidAddonButton(btn_spell),
                   AutoLazy.IsValidAddonButton(btn_buff),
                   AutoLazy.IsValidAddonButton(btn_uiparent_anchored),
                   AutoLazy.IsValidAddonButton(btn_uiparent_border),
                   AutoLazy.IsValidAddonButton(btn_action),
                   AutoLazy.IsValidAddonButton(btn_close)
        """)
        v_itemrack, v_spell, v_buff, v_anchored, v_border, v_action, v_close = res
        self.assertTrue(v_itemrack, "ItemRack_IconFrame must be valid")
        self.assertTrue(v_spell, "SpellAlertMinimapButton must be valid")
        self.assertTrue(v_buff, "SmartBuffMinimapButton must be valid")
        self.assertTrue(v_anchored, "UIParent button anchored to Minimap must be valid")
        self.assertTrue(v_border, "UIParent button with TrackingBorder must be valid")
        self.assertFalse(v_action, "ActionButton1 must NOT be valid")
        self.assertFalse(v_close, "Close button must NOT be valid")

    def test_radio_and_lft_never_swallowed_into_addon_tray(self):
        """Even when HideRadio=false and HideLfg=false, Radio and LFT buttons are never in the Addon Tray."""
        lua = create_autolazy_runtime(r"""
            ebc = CreateFrame("Button", "EBC_Minimap", Minimap)
            ebc.GetWidth = function() return 33 end
            ebc.GetHeight = function() return 33 end
            ebc.GetRegions = function()
                return { GetTexture = function() return "Interface\\Icons\\INV_Gizmo_GoblinBoomBox_01" end }
            end

            lft = CreateFrame("Button", "LFTMinimapButton", Minimap)
            lft.GetWidth = function() return 33 end
            lft.GetHeight = function() return 33 end
            lft.GetRegions = function()
                return { GetTexture = function() return "Interface\\FrameXML\\LFT\\images\\eye\\battlenetworking0" end }
            end

            valid_addon = CreateFrame("Button", "MyGuildAddonMinimapButton", Minimap)
            valid_addon.GetWidth = function() return 32 end
            valid_addon.GetHeight = function() return 32 end
            valid_addon.GetNormalTexture = function()
                return { GetTexture = function() return "Interface\\Icons\\INV_Misc_Gem_Ruby_01" end }
            end

            Minimap.GetChildren = function() return ebc, lft, valid_addon end
        """)
        lua.execute(AUTOLAZY_SOURCE)

        lua.execute(r"""
            AutoLazyDB.Tweaks.HideRadio = false
            AutoLazyDB.Tweaks.HideLfg = false
            buttons = AutoLazy_FindAddonButtons()
        """)
        buttons_count = lua.eval("#buttons")
        self.assertEqual(buttons_count, 1, "Only the 3rd-party user addon should be found")
        first_btn_name = lua.eval("buttons[1]:GetName()")
        self.assertEqual(first_btn_name, "MyGuildAddonMinimapButton")

    def test_unnamed_and_dangling_frames_safe_against_crash(self):
        """Unnamed buttons and dangling anchor throws are rejected and protected against Error 132 crashes."""
        lua = create_autolazy_runtime(r"""
            -- Button with no name (unnamed scratch widget)
            unnamed_btn = CreateFrame("Button", nil, UIParent)
            unnamed_btn.GetWidth = function() return 32 end
            unnamed_btn.GetHeight = function() return 32 end
            unnamed_btn.GetPoint = function() error("dangling anchor C++ fault simulated") end
            unnamed_btn.GetNumPoints = function() return 1 end

            -- Button whose GetPoint throws an error
            throwing_btn = CreateFrame("Button", "BuggyAddonMinimapButton", Minimap)
            throwing_btn.GetWidth = function() return 32 end
            throwing_btn.GetHeight = function() return 32 end
            throwing_btn.GetPoint = function() error("Simulated dangling anchor fault") end
            throwing_btn.GetNumPoints = function() error("Simulated vtable null fault") end
            throwing_btn.GetNormalTexture = function() return { GetTexture = function() return "Interface\\Icons\\INV_Misc_QuestionMark" end } end

            -- Button on UIParent (must NOT be scanned via UIParent:GetChildren)
            uiparent_child = CreateFrame("Button", "UIParentRandomChildButton", UIParent)
            uiparent_child.GetWidth = function() return 32 end
            uiparent_child.GetHeight = function() return 32 end
            uiparent_child.GetNormalTexture = function() return { GetTexture = function() return "Interface\\Icons\\INV_Misc_QuestionMark" end } end

            uiparent_scanned = false
            UIParent.GetChildren = function()
                uiparent_scanned = true
                return uiparent_child
            end
            Minimap.GetChildren = function() return throwing_btn end
        """)
        lua.execute(AUTOLAZY_SOURCE)

        res = lua.execute(r"""
            local v_unnamed = AutoLazy.IsValidAddonButton(unnamed_btn)
            local v_anchored_throw = AutoLazy.IsAnchoredToMinimap(throwing_btn)
            local buttons = AutoLazy_FindAddonButtons()
            return v_unnamed, v_anchored_throw, uiparent_scanned, #buttons
        """)
        v_unnamed, v_anchored_throw, uiparent_scanned, btn_count = res

        self.assertFalse(v_unnamed, "Unnamed button must be rejected immediately to avoid scratch frame vtable dereference")
        self.assertFalse(v_anchored_throw, "Throwing GetPoint/GetNumPoints must be caught safely by pcall")
        self.assertFalse(uiparent_scanned, "UIParent:GetChildren must NEVER be scanned during button discovery")


if __name__ == "__main__":
    unittest.main()
