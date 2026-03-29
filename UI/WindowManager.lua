-- MonkeyTracker: WindowManager.lua
-- Manages one or more independently positioned tracker windows.
-- Each window reads its config from RAPE.db.windows[idx].
local FRAME_MIN_W  = 200
local FRAME_MIN_H  = 60
local BAR_SPACING  = 2
local HEADER_H     = 22
local FRAME_PAD    = 4
local UPDATE_TICK  = 0.1

RAPE.WM = {}
local WM = RAPE.WM
WM.Windows = {}  -- [idx] = window-object

-- ============================================================
-- Helpers
-- ============================================================

local function GetBarH() return (RAPE.db and RAPE.db.barHeight) or 28 end

-- ============================================================
-- Default window config
-- ============================================================

function WM.DefaultWindowConfig(idx)
    return {
        label  = "Window " .. idx,
        x      = nil,
        y      = nil,
        w      = 320,
        h      = 200,
        locked = false,
        hidden = false,
        spells = {},   -- [spellID]=true → only show those; empty = show all
    }
end

-- ============================================================
-- Build all windows from DB
-- ============================================================

function WM.Build()
    if not RAPE.db.windows or #RAPE.db.windows == 0 then
        RAPE.db.windows = { WM.DefaultWindowConfig(1) }
    end
    for idx = 1, #RAPE.db.windows do
        if not WM.Windows[idx] then
            WM.BuildWindow(idx)
        end
    end
end

-- ============================================================
-- Build a single window frame
-- ============================================================

function WM.BuildWindow(idx)
    local cfg = RAPE.db.windows[idx]
    if not cfg then return end

    local win = { idx = idx, ActiveBars = {}, BarPool = {}, Headers = {} }

    -- Main frame
    local frame = CreateFrame("Frame", "MonkeyTrackerWindow" .. idx, UIParent, "BackdropTemplate")
    win.frame = frame
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(FRAME_MIN_W, FRAME_MIN_H, 800, 1200)
    frame:EnableMouse(true)
    frame:SetWidth(cfg.w or 320)
    frame:SetHeight(cfg.h or 200)

    if cfg.x and cfg.y then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.x, cfg.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", (idx - 1) * 40, 100 - (idx - 1) * 40)
    end

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.30, 0.9)

    -- Header bar
    local header = CreateFrame("Frame", nil, frame)
    win.header = header
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.10, 0.10, 0.15, 0.95)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    title:SetText("|cff4fc3f7" .. (cfg.label or ("Window " .. idx)) .. "|r")
    local titleFont = title:GetFont() or "Fonts\\FRIZQT__.TTF"
    title:SetFont(titleFont, 12, "OUTLINE")
    win.title = title

    -- Lock button
    local lockBtn = CreateFrame("Button", nil, header)
    lockBtn:SetSize(18, 18)
    lockBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Up-Up")
    lockBtn:SetPushedTexture("Interface\\Buttons\\LockButton-Up-Down")
    lockBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local capturedIdx = idx
    lockBtn:SetScript("OnClick", function() WM.ToggleLock(capturedIdx) end)
    lockBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(RAPE.db.windows[capturedIdx].locked and "Unlock frame" or "Lock frame")
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.lockBtn = lockBtn

    -- Options button
    local cfgBtn = CreateFrame("Button", nil, header)
    cfgBtn:SetSize(18, 18)
    cfgBtn:SetPoint("RIGHT", lockBtn, "LEFT", -2, 0)
    cfgBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    cfgBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    cfgBtn:SetScript("OnClick", function() 
        if RAPE.MainPanel then RAPE.MainPanel:Toggle() end 
    end)
    cfgBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("MonkeyTracker Settings")
        GameTooltip:Show()
    end)
    cfgBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Header drag
    header:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" and not RAPE.db.windows[capturedIdx].locked then
            frame:StartMoving()
        end
    end)
    header:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        WM.SavePosition(capturedIdx)
    end)

    -- Content area
    local scrollParent = CreateFrame("Frame", nil, frame)
    scrollParent:SetPoint("TOPLEFT",     header, "BOTTOMLEFT",   1, -2)
    scrollParent:SetPoint("BOTTOMRIGHT", frame,  "BOTTOMRIGHT", -1,  4)
    scrollParent:SetClipsChildren(true)
    win.scrollParent = scrollParent

    -- Resize grip
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" and not RAPE.db.windows[capturedIdx].locked then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        WM.SavePosition(capturedIdx)
        WM.RefreshWindow(win)
    end)

    -- Empty label
    local emptyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("CENTER", scrollParent, "CENTER", 0, 0)
    emptyLabel:SetText("No active cooldowns")
    win.emptyLabel = emptyLabel

    -- Update ticker
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= UPDATE_TICK then
            elapsed = 0
            WM.RefreshWindow(win)
        end
    end)

    if cfg.hidden then frame:Hide() end
    WM.ApplyLockState(idx)

    WM.Windows[idx] = win
    return win
