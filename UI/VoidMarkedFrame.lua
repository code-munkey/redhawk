-- MonkeyTracker: VoidMarkedFrame.lua
-- Compact display showing players currently affected by Void Marked.

RAPE.VoidMarkedFrame = RAPE.VoidMarkedFrame or {}
local VMF = RAPE.VoidMarkedFrame

local FRAME_W     = 220
local ROW_H       = 22
local HEADER_H    = 24
local FRAME_PAD   = 4
local UPDATE_TICK = 0.25

-- ============================================================
-- Build the frame
-- ============================================================

function VMF.Build()
    if VMF.frame then return end

    local frame = CreateFrame("Frame", "MonkeyTrackerVoidMark", UIParent, "BackdropTemplate")
    VMF.frame = frame
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetSize(FRAME_W, HEADER_H + FRAME_PAD * 2)

    -- Position: top-center of screen
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.08, 0.02, 0.12, 0.92)
    frame:SetBackdropBorderColor(0.55, 0.10, 0.55, 0.9)

    -- Header
    local header = CreateFrame("Frame", nil, frame)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.15, 0.03, 0.20, 0.95)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    local titleFont = title:GetFont() or "Fonts\\FRIZQT__.TTF"
    title:SetFont(titleFont, 12, "OUTLINE")
    title:SetText("|cffcc44ff⚠ Void Marked|r")
    VMF.title = title

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
    content:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -FRAME_PAD, -2)
    VMF.content = content

    -- Row pool
    VMF.rows = {}

    -- Empty label
    local emptyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("CENTER", content, "CENTER", 0, -4)
    emptyLabel:SetText("No players marked")
    VMF.emptyLabel = emptyLabel

    -- Update ticker
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= UPDATE_TICK then
            elapsed = 0
            VMF.Refresh()
        end
    end)

    frame:Hide()  -- hidden by default
end

-- ============================================================
-- Create/reuse row frames
-- ============================================================

local function GetRow(index)
    if VMF.rows[index] then return VMF.rows[index] end

    local row = CreateFrame("Frame", nil, VMF.content)
    row:SetHeight(ROW_H)

    -- Player name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWidth(140)
    row.nameText = nameText

    -- Timer
    local timerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    timerText:SetJustifyH("RIGHT")
    timerText:SetWidth(50)
    row.timerText = timerText

    -- Subtle background for alternating rows
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.03)
    row.bg = bg

    VMF.rows[index] = row
    return row
end

-- ============================================================
-- Refresh display
-- ============================================================

function VMF.Refresh()
    if not VMF.frame then return end

    local players = RAPE.GetVoidMarkedPlayers()
    local count   = #players

    -- Auto-show/hide based on content
    if count > 0 and not VMF.manualHide then
        VMF.frame:Show()
    elseif count == 0 and not VMF.manualShow then
        VMF.frame:Hide()
        return
    end

    if not VMF.frame:IsShown() then return end

    -- Update rows
    for i, data in ipairs(players) do
        local row = GetRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  VMF.content, "TOPLEFT",  0, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", VMF.content, "TOPRIGHT", 0, -(i - 1) * ROW_H)

        -- Class-colored name
        local r, g, b = RAPE.GetClassColor(data.class)
        row.nameText:SetTextColor(r, g, b, 1)
        row.nameText:SetText(data.name)

        -- Elapsed timer
        row.timerText:SetTextColor(0.9, 0.5, 0.9, 1)
        row.timerText:SetText(RAPE.FormatTime(data.elapsed))

        row.bg:SetShown(i % 2 == 0)
        row:Show()
    end

    -- Hide extra rows
    for i = count + 1, #VMF.rows do
        VMF.rows[i]:Hide()
    end

    -- Resize frame to fit content
    local contentH = math.max(ROW_H, count * ROW_H)
    VMF.frame:SetHeight(HEADER_H + contentH + FRAME_PAD * 2 + 2)
    VMF.emptyLabel:SetShown(count == 0)
end

-- ============================================================
-- Show / Hide / Toggle
-- ============================================================

function VMF.Show()
    if not VMF.frame then VMF.Build() end
    VMF.manualShow = true
    VMF.manualHide = false
    VMF.frame:Show()
    VMF.Refresh()
end

function VMF.Hide()
    VMF.manualShow = false
    VMF.manualHide = true
    if VMF.frame then VMF.frame:Hide() end
end

function VMF.Toggle()
    if not VMF.frame then
        VMF.Build()
        VMF.Show()
        return
    end
    if VMF.frame:IsShown() then
        VMF.Hide()
    else
        VMF.Show()
    end
end
