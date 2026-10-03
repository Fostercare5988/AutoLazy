"""Minimap state regression tests. Run with Lua 5.1, as test_autolazy.py.

These test observable frame state and hook lifecycles. They cannot certify
native C++ pointer safety, real tooltip rendering, or actual hit testing.
"""
import unittest
from test_autolazy import create_autolazy_runtime, TRAY_SOURCE, AUTOLAZY_TOC


class MinimapTrayTests(unittest.TestCase):
    def runtime(self, extra=''):
        return create_autolazy_runtime(extra)

    def check(self, lua, expression):
        self.assertTrue(lua.eval(expression), expression)

    def test_manifest_and_no_tree_traversal_or_reparenting(self):
        self.assertLess(AUTOLAZY_TOC.index('AutoLazy.lua'), AUTOLAZY_TOC.index('AutoLazy_MinimapTray.lua'))
        self.assertLess(AUTOLAZY_TOC.index('AutoLazy_MinimapTray.lua'), AUTOLAZY_TOC.index('AutoLazy_GUI.lua'))
        self.assertNotIn('GetChildren(', TRAY_SOURCE)
        self.assertNotIn('EnumerateFrames(', TRAY_SOURCE)
        self.assertNotIn('SetParent(', TRAY_SOURCE)
        self.assertNotIn('OnUpdate', TRAY_SOURCE)

    def test_arbitrary_names_all_minimap_roots_and_uiparent_anchor(self):
        lua = self.runtime('''
            a = MockButton("GuildLauncher", Minimap)
            b = MockButton("OtherLauncher", MinimapCluster)
            c = MockButton("UnknownLauncher", MinimapBackdrop)
            d = MockButton("ScreenLauncher", UIParent)
        ''')
        self.assertEqual(lua.eval('#AutoLazy_FindAddonButtons()'), 4)
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'a:GetParent() == Minimap and b:GetParent() == MinimapCluster')
        self.check(lua, 'c:GetParent() == MinimapBackdrop and d:GetParent() == UIParent')
        self.check(lua, 'a:IsVisible() and b:IsVisible() and c:IsVisible() and d:IsVisible()')

    def test_system_frames_and_dropdowns_excluded_before_native_queries(self):
        lua = self.runtime('''
            local names = {"MinimapZoomIn", "MinimapZoomOut", "GameTimeFrame",
                "TicketStatusFrame", "WorldStateFrame", "MiniMapMailFrame", "MiniMapTrackingFrame"}
            for _, name in ipairs(names) do MockButton(name) end
            DropDownList1 = { [0] = newproxy(), GetObjectType = function() error("unsafe") end,
                GetPoint = function() error("unsafe") end, GetName = function() error("unsafe") end }
            healthy = MockButton("MyMinimapButton")
        ''')
        self.assertEqual(lua.eval('#AutoLazy_FindAddonButtons()'), 1)
        self.check(lua, 'MinimapZoomIn:IsShown() and GameTimeFrame:IsShown()')

    def test_named_and_unnamed_late_creation(self):
        lua = self.runtime()
        lua.execute('late = MockButton("BrandNewLauncher"); anonymous = MockButton(nil); MockFlushTimers()')
        self.check(lua, 'not late:IsShown() and not anonymous:IsShown()')
        self.assertEqual(lua.eval('#AutoLazy_FindAddonButtons()'), 2)
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'late:IsVisible() and anonymous:IsVisible()')

    def test_explicit_registration_of_existing_private_anonymous_button(self):
        lua = self.runtime('''local private = MockButton(nil)
            function GetPrivateLauncher() return private end
            visible = MockButton("ZLauncher")''')
        # Existing anonymous frame only reachable from a private table is not
        # globally discoverable. Here the test explicitly hands it to AutoLazy.
        lua.execute('held = GetPrivateLauncher(); registered = AutoLazy.Tray.Register(held); MockFlushTimers()')
        self.check(lua, 'registered and not held:IsShown()')
        self.check(lua, 'AutoLazy_FindAddonButtons()[1] == held')

    def test_show_setshown_and_cached_native_show_stay_suppressed(self):
        lua = self.runtime('f = MockButton("PersistentMinimapButton"); cachedShow = f.Show; cachedSetShown = f.SetShown')
        lua.execute('f:Show(); f:SetShown(true); cachedShow(f); cachedSetShown(f, true)')
        self.check(lua, 'not f:IsShown()')
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'f:IsShown()')

    def test_full_state_multiple_anchors_and_original_methods_restored(self):
        lua = self.runtime('''
            f = MockButton("FullStateLauncher")
            f:SetPoint("BOTTOMRIGHT", MinimapCluster, "BOTTOMLEFT", -17, 23)
            f:SetAlpha(0.45); f:SetFrameStrata("LOW"); f:SetFrameLevel(6); f:EnableMouse(false)
            originalShow, originalSetPoint = f.Show, f.SetPoint
        ''')
        for _ in range(3):
            lua.execute('AutoLazy_OpenTray(); AutoLazy_CloseTray()')
            self.check(lua, 'f:GetNumPoints() == 2 and f:GetFrameStrata() == "LOW" and f:GetFrameLevel() == 6')
            self.check(lua, 'f:GetAlpha() == 0.45 and not f:IsMouseEnabled() and not f:IsShown()')
            self.check(lua, 'select(2, f:GetPoint(1)) == Minimap and select(2, f:GetPoint(2)) == MinimapCluster')
        lua.execute('AutoLazy_CollapseAddons(false)')
        self.check(lua, 'f:IsShown() and f.Show == originalShow and f.SetPoint == originalSetPoint')
        self.check(lua, 'rawget(f, "Show") == nil and rawget(f, "SetPoint") == nil')
        self.check(lua, 'AutoLazyDB.Tweaks._trayState == nil')

    def test_initially_hidden_icons_stay_hidden_after_release(self):
        lua = self.runtime('f = MockButton("DisabledLauncher"); f:Hide(); visible = MockButton("EnabledLauncher")')
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'not f:IsShown() and visible:IsVisible()')
        lua.execute('AutoLazy_CollapseAddons(false)')
        self.check(lua, 'not f:IsShown() and visible:IsShown()')

    def test_source_hide_while_collapsed_is_preserved(self):
        lua = self.runtime('f = MockButton("Launcher")')
        lua.execute('f:Hide(); AutoLazy_CollapseAddons(false)')
        self.check(lua, 'not f:IsShown()')

    def test_anchor_and_property_updates_while_docked_are_restored(self):
        lua = self.runtime('f = MockButton("MovingLauncher")')
        lua.execute('''
            AutoLazy_OpenTray()
            f:ClearAllPoints(); f:SetPoint("BOTTOM", "MinimapCluster", "TOP", 37, 19)
            f:SetFrameStrata("HIGH"); f:SetFrameLevel(12); f:SetAlpha(0.6); f:EnableMouse(false)
            MockFlushTimers()
        ''')
        self.check(lua, 'select(2, f:GetPoint(1)) == AutoLazy_ButtonTray and f:GetFrameStrata() == "DIALOG"')
        self.check(lua, 'f:IsMouseEnabled()')
        lua.execute('AutoLazy_CloseTray()')
        self.check(lua, 'f:GetNumPoints() == 1 and select(2, f:GetPoint(1)) == MinimapCluster')
        self.assertEqual(lua.eval('select(4, f:GetPoint(1))'), (37, 19))
        self.check(lua, 'f:GetFrameStrata() == "HIGH" and f:GetFrameLevel() == 12 and f:GetAlpha() == 0.6')
        self.check(lua, 'not f:IsMouseEnabled()')

    def test_native_click_hover_drag_scripts_and_legacy_context_preserved(self):
        lua = self.runtime('''
            f = MockButton("ScriptLauncher")
            clicks, hovers, drags = {}, 0, 0
            click = function() table.insert(clicks, arg1); assert(this == f) end
            enter = function() hovers = hovers + 1; assert(this == f) end
            drag = function() drags = drags + 1; assert(this == f) end
            f:SetScript("OnClick", click); f:SetScript("OnEnter", enter); f:SetScript("OnDragStart", drag)
        ''')
        lua.execute('''AutoLazy_OpenTray()
            MockRunScript(f, "OnClick", "LeftButton"); MockRunScript(f, "OnClick", "RightButton")
            MockRunScript(f, "OnEnter"); MockRunScript(f, "OnDragStart")
        ''')
        self.check(lua, 'clicks[1] == "LeftButton" and clicks[2] == "RightButton" and hovers == 1 and drags == 1')
        self.check(lua, 'f:GetScript("OnClick") == click and f:GetScript("OnEnter") == enter and f:GetScript("OnDragStart") == drag')

    def test_native_onshow_reanchor_does_not_displace_docked_button(self):
        lua = self.runtime('''
            f = MockButton("ReshowLauncher")
            f:SetScript("OnShow", function() this:ClearAllPoints(); this:SetPoint("CENTER", Minimap, "CENTER", 15, -8) end)
        ''')
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'select(2, f:GetPoint(1)) == AutoLazy_ButtonTray')

    def test_escape_close_restores_even_after_native_backdrop_hidden(self):
        lua = self.runtime('f = MockButton("EscapeLauncher")')
        lua.execute('AutoLazy_OpenTray(); AutoLazy_ButtonTray:Hide()')
        self.check(lua, 'not f:IsShown() and f:GetFrameStrata() == "MEDIUM"')
        self.check(lua, 'select(2, f:GetPoint(1)) == Minimap')

    def test_outside_click_deferred_inside_and_launcher_clicks_ignored(self):
        lua = self.runtime('f = MockButton("ClickLauncher")')
        lua.execute('''AutoLazy_OpenTray(); AutoLazy_ButtonTray.mouseOver = true
            MockRunScript(AutoLazy_TrayController, "OnEvent", "GLOBAL_MOUSE_UP"); MockFlushTimers()''')
        self.check(lua, 'AutoLazy_ButtonTray:IsShown()')
        lua.execute('''AutoLazy_ButtonTray.mouseOver = false; AutoLazy_ActionBtn.mouseOver = true
            MockRunScript(AutoLazy_TrayController, "OnEvent", "GLOBAL_MOUSE_UP"); MockFlushTimers()''')
        self.check(lua, 'AutoLazy_ButtonTray:IsShown()')
        lua.execute('''AutoLazy_ActionBtn.mouseOver = false
            MockRunScript(AutoLazy_TrayController, "OnEvent", "GLOBAL_MOUSE_UP")''')
        self.check(lua, 'AutoLazy_ButtonTray:IsShown()')
        lua.execute('MockFlushTimers()')
        self.check(lua, 'not AutoLazy_ButtonTray:IsShown()')

    def test_stale_outside_click_does_not_close_a_reopened_tray(self):
        lua = self.runtime('f = MockButton("EpochLauncher")')
        lua.execute('''AutoLazy_OpenTray()
            MockRunScript(AutoLazy_TrayController, "OnEvent", "GLOBAL_MOUSE_UP")
            AutoLazy_CloseTray(); AutoLazy_OpenTray(); MockFlushTimers()''')
        self.check(lua, 'AutoLazy_ButtonTray:IsShown()')

    def test_radio_and_lft_collapse_and_independent_hide_flags(self):
        lua = self.runtime('radio = MockButton("EBC_Minimap"); lfg = MockButton("LFTMinimapButton")')
        self.check(lua, 'not radio:IsShown() and not lfg:IsShown()')
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'radio:IsVisible() and lfg:IsVisible()')
        lua.execute('AutoLazyDB.Tweaks.HideRadio = true; AutoLazy_ApplySystemIconToggles()')
        self.check(lua, 'not radio:IsShown() and lfg:IsShown()')
        lua.execute('AutoLazy_CollapseAddons(false)')
        self.check(lua, 'not radio:IsShown() and lfg:IsShown()')
        lua.execute('AutoLazyDB.Tweaks.HideRadio = false; AutoLazy_ApplySystemIconToggles()')
        self.check(lua, 'radio:IsShown()')

    def test_atlasloot_container_single_slot_and_child_restoration(self):
        lua = self.runtime('''
            AtlasLootMinimapButtonFrame = CreateFrame("Frame", "AtlasLootMinimapButtonFrame", Minimap)
            root = AtlasLootMinimapButtonFrame; root:SetSize(32, 32)
            root:SetPoint("TOPLEFT", Minimap, "RIGHT", 2, 0); root:SetFrameLevel(6)
            leaf = MockButton("AtlasLootMinimapButton", root)
            leaf:ClearAllPoints(); leaf:SetPoint("TOPLEFT"); leaf:SetFrameLevel(7)
        ''')
        self.assertEqual(lua.eval('#AutoLazy_FindAddonButtons()'), 1)
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'leaf:IsVisible() and root:GetParent() == Minimap and leaf:GetParent() == root')
        lua.execute('AutoLazy_CloseTray()')
        self.check(lua, 'root:GetFrameLevel() == 6 and leaf:GetFrameLevel() == 7 and not root:IsShown()')
        self.check(lua, 'select(2, leaf:GetPoint(1)) == root')
        lua.execute('AutoLazy_CollapseAddons(false)')
        self.check(lua, 'root:IsShown() and leaf:IsShown()')

    def test_other_addon_hook_survives_release_and_reactivation(self):
        lua = self.runtime('f = MockButton("HookedLauncher")')
        lua.execute('''local previous = f.Show
            f.Show = function(self) hookCalls = (hookCalls or 0) + 1; return previous(self) end
            foreignHook = f.Show
            AutoLazy_CollapseAddons(false); assert(f.Show == foreignHook)
            AutoLazy_CollapseAddons(true); f:Show(); AutoLazy_OpenTray(); AutoLazy_CollapseAddons(false)
            f:Hide(); f:Show()
        ''')
        self.check(lua, 'f.Show == foreignHook and f:IsShown() and hookCalls > 0')

    def test_scaled_buttons_keep_scale_and_grid_anchor_offsets(self):
        lua = self.runtime('f = MockButton("ScaledLauncher"); f:SetScale(0.5)')
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'f:GetScale() == 0.5 and select(2, f:GetPoint(1)) == AutoLazy_ButtonTray')
        self.assertEqual(lua.eval('select(4, f:GetPoint(1))'), (50, -50))
        lua.execute('AutoLazy_CloseTray()')
        self.check(lua, 'f:GetScale() == 0.5')

    def test_late_addon_event_after_savedvariables_disabled_collapse(self):
        lua = self.runtime('AutoLazyDB = { Tweaks = { CollapseAddons = false } }')
        lua.execute('f = MockButton("LateDisabledLauncher"); MockRunScript(AutoLazy_TrayController, "OnEvent", "ADDON_LOADED", "OtherAddon"); MockFlushTimers()')
        self.check(lua, 'f:IsShown()')
        lua.execute('AutoLazy_CollapseAddons(true)')
        self.check(lua, 'not f:IsShown()')

    def test_extra_createframe_arguments_are_preserved(self):
        lua = self.runtime('''local nativeCreate = CreateFrame
            CreateFrame = function(kind, name, parent, template, extra)
                extraArgument = extra
                return nativeCreate(kind, name, parent, template)
            end
        ''')
        lua.execute('result = CreateFrame("Button", "ExtendedLauncher", Minimap, nil, 42)')
        self.check(lua, 'extraArgument == 42 and result == ExtendedLauncher')

    def test_reenable_captures_new_native_state(self):
        lua = self.runtime('f = MockButton("FreshSnapshotLauncher")')
        lua.execute('''AutoLazy_CollapseAddons(false)
            f:SetPoint("TOPLEFT", MinimapCluster, "BOTTOMLEFT", 55, -77)
            f:SetAlpha(0.75); f:SetFrameStrata("HIGH"); f:EnableMouse(false)
            AutoLazy_CollapseAddons(true); AutoLazy_OpenTray(); AutoLazy_CollapseAddons(false)''')
        self.check(lua, 'f:GetAlpha() == 0.75 and f:GetFrameStrata() == "HIGH" and not f:IsMouseEnabled()')
        self.check(lua, 'select(2, f:GetPoint(1)) == MinimapCluster')
        self.assertEqual(lua.eval('select(4, f:GetPoint(1))'), (55, -77))

    def test_ui_parent_launcher_name_without_standard_border(self):
        lua = self.runtime('''f = MockButton("CustomMinimapButton", UIParent)
            f:ClearAllPoints(); f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -170, -30)''')
        self.check(lua, 'not f:IsShown()')
        lua.execute('AutoLazy_OpenTray(); AutoLazy_CollapseAddons(false)')
        self.check(lua, 'select(2, f:GetPoint(1)) == UIParent and f:IsShown()')

    def test_incomplete_lua_proxy_does_not_prevent_healthy_registration(self):
        lua = self.runtime('''broken = MockButton("BrokenLauncher")
            broken.GetNumPoints = function() error("unsupported proxy") end
            healthy = MockButton("HealthyLauncher")''')
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'healthy:IsVisible() and broken:IsShown()')
        self.assertEqual(lua.eval('#AutoLazy_FindAddonButtons()'), 1)

    def test_release_event_keeps_menu_open_until_click_up(self):
        lua = self.runtime('f = MockButton("MenuLauncher")')
        lua.execute('''AutoLazy_OpenTray()
            MockRunScript(AutoLazy_TrayController, "OnEvent", "GLOBAL_MOUSE_DOWN"); MockFlushTimers()''')
        self.check(lua, 'AutoLazy_ButtonTray:IsShown()')
        lua.execute('''MockRunScript(AutoLazy_TrayController, "OnEvent", "GLOBAL_MOUSE_UP")
            MockFlushTimers()''')
        self.check(lua, 'not AutoLazy_ButtonTray:IsShown()')

    def test_clickable_pfquest_nodes_remain_on_minimap(self):
        lua = self.runtime('''pin = MockButton("pfMiniMapPin1")
            pin:SetSize(24, 24)
            unknownNode = MockButton("AnonymousQuestMarker")
            unknownNode.minimap = true; unknownNode.node = { title = "Quest" }
            hub = MockButton("pfQuestIcon")''')
        self.assertEqual(lua.eval('#AutoLazy_FindAddonButtons()'), 1)
        self.check(lua, 'pin:IsShown() and unknownNode:IsShown() and not hub:IsShown()')
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'select(2, pin:GetPoint(1)) == Minimap and select(2, unknownNode:GetPoint(1)) == Minimap')

    def test_repeated_hub_clicks_never_iterate_global_namespace(self):
        lua = self.runtime('f = MockButton("WarmLauncher")')
        lua.execute('''local nativePairs = pairs
            globalScans = 0
            pairs = function(t)
                if t == _G then globalScans = globalScans + 1 end
                return nativePairs(t)
            end
            for i = 1, 20 do MockRunScript(AutoLazy_ActionBtn, "OnClick", "LeftButton") end
        ''')
        self.assertEqual(lua.globals().globalScans, 0)
        self.check(lua, 'not AutoLazy_ButtonTray:IsShown() and not f:IsShown()')

    def test_new_button_discovery_only_inspects_pending_references(self):
        lua = self.runtime('f = MockButton("ExistingLauncher")')
        lua.execute('''late = MockButton("IncrementalLauncher")
            local nativePairs = pairs
            globalScans = 0
            pairs = function(t)
                if t == _G then globalScans = globalScans + 1 end
                return nativePairs(t)
            end
            MockFlushTimers()
        ''')
        self.assertEqual(lua.globals().globalScans, 0)
        self.check(lua, 'not late:IsShown()')

    def test_full_lifecycle_scan_supersedes_pending_incremental_request(self):
        lua = self.runtime('unobservedFactory = CreateFrame')
        lua.execute('''incremental = MockButton("IncrementalLauncher")
            fullOnly = unobservedFactory("Button", "CachedFactoryLauncher", Minimap)
            fullOnly:SetSize(32, 32); fullOnly:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
            fullOnly:SetNormalTexture("Interface\\\\Icons\\\\INV_Misc_QuestionMark")
            MockRunScript(AutoLazy_TrayController, "OnEvent", "ADDON_LOADED", "NewAddon")
            MockFlushTimers()
        ''')
        self.check(lua, 'not incremental:IsShown() and not fullOnly:IsShown()')


if __name__ == '__main__':
    unittest.main()
