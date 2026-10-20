-- AutoLazy surfaces, WoW 1.12.1 / ClassicAPI 1.16.0+.
-- Rounded shapes are nine-slices of one white disc, tinted per use, so any
-- size keeps crisp corners. Shared by the options window and the tray.
if not AutoLazy then return end

local MEDIA = "Interface\\AddOns\\AutoLazy\\Media\\"

-- Warm grey surfaces with orange text and controls.
local Style = {
    disc = MEDIA .. "Disc", shadow = MEDIA .. "Shadow", close = MEDIA .. "Close",
    shadowColor = { 0, 0, 0, 0.55 },
    edge = { 1.00, 0.60, 0.25, 0.45 },
    surface = { 0.24, 0.23, 0.22, 0.97 },
    track = { 0.17, 0.16, 0.155, 1 },
    control = { 0.32, 0.305, 0.29, 1 },
    selected = { 0.66, 0.31, 0.07, 1 },
    accent = { 1.00, 0.58, 0.18, 1 },
    knob = { 0.62, 0.60, 0.58, 1 },
    row = { 1, 1, 1, 0.05 },
    hover = { 1, 1, 1, 0.08 },
    clear = { 0, 0, 0, 0 },
    heading = { 1.00, 0.62, 0.22 }, text = { 1.00, 0.84, 0.66 }, hint = { 0.72, 0.69, 0.66 },
}
AutoLazy.Style = Style

-- Per axis: first half, a thin middle strip to stretch, last half.
local SPANS = { { 0, 0.5 }, { 0.49, 0.51 }, { 0.5, 1 } }

function Style.Paint(shape, color)
    if shape.color == color then return end
    shape.color = color
    for i = 1, 9 do shape[i]:SetVertexColor(color[1], color[2], color[3], color[4]) end
end

-- outset grows the shape past the frame (negative insets it); dy shifts it.
function Style.Rounded(frame, layer, radius, color, outset, file, dy)
    outset, dy = outset or 0, dy or 0
    local shape = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local piece = frame:CreateTexture(nil, layer)
            piece:SetTexture(file or Style.disc)
            piece:SetTexCoord(SPANS[col][1], SPANS[col][2], SPANS[row][1], SPANS[row][2])
            shape[(row - 1) * 3 + col] = piece
        end
    end
    local tl, tr, bl, br = shape[1], shape[3], shape[7], shape[9]
    for _, corner in ipairs({ tl, tr, bl, br }) do
        corner:SetWidth(radius); corner:SetHeight(radius)
    end
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset + dy)
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", outset, outset + dy)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -outset, -outset + dy)
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset + dy)
    local function Span(piece, first, firstPoint, last, lastPoint)
        piece:SetPoint("TOPLEFT", first, firstPoint)
        piece:SetPoint("BOTTOMRIGHT", last, lastPoint)
    end
    Span(shape[2], tl, "TOPRIGHT", tr, "BOTTOMLEFT")
    Span(shape[4], tl, "BOTTOMLEFT", bl, "TOPRIGHT")
    Span(shape[5], tl, "BOTTOMRIGHT", br, "TOPLEFT")
    Span(shape[6], tr, "BOTTOMLEFT", br, "TOPRIGHT")
    Span(shape[8], bl, "TOPRIGHT", br, "BOTTOMLEFT")
    Style.Paint(shape, color)
    return shape
end

-- A floating card: soft shadow, a faint orange rim and the grey surface.
-- Uses the frame's BACKGROUND, BORDER and ARTWORK layers; text goes on OVERLAY.
function Style.Surface(frame, radius)
    Style.Rounded(frame, "BACKGROUND", radius + 10, Style.shadowColor, 12, Style.shadow, -3)
    Style.Rounded(frame, "BORDER", radius, Style.edge)
    return Style.Rounded(frame, "ARTWORK", radius - 1, Style.surface, -1)
end