end

-- ============================================================
-- Refresh a single window
-- ============================================================

function WM.RefreshWindow(win)
    if not win or not win.frame or not win.frame:IsShown() then return end

    local cfg         = RAPE.db.windows[win.idx]
    local filterSet   = cfg and cfg.spells
    local hasFilter   = filterSet and next(filterSet) ~= nil
    local disabled    = RAPE.db.disabledSpells or {}

    -- GetActiveCooldowns() already filters global disabledSpells.
    -- Here we only need to apply the per-window spell whitelist (if set).
    local cooldowns = RAPE.GetActiveCooldowns()
    if hasFilter then
        local filtered = {}
        for _, entry in ipairs(cooldowns) do
            if filterSet[entry.spellID] then
                table.insert(filtered, entry)
            end
        end
        cooldowns = filtered
    end

    local parentW  = win.scrollParent:GetWidth()
    local BH       = GetBarH()
    local oldBars  = win.ActiveBars
    win.ActiveBars = {}

    local yOffset  = 0
    local barIndex = 1

    local CATEGORY_ORDER = { RAPE.CATEGORY.HEALING, RAPE.CATEGORY.DEFENSIVE, RAPE.CATEGORY.UTILITY }
    local byCategory = {}
    for _, entry in ipairs(cooldowns) do
        local cat = entry.spellData.category
        if not byCategory[cat] then byCategory[cat] = {} end
        table.insert(byCategory[cat], entry)
    end

    for _, cat in ipairs(CATEGORY_ORDER) do
        local entries = byCategory[cat]
        if entries and #entries > 0 and WM.IsCategoryVisible(cat) then
            local h = WM.GetOrCreateHeader(win, cat)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", win.scrollParent, "TOPLEFT", 2, -yOffset)
            h:SetWidth(parentW - FRAME_PAD)
            h:Show()
            table.insert(win.ActiveBars, h)
            yOffset   = yOffset + 18 + BAR_SPACING
            barIndex  = barIndex + 1

            for _, entry in ipairs(entries) do
                local bar = oldBars[barIndex]
                if not bar or bar.isHeader then
                    bar = WM.AcquireBar(win)
                end
                bar:ClearAllPoints()
                RAPE.UpdateBar(bar, entry, parentW - FRAME_PAD)
                bar:SetPoint("TOPLEFT", win.scrollParent, "TOPLEFT", 2, -yOffset)
                table.insert(win.ActiveBars, bar)
                yOffset  = yOffset + BH + BAR_SPACING
                barIndex = barIndex + 1
            end
        end
    end

    for i = barIndex, #oldBars do
        local b = oldBars[i]
        if b.isHeader then b:Hide() else WM.ReleaseBar(win, b) end
    end

    win.emptyLabel:SetShown(#win.ActiveBars == 0)
end

function WM.RefreshAll()
    for _, win in ipairs(WM.Windows) do
        WM.RefreshWindow(win)
    end
end

-- ============================================================
-- Per-window bar pool
-- ============================================================

function WM.AcquireBar(win)
    local bar = table.remove(win.BarPool)
    if not bar then
        bar = RAPE.CreateBar(win.scrollParent)
    else
        bar:SetParent(win.scrollParent)
        bar:Show()
    end
    return bar
end

function WM.ReleaseBar(win, bar)
    bar:Hide()
    bar:ClearAllPoints()
    table.insert(win.BarPool, bar)
end

-- ============================================================
-- Per-window category headers
-- ============================================================

function WM.GetOrCreateHeader(win, category)
    local h = win.Headers[category]
    if not h then
        h = CreateFrame("Frame", nil, win.scrollParent)
        h:SetHeight(18)
        h.isHeader = true
        local bg = h:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.08, 0.08, 0.12, 0.95)
        local label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", h, "LEFT", 6, 0)
        label:SetTextColor(0.6, 0.6, 0.7, 1)
        h.label = label
        win.Headers[category] = h
    end
    h.label:SetText(category:upper())
    return h
