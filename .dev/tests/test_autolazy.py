"""Regression and integration tests for AutoLazy.
Requires lupa Lua 5.1.
Run: python -B .dev/tests/test_autolazy.py [directory-containing-lupa]
"""
from pathlib import Path
import re
import sys
import unittest

if len(sys.argv) > 1:
    sys.path.insert(0, sys.argv.pop(1))
from lupa.lua51 import LuaRuntime

AUTOLAZY_DIR = Path(__file__).resolve().parents[2]
AUTOLAZY_SOURCE = (AUTOLAZY_DIR / "AutoLazy.lua").read_text(encoding="utf-8")
TRAY_SOURCE = (AUTOLAZY_DIR / "AutoLazy_MinimapTray.lua").read_text(encoding="utf-8")
FRAME_MOCK = (AUTOLAZY_DIR / ".dev" / "tests" / "frame_mock.lua").read_text(encoding="utf-8")
AUTOLAZY_GUI_SOURCE = (AUTOLAZY_DIR / "AutoLazy_GUI.lua").read_text(encoding="utf-8")
AUTOLAZY_TOC = (AUTOLAZY_DIR / "AutoLazy.toc").read_text(encoding="utf-8")
README_SOURCE = (AUTOLAZY_DIR / "README.md").read_text(encoding="utf-8")
USER_GUIDE_SOURCE = (AUTOLAZY_DIR / ".dev" / "USER_GUIDE.md").read_text(encoding="utf-8")


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
    lua.execute(setup + "\n" + FRAME_MOCK + "\n" + extra_lua)
    lua.execute(AUTOLAZY_SOURCE)
    lua.execute(TRAY_SOURCE)
    event_frame = lua.globals().AutoLazy_EventFrame
    if event_frame and event_frame.scripts and event_frame.scripts["OnEvent"]:
        event_frame.scripts["OnEvent"](event_frame, "ADDON_LOADED", "AutoLazy")
    lua.execute('MockRunScript(AutoLazy_TrayController, "OnEvent", "ADDON_LOADED", "AutoLazy"); MockFlushTimers()')
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
        self.assertIn("Hide loot roll spam", AUTOLAZY_GUI_SOURCE)

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
    def test_15_single_available_quest_requires_manual_selection(self):
        """15: A single available quest is left for manual acceptance."""
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
        self.assertFalse(res)
        self.assertIsNone(g.selectedQuestID)

    def test_16_multiple_ordinary_available_quests_do_not_select_first(self):
        """16: Multiple ordinary available quests do NOT auto-select quest 1 and leave acceptance manual."""
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
        self.assertFalse(res)
        self.assertIsNone(g.selectedQuestID)

    def test_17_manual_selection_never_triggers_automatic_acceptance(self):
        """17: A Shift-started session never automatically accepts QUEST_DETAIL."""
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
        self.assertFalse(g.accepted)

    def test_18_completed_repeatable_priority_preserved(self):
        """18: Completed repeatable quests retain inventory-based turn-in priority."""
        extra = """
            selectedQuestID = nil
            C_GossipInfo.GetActiveQuests = function()
                return {
                    { questID = 101, title = "Ordinary Quest", isComplete = true },
                    { questID = 202, title = "Minion's Scourgestones", isComplete = true },
                    { questID = 103, title = "Another Quest", isComplete = true },
                }
            end
            C_GossipInfo.SelectActiveQuest = function(id)
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
                GetActiveQuests = function()
                    gossipCalls = gossipCalls + 1
                    return {}
                end,
                GetOptions = function() return {} end,
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

    def test_removed_quest_settings_and_commands_cannot_reenable_features(self):
        lua = create_autolazy_runtime('''
            AutoLazyDB = { Quests = { AutoAccept = true, AlwaysActive = true,
                Enabled = true, AutoTurnIn = false, SafeRewards = false } }
        ''')
        g = lua.globals()
        self.assertEqual(set(g.AutoLazyDB.Quests.keys()), {"Enabled", "AutoTurnIn", "SafeRewards"})
        self.assertFalse(g.AutoLazyDB.Quests.AutoTurnIn)
        self.assertFalse(g.AutoLazyDB.Quests.SafeRewards)
        self.assertFalse(g.AutoLazy.ShouldAutoQuest())
        for command in ("accept", "always"):
            g.SlashCmdList["AUTOLAZY"](command)
        self.assertIsNone(g.AutoLazyDB.Quests.AutoAccept)
        self.assertIsNone(g.AutoLazyDB.Quests.AlwaysActive)
        help_message = list(g.chatMessages.values())[-1]
        self.assertNotIn("/al accept", help_message)
        self.assertNotIn("/al always", help_message)

    def test_available_quest_apis_never_called_even_with_shift(self):
        lua = create_autolazy_runtime('''
            function IsShiftKeyDown() return true end
            local function forbidden() error("Quest acceptance must stay manual") end
            C_GossipInfo.GetAvailableQuests = forbidden
            C_GossipInfo.SelectAvailableQuest = forbidden
            GetNumAvailableQuests, GetAvailableTitle, SelectAvailableQuest = forbidden, forbidden, forbidden
            AcceptQuest = forbidden
            function GetNumActiveQuests() return 0 end
        ''')
        lua.execute('''
            MockRunScript(AutoLazy_EventFrame, "OnEvent", "GOSSIP_SHOW")
            MockRunScript(AutoLazy_EventFrame, "OnEvent", "QUEST_GREETING")
            MockRunScript(AutoLazy_EventFrame, "OnEvent", "QUEST_DETAIL")
        ''')
        self.assertIsNone(lua.globals().AutoLazy_EventFrame.events["QUEST_DETAIL"])
        self.assertFalse(lua.globals().AutoLazy.ProcessGossip())
        self.assertFalse(lua.globals().AutoLazy.ProcessGreeting())

    def test_new_nonshift_npc_dialog_clears_previous_shift_session(self):
        for event_name in ("GOSSIP_SHOW", "QUEST_GREETING"):
            with self.subTest(event=event_name):
                lua = create_autolazy_runtime('''
                    selected = nil
                    C_GossipInfo.GetActiveQuests = function()
                        return {{ questID = 101, title = "Ordinary Quest", isComplete = true }}
                    end
                    C_GossipInfo.SelectActiveQuest = function(id) selected = id end
                    function GetNumActiveQuests() return 1 end
                    function GetActiveTitle() return "Ordinary Quest", true end
                    function SelectActiveQuest(index) selected = index end
                ''')
                g = lua.globals()
                g.AutoLazy.SetQuestSessionActive(True)
                g.MockRunScript(g.AutoLazy_EventFrame, "OnEvent", event_name)
                self.assertFalse(g.AutoLazy.GetQuestSessionActive())
                self.assertIsNone(g.selected)
                lua.execute('function IsShiftKeyDown() return true end')
                g.MockRunScript(g.AutoLazy_EventFrame, "OnEvent", event_name)
                self.assertTrue(g.AutoLazy.GetQuestSessionActive())
                self.assertIsNotNone(g.selected)

    def test_quest_menu_loads_with_only_remaining_compact_controls(self):
        lua = create_autolazy_runtime()
        lua.execute(AUTOLAZY_GUI_SOURCE)
        g = lua.globals()
        g.AutoLazy_ToggleGUI()
        g.MockRunScript(g.AutoLazy_BtnTab3, "OnClick")
        self.assertTrue(g.AutoLazy_TabQuestsFrame.IsVisible(g.AutoLazy_TabQuestsFrame))
        self.assertEqual(g.AutoLazyDB.SelectedTab, 3)
        self.assertIsNone(g.AutoLazy_QuestAccept)
        self.assertIsNone(g.AutoLazy_QuestAlways)
        self.assertEqual(g.AutoLazy_QuestMasterText.text, "Enable Shift-click")
        for widget_name, key in (("AutoLazy_QuestSafe", "SafeRewards"),
                                 ("AutoLazy_QuestTurnIn", "AutoTurnIn"),
                                 ("AutoLazy_QuestMaster", "Enabled")):
            widget = g[widget_name]
            self.assertTrue(widget.checked)
            widget.SetChecked(widget, False)
            g.MockRunScript(widget, "OnClick")
            self.assertFalse(g.AutoLazyDB.Quests[key])
            self.assertFalse(widget.checked)

    def test_options_open_refreshes_widgets_once(self):
        lua = create_autolazy_runtime()
        lua.execute(AUTOLAZY_GUI_SOURCE)
        lua.execute('''
            guiUpdates = 0
            local update = AutoLazy_UpdateGUI
            AutoLazy_UpdateGUI = function() guiUpdates = guiUpdates + 1; update() end
            AutoLazy_ToggleGUI()
        ''')
        self.assertEqual(lua.globals().guiUpdates, 1)
        lua.execute('AutoLazy_ToggleGUI(); AutoLazy_ToggleGUI()')
        self.assertEqual(lua.globals().guiUpdates, 2)

    def test_ui_created_once_and_hidden_refresh_does_no_work(self):
        lua = create_autolazy_runtime()
        g = lua.globals()
        count = g.MockFrameCount()
        lua.execute(AUTOLAZY_GUI_SOURCE)
        g.AutoLazy_UpdateGUI()
        self.assertIsNone(g.AutoLazy_OptionsFrame)
        self.assertEqual(g.MockFrameCount(), count)
        g.AutoLazy_ToggleGUI()
        built_count = g.MockFrameCount()
        # Initial Minimap and Quests refreshes must not populate Loot rows.
        self.assertIsNone(g.AutoLazy_ItemRow_1.iconTex.path)
        g.MockRunScript(g.AutoLazy_BtnTab3, "OnClick")
        self.assertIsNone(g.AutoLazy_ItemRow_1.iconTex.path)
        g.AutoLazy_ToggleGUI()
        g.AutoLazyDB.SelectedTab = 2
        for _ in range(50):
            g.AutoLazy_UpdateGUI()
        self.assertIsNone(g.AutoLazy_ItemRow_1.iconTex.path)
        g.AutoLazy_ToggleGUI()
        self.assertIsNotNone(g.AutoLazy_ItemRow_1.iconTex.path)
        self.assertEqual(g.MockFrameCount(), built_count)
        self.assertNotIn("OnUpdate", AUTOLAZY_GUI_SOURCE)
        self.assertNotIn("C_Timer", AUTOLAZY_GUI_SOURCE)

    def test_ui_does_not_query_zone_and_status_is_slash_only(self):
        lua = create_autolazy_runtime()
        lua.execute('''
            GetZoneText = function() error("GUI must not query the zone") end
            AutoLazy_ResolveCurrentDungeon = GetZoneText
        ''')
        lua.execute(AUTOLAZY_GUI_SOURCE)
        g = lua.globals()
        g.AutoLazyDB.SelectedTab = 2
        g.AutoLazy_ToggleGUI()
        g.MockRunScript(g.AutoLazy_DungeonBtn_4, "OnClick")
        g.AutoLazy_UpdateGUI()
        self.assertIsNone(g.AutoLazy_BtnStatus)
        self.assertNotIn("Zone:", AUTOLAZY_GUI_SOURCE)
        self.assertNotIn("GetZoneText", AUTOLAZY_GUI_SOURCE)
        self.assertNotIn("ResolveCurrentDungeon", AUTOLAZY_GUI_SOURCE)
        self.assertEqual(g.AutoLazy_BtnTab1.text, "Minimap")
        self.assertEqual(g.AutoLazy_OptionsFrame.backdropColor[4], 0.96)

    def test_loot_grid_choices_are_exclusive_and_survive_native_toggle(self):
        lua = create_autolazy_runtime()
        lua.execute(AUTOLAZY_GUI_SOURCE)
        g = lua.globals()
        g.AutoLazyDB.SelectedTab = 2
        g.AutoLazy_ToggleGUI()
        g.MockRunScript(g.AutoLazy_DungeonBtn_4, "OnClick")
        for i in range(1, 5):
            row = g[f"AutoLazy_ItemRow_{i}"]
            for action in ("MANUAL", "NEED", "GREED", "PASS", "PASS"):
                button = row.actionButtons[action]
                # Native CheckButton behavior happens before OnClick.
                button.SetChecked(button, not button.GetChecked(button))
                g.MockRunScript(button, "OnClick")
                self.assertEqual(g.AutoLazyDB.ItemRules[row.ruleKey], action)
                checked = [key for key in row.actionButtons.keys() if row.actionButtons[key].checked]
                self.assertEqual(checked, [action])
        # Changing dungeons reuses rows, hides unused rows and restores choices.
        g.MockRunScript(g.AutoLazy_DungeonBtn_1, "OnClick")
        self.assertFalse(g.AutoLazy_ItemRow_4.shown)
        g.MockRunScript(g.AutoLazy_DungeonBtn_4, "OnClick")
        self.assertTrue(g.AutoLazy_ItemRow_4.actionButtons.PASS.checked)

    def test_quest_dependencies_dim_without_discarding_preferences(self):
        lua = create_autolazy_runtime()
        lua.execute(AUTOLAZY_GUI_SOURCE)
        g = lua.globals()
        g.AutoLazyDB.SelectedTab = 3
        g.AutoLazy_ToggleGUI()
        g.AutoLazy_QuestMaster.SetChecked(g.AutoLazy_QuestMaster, False)
        g.MockRunScript(g.AutoLazy_QuestMaster, "OnClick")
        self.assertFalse(g.AutoLazy_QuestTurnIn.enabled)
        self.assertFalse(g.AutoLazy_QuestSafe.enabled)
        self.assertTrue(g.AutoLazyDB.Quests.SafeRewards)
        self.assertEqual(g.AutoLazy_QuestSafeText.font, "GameFontDisableSmall")
        g.AutoLazy_QuestMaster.SetChecked(g.AutoLazy_QuestMaster, True)
        g.MockRunScript(g.AutoLazy_QuestMaster, "OnClick")
        self.assertTrue(g.AutoLazy_QuestTurnIn.enabled)
        self.assertTrue(g.AutoLazy_QuestSafe.enabled)
        g.AutoLazy_QuestTurnIn.SetChecked(g.AutoLazy_QuestTurnIn, False)
        g.MockRunScript(g.AutoLazy_QuestTurnIn, "OnClick")
        self.assertFalse(g.AutoLazy_QuestSafe.enabled)
        self.assertTrue(g.AutoLazy_QuestSafe.checked)

    def test_tab_resize_preserves_top_anchor_after_drag(self):
        lua = create_autolazy_runtime()
        lua.execute(AUTOLAZY_GUI_SOURCE)
        g = lua.globals()
        g.AutoLazy_ToggleGUI()
        panel = g.AutoLazy_OptionsFrame
        panel.left, panel.top = 600, 700
        panel.SetScale(panel, 0.8)
        g.UIParent.SetScale(g.UIParent, 1.25)
        g.MockRunScript(panel, "OnDragStop")
        point = panel.GetPoint(panel)
        self.assertEqual(point[0], "TOPLEFT")
        self.assertAlmostEqual(point[3], 480)
        self.assertAlmostEqual(point[4], 560)
        heights = []
        for name in ("AutoLazy_BtnTab2", "AutoLazy_BtnTab3", "AutoLazy_BtnTab1"):
            g.MockRunScript(g[name], "OnClick")
            heights.append(panel.height)
            current = panel.GetPoint(panel)
            self.assertEqual(current[:1] + current[2:], point[:1] + point[2:])
            self.assertTrue(lua.eval('select(2, AutoLazy_OptionsFrame:GetPoint()) == UIParent'))
        self.assertLess(heights[1], heights[0])
        self.assertTrue(all(height < 520 for height in heights))

    def test_unchanged_loot_refresh_does_not_rewrite_item_content(self):
        lua = create_autolazy_runtime()
        lua.execute(AUTOLAZY_GUI_SOURCE)
        g = lua.globals()
        g.AutoLazyDB.SelectedTab = 2
        g.AutoLazy_ToggleGUI()
        lua.execute('''
            AutoLazy_ItemRow_1.iconTex.SetTexture = function() error("Unexpected icon rewrite") end
            AutoLazy_ItemRow_1.nameText.SetText = function() error("Unexpected item label rewrite") end
            for i = 1, 20 do AutoLazy_UpdateGUI() end
        ''')

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
        lua = create_autolazy_runtime('AutoLazyDB = { Tweaks = { CollapseAddons = false } }; testBtn = MockButton("GuildMinimapButton")')
        lua.execute('AutoLazy_OpenTray(); AutoLazy_CloseTray()')
        self.assertTrue(lua.eval('testBtn:IsShown()'))
        self.assertFalse(lua.eval('AutoLazy_ButtonTray:IsShown()'))
        self.assertTrue(lua.eval('select(2, testBtn:GetPoint(1)) == Minimap'))

    def test_tray_full_interactivity_and_outside_click(self):
        lua = create_autolazy_runtime('testBtn = MockButton("GuildMinimapButton")')
        lua.execute('AutoLazy_OpenTray()')
        self.assertTrue(lua.eval('testBtn:IsMouseEnabled() and testBtn:IsVisible()'))
        self.assertIsNone(lua.globals().AutoLazy_TrayDismisser)
        lua.execute('MockRunScript(AutoLazy_TrayController, "OnEvent", "GLOBAL_MOUSE_UP"); MockFlushTimers()')
        self.assertFalse(lua.eval('AutoLazy_ButtonTray:IsShown()'))

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
        g.C_GossipInfo.SelectActiveQuest = lambda qid: selected_id.append(qid)
        g.C_GossipInfo.GetActiveQuests = lambda: lua.table_from([
            lua.table_from({"questID": 40740, "title": q40740_title, "isComplete": True}),
            lua.table_from({"questID": 40739, "title": q40739_title, "isComplete": True}),
        ])
        g.AutoLazy.SetQuestSessionActive(True)
        res = g.AutoLazy.ProcessGossip()
        self.assertEqual(res, "ACTION")
        self.assertEqual(selected_id, [40739])

        # 10. ProcessGreeting selects 40739 over 40740 via exact title fallback when only 40739 met
        set_inv(3, 1)
        selected_greet_idx = []
        g.GetNumActiveQuests = lambda: 2
        g.GetActiveTitle = lambda idx: ([q40740_title, q40739_title][idx - 1], True)
        g.SelectActiveQuest = lambda idx: selected_greet_idx.append(idx)
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
        self.assertIn("Hide loot roll spam: |cFF00FF00ON|r", all_msgs1)

        g.AutoLazyDB.CleanRollChat = False
        g.AutoLazy_PrintStatus()
        all_msgs2 = "\n".join(list(g.chatMessages.values()))
        self.assertIn("Hide loot roll spam: |cFFFF2020OFF|r", all_msgs2)

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
        g.C_GossipInfo.SelectActiveQuest = lambda qid: selected_id.append(qid)
        g.C_GossipInfo.GetActiveQuests = lambda: lua.table_from([
            lua.table_from({"questID": 4806, "title": "Frostmaul E'ko", "isComplete": True}),
            lua.table_from({"questID": 4802, "title": "Winterfall E'ko", "isComplete": True}),
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
        g.C_GossipInfo.SelectActiveQuest = lambda qid: selected_id.append(qid)
        # Both accepted quests are completed; bulk is second in the list
        g.C_GossipInfo.GetActiveQuests = lambda: lua.table_from([
            lua.table_from({"questID": 40340, "title": "Corrupted Sand", "isComplete": True}),
            lua.table_from({"questID": 40341, "title": "Sand in Bulk", "isComplete": True}),
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
        lua = create_autolazy_runtime()
        lua.execute(AUTOLAZY_GUI_SOURCE)
        lua.globals().AutoLazy_ToggleGUI()
        self.assertEqual(lua.globals().AutoLazy_BtnTab2.text, "Loot")

    def test_octowow_pirate_radio_and_lft_buttons_handling(self):
        """Custom launcher classification and dedicated reversible suppression."""
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
        # Collapse still suppresses custom icons after their dedicated hide
        # flags are disabled; turning collapse off restores their native state.
        lua.globals().AutoLazy_CollapseAddons(False)
        self.assertTrue(lua.eval('ebc:IsShown() and lft:IsShown()'))
        self.assertEqual(lua.eval('select(4, ebc:GetPoint(1))'), (-20, -36))
        self.assertEqual(lua.eval('select(4, lft:GetPoint(1))'), (-22, -14))

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

    def test_radio_and_lft_available_when_dedicated_hide_flags_disabled(self):
        """Radio and LFT are available in the tray unless their hide flags are enabled."""
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

        lua.execute(r"""
            AutoLazyDB.Tweaks.HideRadio = false
            AutoLazyDB.Tweaks.HideLfg = false
            buttons = AutoLazy_FindAddonButtons()
        """)
        buttons_count = lua.eval("#buttons")
        self.assertEqual(buttons_count, 3, "Custom client launchers should also be available")
        first_btn_name = lua.eval("buttons[1]:GetName()")
        self.assertEqual(first_btn_name, "EBC_Minimap")

    def test_unrelated_unnamed_buttons_and_lua_getter_errors_rejected(self):
        """Reject unrelated buttons and handle Lua getter errors without frame-tree traversal."""
        lua = create_autolazy_runtime(r"""
            -- Button with no name (unnamed scratch widget)
            unnamed_btn = CreateFrame("Button", nil, UIParent)
            unnamed_btn.GetWidth = function() return 32 end
            unnamed_btn.GetHeight = function() return 32 end
            unnamed_btn.GetPoint = function() error("unsupported Lua anchor getter") end
            unnamed_btn.GetNumPoints = function() return 1 end

            -- Button whose GetPoint throws an error
            throwing_btn = CreateFrame("Button", "BuggyAddonMinimapButton", Minimap)
            throwing_btn.GetWidth = function() return 32 end
            throwing_btn.GetHeight = function() return 32 end
            throwing_btn.GetPoint = function() error("unsupported Lua anchor getter") end
            throwing_btn.GetNumPoints = function() error("unsupported Lua point count getter") end
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

        res = lua.execute(r"""
            local v_unnamed = AutoLazy.IsValidAddonButton(unnamed_btn)
            local v_anchored_throw = AutoLazy.IsAnchoredToMinimap(throwing_btn)
            local buttons = AutoLazy_FindAddonButtons()
            return v_unnamed, v_anchored_throw, uiparent_scanned, #buttons
        """)
        v_unnamed, v_anchored_throw, uiparent_scanned, btn_count = res

        self.assertFalse(v_unnamed, "Unrelated anonymous button lacks minimap launcher evidence")
        self.assertFalse(v_anchored_throw, "Lua GetPoint/GetNumPoints errors should be handled by pcall")
        self.assertFalse(uiparent_scanned, "UIParent:GetChildren must NEVER be scanned during button discovery")


if __name__ == "__main__":
    unittest.main()
