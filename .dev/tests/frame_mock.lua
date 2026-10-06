-- Frame state model for Lua 5.1 tests; native calls share inherited methods.
-- This models Lua behavior, not C++ frame memory safety or real hit testing.
local frames, methods = {}, {}
local function invoke(frame, script, ...)
    local oldThis, oldEvent, oldArg1, oldArg2 = this, event, arg1, arg2
    this = frame
    if script == "OnEvent" then event, arg1, arg2 = unpack(arg, 1, arg.n)
    else arg1, arg2 = unpack(arg, 1, arg.n) end
    if frame.scripts[script] then frame.scripts[script](frame, unpack(arg, 1, arg.n)) end
    for _, callback in ipairs(frame.hooks[script] or {}) do
        callback(frame, unpack(arg, 1, arg.n))
    end
    this, event, arg1, arg2 = oldThis, oldEvent, oldArg1, oldArg2
end
function MockRunScript(frame, script, ...) invoke(frame, script, unpack(arg, 1, arg.n)) end
function methods:GetName() return self.name end
function methods:GetObjectType() return self.frameType end
function methods:IsObjectType(kind) return kind == self.frameType or kind == "Frame" end
function methods:GetParent() return self.parent end
function methods:SetParent() error("Foreign parent mutation is forbidden") end
function methods:GetChildren() error("Frame tree traversal is forbidden") end
function methods:SetScript(script, callback) self.scripts[script] = callback end
function methods:GetScript(script) return self.scripts[script] end
function methods:HookScript(script, callback)
    self.hooks[script] = self.hooks[script] or {}
    table.insert(self.hooks[script], callback)
end
function methods:RegisterEvent(ev) self.events[ev] = true end
function methods:UnregisterEvent(ev) self.events[ev] = nil end
function methods:IsShown() return self.shown end
function methods:IsVisible()
    return self.shown and (not self.parent or self.parent:IsVisible())
end
local function descendants(frame, script)
    for _, child in ipairs(frames) do
        if child.parent == frame and child.shown then
            invoke(child, script)
            descendants(child, script)
        end
    end
end
function methods:Show()
    self.showCalls = (self.showCalls or 0) + 1
    if self.shown then return end
    self.shown = true
    invoke(self, "OnShow")
    if self.shown then descendants(self, "OnShow") end
end
function methods:Hide()
    self.hideCalls = (self.hideCalls or 0) + 1
    if not self.shown then return end
    self.shown = false
    invoke(self, "OnHide")
    descendants(self, "OnHide")
end
-- Native SetShown bypasses per-object Lua Show/Hide methods.
function methods:SetShown(shown)
    if shown then methods.Show(self) else methods.Hide(self) end
end
function methods:GetNumPoints() return table.getn(self.points) end
function methods:GetPoint(index)
    local point = self.points[index or 1]
    if point then return unpack(point, 1, 5) end
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then
        x, y, relative, relativePoint = relative, relativePoint, self.parent, point
    end
    if type(relative) == "string" then relative = getglobal(relative) end
    relative = relative or self.parent
    relativePoint, x, y = relativePoint or point, x or 0, y or 0
    local value = { point, relative, relativePoint, x, y }
    for i, old in ipairs(self.points) do
        if old[1] == point then self.points[i] = value; return end
    end
    table.insert(self.points, value)
end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetSize(w, h) self:SetWidth(w); self:SetHeight(h) end
function methods:SetAlpha(value) self.alpha = value end
function methods:GetAlpha() return self.alpha end
function methods:EnableMouse(value) self.mouse = value and true or false end
function methods:IsMouseEnabled() return self.mouse end
function methods:SetFrameStrata(value) self.strata = value end
function methods:GetFrameStrata() return self.strata end
function methods:SetFrameLevel(value)
    local diff = value - self.level
    self.level = value
    for _, child in ipairs(frames) do
        if child.parent == self then methods.SetFrameLevel(child, child.level + diff) end
    end
