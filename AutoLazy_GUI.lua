-- AutoLazy Options GUI for WoW 1.12.1 (Vanilla Enhanced)
-- Author & Maintainer: Fostercare5988
-- Built natively for ClassicAPI v1.13.3+, SuperWoW 2.2+, NamPower, UnitXP SP3, DXVK

-- Strict Engine Dependency Guard (Mandatory ClassicAPI v1.13.3+ & SuperWoW v2.2+)
if not (CLASSIC_API_VERSION and SUPERWOW_VERSION) then return end

local panel = CreateFrame("Frame", "AutoLazy_OptionsFrame", UIParent)
panel:SetWidth(480)
panel:SetHeight(430)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
panel:SetFrameStrata("DIALOG")
panel:SetToplevel(true)
panel:EnableMouse(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
panel:Hide()

-- Allow closing with ESC key
tinsert(UISpecialFrames, "AutoLazy_OptionsFrame")

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
        cb:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText, 1, 1, 1, 1, 1)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    cb:SetScript("OnClick", function()
        if onClick then onClick(this) end
        if AutoLazy_UpdateGUI then AutoLazy_UpdateGUI() end
    end)

    return cb
end

--------------------------------------------------
-- TAB BUTTONS (CENTERED & REORDERED: TWEAKS FIRST)
--------------------------------------------------
local currentTab = 1

local btnTab1 = CreateFrame("Button", "AutoLazy_BtnTab1", panel, "UIPanelButtonTemplate")
btnTab1:SetWidth(125)
btnTab1:SetHeight(22)
btnTab1:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -68)
btnTab1:SetText("Tweaks")

local btnTab2 = CreateFrame("Button", "AutoLazy_BtnTab2", panel, "UIPanelButtonTemplate")
btnTab2:SetWidth(145)
btnTab2:SetHeight(22)
btnTab2:SetPoint("TOPLEFT", panel, "TOPLEFT", 158, -68)
btnTab2:SetText("Loot & Dungeons")

