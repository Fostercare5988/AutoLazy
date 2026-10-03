-- AutoLazy options, WoW 1.12.1 / ClassicAPI 1.15.15+.
-- Author & Maintainer: Fostercare5988
if type(CLASSIC_API_VERSION) ~= "number" or CLASSIC_API_VERSION < 11515 then return end

local panel, Refresh

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
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Label(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Button(name, parent, text, x, y, width, onClick)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetWidth(width); button:SetHeight(22)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Checkbox(name, parent, text, tip, x, y, onClick, hitWidth)
    local widget = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    widget:SetWidth(20); widget:SetHeight(20)
    widget:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    -- Make the label clickable without overlapping the neighboring column.
    widget:SetHitRectInsets(0, -(hitWidth or 190), 0, 0)
    widget.label = getglobal(name .. "Text")
    widget.label:SetText(text)
    widget.label:SetFontObject("GameFontHighlightSmall")
    widget.label:ClearAllPoints()
    widget.label:SetPoint("LEFT", widget, "RIGHT", 4, 0)
    Tooltip(widget, tip)
    widget:SetScript("OnClick", function(self)
        onClick(Checked(self or this or widget))
        AutoLazy_UpdateGUI()
    end)
    return widget
end

local function Sync(widget, value, enabled)
    value = value and true or false
    if Checked(widget) ~= value then widget:SetChecked(value) end
    local disabled = enabled == false
    if widget.disabled ~= disabled then
        widget.disabled = disabled
        if disabled then widget:Disable() else widget:Enable() end
        widget.label:SetFontObject(disabled and "GameFontDisableSmall" or "GameFontHighlightSmall")
    end
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
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
    panel:SetBackdropBorderColor(0.45, 0.45, 0.50, 1)
    panel:Hide()
    table.insert(UISpecialFrames, "AutoLazy_OptionsFrame")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -18)
    title:SetText("AutoLazy")

    local tabTweaks = CreateFrame("Frame", "AutoLazy_TabTweaksFrame", panel)
    local tabLoot = CreateFrame("Frame", "AutoLazy_TabLootFrame", panel)
    local tabQuests = CreateFrame("Frame", "AutoLazy_TabQuestsFrame", panel)
    local pages, heights = { tabTweaks, tabLoot, tabQuests }, { 310, 380, 300 }
    for i = 1, 3 do pages[i]:SetAllPoints(panel); pages[i]:Hide() end
    local btnTab1 = Button("AutoLazy_BtnTab1", panel, "Minimap", 28, -52, 140)
    local btnTab2 = Button("AutoLazy_BtnTab2", panel, "Loot", 180, -52, 140)
    local btnTab3 = Button("AutoLazy_BtnTab3", panel, "Quests", 332, -52, 140)
    local tabs, activeTab = { btnTab1, btnTab2, btnTab3 }, nil
    local function ShowTab(index)
        if index ~= 1 and index ~= 2 and index ~= 3 then index = 1 end
        AutoLazyDB.SelectedTab = index
        if index ~= activeTab then
            if activeTab then pages[activeTab]:Hide(); tabs[activeTab]:Enable() end
            activeTab = index
            panel:SetHeight(heights[index])
            pages[index]:Show(); tabs[index]:Disable()
        end
    end
    for i = 1, 3 do
        local index = i
        tabs[i]:SetScript("OnClick", function()
            AutoLazyDB.SelectedTab = index
            AutoLazy_UpdateGUI()
        end)
    end

    -- Minimap: related controls share a row; detailed behavior is on hover.
    Label(tabTweaks, "Addon tray", 28, -98)
    local cbCollapse = Checkbox("AutoLazy_ToggleCollapse", tabTweaks, "Collapse minimap addons",
        "Keep addon minimap buttons in the tray. Turn off to restore their positions.", 28, -122, function(value)
            AutoLazy_CollapseAddons(value)
        end)
    Button("AutoLazy_BtnOpenTray", tabTweaks, "Toggle tray", 300, -122, 172, AutoLazy_ToggleTray)
    local cbShowBtn = Checkbox("AutoLazy_ToggleShowBtn", tabTweaks, "Show floating button",
        "Left-click for the tray, right-click for options, or drag to move.", 28, -158, function(value)
            AutoLazyDB.ShowButton = value
            AutoLazy_UpdateActionButton()
        end)
    Button("AutoLazy_BtnResetBtnPos", tabTweaks, "Reset position", 300, -158, 172, AutoLazy_ResetActionButtonPos)
    local cbHideRadio = Checkbox("AutoLazy_ToggleHideRadio", tabTweaks, "Hide Pirate Radio",
        "Hide the Pirate Radio icon, including its tray entry.", 28, -202, function(value)
            AutoLazyDB.Tweaks.HideRadio = value
            AutoLazy_ApplySystemIconToggles()
        end)
    local cbHideLfg = Checkbox("AutoLazy_ToggleHideLfg", tabTweaks, "Hide Group Finder",
        "Hide the Group Finder / LFT icon, including its tray entry.", 264, -202, function(value)
            AutoLazyDB.Tweaks.HideLfg = value
            AutoLazy_ApplySystemIconToggles()
        end, 174)
    Label(tabTweaks, "Left-click: tray   /   Right-click: options   /   Drag: move", 28, -240, "GameFontDisableSmall")
    local function RefreshMinimap()
        Sync(cbCollapse, AutoLazyDB.Tweaks.CollapseAddons ~= false)
        Sync(cbShowBtn, AutoLazyDB.ShowButton ~= false)
        Sync(cbHideRadio, AutoLazyDB.Tweaks.HideRadio)
        Sync(cbHideLfg, AutoLazyDB.Tweaks.HideLfg)
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
    Label(tabLoot, "Dungeon", 28, -174)
    local dungeonOrder = { "The Black Morass", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Naxxramas" }
    local selectedDungeonKey, renderedDungeon = dungeonOrder[1], nil
    local dungeonButtons, itemRows, RefreshLoot = {}, {}, nil
    for i = 1, table.getn(dungeonOrder) do
        local key = dungeonOrder[i]
        dungeonButtons[key] = Button("AutoLazy_DungeonBtn_" .. i, tabLoot, key, 28, -198 - (i - 1) * 30, 132, function()
            selectedDungeonKey = key
            RefreshLoot()
        end)
    end
    local selectedTitle = Label(tabLoot, selectedDungeonKey, 176, -174)
    local actions, labels = { "MANUAL", "NEED", "GREED", "PASS" }, { "Manual", "Need", "Greed", "Pass" }
    local tips = { "Leave the roll open for you to choose.", "Roll Need on this item.", "Roll Greed on this item.", "Pass on this item." }
    local columns = { 164, 202, 240, 278 }
    for i = 1, 4 do
        local heading = tabLoot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        heading:SetPoint("TOP", tabLoot, "TOPLEFT", 176 + columns[i], -198)
        heading:SetText(labels[i])
    end
    for i = 1, 4 do
        local row = CreateFrame("Frame", "AutoLazy_ItemRow_" .. i, tabLoot)
        row:SetWidth(296); row:SetHeight(26)
        row:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 176, -218 - (i - 1) * 28)
        local icon = CreateFrame("Button", "AutoLazy_ItemIcon_" .. i, row)
        icon:SetWidth(20); icon:SetHeight(20)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.iconTex = icon:CreateTexture(nil, "ARTWORK")
        row.iconTex:SetAllPoints(icon)
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self or this or icon, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. row.itemId .. ":0:0:0")
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        row.nameText:SetPoint("RIGHT", row, "LEFT", 142, 0)
        row.nameText:SetJustifyH("LEFT")
        row.actionButtons = {}
        for j = 1, 4 do
            local action = actions[j]
            local choice = CreateFrame("CheckButton", "AutoLazy_ItemAction_" .. i .. "_" .. action, row, "UICheckButtonTemplate")
            choice:SetWidth(20); choice:SetHeight(20)
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
                if key == selectedDungeonKey then button:LockHighlight() else button:UnlockHighlight() end
            end
            local items = AutoLazy_DungeonItems[selectedDungeonKey]
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
                    local choice = row.actionButtons[actions[j]]
                    local checked = selected == actions[j]
                    if Checked(choice) ~= checked then choice:SetChecked(checked) end
                end
            end
        end
    end

    -- Quests: keep existing settings and dim dependent choices when disabled.
    Label(tabQuests, "Quest turn-ins", 28, -98)
    local cbQuestMaster = Checkbox("AutoLazy_QuestMaster", tabQuests, "Enable Shift-click",
        "Hold Shift when talking to an NPC to start quest turn-ins and supported gossip shortcuts.", 28, -128, function(value)
            AutoLazyDB.Quests.Enabled = value
        end, 300)
    local cbQuestTurnIn = Checkbox("AutoLazy_QuestTurnIn", tabQuests, "Turn in completed quests",
        "Complete accepted quests during the Shift session. Choose a quest when several ordinary quests are ready.", 44, -162, function(value)
            AutoLazyDB.Quests.AutoTurnIn = value
        end, 300)
    local cbQuestSafe = Checkbox("AutoLazy_QuestSafe", tabQuests, "Choose rewards manually",
        "Pause if multiple rewards are offered. Turning this off selects the first reward automatically.", 44, -196, function(value)
            AutoLazyDB.Quests.SafeRewards = value
        end, 300)
    Label(tabQuests, "Hold Shift when talking to an NPC.\nNew quests are accepted manually.", 28, -232, "GameFontDisableSmall")
    local function RefreshQuests()
        local quests = AutoLazyDB.Quests
        Sync(cbQuestMaster, quests.Enabled)
        Sync(cbQuestTurnIn, quests.AutoTurnIn, quests.Enabled)
        Sync(cbQuestSafe, quests.SafeRewards, quests.Enabled and quests.AutoTurnIn)
    end

    local close = CreateFrame("Button", "AutoLazy_BtnClose", panel, "UIPanelButtonTemplate")
    close:SetWidth(96); close:SetHeight(22)
    close:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 14)
    close:SetText("Close")
    close:SetScript("OnClick", function() panel:Hide() end)
    local refreshTab = { RefreshMinimap, RefreshLoot, RefreshQuests }
    Refresh = function()
        ShowTab(AutoLazyDB.SelectedTab or 1)
        refreshTab[activeTab]()
    end
    panel:SetScript("OnShow", function() AutoLazy_UpdateGUI() end)
end

function AutoLazy_UpdateGUI()
    if panel and panel:IsShown() and AutoLazyDB then Refresh() end
end

function AutoLazy_ToggleGUI()
    if not AutoLazyDB then return end
    if not panel then CreateOptions() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end