end
function methods:GetFrameLevel() return self.level end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:IsEnabled() return self.enabled end
function methods:SetChecked(value) self.checked = value and true or false end
function methods:GetChecked() return self.checked end
function methods:LockHighlight() self.highlightLocked = true end
function methods:UnlockHighlight() self.highlightLocked = false end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:SetBackdropColor(...) self.backdropColor = arg end
function methods:SetBackdropBorderColor(...) self.backdropBorderColor = arg end
function methods:SetScale(value) self.scale = value end
function methods:GetScale() return self.scale end
function methods:GetEffectiveScale()
    return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1)
end
function methods:GetCenter() return self.centerX or 1500, self.centerY or 900 end
function methods:GetLeft() return self.left or 500 end
function methods:GetTop() return self.top or 800 end
function methods:GetBottom() return self.bottom or 400 end
function methods:SetHitRectInsets(left, right, top, bottom) self.hitInsets = {left, right, top, bottom} end
function methods:IsMouseOver() return self.mouseOver or false end
function methods:SetNormalTexture(path) self.normal = self:CreateTexture(); self.normal:SetTexture(path) end
function methods:GetNormalTexture() return self.normal end
function methods:GetRegions() return unpack(self.regions) end
function methods:CreateTexture()
    local texture = { SetPoint = function() end, SetWidth = function() end,
        SetHeight = function() end, SetTexCoord = function() end,
        SetTexture = function(self, path) self.path = path end,
        SetAllPoints = function(self, target) self.allPoints = target end,
        GetTexture = function(self) return self.path end }
    table.insert(self.regions, texture)
    return texture
end
function methods:CreateFontString(name)
    local text = { points = {}, SetPoint = methods.SetPoint, ClearAllPoints = methods.ClearAllPoints,
        SetText = methods.SetText, GetText = methods.GetText,
        SetFontObject = function(self, font) self.font = font end,
        SetJustifyH = function(self, value) self.justifyH = value end }
    if name then _G[name] = text end
    return text
end
for _, name in ipairs({ "SetToplevel", "SetClampedToScreen", "SetHighlightTexture", "SetMovable", "RegisterForClicks",
    "RegisterForDrag", "SetPushedTexture", "SetDisabledTexture", "StartMoving",
    "StopMovingOrSizing", "SetAllPoints" }) do methods[name] = function() end end
function CreateFrame(frameType, name, parent, template)
    local frame = setmetatable({ [0] = newproxy(), name = name, frameType = frameType,
        parent = parent, scripts = {}, hooks = {}, events = {}, points = {}, regions = {},
        width = 0, height = 0, alpha = 1, mouse = frameType == "Button", shown = true, enabled = true,
        strata = "MEDIUM", level = parent and parent:GetFrameLevel() + 1 or 1, scale = 1,
    }, { __index = methods })
    if frameType == "Button" then frame.scripts.OnClick = function() end end
    if name then _G[name] = frame end
    if template == "UICheckButtonTemplate" then frame:CreateFontString(name .. "Text") end
    table.insert(frames, frame)
    return frame
end
UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
MinimapBackdrop = CreateFrame("Frame", "MinimapBackdrop", MinimapCluster)
Minimap = CreateFrame("Frame", "Minimap", MinimapBackdrop)
Minimap:SetSize(140, 140)
GameTooltip = { SetOwner = function() end, AddLine = function() end,
    SetText = function() end, SetHyperlink = function() end,
    Show = function() end, Hide = function() end }
function IsShiftKeyDown() return false end
function MockButton(name, parent)
    local frame = CreateFrame("Button", name, parent or Minimap)
    frame:SetSize(32, 32)
    frame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 10, -20)
    frame:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    return frame
end
function MockFlushTimers()
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do timer.callback() end
end
function MockFrameCount() return table.getn(frames) end
