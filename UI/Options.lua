-- MonkeyTracker: Options.lua
-- DB defaults, InitDB, custom 4-tab options panel, and slash commands.

RAPE.Options = {}
local O = RAPE.Options

-- ============================================================
-- Default Settings
-- ============================================================

RAPE.DB_DEFAULTS = {
    debugMode         = false,
    disabledSpells    = {},
    categoryFilter    = {
        [RAPE.CATEGORY.HEALING]   = true,
        [RAPE.CATEGORY.DEFENSIVE] = true,
        [RAPE.CATEGORY.UTILITY]   = true,
    },
    cooldownOverrides = {},
    windows           = {},   -- populated by WM.DefaultWindowConfig on first run
    barHeight         = 28,
    barFont           = "Fonts\\FRIZQT__.TTF",
    barFontSize       = 11,
}

--- Merge saved variables with defaults and handle legacy migration.
function RAPE.InitDB()
    if not RapeDB then RapeDB = {} end

    for k, v in pairs(RAPE.DB_DEFAULTS) do
        if RapeDB[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for k2, v2 in pairs(v) do copy[k2] = v2 end
                RapeDB[k] = copy
            else
                RapeDB[k] = v
            end
        end
    end

    local db = RapeDB

    -- MIGRATION: old single-window fields → windows[1]
    if (db.x or db.y or db.width or db.height) and (#db.windows == 0) then
        db.windows[1] = {
            label  = "Window 1",
            x      = db.x,
            y      = db.y,
            w      = db.width  or 320,
            h      = db.height or 200,
            locked = db.locked or false,
            hidden = db.hidden or false,
            spells = {},
        }
        db.x = nil; db.y = nil; db.width = nil; db.height = nil
        db.locked = nil; db.hidden = nil
    end

    -- Ensure at least one window config
    if not db.windows or #db.windows == 0 then
        db.windows = { RAPE.WM.DefaultWindowConfig(1) }
    end

    RAPE.db = RapeDB
end

-- ============================================================
-- Panel helpers
-- ============================================================

local PANEL_W, PANEL_H = 560, 510
local TAB_H = 26
local CONTENT_Y_START = -(TAB_H + 6)

local FONTS = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF"  },
    { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF"    },
    { name = "Morpheus",      path = "Fonts\\MORPHEUS.ttf"  },
    { name = "Skurri",        path = "Fonts\\SKURRI.TTF"    },
}

local function MakeLabel(parent, text, x, y, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

local function MakeButton(parent, text, w, h)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w or 140, h or 22)
    btn:SetText(text)
    return btn
end

local function MakeSlider(parent, label, minV, maxV, step, defaultV, x, y, w)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(w or 260, 40)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    lbl:SetText(label)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
    slider:SetSize((w or 260) - 60, 14)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetValue(defaultV)
    slider.Low:SetText(minV)
    slider.High:SetText(maxV)

    local valText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valText:SetText(tostring(defaultV))
    valText:SetWidth(30)

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val + 0.5)
        valText:SetText(tostring(val))
        if self.onChange then self.onChange(val) end
    end)

    container.slider = slider
    container.valText = valText
    return container
end

-- ============================================================
-- Build options panel
-- ============================================================

