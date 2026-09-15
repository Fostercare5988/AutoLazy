-- AutoLazy Options GUI for WoW 1.12.1 (Vanilla Enhanced)
-- Author & Maintainer: Fostercare5988
-- Built natively for ClassicAPI v1.14.0+, SuperWoW 2.2+, NamPower, UnitXP SP3, DXVK

-- Strict Engine Dependency Guard (Mandatory ClassicAPI v1.14.0+ & SuperWoW v2.2+)
local MIN_CLASSIC_API = 11400

if not (CLASSIC_API_VERSION and SUPERWOW_VERSION) or 
   (type(CLASSIC_API_VERSION) == "number" and CLASSIC_API_VERSION < MIN_CLASSIC_API) then
    return
end

local panel = CreateFrame("Frame", "AutoLazy_OptionsFrame", UIParent)
panel:SetWidth(500)
panel:SetHeight(520)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
panel:SetFrameStrata("DIALOG")
panel:SetToplevel(true)
panel:EnableMouse(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() panel:StartMoving() end)
panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
panel:Hide()

-- Allow closing with ESC key
table.insert(UISpecialFrames, "AutoLazy_OptionsFrame")

-- Standard Vanilla Dialog Backdrop
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

-- Header Title & Subtitle with generous vertical breathing room
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOP", panel, "TOP", 0, -18)
title:SetText("AutoLazy")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
subtitle:SetText("Made by Fostercare5988")

-- Storage for widgets to sync with DB
local dungeonWidgets = {}
local generalWidgets = {}
local questWidgets = {}
local tweakWidgets = {}

-- Tab Content Frames
local tabTweaks = CreateFrame("Frame", "AutoLazy_TabTweaksFrame", panel)
tabTweaks:SetAllPoints(panel)

local tabLoot = CreateFrame("Frame", "AutoLazy_TabLootFrame", panel)
tabLoot:SetAllPoints(panel)
tabLoot:Hide()

local tabQuests = CreateFrame("Frame", "AutoLazy_TabQuestsFrame", panel)
tabQuests:SetAllPoints(panel)
tabQuests:Hide()

-- Helper: Create a Checkbox
local function CreateCheckbox(name, labelText, tooltipText, parentFrame, point, relFrame, relPoint, x, y, onClick)
    local cb = CreateFrame("CheckButton", name, parentFrame or panel, "UICheckButtonTemplate")
    cb:SetWidth(20)
    cb:SetHeight(20)
    cb:SetPoint(point or "TOPLEFT", relFrame or panel, relPoint or "TOPLEFT", x or 0, y or 0)

    local text = getglobal(name .. "Text")
    if text then
        text:SetText(labelText)
        text:SetFontObject("GameFontHighlightSmall")
        text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    end

    if tooltipText then
        cb:SetScript("OnEnter", function(self)
            local target = self or this or cb
            GameTooltip:SetOwner(target, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText, 1, 1, 1, 1, 1)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    cb:SetScript("OnClick", function(self)
        local target = self or this or cb
        if onClick then onClick(target) end
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end)

    return cb
end

--------------------------------------------------
-- TAB BUTTONS (CENTERED & REORDERED: TWEAKS FIRST)
--------------------------------------------------
local currentTab = 1

local btnTab1 = CreateFrame("Button", "AutoLazy_BtnTab1", panel, "UIPanelButtonTemplate")
btnTab1:SetWidth(130)
btnTab1:SetHeight(22)
btnTab1:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -68)
btnTab1:SetText("Tweaks")

local btnTab2 = CreateFrame("Button", "AutoLazy_BtnTab2", panel, "UIPanelButtonTemplate")
btnTab2:SetWidth(150)
btnTab2:SetHeight(22)
btnTab2:SetPoint("TOPLEFT", panel, "TOPLEFT", 165, -68)
btnTab2:SetText("Loot & Dungeons")

local btnTab3 = CreateFrame("Button", "AutoLazy_BtnTab3", panel, "UIPanelButtonTemplate")
btnTab3:SetWidth(150)
btnTab3:SetHeight(22)
btnTab3:SetPoint("TOPLEFT", panel, "TOPLEFT", 325, -68)
btnTab3:SetText("Quest Automation")

