-- MonkeyTracker: NullCoronaFrame.lua
-- Compact display showing players currently affected by Null Corona.

RAPE.NullCoronaFrame = RAPE.NullCoronaFrame or {}
local NCF = RAPE.NullCoronaFrame

local FRAME_W     = 240
local ROW_H       = 24
local HEADER_H    = 24
local FRAME_PAD   = 4
local UPDATE_TICK = 0.25

-- Helper to format large numbers (e.g. 1.2M, 850k)
local function FormatValue(val)
    if val >= 1000000 then
        return string.format("%.1fM", val / 1000000)
    elseif val >= 1000 then
        return string.format("%.0fk", val / 1000)
    else
        return tostring(val)
    end
end

-- ============================================================
-- Build the frame
-- ============================================================

function NCF.Build()
    if NCF.frame then return end

    local frame = CreateFrame("Frame", "MonkeyTrackerNullCorona", UIParent, "BackdropTemplate")
    NCF.frame = frame
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetSize(FRAME_W, HEADER_H + FRAME_PAD * 2)

    -- Position: near the void marked frame by default
    frame:SetPoint("TOP", UIParent, "TOP", 250, -120)

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.08, 0.02, 0.12, 0.92)
    frame:SetBackdropBorderColor(0.20, 0.60, 0.80, 0.9)

    -- Header
    local header = CreateFrame("Frame", nil, frame)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.05, 0.15, 0.25, 0.95)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    local titleFont = title:GetFont() or "Fonts\\FRIZQT__.TTF"
    title:SetFont(titleFont, 12, "OUTLINE")
    title:SetText("|cff33ccffNull Corona|r")
    NCF.title = title

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
    NCF.content = content

    -- Row pool
    NCF.rows = {}

    -- Empty label
    local emptyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("CENTER", content, "CENTER", 0, 0)
    emptyLabel:SetText("No players affected")
    NCF.emptyLabel = emptyLabel

    -- Update ticker
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= UPDATE_TICK then
            elapsed = 0
            NCF.Refresh()
        end
    end)

    frame:Hide()  -- hidden by default
end

-- ============================================================
-- Create/reuse row frames
-- ============================================================

local function GetRow(index)
    if NCF.rows[index] then return NCF.rows[index] end

    local row = CreateFrame("Frame", nil, NCF.content)
    row:SetHeight(ROW_H)

    -- Player name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWidth(90)
    row.nameText = nameText

    -- Absorb value
    local absorbText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    absorbText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    absorbText:SetJustifyH("RIGHT")
    row.absorbText = absorbText

    -- Progress Bar for Absorb Remaining
    local statusBar = CreateFrame("StatusBar", nil, row)
    statusBar:SetPoint("BOTTOMLEFT", nameText, "BOTTOMRIGHT", 4, -4)
    statusBar:SetPoint("BOTTOMRIGHT", absorbText, "BOTTOMLEFT", -4, -4)
    statusBar:SetHeight(16)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetStatusBarColor(0.2, 0.8, 1.0, 0.8)
    
    local bg = statusBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    row.statusBar = statusBar

    -- Subtle background for alternating rows
    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints()
    rowBg:SetColorTexture(1, 1, 1, 0.03)
    row.bg = rowBg

    NCF.rows[index] = row
    return row
end

-- ============================================================
-- Refresh display
-- ============================================================

function NCF.Refresh()
    if not NCF.frame then return end
    
    -- Ensure tracker is enabled in settings
    if not RAPE.db.NullCoronaTracker then
        NCF.frame:Hide()
        return
    end

    local players = RAPE.GetNullCoronaPlayers()
    local count   = #players

    if count > 0 and not NCF.manualHide then
        NCF.frame:Show()
    elseif count == 0 and not NCF.manualShow then
        NCF.frame:Hide()
    end

    if not NCF.frame:IsShown() then return end

    -- Update rows
    for i, data in ipairs(players) do
        local row = GetRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  NCF.content, "TOPLEFT",  0, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", NCF.content, "TOPRIGHT", 0, -(i - 1) * ROW_H)

        -- Class-colored name
        local r, g, b = RAPE.GetClassColor(data.class)
        row.nameText:SetTextColor(r, g, b, 1)
        row.nameText:SetText(data.name)

        -- Absorb text
        row.absorbText:SetTextColor(0.3, 0.9, 1.0, 1)
        row.absorbText:SetText(FormatValue(data.remaining))

        -- Status bar (Remaining / Initial)
        if data.initial and data.initial > 0 then
            row.statusBar:SetMinMaxValues(0, data.initial)
            row.statusBar:SetValue(data.remaining)
        else
            row.statusBar:SetMinMaxValues(0, 1)
            row.statusBar:SetValue(1)
        end

        row.bg:SetShown(i % 2 == 0)
        row:Show()
    end

    -- Hide extra rows
    for i = count + 1, #NCF.rows do
        NCF.rows[i]:Hide()
    end

    local contentH = math.max(ROW_H, count * ROW_H)
    NCF.frame:SetHeight(HEADER_H + contentH + FRAME_PAD * 2 + 2)
    NCF.emptyLabel:SetShown(count == 0)
end

-- ============================================================
-- Show / Hide / Toggle
-- ============================================================

function NCF.Show()
    if not NCF.frame then NCF.Build() end
    NCF.manualShow = true
    NCF.manualHide = false
    NCF.frame:Show()
    NCF.Refresh()
end

function NCF.Hide()
    NCF.manualShow = false
    NCF.manualHide = true
    if NCF.frame then NCF.frame:Hide() end
end

function NCF.Toggle()
    if not NCF.frame then
        NCF.Build()
        NCF.Show()
        return
    end
    if NCF.frame:IsShown() then
        NCF.Hide()
    else
        NCF.Show()
    end
end