function O.BuildPanel()
    if O.panel then return end

    local panel = CreateFrame("Frame", "MonkeyTrackerOptionsPanel", UIParent, "BackdropTemplate")
    O.panel = panel
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then self:StartMoving() end
    end)
    panel:SetScript("OnMouseUp",  function(self) self:StopMovingOrSizing() end)

    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.06, 0.06, 0.10, 0.97)
    panel:SetBackdropBorderColor(0.30, 0.30, 0.40, 1)

    -- Title bar
    local titleBar = panel:CreateTexture(nil, "BACKGROUND")
    titleBar:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1, -1)
    titleBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(24)
    titleBar:SetColorTexture(0.10, 0.10, 0.18, 1)

    local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -6)
    titleText:SetText("|cff4fc3f7MonkeyTracker|r Settings")

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- Tab buttons & content frames
    local tabNames    = { "Spells", "Windows", "Appearance", "Tools" }
    local tabBtns     = {}
    local tabContents = {}
    local activeTab   = 1

    local function ShowTab(idx)
        activeTab = idx
        for i, content in ipairs(tabContents) do
            content:SetShown(i == idx)
        end
        for i, btn in ipairs(tabBtns) do
            if i == idx then
                btn:SetNormalFontObject("GameFontHighlightSmall")
                local nt = btn:GetNormalTexture()
                if nt then nt:SetAlpha(0) end  -- visually highlight active tab
                btn:SetAlpha(1)
            else
                btn:SetNormalFontObject("GameFontNormalSmall")
                btn:SetAlpha(0.75)
            end
        end
        if idx == 1 then O.RefreshSpellTab() end
        if idx == 2 then O.RefreshWindowsTab() end
        if idx == 4 then O.RefreshToolsTab() end
    end

    local tabW = math.floor((PANEL_W - 10) / #tabNames)
    for i, name in ipairs(tabNames) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(tabW, TAB_H)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 5 + (i - 1) * tabW, -26)
        btn:SetText(name)
        local capturedI = i
        btn:SetScript("OnClick", function() ShowTab(capturedI) end)
        table.insert(tabBtns, btn)

        local content = CreateFrame("Frame", nil, panel)
        content:SetPoint("TOPLEFT",     panel, "TOPLEFT",     5,  CONTENT_Y_START - TAB_H - 4)
        content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 30)
        content:Hide()
        table.insert(tabContents, content)
    end

    O.tabBtns     = tabBtns
    O.tabContents = tabContents

    O.BuildSpellTab(tabContents[1])
    O.BuildWindowsTab(tabContents[2])
    O.BuildAppearanceTab(tabContents[3])
    O.BuildToolsTab(tabContents[4])

    ShowTab(1)
    panel:Hide()
end

-- ============================================================
-- Tab 1: Spells
-- ============================================================

local function GetSortedSpells()
    local list = {}
    for spellID, data in pairs(RAPE.SpellDB) do
        table.insert(list, { id = spellID, name = data.name, class = data.class, data = data })
    end
    table.sort(list, function(a, b)
        if (a.class or "") ~= (b.class or "") then return (a.class or "") < (b.class or "") end
        return a.name < b.name
    end)
    return list
end

function O.BuildSpellTab(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     parent, "TOPLEFT",     0,   0)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 0)

    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(sf:GetWidth() or (PANEL_W - 36))
    sf:SetScrollChild(child)

    O.spellTab      = parent
    O.spellChild    = child
    O.spellScroll   = sf
    O.spellRows     = {}
end

