-- MonkeyTracker: PIAssistanceFrame.lua
-- Compact display showing tracked players currently in an active DPS burst window.

RAPE.PIFrame = RAPE.PIFrame or {}
local PIF = RAPE.PIFrame

local FRAME_W     = 220
local ROW_H       = 22
local HEADER_H    = 24
local FRAME_PAD   = 4

-- ============================================================
-- Build the frame
-- ============================================================

function PIF.Build()
    if PIF.frame then return end

    local frame = CreateFrame("Frame", "MonkeyTrackerPIAssistance", UIParent, "BackdropTemplate")
    PIF.frame = frame
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetSize(FRAME_W, HEADER_H + FRAME_PAD * 2)

    -- Position: near center right
    frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
    frame:SetBackdropBorderColor(0.55, 0.55, 0.10, 0.9)

    -- Header
    local header = CreateFrame("Frame", nil, frame)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.20, 0.20, 0.03, 0.95)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    local titleFont = title:GetFont() or "Fonts\\FRIZQT__.TTF"
    title:SetFont(titleFont, 12, "OUTLINE")
    title:SetText("|cffffff00PI Assistance|r")
    PIF.title = title

    -- Drag
    header:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then frame:StartMoving() end
    end)
    header:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
    end)

    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT",  header, "BOTTOMLEFT",  FRAME_PAD, -2)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FRAME_PAD, FRAME_PAD)
    PIF.content = content

    PIF.rows = {}

    -- Empty label
    local emptyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("CENTER", content, "CENTER", 0, 0)
    emptyLabel:SetText("No active CDs")
    PIF.emptyLabel = emptyLabel

    frame:Hide()  -- hidden by default
end

-- ============================================================
-- Create/reuse row frames
-- ============================================================

local function GetRow(index)
    if PIF.rows[index] then return PIF.rows[index] end

    local row = CreateFrame("Frame", nil, PIF.content)
    row:SetHeight(ROW_H)

    -- Player name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWidth(110)
    row.nameText = nameText

    -- Spell name
    local spellText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellText:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
    spellText:SetJustifyH("LEFT")
    spellText:SetWidth(70)
    row.spellText = spellText

    -- Timer
    local timerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    timerText:SetJustifyH("RIGHT")
    timerText:SetWidth(30)
    row.timerText = timerText

    -- Subtle background for alternating rows
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.03)
    row.bg = bg

    PIF.rows[index] = row
    return row
end

-- ============================================================
-- Refresh display
-- ============================================================

function PIF.Refresh()
    if not PIF.frame then return end

    local mode = RAPE.db.piAssistanceMode or 3
    if mode == 2 then 
        -- Mode 2 is Highlight Only. Hide list.
        PIF.frame:Hide()
        return 
    end

    local players = {}
    for playerName, info in pairs(RAPE.PI.ActivePlayers) do
        local class = RAPE.Roster[playerName]
        local spellName = RAPE.SpellDB[info.spellID] and RAPE.SpellDB[info.spellID].name or "Unknown"
        table.insert(players, {
            name = playerName,
            class = class,
            spellName = spellName,
            remaining = info.remaining or 0
        })
    end

    -- Sort by time remaining (ascending)
    table.sort(players, function(a, b)
        return a.remaining < b.remaining
    end)

    local count = #players

    if count > 0 and not PIF.manualHide then
        PIF.frame:Show()
    elseif count == 0 and not PIF.manualShow then
        PIF.frame:Hide()
    end

    if not PIF.frame:IsShown() then return end

    -- Update rows
    for i, data in ipairs(players) do
        local row = GetRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  PIF.content, "TOPLEFT",  0, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", PIF.content, "TOPRIGHT", 0, -(i - 1) * ROW_H)

        -- Class-colored name
        if data.class then
            local r, g, b = RAPE.GetClassColor(data.class)
            row.nameText:SetTextColor(r, g, b, 1)
        else
            row.nameText:SetTextColor(1, 1, 1, 1)
        end
        row.nameText:SetText(data.name)

        row.spellText:SetTextColor(0.9, 0.9, 0.9, 1)
        row.spellText:SetText(data.spellName)

        row.timerText:SetTextColor(1.0, 0.8, 0.0, 1)
        row.timerText:SetText(RAPE.FormatTime(data.remaining))

        row.bg:SetShown(i % 2 == 0)
        row:Show()
    end

    -- Hide extra rows
    for i = count + 1, #PIF.rows do
        PIF.rows[i]:Hide()
    end

    local contentH = math.max(ROW_H, count * ROW_H)
    PIF.frame:SetHeight(HEADER_H + contentH + FRAME_PAD * 2 + 2)
    PIF.emptyLabel:SetShown(count == 0)
end

function PIF.Show()
    if not PIF.frame then PIF.Build() end
    PIF.manualShow = true
    PIF.manualHide = false
    PIF.frame:Show()
    PIF.Refresh()
end

function PIF.Hide()
    PIF.manualShow = false
    PIF.manualHide = true
    if PIF.frame then PIF.frame:Hide() end
end

function PIF.Toggle()
    if not PIF.frame then
        PIF.Build()
        PIF.Show()
        return
    end
    if PIF.frame:IsShown() then
        PIF.Hide()
    else
        PIF.Show()
    end
end