local function ShowTab(tabIndex)
    currentTab = tabIndex
    if AutoLazyDB then AutoLazyDB.SelectedTab = tabIndex end

    tabTweaks:Hide()
    tabLoot:Hide()
    tabQuests:Hide()

    btnTab1:Enable()
    btnTab2:Enable()
    btnTab3:Enable()

    if tabIndex == 1 then
        tabTweaks:Show()
        btnTab1:Disable()
    elseif tabIndex == 2 then
        tabLoot:Show()
        btnTab2:Disable()
    elseif tabIndex == 3 then
        tabQuests:Show()
        btnTab3:Disable()
    end
end

btnTab1:SetScript("OnClick", function() ShowTab(1) end)
btnTab2:SetScript("OnClick", function() ShowTab(2) end)
btnTab3:SetScript("OnClick", function() ShowTab(3) end)

--------------------------------------------------
-- TAB 1: TWEAKS (SYSTEM BLOAT & ADDON TRAY)
--------------------------------------------------
local secTweaksTitle = tabTweaks:CreateFontString(nil, "ARTWORK", "GameFontNormal")
secTweaksTitle:SetPoint("TOPLEFT", tabTweaks, "TOPLEFT", 36, -104)
secTweaksTitle:SetText("|cFFFFD100System Toggles & Addon Tray|r")

local secTweaksDesc = tabTweaks:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
secTweaksDesc:SetPoint("TOPLEFT", tabTweaks, "TOPLEFT", 36, -124)
secTweaksDesc:SetText("Manage system icons, suppress bloat, and configure your draggable Addon Tray.")

-- Section 1: AutoLazy Floating Button
local secHubTitle = tabTweaks:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
secHubTitle:SetPoint("TOPLEFT", tabTweaks, "TOPLEFT", 36, -150)
secHubTitle:SetText("|cFFFFD100AutoLazy Floating Button|r")

local cbShowBtn = CreateCheckbox("AutoLazy_ToggleShowBtn", "Show AutoLazy Button", "Show or hide the floating AutoLazy button on your screen.", tabTweaks, "TOPLEFT", tabTweaks, "TOPLEFT", 36, -170, function(btn)
    if AutoLazyDB then
        AutoLazyDB.ShowButton = (btn:GetChecked() == 1 or btn:GetChecked() == true)
        if AutoLazy_UpdateActionButton then AutoLazy_UpdateActionButton() end
    end
end)
tweakWidgets["ShowButton"] = cbShowBtn

local btnResetBtnPos = CreateFrame("Button", "AutoLazy_BtnResetBtnPos", tabTweaks, "UIPanelButtonTemplate")
btnResetBtnPos:SetWidth(185)
btnResetBtnPos:SetHeight(22)
btnResetBtnPos:SetPoint("TOPLEFT", tabTweaks, "TOPLEFT", 250, -170)
btnResetBtnPos:SetText("Reset Button Position")
btnResetBtnPos:SetScript("OnClick", function()
    if AutoLazy_ResetActionButtonPos then AutoLazy_ResetActionButtonPos() end
end)

-- Section 2: Hide System Bloat (Radio & LFG)
local secBloatTitle = tabTweaks:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
secBloatTitle:SetPoint("TOPLEFT", tabTweaks, "TOPLEFT", 36, -206)
secBloatTitle:SetText("|cFFFFD100Hide Built-in System Bloat (Radio & LFG)|r")

local cbHideRadio = CreateCheckbox("AutoLazy_ToggleHideRadio", "|cFFFF8080Hide Pirate Radio|r", "Permanently hides the Booty Bay Pirate Radio button, stations, mute, and all broadcasting towers.", tabTweaks, "TOPLEFT", tabTweaks, "TOPLEFT", 36, -226, function(btn)
    if AutoLazyDB and AutoLazyDB.Tweaks then
        AutoLazyDB.Tweaks.HideRadio = (btn:GetChecked() == 1 or btn:GetChecked() == true)
        if AutoLazy_ApplySystemIconToggles then AutoLazy_ApplySystemIconToggles() end
    end
end)
tweakWidgets["HideRadio"] = cbHideRadio

