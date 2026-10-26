-- AutoLazy options, WoW 1.12.1 / ClassicAPI 1.17.7+.
-- Author & Maintainer: Fostercare5988
if type(CLASSIC_API_VERSION) ~= "number" or CLASSIC_API_VERSION < 11707 then return end

local panel, Refresh
local Style = AutoLazy.Style
local WHITE = { 1, 1, 1, 1 }

local function Color(font, role)
    local c = Style[role]
    font:SetTextColor(c[1], c[2], c[3])
end

local function Tint(texture, c)
    texture:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

local function Disc(parent, layer, size, color)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetTexture(Style.disc)
    texture:SetWidth(size); texture:SetHeight(size)
    Tint(texture, color)
    return texture
end

-- Selected buttons (active tab, chosen dungeon) become a filled orange pill.
-- Ghost buttons sit on a track and show no fill until selected.
local function Select(button, selected)
    if button.selected == selected then return end
    button.selected = selected
    Style.Paint(button.fill, selected and Style.selected or (button.ghost and Style.clear or Style.control))
    Color(button:GetFontString(), (selected or not button.ghost) and "text" or "hint")
end

local function SetEnabled(button, enabled)
    if enabled then button:Enable() else button:Disable() end
    button:SetAlpha(enabled and 1 or 0.4)
end

local function HideTooltip() GameTooltip:Hide() end

local function Checked(widget)
    local value = widget:GetChecked()
    return value == true or value == 1
end

local function Tooltip(widget, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self or this or widget, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", HideTooltip)
end

local function Label(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    Color(label, font and "hint" or "heading")
    return label
end

-- Section headings: small orange capitals.
local function Heading(parent, text, x, y)
    local label = Label(parent, string.upper(text), x, y, "GameFontNormalSmall")
    Color(label, "heading")
    return label
end

-- A rounded pill. options: ghost, height, font.
local function Button(name, parent, text, x, y, width, onClick, options)
    options = options or {}
    local height = options.height or 22
    local button = CreateFrame("Button", name, parent)
    button:SetWidth(width); button:SetHeight(height)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:RegisterForClicks("LeftButtonUp")
    button.fill = Style.Rounded(button, "BACKGROUND", height / 2, Style.clear)
    Style.Rounded(button, "HIGHLIGHT", height / 2, Style.hover)
    local label = button:CreateFontString(nil, "OVERLAY", options.font or "GameFontHighlightSmall")
    label:SetAllPoints(button)
    button:SetFontString(label)
    button:SetText(text)
    button.ghost = options.ghost
    Select(button, false)
    button:SetScript("OnClick", onClick)
    return button
end

-- Switches and radio dots draw their own state, so a disabled or
-- unchecked control never shows the native check art.
local function Paint(widget)
    local on, dim = Checked(widget), widget.disabled and true or false
    if widget.shownOn == on and widget.shownDim == dim then return end
    widget.shownOn, widget.shownDim = on, dim
    if widget.dot then
        Tint(widget.ring, on and Style.accent or Style.hint)
        if on then widget.dot:Show() else widget.dot:Hide() end
    else
        Style.Paint(widget.track, on and Style.selected or Style.control)
        widget.knob:ClearAllPoints()
        widget.knob:SetPoint("LEFT", widget, "LEFT", on and 14 or 2, 0)
        Tint(widget.knob, on and WHITE or Style.knob)
    end
    widget:SetAlpha(dim and 0.4 or 1)
end

local function SetCheck(widget, value)
    if Checked(widget) ~= value then widget:SetChecked(value) end
    Paint(widget)
end

local function Checkbox(name, parent, text, tip, x, y, onClick, hitWidth)
    local widget = CreateFrame("CheckButton", name, parent)
    widget:SetWidth(28); widget:SetHeight(16)
    widget:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 2)
    -- Make the label clickable without overlapping the neighboring column.
    widget:SetHitRectInsets(0, -(hitWidth or 190), 0, 0)
    widget.track = Style.Rounded(widget, "BACKGROUND", 8, Style.control)
    widget.knob = Disc(widget, "ARTWORK", 12, Style.knob)
    local halo = Disc(widget, "HIGHLIGHT", 22, { 1, 1, 1, 0.10 })
    halo:SetPoint("CENTER", widget.knob, "CENTER", 0, 0)
    -- Keep the template's label name for anything that refers to it.
    widget.label = widget:CreateFontString(name .. "Text", "OVERLAY", "GameFontHighlightSmall")
    widget.label:SetPoint("LEFT", widget, "RIGHT", 8, 0)
    widget.label:SetJustifyH("LEFT")
    widget.label:SetText(text)
    Color(widget.label, "text")
    if tip then Tooltip(widget, tip) end
    if onClick then
        widget:SetScript("OnClick", function(self)
            local clicked = self or this or widget
            Paint(clicked)
            onClick(Checked(clicked))
            AutoLazy.UpdateGUI()
        end)
    end
    Paint(widget)
    return widget
end

local function Radio(name, parent)
    local widget = CreateFrame("CheckButton", name, parent)
    widget:SetWidth(16); widget:SetHeight(16)
    widget.ring = Disc(widget, "BACKGROUND", 14, Style.hint)
    widget.ring:SetPoint("CENTER", widget, "CENTER", 0, 0)
    Disc(widget, "BORDER", 10, Style.surface):SetPoint("CENTER", widget, "CENTER", 0, 0)
    widget.dot = Disc(widget, "ARTWORK", 6, Style.accent)
    widget.dot:SetPoint("CENTER", widget, "CENTER", 0, 0)
    Disc(widget, "HIGHLIGHT", 22, { 1, 1, 1, 0.10 }):SetPoint("CENTER", widget, "CENTER", 0, 0)
    Paint(widget)
    return widget
end

local function Sync(widget, value, enabled)
    local disabled = enabled == false
    if widget.disabled ~= disabled then
        widget.disabled = disabled
        if disabled then widget:Disable() else widget:Enable() end
    end
    SetCheck(widget, value and true or false)
end

local function PinTop()
    -- StartMoving can leave a CENTER anchor. Pin the top before tab resizing.
    local left, top = panel:GetLeft(), panel:GetTop()
    if left and top then
        local ratio = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * ratio, top * ratio)
    end