local btnTab3 = CreateFrame("Button", "AutoLazy_BtnTab3", panel, "UIPanelButtonTemplate")
btnTab3:SetWidth(145)
btnTab3:SetHeight(22)
btnTab3:SetPoint("TOPLEFT", panel, "TOPLEFT", 311, -68)
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
local cbMaster = CreateCheckbox("AutoLazy_MasterEnable", "|cFF00FF00Enable Auto-Loot|r", "Master toggle to enable or disable automatic loot rolling in dungeons and raids.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 36, -104, function(btn)
    if AutoLazyDB then
        AutoLazyDB.Enabled = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
generalWidgets["Enabled"] = cbMaster

local cbBop = CreateCheckbox("AutoLazy_OptBop", "Auto-Confirm BoP Dialogs", "Automatically confirms the 'Looting this item will bind it to you' popup globally.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 250, -104, function(btn)
    if AutoLazyDB then
        AutoLazyDB.AutoConfirmBop = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
generalWidgets["AutoConfirmBop"] = cbBop

local cbFarmOnly = CreateCheckbox("AutoLazy_FarmOnly", "|cFFFFFF00Farm items ONLY|r (Ignores gear)", "Only auto-roll on farm items (Sand, Coins, Bijous, Scarabs, Idols). Weapons and gear are skipped for manual rolling.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 36, -130, function(btn)
    if AutoLazyDB then
        AutoLazyDB.FarmOnly = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
generalWidgets["FarmOnly"] = cbFarmOnly

local cbChat = CreateCheckbox("AutoLazy_OptChat", "Chat Roll Alerts", "Prints a message in chat when AutoLazy rolls on an item.", tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 250, -130, function(btn)
    if AutoLazyDB then
        AutoLazyDB.AnnounceChat = (btn:GetChecked() == 1 or btn:GetChecked() == true)
    end
end)
generalWidgets["AnnounceChat"] = cbChat

local secDungeons = tabLoot:CreateFontString(nil, "ARTWORK", "GameFontNormal")
secDungeons:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 36, -162)
secDungeons:SetText("|cFFFFD100Dungeon Rules|r")

local dungeonList = {
    { key = "The Black Morass", name = "The Black Morass", items = "(Corrupted Sand)", y = -184 },
    { key = "Zul'Gurub", name = "Zul'Gurub", items = "(Coins & Bijous)", y = -232 },
    { key = "Ruins of Ahn'Qiraj", name = "Ruins of Ahn'Qiraj", items = "(Scarabs, Idols, Keys)", y = -280 },
}

for i, d in ipairs(dungeonList) do
    local dKey = d.key
    dungeonWidgets[dKey] = {}

    local lblTitle = tabLoot:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblTitle:SetPoint("TOPLEFT", tabLoot, "TOPLEFT", 36, d.y)
    lblTitle:SetText(d.name .. "  |cFF888888" .. d.items .. "|r")

    local cbActive = CreateCheckbox("AutoLazy_Active_" .. i, "Active", "Enable auto-rolling for " .. d.name, tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 36, d.y - 18, function(btn)
        if AutoLazyDB and AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[dKey] then
            AutoLazyDB.Dungeons[dKey].Enabled = (btn:GetChecked() == 1 or btn:GetChecked() == true)
        end
    end)
    dungeonWidgets[dKey].Active = cbActive

    local rNeed = CreateCheckbox("AutoLazy_Need_" .. i, "|cFFFF8000Need|r", "Auto-roll Need in " .. d.name, tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 145, d.y - 18, function(btn)
        if AutoLazyDB and AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[dKey] then
            AutoLazyDB.Dungeons[dKey].Mode = "NEED"
        end
    end)
    dungeonWidgets[dKey].Need = rNeed

    local rGreed = CreateCheckbox("AutoLazy_Greed_" .. i, "|cFF00FF00Greed|r", "Auto-roll Greed in " .. d.name, tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 245, d.y - 18, function(btn)
        if AutoLazyDB and AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[dKey] then
            AutoLazyDB.Dungeons[dKey].Mode = "GREED"
        end
    end)
    dungeonWidgets[dKey].Greed = rGreed

    local rPass = CreateCheckbox("AutoLazy_Pass_" .. i, "|cFF888888Pass|r", "Auto-roll Pass in " .. d.name, tabLoot, "TOPLEFT", tabLoot, "TOPLEFT", 345, d.y - 18, function(btn)
        if AutoLazyDB and AutoLazyDB.Dungeons and AutoLazyDB.Dungeons[dKey] then
            AutoLazyDB.Dungeons[dKey].Mode = "PASS"
        end
    end)
    dungeonWidgets[dKey].Pass = rPass
end

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
btnStatus:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 36, 18)
btnStatus:SetText("Check Status")
btnStatus:SetScript("OnClick", function()
    if AutoLazy_PrintStatus then AutoLazy_PrintStatus() end
end)

local btnClose = CreateFrame("Button", "AutoLazy_BtnClose", panel, "UIPanelButtonTemplate")
btnClose:SetWidth(120)
btnClose:SetHeight(24)
btnClose:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 18)
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
    if generalWidgets["FarmOnly"] then
        generalWidgets["FarmOnly"]:SetChecked(AutoLazyDB.FarmOnly == true)
    end
    if generalWidgets["AutoConfirmBop"] then
        generalWidgets["AutoConfirmBop"]:SetChecked(AutoLazyDB.AutoConfirmBop == true)
    end
    if generalWidgets["AnnounceChat"] then
        generalWidgets["AnnounceChat"]:SetChecked(AutoLazyDB.AnnounceChat == true)
    end

    -- Dungeon rows
    if AutoLazyDB.Dungeons then
        for dKey, widgets in pairs(dungeonWidgets) do
            local cfg = AutoLazyDB.Dungeons[dKey]
            if cfg then
                if widgets.Active then
                    widgets.Active:SetChecked(cfg.Enabled == true)
                end
                local mode = cfg.Mode or "NEED"
                if widgets.Need then widgets.Need:SetChecked(mode == "NEED") end
                if widgets.Greed then widgets.Greed:SetChecked(mode == "GREED") end
                if widgets.Pass then widgets.Pass:SetChecked(mode == "PASS") end
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