local cbHideLfg = CreateCheckbox("AutoLazy_ToggleHideLfg", "|cFFFF8080Hide Group Finder (LFG)|r", "Permanently hides the TurtleWoW Group Finder / Meeting Stone eye button.", tabTweaks, "TOPLEFT", tabTweaks, "TOPLEFT", 250, -226, function(btn)
    if AutoLazyDB and AutoLazyDB.Tweaks then
        AutoLazyDB.Tweaks.HideLfg = (btn:GetChecked() == 1 or btn:GetChecked() == true)
        if AutoLazy_ApplySystemIconToggles then AutoLazy_ApplySystemIconToggles() end
    end
end)
tweakWidgets["HideLfg"] = cbHideLfg

-- Section 3: Addon Tray & Minimap Collapse
local secTrayTitle = tabTweaks:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
secTrayTitle:SetPoint("TOPLEFT", tabTweaks, "TOPLEFT", 36, -262)
secTrayTitle:SetText("|cFFFFD100Addon Tray & Minimap Collapse|r")

local cbCollapse = CreateCheckbox("AutoLazy_ToggleCollapse", "|cFF00FF00Collapse Addons into Tray|r", "Automatically collapses all addon minimap buttons into the tray on login to keep your minimap 100% clean.", tabTweaks, "TOPLEFT", tabTweaks, "TOPLEFT", 36, -282, function(btn)
    if AutoLazyDB and AutoLazyDB.Tweaks then
        AutoLazyDB.Tweaks.CollapseAddons = (btn:GetChecked() == 1 or btn:GetChecked() == true)
        if AutoLazy_CollapseAddons then AutoLazy_CollapseAddons(AutoLazyDB.Tweaks.CollapseAddons) end
    end
end)
tweakWidgets["CollapseAddons"] = cbCollapse

local btnOpenTray = CreateFrame("Button", "AutoLazy_BtnOpenTray", tabTweaks, "UIPanelButtonTemplate")
btnOpenTray:SetWidth(185)
btnOpenTray:SetHeight(22)
btnOpenTray:SetPoint("TOPLEFT", tabTweaks, "TOPLEFT", 250, -282)
btnOpenTray:SetText("Toggle Addon Tray")
btnOpenTray:SetScript("OnClick", function()
    if AutoLazy_ToggleTray then AutoLazy_ToggleTray() end
end)

-- Helpful Control Hints
local tweakTip = tabTweaks:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
tweakTip:SetPoint("TOPLEFT", tabTweaks, "TOPLEFT", 36, -320)
tweakTip:SetPoint("RIGHT", tabTweaks, "RIGHT", -36, 0)
tweakTip:SetJustifyH("LEFT")
tweakTip:SetText("|cFF888888AutoLazy Button Controls:\n  • |cFFFFD100Left-Click:|r Open / Close Addon Tray\n  • |cFFFFD100Right-Click:|r Open AutoLazy Options\n  • |cFF00FF00Click & Drag:|r Move button anywhere on screen|r")

--------------------------------------------------
-- TAB 2: LOOT & DUNGEONS
--------------------------------------------------
local cbMaster = CreateCheckbox("AutoLazy_MasterEnable", "|cFF00FF00Enable Auto-Loot|r", "Master toggle to enable or disable automatic loot rolling in dungeons and raids.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 25, -104, function(btn)
    if AutoLazyDB then
        AutoLazyDB.Enabled = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
generalWidgets["Enabled"] = cbMaster

local cbBop = CreateCheckbox("AutoLazy_OptBop", "Auto-Confirm BoP Dialogs", "Automatically confirms the 'Looting this item will bind it to you' popup globally.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 260, -104, function(btn)
    if AutoLazyDB then
        AutoLazyDB.AutoConfirmBop = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
generalWidgets["AutoConfirmBop"] = cbBop

local cbChat = CreateCheckbox("AutoLazy_OptChat", "Chat Roll Alerts", "Prints a message in chat when AutoLazy rolls on an item.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 25, -130, function(btn)
    if AutoLazyDB then
        AutoLazyDB.AnnounceChat = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
generalWidgets["AnnounceChat"] = cbChat

-- Left Column: Dungeons List
local lblDungeons = tabLoot:CreateFontString(nil, "ARTWORK", "GameFontNormal")
lblDungeons:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 25, -158)
lblDungeons:SetText("|cFFFFD100Dungeons|r")

local dungeonOrder = {
    "The Black Morass",
    "Zul'Gurub",
    "Ruins of Ahn'Qiraj",
    "Naxxramas",
}

local selectedDungeonKey = "The Black Morass"
local dungeonButtons = {}

for i, dKey in ipairs(dungeonOrder) do
    local btn = CreateFrame("Button", "AutoLazy_DungeonBtn_" .. i, tabLoot, "UIPanelButtonTemplate")
    btn:SetWidth(140)
    btn:SetHeight(24)
    btn:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 25, -178 - (i - 1) * 28)
    btn:SetText(dKey)
    btn.dungeonKey = dKey
    btn:SetScript("OnClick", function(self)
        local target = self or this or btn
        selectedDungeonKey = target.dungeonKey
        AutoLazy_UpdateGUI()
    end)
    dungeonButtons[dKey] = btn
end

local lblZone = tabLoot:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
lblZone:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 25, -300)
lblZone:SetPoint("RIGHT", tabLoot, "TOPLEFT", 165, -300)
lblZone:SetJustifyH("LEFT")
lblZone:SetText("Zone: Detecting...")