end

local function CreateOptions()
    panel = CreateFrame("Frame", "AutoLazy_OptionsFrame", UIParent)
    panel:SetWidth(500); panel:SetHeight(310)
    panel:SetPoint("TOP", UIParent, "CENTER", 0, 190)
    panel:SetFrameStrata("DIALOG"); panel:SetToplevel(true)
    panel:EnableMouse(true); panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() panel:StartMoving() end)
    panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing(); PinTop() end)
    panel:SetClampedToScreen(true)
    Style.Surface(panel, 14)
    panel:Hide()
    table.insert(UISpecialFrames, "AutoLazy_OptionsFrame")

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, -18)
    title:SetText("AutoLazy")
    Color(title, "heading")
    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
    version:SetText("v" .. (GetAddOnMetadata("AutoLazy", "Version") or ""))
    Color(version, "hint")
    local close = CreateFrame("Button", "AutoLazy_BtnClose", panel)
    close:SetWidth(22); close:SetHeight(22)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -14)
    close:RegisterForClicks("LeftButtonUp")
    Disc(close, "HIGHLIGHT", 22, { 1, 1, 1, 0.10 }):SetAllPoints(close)
    local glyph = close:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture(Style.close)
    glyph:SetWidth(12); glyph:SetHeight(12)
    glyph:SetPoint("CENTER", close, "CENTER", 0, 0)
    Tint(glyph, Style.hint)
    close:SetScript("OnClick", function() panel:Hide() end)

    local tabTweaks = CreateFrame("Frame", "AutoLazy_TabTweaksFrame", panel)
    local tabLoot = CreateFrame("Frame", "AutoLazy_TabLootFrame", panel)
    local tabQuests = CreateFrame("Frame", "AutoLazy_TabQuestsFrame", panel)
    local pages, heights = { tabTweaks, tabLoot, tabQuests }, { 310, 380, 300 }
    for i = 1, 3 do pages[i]:SetAllPoints(panel); pages[i]:Hide() end
    -- Segmented control: one pill track, the active tab a filled pill inside it.
    local tabTrack = CreateFrame("Frame", nil, panel)
    tabTrack:SetWidth(452); tabTrack:SetHeight(30)
    tabTrack:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -48)
    Style.Rounded(tabTrack, "BACKGROUND", 15, Style.track)
    local tabStyle = { ghost = true, height = 24, font = "GameFontHighlight" }
    local btnTab1 = Button("AutoLazy_BtnTab1", tabTrack, "Minimap", 3, -3, 148, nil, tabStyle)
    local btnTab2 = Button("AutoLazy_BtnTab2", tabTrack, "Loot", 152, -3, 148, nil, tabStyle)
    local btnTab3 = Button("AutoLazy_BtnTab3", tabTrack, "Quests", 301, -3, 148, nil, tabStyle)
    local tabs, activeTab, activePage, activeHeight = { btnTab1, btnTab2, btnTab3 }
    local keepMode, keepPage, picker, RefreshPicker = false, 1, nil, nil
    local function ShowTab(index, page, height)
        if index ~= 1 and index ~= 2 and index ~= 3 then index = 1 end
        AutoLazyDB.SelectedTab = index
        if index ~= activeTab then
            if activeTab then Select(tabs[activeTab], false) end
            activeTab = index
            Select(tabs[index], true)
        end
        page, height = page or pages[index], height or heights[index]
        if height ~= activeHeight then panel:SetHeight(height); activeHeight = height end
        if page ~= activePage then
            if activePage then activePage:Hide() end
            activePage = page
            page:Show()
        end
    end
    for i = 1, 3 do
        local index = i
        tabs[i]:SetScript("OnClick", function()
            keepMode = false
            AutoLazyDB.SelectedTab = index
            AutoLazy.UpdateGUI()
        end)
    end

    -- Minimap: related controls share a row; detailed behavior is on hover.
    Heading(tabTweaks, "Addon tray", 28, -98)
    local cbCollapse = Checkbox("AutoLazy_ToggleCollapse", tabTweaks, "Collapse minimap addons",
        "Keep addon minimap buttons in the tray. Turn off to restore their positions.", 28, -122, function(value)
            AutoLazy.CollapseAddons(value)
        end)
    Button("AutoLazy_BtnOpenTray", tabTweaks, "Toggle tray", 300, -120, 172, AutoLazy.ToggleTray)
    local cbShowBtn = Checkbox("AutoLazy_ToggleShowBtn", tabTweaks, "Show floating button",
        "Left-click for the tray, right-click for options, or drag to move.", 28, -158, function(value)
            AutoLazyDB.ShowButton = value
            AutoLazy.UpdateActionButton()
        end)
    Button("AutoLazy_BtnResetBtnPos", tabTweaks, "Reset position", 300, -156, 172, AutoLazy.ResetActionButtonPos)
    local cbHideRadio = Checkbox("AutoLazy_ToggleHideRadio", tabTweaks, "Hide Pirate Radio",
        "Hide the Pirate Radio icon, including its tray entry.", 28, -202, function(value)
            AutoLazyDB.Tweaks.HideRadio = value
            AutoLazy.ApplySystemIconToggles()
        end)
    local cbHideLfg = Checkbox("AutoLazy_ToggleHideLfg", tabTweaks, "Hide Group Finder",
        "Hide the Group Finder / LFT icon, including its tray entry.", 264, -202, function(value)
            AutoLazyDB.Tweaks.HideLfg = value
            AutoLazy.ApplySystemIconToggles()
        end, 174)
    Label(tabTweaks, "Left-click: tray   /   Right-click: options   /   Drag: move", 28, -240, "GameFontDisableSmall")
    local function RefreshMinimap()
        Sync(cbCollapse, AutoLazyDB.Tweaks.CollapseAddons ~= false)
        Sync(cbShowBtn, AutoLazyDB.ShowButton ~= false)
        Sync(cbHideRadio, AutoLazyDB.Tweaks.HideRadio)
        Sync(cbHideLfg, AutoLazyDB.Tweaks.HideLfg)
    end

    local keepButton = Button("AutoLazy_BtnKeepIcons", tabTweaks, "Choose minimap icons", 0, 0, 172, function()
        keepMode, keepPage = true, 1
        AutoLazy.UpdateGUI()
    end)
    keepButton:ClearAllPoints()
    keepButton:SetPoint("BOTTOMLEFT", tabTweaks, "BOTTOMLEFT", 28, 18)
    Tooltip(keepButton, "Choose which addon icons stay on your minimap.")

    local function CreatePicker()
        picker = CreateFrame("Frame", "AutoLazy_KeepIconsFrame", panel)
        picker:SetAllPoints(panel); picker:Hide()
        Heading(picker, "Choose minimap icons", 28, -98)
        Label(picker, "Checked icons stay on the minimap.", 28, -116, "GameFontHighlightSmall")
        local empty = Label(picker, "", 28, -148, "GameFontDisableSmall")
        local pageText = picker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        Color(pageText, "hint")
        pageText:SetPoint("BOTTOM", picker, "BOTTOM", 0, 50)
        local rows, perPage = {}, 8
        for i = 1, perPage do
            local row = Checkbox("AutoLazy_KeepIcon_" .. i, picker, "", nil, 28, -148 - (i - 1) * 26, nil, 412)
            -- Bound long frame names to this row's clickable area.
            row.label:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 412, 0)
            -- Discovery can update the list between mouse down and click.
            -- Retain that click's identity and intent rather than using a new row.
            row:SetScript("OnMouseDown", function(self)
                local widget = self or this or row
                widget.pressed = widget.entry
            end)
            row:SetScript("OnClick", function(self)
                local widget = self or this or row
                local entry = widget.pressed or widget.entry
                local keep = Checked(widget)
                if widget.pressed then keep = not widget.pressed.kept end
                widget.pressed = nil
                if entry then AutoLazy.Tray.SetKept(entry.frame, keep) end
                Paint(widget)
            end)
            row:SetScript("OnHide", function() row.pressed = nil end)
            row:SetScript("OnEnter", function(self)
                local entry = row.entry
                if not entry then return end
                local tip = "Check to keep this icon on the minimap. Uncheck to put it in the tray."
                if not entry.key then tip = tip .. "\nUnnamed icon: this choice lasts until you reload." end
                if entry.hidden then tip = tip .. "\nTurn off its Hide setting on the Minimap page to show it." end
                GameTooltip:SetOwner(self or this or row, "ANCHOR_RIGHT")
                GameTooltip:SetText(tip, 1, 1, 1, 1, 1)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", HideTooltip)
            rows[i] = row
        end
        local back = Button("AutoLazy_KeepIconsBack", picker, "Back", 0, 0, 104, function()
            keepMode = false
            AutoLazy.UpdateGUI()
        end)
        back:ClearAllPoints(); back:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 28, 18)
        local previous = Button("AutoLazy_KeepIconsPrevious", picker, "Previous", 0, 0, 84, function()
            keepPage = keepPage - 1
            AutoLazy.UpdateGUI()
        end)
        previous:ClearAllPoints(); previous:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 156, 18)
        local nextPage = Button("AutoLazy_KeepIconsNext", picker, "Next", 0, 0, 84, function()
            keepPage = keepPage + 1
            AutoLazy.UpdateGUI()
        end)
        nextPage:ClearAllPoints(); nextPage:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 252, 18)
        RefreshPicker = function()
            local entries = AutoLazy.Tray.GetEntries()
            local count = table.getn(entries)
            local pageCount = math.max(1, math.ceil(count / perPage))
            keepPage = math.max(1, math.min(keepPage, pageCount))
            local first = (keepPage - 1) * perPage
            local visible = math.min(perPage, count - first)
            empty:SetText(count == 0 and "No addon icons detected yet." or "")
            for i = 1, perPage do
                local row, entry = rows[i], entries[first + i]
                row.entry = entry
                if entry then
                    row.label:SetText(entry.label .. (entry.hidden and " |cFF888888(hidden)|r" or ""))
                    Sync(row, entry.kept)
                    row:Show()
                else row:Hide() end
            end
            if pageCount > 1 then
                pageText:SetText("Page " .. keepPage .. " of " .. pageCount)
                previous:Show(); nextPage:Show()
                SetEnabled(previous, keepPage > 1)
                SetEnabled(nextPage, keepPage < pageCount)
            else
                pageText:SetText("")
                previous:Hide(); nextPage:Hide()
            end
            return 190 + math.max(1, visible) * 26 + (pageCount > 1 and 20 or 0)
        end
    end

    -- Loot: one set of headings, one mutually exclusive choice per item.
    local cbMaster = Checkbox("AutoLazy_MasterEnable", tabLoot, "Enable auto-roll",
        "Automatically roll Need, Greed or Pass for the items below in their dungeon. Manual leaves the roll open. Other items are never auto-rolled.", 28, -98, function(value)
            AutoLazyDB.Enabled = value
        end)
    local cbBop = Checkbox("AutoLazy_OptBop", tabLoot, "Auto-confirm loot",
        "Automatically accept the warning that an item will bind to your character. Works when looting or rolling, while auto-roll is enabled.", 264, -98, function(value)
            AutoLazyDB.AutoConfirmBop = value
        end, 174)
    local cbClean = Checkbox("AutoLazy_OptCleanRollChat", tabLoot, "Hide loot roll spam",
        "Hide Need, Greed, Pass and dice-roll messages. Keep the winner, item loot and money messages. Works even when auto-roll is off.", 28, -130, function(value)
            AutoLazyDB.CleanRollChat = value
        end)
    Heading(tabLoot, "Dungeon", 28, -174)
    local dungeonOrder = { "The Black Morass", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Naxxramas" }
    local selectedDungeonKey, renderedDungeon = dungeonOrder[1], nil
    local dungeonButtons, itemRows, RefreshLoot = {}, {}, nil
    local dungeonStyle = { ghost = true, height = 24 }
    for i = 1, table.getn(dungeonOrder) do
        local key = dungeonOrder[i]
        dungeonButtons[key] = Button("AutoLazy_DungeonBtn_" .. i, tabLoot, key, 24, -194 - (i - 1) * 30, 136, function()
            selectedDungeonKey = key
            RefreshLoot()
        end, dungeonStyle)
    end
    local selectedTitle = Label(tabLoot, selectedDungeonKey, 176, -172)
    local actions, labels = { "MANUAL", "NEED", "GREED", "PASS" }, { "Manual", "Need", "Greed", "Pass" }
    local tips = { "Leave the roll open for you to choose.", "Roll Need on this item.", "Roll Greed on this item.", "Pass on this item." }
    local columns = { 164, 202, 240, 278 }
    for i = 1, 4 do
        local heading = tabLoot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        heading:SetPoint("TOP", tabLoot, "TOPLEFT", 176 + columns[i], -198)
        heading:SetText(labels[i])
        Color(heading, "hint")
    end
    for i = 1, 4 do
        local row = CreateFrame("Frame", "AutoLazy_ItemRow_" .. i, tabLoot)
        row:SetWidth(296); row:SetHeight(26)
        row:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 176, -218 - (i - 1) * 28)
        Style.Rounded(row, "BACKGROUND", 7, Style.row, 4)
        local icon = CreateFrame("Button", "AutoLazy_ItemIcon_" .. i, row)
        icon:SetWidth(20); icon:SetHeight(20)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.iconTex = icon:CreateTexture(nil, "ARTWORK")
        row.iconTex:SetAllPoints(icon)
        -- Trim the stock icon border so the art sits flush in the row.
        row.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self or this or icon, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. row.itemId .. ":0:0:0")
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", HideTooltip)
        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        row.nameText:SetPoint("RIGHT", row, "LEFT", 142, 0)
        row.nameText:SetJustifyH("LEFT")
        row.actionButtons = {}
        for j = 1, 4 do
            local action = actions[j]
            local choice = Radio("AutoLazy_ItemAction_" .. i .. "_" .. action, row)
            choice:SetPoint("CENTER", row, "LEFT", columns[j], 0)
            Tooltip(choice, tips[j])
            choice:SetScript("OnClick", function()
                AutoLazyDB.ItemRules[row.ruleKey] = action
                RefreshLoot()
            end)
            row.actionButtons[action] = choice
        end
        itemRows[i] = row
    end
    local colors = { [2] = "|cFF1EFF00", [3] = "|cFF0070DD", [4] = "|cFFA335EE" }
    RefreshLoot = function()
        Sync(cbMaster, AutoLazyDB.Enabled)
        Sync(cbBop, AutoLazyDB.AutoConfirmBop, AutoLazyDB.Enabled)
        Sync(cbClean, AutoLazyDB.CleanRollChat)
        if renderedDungeon ~= selectedDungeonKey then
            renderedDungeon = selectedDungeonKey
            selectedTitle:SetText(selectedDungeonKey)
            for key, button in pairs(dungeonButtons) do
                Select(button, key == selectedDungeonKey)
            end
            local items = AutoLazy.DungeonItems[selectedDungeonKey]
            for i = 1, 4 do
                local row, item = itemRows[i], items[i]
                if item then
                    row.itemId, row.ruleKey = item.id, item.key or string.lower(item.name)
                    row.iconTex:SetTexture(item.texture)
                    row.nameText:SetText((colors[item.quality] or "|cFFFFFFFF") .. item.name .. "|r")
                    row:Show()
                else
                    row.ruleKey = nil
                    row:Hide()
                end
            end
        end
        for i = 1, 4 do
            local row = itemRows[i]
            if row.ruleKey then
                local selected = AutoLazyDB.ItemRules[row.ruleKey] or "MANUAL"
                -- A native checkbutton toggles itself before OnClick, even
                -- when the player clicks the already selected action.
                for j = 1, 4 do
                    SetCheck(row.actionButtons[actions[j]], selected == actions[j])
                end
            end
        end
    end

    -- Quests: keep existing settings and dim dependent choices when disabled.
    Heading(tabQuests, "Quest turn-ins", 28, -98)
    local cbQuestMaster = Checkbox("AutoLazy_QuestMaster", tabQuests, "Enable Shift-click",
        "Hold Shift when talking to an NPC for turn-ins and supported gossip shortcuts. Keep holding Shift to turn in the same quest again. Shift-right-click a quest name to pick which one.", 28, -128, function(value)
            AutoLazyDB.Quests.Enabled = value
            if not value then AutoLazy.CancelQuestTurnIn() end
        end, 300)
    local cbQuestTurnIn = Checkbox("AutoLazy_QuestTurnIn", tabQuests, "Turn in completed quests",
        "Complete accepted quests during the Shift session. Shift-right-click a quest name for one selected turn-in, including repeatables that open directly to their progress dialog.", 44, -162, function(value)
            AutoLazyDB.Quests.AutoTurnIn = value
            if not value then AutoLazy.CancelQuestTurnIn() end
        end, 300)
    local cbQuestSafe = Checkbox("AutoLazy_QuestSafe", tabQuests, "Choose rewards manually",
        "Pause if multiple rewards are offered. Turning this off selects the first reward automatically.", 44, -196, function(value)
            AutoLazyDB.Quests.SafeRewards = value
        end, 300)
    Label(tabQuests, "Shift-right-click a quest name to pick it. Hold Shift to repeat it.\nNew quests are accepted manually.", 28, -232, "GameFontDisableSmall")
    local function RefreshQuests()
        local quests = AutoLazyDB.Quests
        Sync(cbQuestMaster, quests.Enabled)
        Sync(cbQuestTurnIn, quests.AutoTurnIn, quests.Enabled)
        Sync(cbQuestSafe, quests.SafeRewards, quests.Enabled and quests.AutoTurnIn)
    end

    local refreshTab = { RefreshMinimap, RefreshLoot, RefreshQuests }
    Refresh = function()
        local index = AutoLazyDB.SelectedTab
        if index ~= 1 and index ~= 2 and index ~= 3 then index = 1 end
        if keepMode and index == 1 then
            if not picker then CreatePicker() end
            ShowTab(index, picker, RefreshPicker())
        else
            keepMode = false
            ShowTab(index)
            refreshTab[index]()
        end
    end
    panel:SetScript("OnShow", function() AutoLazy.UpdateGUI() end)
    panel:SetScript("OnHide", function() keepMode = false end)
end

function AutoLazy.UpdateGUI()
    if panel and panel:IsShown() and AutoLazyDB then Refresh() end
end

function AutoLazy.ToggleGUI()
    if not AutoLazyDB then return end
    if not panel then CreateOptions() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- Game Menu > AddOn Options > AutoLazy (ClassicAPI InterfaceOptions_AddCategory).
local entry = CreateFrame("Frame", "AutoLazyOptionsEntry")
entry.name = "AutoLazy"
local entryTitle = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
entryTitle:SetPoint("TOPLEFT", entry, "TOPLEFT", 16, -16)
entryTitle:SetText("AutoLazy")
local entryText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
entryText:SetPoint("TOPLEFT", entryTitle, "BOTTOMLEFT", 0, -8)
entryText:SetText("Settings open in their own window. Type /al to open them at any time.")
local open = Button("AutoLazyOptionsOpen", entry, "Open settings", 16, -70, 172, function()
    if InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
    if GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
    if not AutoLazyDB then return end
    if not panel then CreateOptions() end
    panel:Show()
end)
Select(open, true)
InterfaceOptions_AddCategory(entry)
