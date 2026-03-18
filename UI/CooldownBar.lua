-- MonkeyTracker: CooldownBar.lua
-- Creates and manages individual cooldown row widgets.
-- Each bar represents one active cooldown for one player.

local MT = MonkeyTracker

-- Bar dimensions
local BAR_HEIGHT         = 28
local BAR_WIDTH          = 300  -- default; scales with frame width
local ICON_SIZE          = BAR_HEIGHT
local CLASS_STRIPE_WIDTH = 4
local BAR_PADDING        = 2

-- Pool of reusable bar frames to avoid create/destroy churn
MT.BarPool = {}
MT.ActiveBars = {}

-- ============================================================
-- Bar Widget Factory
-- ============================================================

--- Creates a single cooldown bar frame (or recycles from pool).
-- @param parent Frame
-- @return Frame   The bar widget
function MT.AcquireBar(parent)
    local bar = table.remove(MT.BarPool)
    if not bar then
        bar = MT.CreateBar(parent)
    else
        bar:SetParent(parent)
        bar:Show()
    end
    return bar
end

--- Returns a bar to the pool.
function MT.ReleaseBar(bar)
    bar:Hide()
    bar:ClearAllPoints()
    table.insert(MT.BarPool, bar)
end

--- Construct a new bar frame with all sub-elements.
function MT.CreateBar(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(BAR_HEIGHT)

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
    f.icon:SetSize(ICON_SIZE - 2, ICON_SIZE - 2)
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
    f.label = f.progress:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.label:SetPoint("LEFT",  f.progress, "LEFT",  5, 0)
    f.label:SetPoint("RIGHT", f.progress, "RIGHT", -40, 0)
    f.label:SetJustifyH("LEFT")
    f.label:SetFont(f.label:GetFont(), 11, "OUTLINE")
    f.label:SetTextColor(1, 1, 1, 1)

    -- Time remaining label
    f.timeText = f.progress:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.timeText:SetPoint("RIGHT", f.progress, "RIGHT", -4, 0)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetFont(f.timeText:GetFont(), 11, "OUTLINE")
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
            GameTooltip:AddDoubleLine("Ready in:", MT.FormatTime(remaining), 0.7, 0.7, 0.7, 1, 0.8, 0.2)
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
-- @param entry table     CD entry from MT.GetActiveCooldowns()
-- @param width number    Available width for the bar
function MT.UpdateBar(bar, entry, width)
    bar.entry = entry

    -- Layout to available width
    bar:SetWidth(width)

    -- Class stripe color
    local r, g, b = MT.GetClassColor(entry.playerClass)
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

    -- Progress and color
    local progress = 1 - (entry.remaining / entry.cooldown)  -- 0=fresh, 1=ready
    progress = math.min(1, math.max(0, progress))

    bar.progress:SetValue(progress)

    local cr, cg, cb = MT.GetCooldownColor(progress)
    bar.progress:SetStatusBarColor(cr, cg, cb, 0.7)

    -- Time text
    if entry.remaining <= 0 then
        bar.timeText:SetText("Ready")
    else
        bar.timeText:SetText(MT.FormatTime(entry.remaining))
    end
end