-- Right Column: Selected Dungeon Details & Items
local lblSelectedTitle = tabLoot:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
lblSelectedTitle:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 180, -158)
lblSelectedTitle:SetText("The Black Morass")

local cbDungeonActive = CreateCheckbox("AutoLazy_DungeonActive", "Active in this Dungeon", "Enable or disable automatic rolling while inside this dungeon.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 180, -178, function(btn)
    if AutoLazyDB and AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[selectedDungeonKey] then
        AutoLazyDB.Dungeons[selectedDungeonKey].Enabled = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)

local lblNonNeed = tabLoot:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
lblNonNeed:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 180, -204)
lblNonNeed:SetText("|cFFFFD100When Auto-Need is OFF:|r")

local cbNonNeedManual = CreateCheckbox("AutoLazy_NonNeedManual", "Roll Manually", "AutoLazy will not auto-roll on this item. The normal game roll dialog stays on your screen so you can roll or pass manually.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 180, -222, function()
    if AutoLazyDB and AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[selectedDungeonKey] then
        AutoLazyDB.Dungeons[selectedDungeonKey].NonNeedMode = "MANUAL"
    end
    AutoLazy_UpdateGUI()
end)

local cbNonNeedGreed = CreateCheckbox("AutoLazy_NonNeedGreed", "Greed", "Automatically roll Greed on items that have Auto-Need turned Off.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 295, -222, function()
    if AutoLazyDB and AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[selectedDungeonKey] then
        AutoLazyDB.Dungeons[selectedDungeonKey].NonNeedMode = "GREED"
    end
    AutoLazy_UpdateGUI()
end)

local cbNonNeedPass = CreateCheckbox("AutoLazy_NonNeedPass", "Pass", "Automatically pass on items that have Auto-Need turned Off.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 365, -222, function()
    if AutoLazyDB and AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[selectedDungeonKey] then
        AutoLazyDB.Dungeons[selectedDungeonKey].NonNeedMode = "PASS"
    end
    AutoLazy_UpdateGUI()
end)

