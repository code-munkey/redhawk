-- MonkeyTracker: MainFrame.lua
-- The primary display window. Shows all active cooldowns as scrollable bars.
-- Supports drag-to-move, resize, lock/unlock.

local MT = MonkeyTracker

local FRAME_MIN_WIDTH  = 280
local FRAME_MIN_HEIGHT = 80
local BAR_HEIGHT       = 28
local BAR_SPACING      = 2
local HEADER_HEIGHT    = 22
local FRAME_PADDING    = 4

-- Update interval in seconds
local UPDATE_INTERVAL  = 0.1

MT.MainFrame = {}
local F = MT.MainFrame
F.ActiveBars = {}
F.Headers = {}  -- category header frames, keyed by category name

-- ============================================================
-- Build Frame
-- ============================================================

function F.Build()
    if F.frame then return end  -- already built

    local frame = CreateFrame("Frame", "MonkeyTrackerMainFrame", UIParent, "BackdropTemplate")
    F.frame = frame

    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(FRAME_MIN_WIDTH, FRAME_MIN_HEIGHT, 800, 1200)
    frame:EnableMouse(true)

    -- Restore saved position / size
    local db = MT.db
    frame:SetWidth(db.width or 320)
    frame:SetHeight(db.height or 200)

    if db.x and db.y then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.x, db.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end

    -- Backdrop
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.30, 0.9)

    -- --------------------------------------------------------
    -- Header bar
    -- --------------------------------------------------------
    local header = CreateFrame("Frame", nil, frame)
    F.header = header
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.10, 0.10, 0.15, 0.95)

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    title:SetText("|cff4fc3f7MonkeyTracker|r")
    title:SetFont(title:GetFont(), 12, "OUTLINE")
    F.title = title

    -- Lock button
    local lockBtn = CreateFrame("Button", nil, header)
    lockBtn:SetSize(18, 18)
    lockBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Up-Up")
    lockBtn:SetPushedTexture("Interface\\Buttons\\LockButton-Up-Down")
    lockBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    lockBtn:SetScript("OnClick", function() F.ToggleLock() end)
    lockBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(MT.db.locked and "Unlock frame" or "Lock frame")
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    F.lockBtn = lockBtn

    -- Config button
    local cfgBtn = CreateFrame("Button", nil, header)
    cfgBtn:SetSize(18, 18)
    cfgBtn:SetPoint("RIGHT", lockBtn, "LEFT", -2, 0)
    cfgBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    cfgBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    cfgBtn:SetScript("OnClick", function() MT.Options.Toggle() end)
    cfgBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("MonkeyTracker Settings")
        GameTooltip:Show()
    end)
    cfgBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Header drag
    header:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" and not MT.db.locked then
            frame:StartMoving()
        end
    end)
    header:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        F.SavePosition()
    end)

    -- --------------------------------------------------------
    -- Scroll / content area
    -- --------------------------------------------------------
    local scrollParent = CreateFrame("Frame", nil, frame)
    scrollParent:SetPoint("TOPLEFT",     header,  "BOTTOMLEFT",   1, -2)
    scrollParent:SetPoint("BOTTOMRIGHT", frame,   "BOTTOMRIGHT", -1,  4)
    scrollParent:SetClipsChildren(true)
    F.scrollParent = scrollParent

    -- --------------------------------------------------------
    -- Resize grip
    -- --------------------------------------------------------
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" and not MT.db.locked then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        F.SavePosition()
        F.Refresh()
    end)

    -- --------------------------------------------------------
    -- Empty state label
    -- --------------------------------------------------------
    local emptyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("CENTER", scrollParent, "CENTER", 0, 0)
    emptyLabel:SetText("No active cooldowns")
    F.emptyLabel = emptyLabel

    -- --------------------------------------------------------
    -- OnUpdate ticker
    -- --------------------------------------------------------
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= UPDATE_INTERVAL then
            elapsed = 0
            F.Refresh()
        end
    end)

    -- Apply initial visibility
    if MT.db.hidden then
        frame:Hide()
    end

    F.ApplyLockState()
end

-- ============================================================
-- Refresh: rebuild bar list every tick
-- ============================================================