function O.RefreshSpellTab()
    local child = O.spellChild
    if not child then return end

    -- Clear old rows
    for _, row in ipairs(O.spellRows or {}) do
        row:Hide()
    end
    O.spellRows = {}

    local spells = GetSortedSpells()
    local ROW_H  = 24
    child:SetHeight(#spells * ROW_H + 4)

    for i, spell in ipairs(spells) do
        local capturedID = spell.id
        local y = -(i - 1) * ROW_H - 2

        local row = CreateFrame("Frame", nil, child)
        row:SetPoint("TOPLEFT",  child, "TOPLEFT",  0, y)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        row:SetHeight(ROW_H)
        table.insert(O.spellRows, row)

        -- Alternating row bg
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end

        -- Enabled checkbox
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("LEFT", row, "LEFT", 2, 0)
        cb:SetChecked(not (RAPE.db.disabledSpells[capturedID]))
        cb:SetScript("OnClick", function(self)
            if self:GetChecked() then
                RAPE.db.disabledSpells[capturedID] = nil
            else
                RAPE.db.disabledSpells[capturedID] = true
            end
        end)

        -- Spell icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local tex = C_Spell.GetSpellTexture(spell.id)
        if tex then icon:SetTexture(tex) end

        -- Label
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT",  icon, "RIGHT", 4, 0)
        lbl:SetPoint("RIGHT", row,  "RIGHT", -60, 0)
        lbl:SetJustifyH("LEFT")
        local r, g, b = RAPE.GetClassColor(spell.class)
        lbl:SetTextColor(r, g, b, 1)
        lbl:SetText(spell.class .. "  " .. spell.name)

        -- Window assignment cycling button
        local winBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        winBtn:SetSize(52, 18)
        winBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)

        local function UpdateWinBtnText()
            local assigned = "All"
            for idx, wincfg in ipairs(RAPE.db.windows) do
                if wincfg.spells[capturedID] then
                    assigned = "W" .. idx
                    break
                end
            end
            winBtn:SetText(assigned)
        end

        winBtn:SetScript("OnClick", function()
            local currentWin = 0
            for idx, wincfg in ipairs(RAPE.db.windows) do
                if wincfg.spells[capturedID] then
                    currentWin = idx
                    break
                end
            end
            -- Remove from all
            for _, wincfg in ipairs(RAPE.db.windows) do
                wincfg.spells[capturedID] = nil
            end
            -- Assign to next
            local nextWin = currentWin + 1
            if nextWin <= #RAPE.db.windows then
                RAPE.db.windows[nextWin].spells[capturedID] = true
            end
            -- else stays "All" (not in any window's filter)
            UpdateWinBtnText()
        end)
        winBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Click to cycle window assignment.\n|cffaaaaaa'All' = show in every window|r")
            GameTooltip:Show()
        end)
        winBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        UpdateWinBtnText()
    end
end

-- ============================================================
-- Tab 2: Windows
-- ============================================================

function O.BuildWindowsTab(parent)
    O.winTab = parent

    local addBtn = MakeButton(parent, "+ Add Window", 140, 24)
    addBtn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 4, 4)
    addBtn:SetScript("OnClick", function()
        RAPE.WM.AddWindow()
        O.RefreshWindowsTab()
    end)

    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     parent, "TOPLEFT",     0, 0)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 32)

    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(sf:GetWidth() or (PANEL_W - 36))
    sf:SetScrollChild(child)

    O.winChild  = child
    O.winScroll = sf
    O.winRows   = {}
end