-- 5 Dynamic Item Rows
local itemRows = {}
for i = 1, 5 do
    local row = CreateFrame("Frame", "AutoLazy_ItemRow_" .. i, tabLoot)
    row:SetWidth(295)
    row:SetHeight(34)
    row:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 180, -248 - (i - 1) * 38)

    local iconBtn = CreateFrame("Button", "AutoLazy_ItemIcon_" .. i, row)
    iconBtn:SetWidth(28)
    iconBtn:SetHeight(28)
    iconBtn:SetPoint("LEFT", row, "LEFT", 0, 0)

    local iconTex = iconBtn:CreateTexture(nil, "BORDER")
    iconTex:SetWidth(24)
    iconTex:SetHeight(24)
    iconTex:SetPoint("CENTER", iconBtn, "CENTER", 0, 0)
    row.iconTex = iconTex

    local border = iconBtn:CreateTexture(nil, "OVERLAY")
    border:SetWidth(38)
    border:SetHeight(38)
    border:SetPoint("CENTER", iconBtn, "CENTER", 0, 0)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    iconBtn:SetScript("OnEnter", function(self)
        local target = self or this or iconBtn
        GameTooltip:SetOwner(target, "ANCHOR_RIGHT")
        if row.itemId and row.itemId > 0 then
            GameTooltip:SetHyperlink("item:" .. row.itemId .. ":0:0:0")
        else
            GameTooltip:SetText(row.itemName or "")
        end
        GameTooltip:Show()
    end)
    iconBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.iconBtn = iconBtn

    local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    nameText:SetPoint("LEFT", iconBtn, "RIGHT", 10, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -75, 0)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    local cbNeed = CreateFrame("CheckButton", "AutoLazy_ItemCb_" .. i, row, "UICheckButtonTemplate")
    cbNeed:SetWidth(20)
    cbNeed:SetHeight(20)
    cbNeed:SetPoint("RIGHT", row, "RIGHT", -40, 0)

    local cbNeedText = getglobal("AutoLazy_ItemCb_" .. i .. "Text")
    if cbNeedText then
        cbNeedText:SetPoint("LEFT", cbNeed, "RIGHT", 4, 1)
        cbNeedText:SetFontObject("GameFontHighlightSmall")
    end
    row.cbNeedText = cbNeedText

    cbNeed:SetScript("OnEnter", function(self)
        local target = self or this or cbNeed
        GameTooltip:SetOwner(target, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggle automatic Need rolling on/off for this item.", 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    cbNeed:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    cbNeed:SetScript("OnClick", function(self)
        local target = self or this or cbNeed
        local checked = (target:GetChecked() == 1 or target:GetChecked() == true)
        if row.ruleKey and AutoLazyDB and AutoLazyDB.ItemRules then
            AutoLazyDB.ItemRules[row.ruleKey] = checked
        end
        AutoLazy_UpdateGUI()
    end)
    row.cbNeed = cbNeed

    itemRows[i] = row
end

-- Quick Action Buttons
local btnEnableAll = CreateFrame("Button", "AutoLazy_BtnEnableAll", tabLoot, "UIPanelButtonTemplate")
btnEnableAll:SetWidth(90)
btnEnableAll:SetHeight(20)
btnEnableAll:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 180, -436)
btnEnableAll:SetText("Enable All")
btnEnableAll:SetScript("OnClick", function()
    local items = AutoLazy_DungeonItems and AutoLazy_DungeonItems[selectedDungeonKey]
    if items and AutoLazyDB and AutoLazyDB.ItemRules then
        for _, itm in ipairs(items) do
            local ruleKey = itm.key or string.lower(itm.name)
            AutoLazyDB.ItemRules[ruleKey] = true
        end
        AutoLazy_UpdateGUI()
    end
end)

local btnDisableAll = CreateFrame("Button", "AutoLazy_BtnDisableAll", tabLoot, "UIPanelButtonTemplate")
btnDisableAll:SetWidth(90)
btnDisableAll:SetHeight(20)
btnDisableAll:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 275, -436)
btnDisableAll:SetText("Disable All")
btnDisableAll:SetScript("OnClick", function()
    local items = AutoLazy_DungeonItems and AutoLazy_DungeonItems[selectedDungeonKey]
    if items and AutoLazyDB and AutoLazyDB.ItemRules then
        for _, itm in ipairs(items) do
            local ruleKey = itm.key or string.lower(itm.name)
            AutoLazyDB.ItemRules[ruleKey] = false
        end
        AutoLazy_UpdateGUI()
    end
end)

local btnResetDefaults = CreateFrame("Button", "AutoLazy_BtnResetDefaults", tabLoot, "UIPanelButtonTemplate")
btnResetDefaults:SetWidth(100)
btnResetDefaults:SetHeight(20)
btnResetDefaults:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 370, -436)
btnResetDefaults:SetText("Reset Defaults")
btnResetDefaults:SetScript("OnClick", function()
    local items = AutoLazy_DungeonItems and AutoLazy_DungeonItems[selectedDungeonKey]
    if items and AutoLazyDB and AutoLazyDB.ItemRules then
        for _, itm in ipairs(items) do
            local ruleKey = itm.key or string.lower(itm.name)
            AutoLazyDB.ItemRules[ruleKey] = itm.defaultNeed
        end
        if AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[selectedDungeonKey] then
            AutoLazyDB.Dungeons[selectedDungeonKey].NonNeedMode = "MANUAL"
        end
        AutoLazy_UpdateGUI()
    end
end)

