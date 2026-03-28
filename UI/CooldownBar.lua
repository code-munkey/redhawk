-- MonkeyTracker: CooldownBar.lua
-- Creates and manages individual cooldown row widgets.
-- Each bar represents one active cooldown for one player.
-- Bar dimensions (defaults; actual values read from RAPE.db at bar creation/update)
local BAR_HEIGHT_DEFAULT  = 28
local BAR_WIDTH           = 300
local CLASS_STRIPE_WIDTH  = 4
local BAR_PADDING         = 2

local function GetBarH()  return (RAPE.db and RAPE.db.barHeight)   or BAR_HEIGHT_DEFAULT end
local function GetBarF()  return (RAPE.db and RAPE.db.barFont)     or "Fonts\\FRIZQT__.TTF" end
local function GetBarFS() return (RAPE.db and RAPE.db.barFontSize) or 11 end

-- Pool of reusable bar frames to avoid create/destroy churn
RAPE.BarPool = {}
RAPE.ActiveBars = {}

-- ============================================================
-- Bar Widget Factory
-- ============================================================

--- Creates a single cooldown bar frame (or recycles from pool).
-- @param parent Frame
-- @return Frame   The bar widget
function RAPE.AcquireBar(parent)
    local bar = table.remove(RAPE.BarPool)
    if not bar then
        bar = RAPE.CreateBar(parent)
    else
        bar:SetParent(parent)
        bar:Show()
    end
    return bar
end

--- Returns a bar to the pool.
function RAPE.ReleaseBar(bar)
    bar:Hide()
    bar:ClearAllPoints()
    table.insert(RAPE.BarPool, bar)
end

--- Construct a new bar frame with all sub-elements.
function RAPE.CreateBar(parent)
    local BH = GetBarH()
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(BH)

    -- Background
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)

    -- Class color stripe (left edge)
    f.stripe = f:CreateTexture(nil, "BORDER")
    f.stripe:SetWidth(CLASS_STRIPE_WIDTH)
    f.stripe:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.stripe:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)

    -- Spell icon
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(BH - 2, BH - 2)
    f.icon:SetPoint("LEFT", f.stripe, "RIGHT", 2, 0)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- trim default icon borders

    -- Progress bar (fills right as CD completes)
    f.progress = CreateFrame("StatusBar", nil, f, "TextStatusBar")
    f.progress:SetPoint("TOPLEFT",     f.icon,    "TOPRIGHT",    4, -1)
    f.progress:SetPoint("BOTTOMRIGHT", f,         "BOTTOMRIGHT", -2,  1)
    f.progress:SetMinMaxValues(0, 1)
    f.progress:SetValue(0)
    f.progress:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")

    -- Progress bar background (dimmed fill)
    f.progressBg = f.progress:CreateTexture(nil, "BACKGROUND")
    f.progressBg:SetAllPoints(f.progress)
    f.progressBg:SetColorTexture(0.12, 0.12, 0.12, 0.9)

    -- Player + Spell label
    local bf, bfs = GetBarF(), GetBarFS()
    f.label = f.progress:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.label:SetPoint("LEFT",  f.progress, "LEFT",  5, 0)
    f.label:SetPoint("RIGHT", f.progress, "RIGHT", -40, 0)
    f.label:SetJustifyH("LEFT")
    f.label:SetFont(bf, bfs, "OUTLINE")
    f.label:SetTextColor(1, 1, 1, 1)

    -- Time remaining label
    f.timeText = f.progress:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.timeText:SetPoint("RIGHT", f.progress, "RIGHT", -4, 0)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetFont(bf, bfs, "OUTLINE")
    f.timeText:SetTextColor(1, 1, 1, 1)

    -- Tooltip support
    f:SetScript("OnEnter", function(self)
        if self.entry then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.entry.spellData.name, 1, 1, 1)
            GameTooltip:AddLine(self.entry.playerName, 0.7, 0.7, 0.7)
            if self.entry.spellData.note then
                GameTooltip:AddLine(self.entry.spellData.note, nil, nil, nil, true)
            end
            local remaining = self.entry.expireTime - GetTime()
            GameTooltip:AddDoubleLine("Ready in:", RAPE.FormatTime(remaining), 0.7, 0.7, 0.7, 1, 0.8, 0.2)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return f
end

-- ============================================================
-- Bar Update
-- ============================================================

--- Update a bar's visual state to match the given CD entry.
-- @param bar   Frame     The bar widget
-- @param entry table     CD entry from RAPE.GetActiveCooldowns()
-- @param width number    Available width for the bar
function RAPE.UpdateBar(bar, entry, width)
    bar.entry = entry

    -- Layout to available width
    bar:SetWidth(width)

    -- Class stripe color
    local r, g, b = RAPE.GetClassColor(entry.playerClass)
    bar.stripe:SetColorTexture(r, g, b, 1)

    -- Spell icon
    local iconID = C_Spell.GetSpellTexture(entry.spellID)
    if iconID then
        bar.icon:SetTexture(iconID)
    else
        bar.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Label: "PlayerName – SpellName"
    bar.label:SetText(entry.playerName .. "  " .. entry.spellData.name)
    -- Apply current font settings
    local bf, bfs = GetBarF(), GetBarFS()
    bar.label:SetFont(bf, bfs, "OUTLINE")
    bar.timeText:SetFont(bf, bfs, "OUTLINE")

    -- Progress and color
    local progress = 1 - (entry.remaining / entry.cooldown)  -- 0=fresh, 1=ready
    progress = math.min(1, math.max(0, progress))

    bar.progress:SetValue(progress)

    local cr, cg, cb = RAPE.GetCooldownColor(progress)
    bar.progress:SetStatusBarColor(cr, cg, cb, 0.7)

    -- Time text
    if entry.remaining <= 0 then
        bar.timeText:SetText("Ready")
    else
        bar.timeText:SetText(RAPE.FormatTime(entry.remaining))
    end
end