end

-- ============================================================
-- Lock / position
-- ============================================================

function WM.ToggleLock(idx)
    local cfg = RAPE.db.windows[idx]
    if cfg then cfg.locked = not cfg.locked end
    WM.ApplyLockState(idx)
end

function WM.ApplyLockState(idx)
    local win = WM.Windows[idx]
    local cfg = RAPE.db.windows[idx]
    if not win or not cfg then return end
    if cfg.locked then
        win.lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
        win.frame:SetMovable(false)
        win.frame:SetResizable(false)
    else
        win.lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Up-Up")
        win.frame:SetMovable(true)
        win.frame:SetResizable(true)
    end
end

function WM.SavePosition(idx)
    local win = WM.Windows[idx]
    local cfg = RAPE.db.windows[idx]
    if not win or not cfg then return end
    cfg.x = win.frame:GetLeft()
    cfg.y = win.frame:GetTop()
    cfg.w = win.frame:GetWidth()
    cfg.h = win.frame:GetHeight()
end

-- ============================================================
-- Category visibility (reads from shared categoryFilter)
-- ============================================================

function WM.IsCategoryVisible(category)
    if not RAPE.db or not RAPE.db.categoryFilter then return true end
    local filter = RAPE.db.categoryFilter[category]
    if filter == nil then return true end
    return filter
end

-- ============================================================
-- Show / hide / toggle
-- ============================================================

function WM.ShowWindow(idx)
    local cfg = RAPE.db.windows[idx]
    local win = WM.Windows[idx]
    if cfg then cfg.hidden = false end
    if win and win.frame then win.frame:Show() end
end

function WM.HideWindow(idx)
    local cfg = RAPE.db.windows[idx]
    local win = WM.Windows[idx]
    if cfg then cfg.hidden = true end
    if win and win.frame then win.frame:Hide() end
end

function WM.ToggleWindow(idx)
    local win = WM.Windows[idx]
    if win and win.frame and win.frame:IsShown() then
        WM.HideWindow(idx)
    else
        WM.ShowWindow(idx)
    end
end

function WM.UpdateWindowLabel(idx)
    local win = WM.Windows[idx]
    local cfg = RAPE.db.windows[idx]
    if win and win.title and cfg then
        win.title:SetText("|cff4fc3f7" .. (cfg.label or ("Window " .. idx)) .. "|r")
    end
end

-- ============================================================
-- Add / Remove
-- ============================================================

function WM.AddWindow()
    local idx = #RAPE.db.windows + 1
    RAPE.db.windows[idx] = WM.DefaultWindowConfig(idx)
    WM.BuildWindow(idx)
    return idx
end

function WM.RemoveWindow(idx)
    if #RAPE.db.windows <= 1 then return end  -- always keep at least 1
    local win = WM.Windows[idx]
    if win and win.frame then win.frame:Hide() end

    table.remove(RAPE.db.windows, idx)
    table.remove(WM.Windows, idx)

    -- Fix indices on remaining windows
    for i, w in ipairs(WM.Windows) do
        w.idx = i
        if w.title and RAPE.db.windows[i] then
            w.title:SetText("|cff4fc3f7" .. (RAPE.db.windows[i].label or ("Window " .. i)) .. "|r")
        end
    end
end

-- ============================================================
-- Rebuild all (used after Appearance changes)
-- ============================================================

function WM.RebuildAll()
    for _, win in ipairs(WM.Windows) do
        if win.frame then win.frame:Hide() end
    end
    WM.Windows = {}
    for idx = 1, #RAPE.db.windows do
        WM.BuildWindow(idx)
    end
end
