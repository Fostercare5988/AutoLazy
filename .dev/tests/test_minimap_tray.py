"""Minimap state regression tests. Run with Lua 5.1, as test_autolazy.py.

These test observable frame state and hook lifecycles. They cannot certify
native C++ pointer safety, real tooltip rendering, or actual hit testing.
"""
import unittest
from test_autolazy import create_autolazy_runtime, TRAY_SOURCE, AUTOLAZY_TOC, AUTOLAZY_GUI_SOURCE


class MinimapTrayTests(unittest.TestCase):
    def runtime(self, extra=''):
        return create_autolazy_runtime(extra)

    def check(self, lua, expression):
        self.assertTrue(lua.eval(expression), expression)

    def test_repeated_show_requests_do_not_schedule_layout_or_skip_native_methods(self):
        lua = self.runtime('''f = MockButton("PersistentLauncher"); other = MockButton("OtherLauncher")
            timerRequests = 0
            local after = C_Timer.After
            C_Timer.After = function(delay, callback)
                timerRequests = timerRequests + 1; return after(delay, callback)
            end
        ''')
        lua.execute('''AutoLazy_OpenTray(); MockFlushTimers(); previousShows = f.showCalls; timerRequests = 0
            for i = 1, 60 do f:Show(); f:SetShown(true); MockFlushTimers() end
        ''')
        self.assertEqual(lua.eval('f.showCalls - previousShows'), 120)
        self.assertEqual(lua.globals().timerRequests, 0)
        lua.execute('f:Hide(); MockFlushTimers()')
        self.check(lua, 'not f:IsShown() and other:IsVisible()')
        lua.execute('f:Show(); MockFlushTimers()')
        self.check(lua, 'f:IsVisible() and other:IsVisible()')

    def test_docking_skips_unchanged_properties_but_repairs_native_overwrites(self):
        lua = self.runtime('''f = MockButton("StableLauncher"); cached = {}; propertyWrites = 0
            for _, name in ipairs({"SetFrameStrata", "SetFrameLevel", "SetAlpha", "EnableMouse", "SetWidth", "SetHeight"}) do
                local native = f[name]; cached[name] = native
                f[name] = function(self, value)
                    propertyWrites = propertyWrites + 1; return native(self, value)
                end
            end
        ''')
        lua.execute('AutoLazy_OpenTray(); MockFlushTimers(); propertyWrites = 0; AutoLazy_OpenTray()')
        # The dimensions are intentionally reapplied after clearing anchors.
        self.assertEqual(lua.globals().propertyWrites, 2)
        lua.execute('''cached.SetFrameStrata(f, "LOW"); cached.SetFrameLevel(f, 5)
            cached.SetAlpha(f, 0.1); cached.EnableMouse(f, false)
            cached.SetWidth(f, 55); cached.SetHeight(f, 44)
            propertyWrites = 0; AutoLazy_OpenTray()
        ''')
        self.assertEqual(lua.globals().propertyWrites, 6)
        self.check(lua, 'f:GetFrameStrata() == "DIALOG" and f:GetFrameLevel() == 21 and f:GetAlpha() == 1')
        self.check(lua, 'f:IsMouseEnabled() and f:GetWidth() == 32 and f:GetHeight() == 32')
        lua.execute('AutoLazy_CollapseAddons(false)')
        self.check(lua, 'f:IsShown() and f:GetFrameStrata() == "MEDIUM" and select(2, f:GetPoint()) == Minimap')

    def test_foreign_show_overrides_still_reflow_scale_before_and_after_ownership(self):
        override = '''local previous = f.Show
            f.Show = function(self) self:SetScale(requestedScale); return previous(self) end
        '''
        for before in (True, False):
            with self.subTest(before=before):
                lua = self.runtime('f = MockButton("ScaledLauncher"); requestedScale = 1\n' + (override if before else ''))
                if not before:
                    lua.execute(override)
                lua.execute('AutoLazy_OpenTray(); MockFlushTimers(); requestedScale = 0.5; f:Show(); MockFlushTimers()')
                self.assertEqual(lua.eval('select(4, f:GetPoint())'), (50, -50))
                self.check(lua, 'f:IsVisible() and f:GetScale() == 0.5')

    def test_full_scan_skips_nonframe_name_work_and_blocks_unsafe_proxies_before_method_lookup(self):
        lua = self.runtime('''noiseChecks = 0
            for i = 1, 500 do _G["ColdNoise_" .. i] = {} end
            local lower = string.lower
            string.lower = function(value)
                if string.find(value, "^ColdNoise_") then noiseChecks = noiseChecks + 1 end
                return lower(value)
            end
            DropDownList1 = setmetatable({[0] = newproxy()}, {__index = function()
                error("Excluded proxy must not be inspected")
            end})
            f = MockButton("HealthyLauncher")
        ''')
        self.assertEqual(lua.globals().noiseChecks, 0)
        self.check(lua, 'not f:IsShown() and #AutoLazy_FindAddonButtons() == 1')

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

    def test_kept_icons_load_from_saved_names_without_itemrack_default(self):
        lua = self.runtime('''
            AutoLazyDB = { Tweaks = { KeepOnMinimap = { GuildLauncher = true } } }
            kept = MockButton("GuildLauncher"); other = MockButton("ItemRack_IconFrame")
        ''')
        self.check(lua, 'kept:IsShown() and not other:IsShown()')
        lua.execute('AutoLazy_OpenTray(); AutoLazy_CloseTray(); AutoLazy_CollapseAddons(false); AutoLazy_CollapseAddons(true)')
        self.check(lua, 'kept:IsShown() and select(2, kept:GetPoint()) == Minimap and not other:IsShown()')
        self.check(lua, 'rawget(kept, "Show") == nil and rawget(kept, "SetPoint") == nil')

    def test_exclusion_releases_full_state_and_keeps_native_input_scripts(self):
        for opened in (False, True):
            with self.subTest(opened=opened):
                lua = self.runtime('''
                    f = MockButton("ItemRack_IconFrame"); other = MockButton("OtherLauncher")
                    f:SetPoint("BOTTOMRIGHT", MinimapCluster, "BOTTOMLEFT", -17, 23)
                    f:SetAlpha(0.45); f:SetFrameStrata("LOW"); f:SetFrameLevel(6); f:EnableMouse(false)
                    originalShow, originalSetPoint = f.Show, f.SetPoint
                    clicks = {}; click = function() table.insert(clicks, arg1) end
                    f:SetScript("OnClick", click)
                ''')
                if opened:
                    lua.execute('AutoLazy_OpenTray()')
                lua.execute('AutoLazy.Tray.SetKept(f, true)')
                self.check(lua, 'f:IsShown() and f:GetNumPoints() == 2 and f:GetParent() == Minimap')
                self.check(lua, 'f:GetAlpha() == 0.45 and f:GetFrameStrata() == "LOW" and f:GetFrameLevel() == 6 and not f:IsMouseEnabled()')
                self.check(lua, 'f.Show == originalShow and f.SetPoint == originalSetPoint and f:GetScript("OnClick") == click')
                self.check(lua, 'select(2, f:GetPoint(2)) == MinimapCluster')
                lua.execute('MockRunScript(f, "OnClick", "LeftButton"); MockRunScript(f, "OnClick", "RightButton")')
                self.check(lua, 'clicks[1] == "LeftButton" and clicks[2] == "RightButton"')
                self.check(lua, 'AutoLazyDB.Tweaks.KeepOnMinimap.ItemRack_IconFrame == true')
                self.check(lua, 'other:IsShown() == ' + ('true' if opened else 'false'))
                lua.execute('AutoLazy_CloseTray(); AutoLazy_OpenTray()')
                self.check(lua, 'f:IsShown() and select(2, f:GetPoint()) == Minimap')

    def test_reincluding_captures_new_state_and_restores_latest_addon_requests(self):
        lua = self.runtime('f = MockButton("MovingLauncher"); other = MockButton("OtherLauncher")')
        lua.execute('''AutoLazy_OpenTray()
            f:ClearAllPoints(); f:SetPoint("BOTTOM", "MinimapCluster", "TOP", 37, 19)
            f:SetFrameStrata("HIGH"); f:SetAlpha(0.6); f:SetFrameLevel(12)
            AutoLazy.Tray.SetKept(f, true)
        ''')
        self.check(lua, 'f:GetFrameStrata() == "HIGH" and f:GetAlpha() == 0.6 and f:GetFrameLevel() == 12')
        self.assertEqual(lua.eval('select(4, f:GetPoint())'), (37, 19))
        lua.execute('''f:SetPoint("BOTTOM", UIParent, "BOTTOM", 55, 77); f:SetAlpha(0.75)
            AutoLazy.Tray.SetKept(f, false)
        ''')
        self.check(lua, 'select(2, f:GetPoint()) == AutoLazy_ButtonTray and f:IsShown()')
        self.check(lua, 'AutoLazyDB.Tweaks.KeepOnMinimap.MovingLauncher == nil')
        lua.execute('AutoLazy_CloseTray()')
        self.check(lua, 'not f:IsShown() and select(2, f:GetPoint()) == UIParent and f:GetAlpha() == 0.75')
        self.assertEqual(lua.eval('select(4, f:GetPoint())'), (55, 77))
        lua.execute('AutoLazy_CollapseAddons(false)')
        self.check(lua, 'f:IsShown() and rawget(f, "Show") == nil')

    def test_keep_choices_preserve_disabled_icons_and_apply_to_manual_tray(self):
        lua = self.runtime('''AutoLazyDB = { Tweaks = { CollapseAddons = false } }
            f = MockButton("DisabledLauncher"); f:Hide(); other = MockButton("OtherLauncher")''')
        lua.execute('AutoLazy.Tray.SetKept(f, true); AutoLazy_OpenTray(); AutoLazy_CloseTray()')
        self.check(lua, 'not f:IsShown() and rawget(f, "Show") == nil')
        lua.execute('f:Show(); AutoLazy_OpenTray()')
        self.check(lua, 'f:IsShown() and select(2, f:GetPoint()) == Minimap and select(2, other:GetPoint()) == AutoLazy_ButtonTray')

    def test_custom_hide_settings_take_precedence_without_erasing_keep_choices(self):
        lua = self.runtime('radio = MockButton("EBC_Minimap"); lfg = MockButton("LFTMinimapButton")')
        lua.execute('''AutoLazy.Tray.SetKept(radio, true); AutoLazy.Tray.SetKept(lfg, true)
            AutoLazyDB.Tweaks.HideRadio = true; AutoLazyDB.Tweaks.HideLfg = true
            AutoLazy_ApplySystemIconToggles(); radio:Show(); lfg:Show(); AutoLazy_OpenTray()
        ''')
        self.check(lua, 'not radio:IsShown() and not lfg:IsShown() and not AutoLazy_ButtonTray:IsShown()')
        self.check(lua, 'AutoLazyDB.Tweaks.KeepOnMinimap.EBC_Minimap and AutoLazyDB.Tweaks.KeepOnMinimap.LFTMinimapButton')
        lua.execute('AutoLazyDB.Tweaks.HideRadio = false; AutoLazyDB.Tweaks.HideLfg = false; AutoLazy_ApplySystemIconToggles()')
        self.check(lua, 'radio:IsShown() and lfg:IsShown() and select(2, radio:GetPoint()) == Minimap')
        lua.execute('AutoLazy.SetFrameSuppressed(radio, true); AutoLazy.Tray.SetKept(radio, true)')
        self.check(lua, 'not radio:IsShown()')
        lua.execute('AutoLazy.SetFrameSuppressed(radio, false)')
        self.check(lua, 'radio:IsShown()')

    def test_choice_before_late_loading_and_malformed_map_cleanup(self):
        lua = self.runtime('''AutoLazyDB = { Tweaks = { KeepOnMinimap = {
            NotLoaded = true, FalseChoice = false, StringChoice = "true", [1] = true, [""] = true,
        } } }''')
        self.check(lua, 'AutoLazyDB.Tweaks.KeepOnMinimap.NotLoaded == true')
        self.check(lua, 'AutoLazyDB.Tweaks.KeepOnMinimap.FalseChoice == nil and AutoLazyDB.Tweaks.KeepOnMinimap.StringChoice == nil')
        self.check(lua, 'AutoLazyDB.Tweaks.KeepOnMinimap[1] == nil and AutoLazyDB.Tweaks.KeepOnMinimap[""] == nil')
        lua.execute('''assert(AutoLazy.Tray.SetKept("DelayedLauncher", true))
            f = MockButton("DelayedLauncher"); other = MockButton("OtherLauncher")
            MockRunScript(AutoLazy_TrayController, "OnEvent", "ADDON_LOADED", "LateAddon"); MockFlushTimers()
        ''')
        self.check(lua, 'f:IsShown() and rawget(f, "Show") == nil and not other:IsShown()')
        for bad_value in ('false', '"invalid"', '42'):
            lua = self.runtime('AutoLazyDB = { Tweaks = { KeepOnMinimap = ' + bad_value + ' } }')
            self.check(lua, 'type(AutoLazyDB.Tweaks.KeepOnMinimap) == "table" and next(AutoLazyDB.Tweaks.KeepOnMinimap) == nil')

    def test_anonymous_choice_stays_in_runtime_and_named_child_can_persist(self):
        lua = self.runtime()
        lua.execute('f = MockButton(nil); MockFlushTimers(); AutoLazy.Tray.SetKept(f, true)')
        self.check(lua, 'f:IsShown() and next(AutoLazyDB.Tweaks.KeepOnMinimap) == nil')
        self.check(lua, 'AutoLazy.Tray.GetEntries()[1].key == nil and AutoLazy.Tray.GetEntries()[1].kept')
        lua.execute('AutoLazy.Tray.SetKept(f, false)')
        self.check(lua, 'not f:IsShown()')
        lua.execute('''root = CreateFrame("Frame", nil, Minimap); root:SetSize(32, 32)
            leaf = MockButton("NamedPrivateLauncher", root)
            assert(AutoLazy.Tray.Register(root, leaf)); MockFlushTimers()
            AutoLazy.Tray.SetKept(leaf, true)
        ''')
        self.check(lua, 'root:IsShown() and leaf:IsShown() and AutoLazyDB.Tweaks.KeepOnMinimap.NamedPrivateLauncher')

    def test_composite_exclusion_has_one_entry_and_restores_root_and_child(self):
        lua = self.runtime('''AtlasLootMinimapButtonFrame = CreateFrame("Frame", "AtlasLootMinimapButtonFrame", Minimap)
            root = AtlasLootMinimapButtonFrame; root:SetSize(32, 32); root:SetFrameLevel(6)
            root:SetPoint("TOPLEFT", Minimap, "RIGHT", 2, 0)
            leaf = MockButton("AtlasLootMinimapButton", root); leaf:SetFrameLevel(7)
            leaf:ClearAllPoints(); leaf:SetPoint("TOPLEFT")
        ''')
        lua.execute('AutoLazy_OpenTray(); AutoLazy.Tray.SetKept(leaf, true)')
        self.check(lua, '#AutoLazy.Tray.GetEntries() == 1 and AutoLazy.Tray.GetEntries()[1].label == "AtlasLoot"')
        self.check(lua, 'root:IsShown() and leaf:IsShown() and root:GetFrameLevel() == 6 and leaf:GetFrameLevel() == 7')
        self.check(lua, 'select(2, root:GetPoint()) == Minimap and select(2, leaf:GetPoint()) == root')
        self.check(lua, 'AutoLazyDB.Tweaks.KeepOnMinimap.AtlasLootMinimapButtonFrame == true and rawget(leaf, "Show") == nil')

    def test_last_exclusion_closes_empty_tray_without_hiding_kept_icons(self):
        lua = self.runtime('f = MockButton("LastLauncher")')
        lua.execute('AutoLazy_OpenTray(); AutoLazy.Tray.SetKept(f, true)')
        self.check(lua, 'f:IsShown() and not AutoLazy_ButtonTray:IsShown()')
        lua.execute('AutoLazy_OpenTray()')
        self.check(lua, 'f:IsShown() and not AutoLazy_ButtonTray:IsShown()')
        self.assertEqual(lua.eval('#AutoLazy_FindAddonButtons()'), 0)
        lua.execute('AutoLazy.Tray.SetKept(f, false); AutoLazy_OpenTray()')
        self.check(lua, 'AutoLazy_ButtonTray:IsShown() and select(2, f:GetPoint()) == AutoLazy_ButtonTray')

    def test_generic_display_names_and_picker_use_registry_without_global_scan(self):
        lua = self.runtime('''a = MockButton("ItemRack_IconFrame"); b = MockButton("LibDBIcon10_MyTools")
            c = MockButton("pfQuestIcon"); d = MockButton("ArbitraryName")''')
        lua.execute(AUTOLAZY_GUI_SOURCE)
        lua.execute('''local nativePairs = pairs; globalScans = 0
            pairs = function(t) if t == _G then globalScans = globalScans + 1 end; return nativePairs(t) end
            AutoLazy_ToggleGUI(); MockRunScript(AutoLazy_BtnKeepIcons, "OnClick")
            for i = 1, 20 do
                AutoLazy.Tray.SetKept(a, true); AutoLazy.Tray.SetKept(a, false)
                AutoLazy_OpenTray(); AutoLazy_CloseTray(); AutoLazy_UpdateGUI()
            end
            labels = {}
            for _, entry in ipairs(AutoLazy.Tray.GetEntries()) do labels[entry.key] = entry.label end
        ''')
        self.assertEqual(lua.globals().globalScans, 0)
        self.assertEqual(lua.globals().labels.ItemRack_IconFrame, 'ItemRack')
        self.assertEqual(lua.globals().labels.LibDBIcon10_MyTools, 'MyTools')
        self.assertEqual(lua.globals().labels.pfQuestIcon, 'pfQuest')
        self.assertEqual(lua.globals().labels.ArbitraryName, 'ArbitraryName')

    def picker_runtime(self, extra=''):
        lua = self.runtime(extra)
        lua.execute(AUTOLAZY_GUI_SOURCE)
        lua.execute('AutoLazy_ToggleGUI(); MockRunScript(AutoLazy_BtnKeepIcons, "OnClick")')
        return lua

    def test_picker_checked_means_keep_and_is_lazy_and_reused(self):
        lua = self.runtime('f = MockButton("ItemRack_IconFrame"); other = MockButton("ZOther")')
        lua.execute(AUTOLAZY_GUI_SOURCE)
        self.check(lua, 'AutoLazy_OptionsFrame == nil and AutoLazy_KeepIconsFrame == nil')
        lua.execute('AutoLazy_ToggleGUI()')
        self.check(lua, 'AutoLazy_KeepIconsFrame == nil')
        lua.execute('''MockRunScript(AutoLazy_BtnKeepIcons, "OnClick"); built = MockFrameCount()
            AutoLazy_KeepIcon_1:SetChecked(true); MockRunScript(AutoLazy_KeepIcon_1, "OnClick")
        ''')
        self.check(lua, 'AutoLazy_KeepIconsFrame:IsVisible() and not AutoLazy_TabTweaksFrame:IsShown() and AutoLazyDB.SelectedTab == 1')
        self.check(lua, 'AutoLazy_KeepIcon_1:GetChecked() and f:IsShown() and not other:IsShown()')
        lua.execute('''AutoLazy_KeepIcon_1:SetChecked(false); MockRunScript(AutoLazy_KeepIcon_1, "OnClick")
            MockRunScript(AutoLazy_KeepIconsBack, "OnClick"); MockRunScript(AutoLazy_BtnKeepIcons, "OnClick")
        ''')
        self.check(lua, 'not f:IsShown() and not AutoLazy_KeepIcon_1:GetChecked() and MockFrameCount() == built')
        lua.execute('AutoLazy_ToggleGUI(); AutoLazy_ToggleGUI()')
        self.check(lua, 'AutoLazy_TabTweaksFrame:IsVisible() and not AutoLazy_KeepIconsFrame:IsShown()')

    def test_picker_empty_then_late_discovery_refreshes_only_visible_options(self):
        lua = self.picker_runtime()
        self.check(lua, 'not AutoLazy_KeepIcon_1:IsShown() and not AutoLazy_KeepIconsNext:IsShown()')
        lua.execute('f = MockButton("LateLauncher"); MockFlushTimers()')
        self.check(lua, 'AutoLazy_KeepIcon_1:IsVisible() and AutoLazy_KeepIcon_1.entry.frame == f')
        lua.execute('''AutoLazy_ToggleGUI()
            AutoLazy.Tray.GetEntries = function() error("Hidden options must not refresh the picker") end
            f2 = MockButton("AnotherLateLauncher"); MockFlushTimers()
        ''')

    def test_picker_pagination_reuses_rows_preserves_checkmarks_and_top_anchor(self):
        lua = self.picker_runtime('for i = 1, 17 do MockButton(string.format("Launcher%02d", i)) end')
        lua.execute('''AutoLazy_OptionsFrame.left = 600; AutoLazy_OptionsFrame.top = 700
            MockRunScript(AutoLazy_OptionsFrame, "OnDragStop"); built = MockFrameCount()
            assert(not AutoLazy_KeepIconsPrevious:IsEnabled() and AutoLazy_KeepIconsNext:IsEnabled())
            AutoLazy_KeepIcon_1:SetChecked(true); MockRunScript(AutoLazy_KeepIcon_1, "OnClick")
            MockRunScript(AutoLazy_KeepIconsNext, "OnClick")
        ''')
        self.check(lua, 'AutoLazy_KeepIcon_1.entry.key == "Launcher09" and not AutoLazy_KeepIcon_1:GetChecked()')
        lua.execute('MockRunScript(AutoLazy_KeepIconsNext, "OnClick")')
        self.check(lua, 'AutoLazy_KeepIcon_1.entry.key == "Launcher17" and not AutoLazy_KeepIcon_2:IsShown()')
        self.check(lua, 'not AutoLazy_KeepIconsNext:IsEnabled() and AutoLazy_KeepIconsPrevious:IsEnabled()')
        self.check(lua, 'AutoLazy_OptionsFrame:GetHeight() == 236 and select(1, AutoLazy_OptionsFrame:GetPoint()) == "TOPLEFT"')
        self.assertEqual(lua.eval('select(4, AutoLazy_OptionsFrame:GetPoint())'), (600, 700))
        lua.execute('MockRunScript(AutoLazy_KeepIconsPrevious, "OnClick"); MockRunScript(AutoLazy_KeepIconsPrevious, "OnClick")')
        self.check(lua, 'AutoLazy_KeepIcon_1:GetChecked() and AutoLazy_OptionsFrame:GetHeight() == 418 and MockFrameCount() == built')
        lua.execute('MockRunScript(AutoLazy_BtnTab2, "OnClick")')
        self.check(lua, 'AutoLazy_TabLootFrame:IsVisible() and not AutoLazy_KeepIconsFrame:IsShown() and AutoLazyDB.SelectedTab == 2')

    def test_picker_click_keeps_original_target_if_discovery_resorts_a_pressed_row(self):
        lua = self.picker_runtime('f = MockButton("ZLauncher")')
        lua.execute('''MockRunScript(AutoLazy_KeepIcon_1, "OnMouseDown", "LeftButton")
            newcomer = MockButton("ALauncher"); MockFlushTimers()
            assert(AutoLazy_KeepIcon_1.entry.frame == newcomer)
            AutoLazy_KeepIcon_1:SetChecked(true); MockRunScript(AutoLazy_KeepIcon_1, "OnClick")
        ''')
        self.check(lua, 'AutoLazyDB.Tweaks.KeepOnMinimap.ZLauncher and not AutoLazyDB.Tweaks.KeepOnMinimap.ALauncher')
        self.check(lua, 'f:IsShown() and not newcomer:IsShown() and not AutoLazy_KeepIcon_1:GetChecked() and AutoLazy_KeepIcon_2:GetChecked()')

    def test_picker_row_hit_rectangles_and_footer_fit_on_every_page(self):
        lua = self.picker_runtime('for i = 1, 9 do MockButton(string.format("Launcher%02d", i)) end')
        self.check(lua, 'AutoLazy_KeepIcon_1.hitInsets[2] == -420 and AutoLazy_KeepIcon_1.label:GetText() == "Launcher01"')
        self.check(lua, 'AutoLazy_KeepIcon_1.label.points[2][1] == "BOTTOMRIGHT" and AutoLazy_KeepIcon_1.label.points[2][4] == 420')
        for _ in range(2):
            self.check(lua, '''(function()
                local panelHeight = AutoLazy_OptionsFrame:GetHeight()
                for i = 1, 8 do
                    local row = getglobal("AutoLazy_KeepIcon_" .. i)
                    if row:IsShown() then
                        local _, _, _, x, y = row:GetPoint()
                        assert(x + row:GetWidth() - row.hitInsets[2] <= 472)
                        assert(-y + row:GetHeight() < panelHeight - 60)
                    end
                end
                return true
            end)()''')
            lua.execute('MockRunScript(AutoLazy_KeepIconsNext, "OnClick")')


if __name__ == '__main__':
    unittest.main()