function F.Refresh()
    if not F.frame or not F.frame:IsShown() then return end

    local cooldowns = MT.GetActiveCooldowns()
    local parentW   = F.scrollParent:GetWidth()

    local oldBars = F.ActiveBars
    F.ActiveBars = {}

    local yOffset = 0
    local barIndex = 1

    local CATEGORY_ORDER = { MT.CATEGORY.HEALING, MT.CATEGORY.DEFENSIVE, MT.CATEGORY.UTILITY }

    -- Group entries by category
    local byCategory = {}
    for _, entry in ipairs(cooldowns) do
        local cat = entry.spellData.category
        if not byCategory[cat] then byCategory[cat] = {} end
        table.insert(byCategory[cat], entry)
    end

    for _, cat in ipairs(CATEGORY_ORDER) do
        local entries = byCategory[cat]
        if entries and #entries > 0 and F.IsCategoryVisible(cat) then
            -- Category header
            local header = F.GetOrCreateHeader(cat, barIndex)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", F.scrollParent, "TOPLEFT", 2, -yOffset)
            header:SetWidth(parentW - FRAME_PADDING)
            header:Show()
            table.insert(F.ActiveBars, header)
            yOffset = yOffset + 18 + BAR_SPACING
            barIndex = barIndex + 1

            for _, entry in ipairs(entries) do
                local bar = oldBars[barIndex]
                if not bar or bar.isHeader then
                    bar = MT.AcquireBar(F.scrollParent)
                end
                bar:ClearAllPoints()
                MT.UpdateBar(bar, entry, parentW - FRAME_PADDING)
                bar:SetPoint("TOPLEFT", F.scrollParent, "TOPLEFT", 2, -yOffset)
                table.insert(F.ActiveBars, bar)
                yOffset = yOffset + BAR_HEIGHT + BAR_SPACING
                barIndex = barIndex + 1
            end
        end
    end

    for i = barIndex, #oldBars do
        local b = oldBars[i]
        if b.isHeader then b:Hide() else MT.ReleaseBar(b) end
    end

    F.emptyLabel:SetShown(#F.ActiveBars == 0)
end

function F.OnDataChanged()
    F.Refresh()
end

function F.GetOrCreateHeader(category, index)
    local h = F.Headers[category]
    if not h then
        h = CreateFrame("Frame", nil, F.scrollParent)
        h:SetHeight(18)
        h.isHeader = true
        local bg = h:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.08, 0.08, 0.12, 0.95)
        local label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", h, "LEFT", 6, 0)
        label:SetTextColor(0.6, 0.6, 0.7, 1)
        h.label = label
        F.Headers[category] = h
    end
    h.label:SetText(category:upper())
    return h
end

-- ============================================================
-- Category Visibility
-- ============================================================

function F.IsCategoryVisible(category)
    if not MT.db or not MT.db.categoryFilter then return true end
    local filter = MT.db.categoryFilter
    -- If all are true or the map is empty, show everything
    if filter[category] == nil then return true end
    return filter[category]
end

-- ============================================================
-- Helpers
-- ============================================================

function F.ToggleLock()
    MT.db.locked = not MT.db.locked
    F.ApplyLockState()
end

function F.ApplyLockState()
    if not F.frame then return end
    if MT.db.locked then
        F.lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
        F.frame:SetMovable(false)
        F.frame:SetResizable(false)
    else
        F.lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Up-Up")
        F.frame:SetMovable(true)
        F.frame:SetResizable(true)
    end
end

function F.SavePosition()
    if not F.frame then return end
    local point, _, _, x, y = F.frame:GetPoint()
    -- Store as BOTTOMLEFT offset from BOTTOMLEFT of UIParent
    local left   = F.frame:GetLeft()
    local top    = F.frame:GetTop()
    MT.db.x      = left
    MT.db.y      = top
    MT.db.width  = F.frame:GetWidth()
    MT.db.height = F.frame:GetHeight()
end

function F.Show()
    MT.db.hidden = false
    if F.frame then F.frame:Show() end
end

function F.Hide()
    MT.db.hidden = true
    if F.frame then F.frame:Hide() end
end

function F.Toggle()
    if F.frame and F.frame:IsShown() then
        F.Hide()
    else
        F.Show()
    end
end