--------------------------------------------------
-- TAB 3: QUEST AUTOMATION
--------------------------------------------------
local secQuestTitle = tabQuests:CreateFontString(nil, "ARTWORK", "GameFontNormal")
secQuestTitle:SetPoint("TOPLEFT", tabQuests, "TOPLEFT", 36, -104)
secQuestTitle:SetText("|cFFFFD100Quest Automation|r")

local secQuestDesc = tabQuests:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
secQuestDesc:SetPoint("TOPLEFT", tabQuests, "TOPLEFT", 36, -124)
secQuestDesc:SetText("Hold |cFFFFD100Shift|r while talking to an NPC to instantly accept and turn in quests.")

local cbQuestMaster = CreateCheckbox("AutoLazy_QuestMaster", "|cFF00FF00Enable Shift + Click Quest Automation|r", "Hold Shift while right-clicking an NPC for instant turn-in and accepting.", tabQuests, "TOPLEFT", tabQuests, "TOPLEFT", 36, -154, function(btn)
    if AutoLazyDB and AutoLazyDB.Quests then
        AutoLazyDB.Quests.Enabled = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
questWidgets["Enabled"] = cbQuestMaster

local cbQuestTurnIn = CreateCheckbox("AutoLazy_QuestTurnIn", "Auto-Turn In Completed Quests", "Automatically turn in and finish completed quests.", tabQuests, "TOPLEFT", tabQuests, "TOPLEFT", 36, -184, function(btn)
    if AutoLazyDB and AutoLazyDB.Quests then
        AutoLazyDB.Quests.AutoTurnIn = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
questWidgets["AutoTurnIn"] = cbQuestTurnIn

local cbQuestAccept = CreateCheckbox("AutoLazy_QuestAccept", "Auto-Accept Available Quests", "Automatically accept newly offered quests.", tabQuests, "TOPLEFT", tabQuests, "TOPLEFT", 36, -214, function(btn)
    if AutoLazyDB and AutoLazyDB.Quests then
        AutoLazyDB.Quests.AutoAccept = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
questWidgets["AutoAccept"] = cbQuestAccept

local cbQuestSafe = CreateCheckbox("AutoLazy_QuestSafe", "Reward Safety (Pause if multiple gear rewards exist)", "Stops auto turn-in when multiple rewards are offered so you can choose gear manually.", tabQuests, "TOPLEFT", tabQuests, "TOPLEFT", 36, -244, function(btn)
    if AutoLazyDB and AutoLazyDB.Quests then
        AutoLazyDB.Quests.SafeRewards = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
questWidgets["SafeRewards"] = cbQuestSafe

local cbQuestAlways = CreateCheckbox("AutoLazy_QuestAlways", "Always Active (Does not require holding Shift)", "Automatically handles quests on all NPC interactions without holding Shift.", tabQuests, "TOPLEFT", tabQuests, "TOPLEFT", 36, -274, function(btn)
    if AutoLazyDB and AutoLazyDB.Quests then
        AutoLazyDB.Quests.AlwaysActive = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
questWidgets["AlwaysActive"] = cbQuestAlways

--------------------------------------------------
-- BOTTOM ACTION BUTTONS (CENTERED & BALANCED)
--------------------------------------------------
local btnStatus = CreateFrame("Button", "AutoLazy_BtnStatus", panel, "UIPanelButtonTemplate")
btnStatus:SetWidth(130)
btnStatus:SetHeight(24)
btnStatus:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 25, 18)
btnStatus:SetText("Check Status")
btnStatus:SetScript("OnClick", function()
    if AutoLazy_PrintStatus then AutoLazy_PrintStatus() end
end)

local btnClose = CreateFrame("Button", "AutoLazy_BtnClose", panel, "UIPanelButtonTemplate")
btnClose:SetWidth(120)
btnClose:SetHeight(24)
btnClose:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -25, 18)
btnClose:SetText("Close")
btnClose:SetScript("OnClick", function()
    panel:Hide()
end)

--------------------------------------------------
-- GUI SYNCHRONIZATION WITH DATABASE
--------------------------------------------------
function AutoLazy_UpdateGUI()
    if not AutoLazyDB then return end

    -- Tab synchronization
    ShowTab(AutoLazyDB.SelectedTab or 1)

    -- Master enable
    if generalWidgets["Enabled"] then
        generalWidgets["Enabled"]:SetChecked(AutoLazyDB.Enabled == true)
    end

    -- General options
    if generalWidgets["AutoConfirmBop"] then
        generalWidgets["AutoConfirmBop"]:SetChecked(AutoLazyDB.AutoConfirmBop == true)
    end
    if generalWidgets["AnnounceChat"] then
        generalWidgets["AnnounceChat"]:SetChecked(AutoLazyDB.AnnounceChat == true)
    end

    -- Tab 2 Master-Detail Dungeon and Items Synchronization
    if selectedDungeonKey and dungeonButtons then
        for dKey, btn in pairs(dungeonButtons) do
            if dKey == selectedDungeonKey then
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        end

        local curZone, _, curDef = AutoLazy_ResolveCurrentDungeon and AutoLazy_ResolveCurrentDungeon()
        if curDef then
            lblZone:SetText("|cFF00FF00In: " .. curDef.title .. "|r")
        else
            local z = (GetZoneText and GetZoneText()) or "World"
            lblZone:SetText("|cFF888888Zone: " .. z .. "|r")
        end

        lblSelectedTitle:SetText(selectedDungeonKey)

        local cfg = AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[selectedDungeonKey]
        if cfg then
            cbDungeonActive:SetChecked(cfg.Enabled == true)
            local nonNeed = cfg.NonNeedMode or "MANUAL"
            cbNonNeedManual:SetChecked(nonNeed == "MANUAL")
            cbNonNeedGreed:SetChecked(nonNeed == "GREED")
            cbNonNeedPass:SetChecked(nonNeed == "PASS")
        end

        local items = AutoLazy_DungeonItems and AutoLazy_DungeonItems[selectedDungeonKey]
        for i = 1, 5 do
            local row = itemRows[i]
            if row then
                local itm = items and items[i]
                if itm then
                    row.itemId = itm.id
                    row.itemName = itm.name
                    row.ruleKey = itm.key or string.lower(itm.name)
                    row.iconTex:SetTexture(itm.texture)

                    local color = (itm.quality == 3 and "|cFF0070DD") or (itm.quality == 2 and "|cFF1EFF00") or (itm.quality == 4 and "|cFFA335EE") or "|cFFFFFFFF"
                    row.nameText:SetText(color .. itm.name .. "|r")

                    local isNeed = (AutoLazyDB.ItemRules and AutoLazyDB.ItemRules[row.ruleKey] == true)
                    row.cbNeed:SetChecked(isNeed)
                    if row.cbNeedText then
                        row.cbNeedText:SetText(isNeed and "|cFFFF8000Need|r" or "|cFF888888Off|r")
                    end
                    row:Show()
                else
                    row:Hide()
                end
            end
        end
    end

    -- Quest widgets
    if AutoLazyDB.Quests then
        for qKey, widget in pairs(questWidgets) do
            if widget then
                widget:SetChecked(AutoLazyDB.Quests[qKey] == true)
            end
        end
    end

    -- Tweak widgets
    if tweakWidgets["ShowButton"] then
        tweakWidgets["ShowButton"]:SetChecked(AutoLazyDB.ShowButton ~= false)
    end

    if AutoLazyDB.Tweaks then
        if tweakWidgets["HideRadio"] then
            tweakWidgets["HideRadio"]:SetChecked(AutoLazyDB.Tweaks.HideRadio == true)
        end
        if tweakWidgets["HideLfg"] then
            tweakWidgets["HideLfg"]:SetChecked(AutoLazyDB.Tweaks.HideLfg == true)
        end
        if tweakWidgets["CollapseAddons"] then
            tweakWidgets["CollapseAddons"]:SetChecked(AutoLazyDB.Tweaks.CollapseAddons ~= false)
        end
    end
end

-- Toggle GUI Visibility
function AutoLazy_ToggleGUI()
    if panel:IsShown() then
        panel:Hide()
    else
        AutoLazy_UpdateGUI()
        panel:Show()
    end
end

panel:SetScript("OnShow", function()
    AutoLazy_UpdateGUI()
end)