function O.RefreshWindowsTab()
    local child = O.winChild
    if not child then return end

    for _, row in ipairs(O.winRows or {}) do row:Hide() end
    O.winRows = {}

    local ROW_H = 30
    child:SetHeight(#RAPE.db.windows * ROW_H + 4)

    for i, wincfg in ipairs(RAPE.db.windows) do
        local capturedI = i
        local y = -(i - 1) * ROW_H - 2

        local row = CreateFrame("Frame", nil, child)
        row:SetPoint("TOPLEFT",  child, "TOPLEFT",  0, y)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        row:SetHeight(ROW_H)
        table.insert(O.winRows, row)

        -- Index label
        local numLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        numLbl:SetPoint("LEFT", row, "LEFT", 4, 0)
        numLbl:SetText("|cff888888W" .. i .. "|r")
        numLbl:SetWidth(24)

        -- Name edit box
        local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        eb:SetPoint("LEFT",  numLbl, "RIGHT", 6, 0)
        eb:SetPoint("RIGHT", row,    "RIGHT", -80, 0)
        eb:SetHeight(20)
        eb:SetAutoFocus(false)
        eb:SetText(wincfg.label or ("Window " .. i))
        eb:SetScript("OnEnterPressed", function(self)
            wincfg.label = self:GetText()
            RAPE.WM.UpdateWindowLabel(capturedI)
            self:ClearFocus()
        end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        -- Show/Hide toggle button
        local vis = wincfg.hidden and "Show" or "Hide"
        local visBtn = MakeButton(row, vis, 50, 20)
        visBtn:SetPoint("RIGHT", row, "RIGHT", -28, 0)
        visBtn:SetScript("OnClick", function(self)
            if RAPE.db.windows[capturedI].hidden then
                RAPE.WM.ShowWindow(capturedI)
                self:SetText("Hide")
            else
                RAPE.WM.HideWindow(capturedI)
                self:SetText("Show")
            end
        end)

        -- Remove button (only if more than 1 window)
        if #RAPE.db.windows > 1 then
            local remBtn = MakeButton(row, "✕", 22, 20)
            remBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            remBtn:SetScript("OnClick", function()
                RAPE.WM.RemoveWindow(capturedI)
                O.RefreshWindowsTab()
            end)
        end
    end
end

-- ============================================================
-- Tab 3: Appearance
-- ============================================================

function O.BuildAppearanceTab(parent)
    local Y = -10

    MakeLabel(parent, "Bar Height", 10, Y, {0.8, 0.8, 0.8})
    local hSlider = MakeSlider(parent, "Bar Height (px)", 16, 48, 1, RAPE.db.barHeight, 10, Y - 14, 280)
    hSlider.slider.onChange = function(val) RAPE.db.barHeight = val end
    Y = Y - 60

    MakeLabel(parent, "Font", 10, Y, {0.8, 0.8, 0.8})
    Y = Y - 18

    -- Font cycling button
    local currentFontIdx = 1
    for i, f in ipairs(FONTS) do
        if f.path == RAPE.db.barFont then currentFontIdx = i break end
    end

    local fontBtn = MakeButton(parent, FONTS[currentFontIdx].name, 200, 24)
    fontBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, Y)
    fontBtn:SetScript("OnClick", function()
        currentFontIdx = (currentFontIdx % #FONTS) + 1
        RAPE.db.barFont = FONTS[currentFontIdx].path
        fontBtn:SetText(FONTS[currentFontIdx].name)
    end)
    Y = Y - 38

    MakeLabel(parent, "Font Size", 10, Y, {0.8, 0.8, 0.8})
    local fsSlider = MakeSlider(parent, "Font Size", 8, 20, 1, RAPE.db.barFontSize, 10, Y - 14, 280)
    fsSlider.slider.onChange = function(val) RAPE.db.barFontSize = val end
    Y = Y - 70

    local divider = parent:CreateTexture(nil, "BACKGROUND")
    divider:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, Y)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, Y)
    divider:SetHeight(1)
    divider:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    Y = Y - 14

    MakeLabel(parent, "Category Visibility", 10, Y, {0.8, 0.8, 0.8})
    Y = Y - 22

    local categories = {
        { key = RAPE.CATEGORY.HEALING,   label = "Healing"   },
        { key = RAPE.CATEGORY.DEFENSIVE, label = "Defensive" },
        { key = RAPE.CATEGORY.UTILITY,   label = "Utility"   },
    }
    for _, cat in ipairs(categories) do
        local catKey = cat.key
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, Y)
        cb:SetChecked(RAPE.db.categoryFilter[catKey] ~= false)
        cb:SetScript("OnClick", function(self)
            RAPE.db.categoryFilter[catKey] = self:GetChecked()
        end)
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        lbl:SetText(cat.label)
        Y = Y - 24
    end

    Y = Y - 10
    local applyBtn = MakeButton(parent, "Apply Appearance Changes", 220, 26)
    applyBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, Y)
    applyBtn:SetScript("OnClick", function()
        RAPE.WM.RebuildAll()
        RAPE.Print("Appearance applied.")
    end)
end

-- ============================================================
-- Tab 4: Tools
-- ============================================================

function O.BuildToolsTab(parent)

    -- Section: Debug
    local Y = -10
    MakeLabel(parent, "Debug", 10, Y, {0.7, 0.7, 1.0})
    Y = Y - 24

    local debugBtn = MakeButton(parent, "", 200, 26)
    debugBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, Y)
    O.debugBtn = debugBtn

    local function UpdateDebugBtn()
        local state = RAPE.db.debugMode and "|cff00ff00ON|r" or "|cffff4444OFF|r"
        debugBtn:SetText("Debug Logging: " .. state)
    end
    debugBtn:SetScript("OnClick", function()
        RAPE.db.debugMode = not RAPE.db.debugMode
        UpdateDebugBtn()
        RAPE.Print("Debug mode:", RAPE.db.debugMode and "ON" or "OFF")
    end)
    UpdateDebugBtn()
    Y = Y - 38

    -- Section: Version Check
    local divider1 = parent:CreateTexture(nil, "BACKGROUND")
    divider1:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, Y)
    divider1:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, Y)
    divider1:SetHeight(1)
    divider1:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    Y = Y - 14

    MakeLabel(parent, "Addon Communication", 10, Y, {0.7, 0.7, 1.0})
    Y = Y - 24

    local verBtn = MakeButton(parent, "Check Version", 160, 26)
    verBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, Y)
    verBtn:SetScript("OnClick", function() RAPE.BroadcastVersionCheck() end)
    verBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Asks all group members to report their MonkeyTracker version.\nReplies appear in chat.")
        GameTooltip:Show()
    end)
    verBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Y = Y - 36

    local slBtn = MakeButton(parent, "Request All Spell Lists", 200, 26)
    slBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, Y)
    slBtn:SetScript("OnClick", function() RAPE.RequestSpellLists() end)
    slBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Asks all group members to rebroadcast their spell lists.\nUseful if someone's cooldowns aren't showing.")
        GameTooltip:Show()
    end)
    slBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Y = Y - 38

    -- Section: Per-player refresh
    local divider2 = parent:CreateTexture(nil, "BACKGROUND")
    divider2:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, Y)
    divider2:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, Y)
    divider2:SetHeight(1)
    divider2:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    Y = Y - 14

    MakeLabel(parent, "Request Refresh from Specific Player", 10, Y, {0.7, 0.7, 1.0})
    Y = Y - 26

    local rosterNames = {}
    local rosterIdx   = 1

    local playerLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, Y)
    playerLabel:SetText("Player: —")
    playerLabel:SetWidth(220)
    O.playerLabel = playerLabel

    local prevBtn = MakeButton(parent, "<", 28, 24)
    prevBtn:SetPoint("LEFT", playerLabel, "RIGHT", 6, 0)
    prevBtn:SetScript("OnClick", function()
        if #rosterNames == 0 then return end
        rosterIdx = ((rosterIdx - 2) % #rosterNames) + 1
        playerLabel:SetText("Player: " .. rosterNames[rosterIdx])
    end)

    local nextBtn = MakeButton(parent, ">", 28, 24)
    nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
    nextBtn:SetScript("OnClick", function()
        if #rosterNames == 0 then return end
        rosterIdx = (rosterIdx % #rosterNames) + 1
        playerLabel:SetText("Player: " .. rosterNames[rosterIdx])
    end)
    Y = Y - 36

    local refreshBtn = MakeButton(parent, "Request Refresh", 160, 26)
    refreshBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, Y)
    refreshBtn:SetScript("OnClick", function()
        local name = rosterNames[rosterIdx]
        if name then RAPE.RequestPlayerRefresh(name) end
    end)

    -- Re-populate roster names whenever the tab is shown
    O.refreshToolsRoster = function()
        rosterNames = {}
        rosterIdx   = 1
        for name in pairs(RAPE.Roster) do
            table.insert(rosterNames, name)
        end
        table.sort(rosterNames)
        if #rosterNames > 0 then
            playerLabel:SetText("Player: " .. rosterNames[1])
        else
            playerLabel:SetText("Player: (no group)")
        end
    end
end

function O.RefreshToolsTab()
    if O.refreshToolsRoster then O.refreshToolsRoster() end
    if O.debugBtn then
        local state = RAPE.db.debugMode and "|cff00ff00ON|r" or "|cffff4444OFF|r"
        O.debugBtn:SetText("Debug Logging: " .. state)
    end
end

-- ============================================================
-- Toggle / open
-- ============================================================

function O.Toggle()
    if not O.panel then O.BuildPanel() end
    if O.panel:IsShown() then
        O.panel:Hide()
    else
        O.panel:Show()
        O.RefreshSpellTab()
        O.RefreshWindowsTab()
        O.RefreshToolsTab()
    end
end

-- Legacy Blizzard settings stub (no-op — we're fully custom now)
function O.RegisterSettingsPanel() end

-- ============================================================
-- Slash Commands
-- ============================================================

function O.RegisterSlashCommands()
    SLASH_RAPE1 = "/RAPE"

    SlashCmdList["RAPE"] = function(msg)
        msg = msg and strtrim(msg:lower()) or ""

        if msg == "" or msg == "show" then
            RAPE.MainFrame.Show()
            RAPE.Print("Tracker shown. Type /RAPE hide to hide.")

        elseif msg == "hide" then
            RAPE.MainFrame.Hide()
            RAPE.Print("Tracker hidden. Type /RAPE show to show.")

        elseif msg == "options" then
            RAPE.MainPanel:Toggle()
        elseif msg == "lock" then
            RAPE.db.windows[1].locked = true
            RAPE.WM.ApplyLockState(1)
            RAPE.Print("Window 1 locked.")
        elseif msg == "unlock" then
            RAPE.db.windows[1].locked = false
            RAPE.WM.ApplyLockState(1)
            RAPE.Print("Window 1 unlocked.")
        elseif msg == "reset" then
            RAPE.ClearAllCooldowns()
            RAPE.Print("All cooldowns cleared.")
        elseif msg == "config" then
            O.Toggle()
        elseif msg == "debug" then
            RAPE.db.debugMode = not RAPE.db.debugMode
            RAPE.Print("Debug mode:", RAPE.db.debugMode and "ON" or "OFF")
        elseif msg == "version" then
            RAPE.BroadcastVersionCheck()
        elseif msg == "reqspells" then
            RAPE.RequestSpellLists()
        elseif msg:sub(1, 8) == "refresh " then
            RAPE.RequestPlayerRefresh(strtrim(msg:sub(9)))
        elseif msg == "voidmark" then
            if RAPE.VoidMarkedFrame then
                RAPE.VoidMarkedFrame.Toggle()
            end
        elseif msg == "admin" then
            if RAPE.AdminFrame then
                RAPE.AdminFrame.Toggle()
            end
        elseif msg == "testvoidmark" or msg:sub(1, 13) == "testvoidmark " then
            local action = strtrim(msg:sub(14))
            RAPE.TestVoidMark(action)

        elseif msg == "debug roster" then
            RAPE.Print("Current roster (" .. RAPE.TableCount(RAPE.Roster) .. " members):")
            for name, class in pairs(RAPE.Roster) do
                RAPE.Print("  " .. name .. " — " .. class)
            end

        elseif msg == "debug cds" then
            local list = RAPE.GetActiveCooldowns()
            if #list == 0 then
                RAPE.Print("No active cooldowns tracked.")
            else
                RAPE.Print("Active cooldowns (" .. #list .. "):")
                for _, e in ipairs(list) do
                    RAPE.Print(string.format("  [%s] %s — %s remaining",
                        e.playerName, e.spellData.name, RAPE.FormatTime(e.remaining)))
                end
            end

        elseif msg == "help" then
            RAPE.Print("/RAPE              — show tracker")
            RAPE.Print("/RAPE hide         — hide tracker")
            RAPE.Print("/RAPE toggle       — toggle visibility")
            RAPE.Print("/RAPE lock/unlock  — lock/unlock window 1")
            RAPE.Print("/RAPE reset        — clear all active cooldowns")
            RAPE.Print("/RAPE config       — open settings panel")
            RAPE.Print("/RAPE debug        — toggle debug logging")
            RAPE.Print("/RAPE version      — broadcast version check")
            RAPE.Print("/RAPE reqspells    — request spell lists from all")
            RAPE.Print("/RAPE refresh <name> — request refresh from player")
            RAPE.Print("/RAPE voidmark      — toggle Void Marked tracker")
            RAPE.Print("/RAPE admin          — open admin / raid leader panel")
            RAPE.Print("/RAPE testvoidmark [gain|fade] — simulate void mark")
            RAPE.Print("/RAPE debug roster — print known raid members")
            RAPE.Print("/RAPE debug cds    — list all active cooldowns")

        else
            RAPE.Print("Unknown command. Type /RAPE help for options.")
        end
    end
end
