-- MonkeyTracker: AdminFrame.lua
-- Admin / Raid Leader panel: roster overview, version status, whisper, force settings.

RAPE.AdminFrame = {}
local AF = RAPE.AdminFrame

local PANEL_W, PANEL_H = 580, 460
local ROW_H = 24

-- ============================================================
-- Helpers
-- ============================================================

local function IsRaidLeaderOrAssist()
    if UnitIsGroupLeader("player") then return true end
    if UnitIsGroupAssistant and UnitIsGroupAssistant("player") then return true end
    -- In a party (non-raid), party leader is always the leader
    return false
end

local function CompareVersions(v1, v2)
    -- Returns: 0 if equal, -1 if v1 < v2, 1 if v1 > v2
    if v1 == v2 then return 0 end
    local a1, a2, a3 = v1:match("^(%d+)%.(%d+)%.(%d+)$")
    local b1, b2, b3 = v2:match("^(%d+)%.(%d+)%.(%d+)$")
    if not (a1 and b1) then return 0 end
    a1, a2, a3 = tonumber(a1), tonumber(a2), tonumber(a3)
    b1, b2, b3 = tonumber(b1), tonumber(b2), tonumber(b3)
    if a1 ~= b1 then return a1 < b1 and -1 or 1 end
    if a2 ~= b2 then return a2 < b2 and -1 or 1 end
    if a3 ~= b3 then return a3 < b3 and -1 or 1 end
    return 0
end

local function GetVersionStatus(playerName)
    -- Returns: "current", "outdated", "not_installed", or "unknown"
    local ver = RAPE.VersionResponses[playerName]
    if not ver then return "unknown" end
    if ver == "NOT_INSTALLED" then return "not_installed" end
    local cmp = CompareVersions(ver, RAPE.VERSION)
    if cmp == 0 then return "current" end
    if cmp < 0 then return "outdated" end
    return "current"  -- newer is fine
end

local function GetWhisperMessage(status)
    if status == "not_installed" then
        return string.format("Hey! Our raid uses the R A P E addon for cooldown tracking. Please install it. Current version: v%s", RAPE.VERSION)
    else
        return string.format("Hey! Our raid uses the R A P E addon for cooldown tracking. Please update yours to the latest version: v%s", RAPE.VERSION)
    end
end

-- ============================================================
-- Build the admin panel
-- ============================================================

function AF.Build()
    if AF.panel then return end

    local panel = CreateFrame("Frame", "RAPEAdminPanel", UIParent, "BackdropTemplate")
    AF.panel = panel
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then self:StartMoving() end
    end)
    panel:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

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
    titleBar:SetColorTexture(0.12, 0.08, 0.08, 1)

    local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -6)
    titleText:SetText("|cffff8800Admin Panel|r — " .. RAPE.NAME)

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- Column headers
    local headerY = -32
    local colName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colName:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, headerY)
    colName:SetText("|cffaaaaaaPlayer|r")
    colName:SetWidth(180)
    colName:SetJustifyH("LEFT")

    local colVer = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colVer:SetPoint("TOPLEFT", panel, "TOPLEFT", 200, headerY)
    colVer:SetText("|cffaaaaaaVersion|r")
    colVer:SetWidth(120)
    colVer:SetJustifyH("LEFT")

    local colAct = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colAct:SetPoint("TOPLEFT", panel, "TOPLEFT", 330, headerY)
    colAct:SetText("|cffaaaaaaActions|r")

    -- Divider under headers
    local hDiv = panel:CreateTexture(nil, "BACKGROUND")
    hDiv:SetPoint("TOPLEFT",  panel, "TOPLEFT",  8,  headerY - 14)
    hDiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, headerY - 14)
    hDiv:SetHeight(1)
    hDiv:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Scrollable roster area
    local sf = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",  panel, "TOPLEFT",  6,  headerY - 18)
    sf:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 120)

    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(sf:GetWidth() or (PANEL_W - 40))
    sf:SetScrollChild(child)

    AF.rosterChild = child
    AF.rosterScroll = sf
    AF.rosterRows = {}

    -- ============================================================
    -- Action bar at bottom
    -- ============================================================

    local actionY = 110

    -- Run Version Check button
    local verBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    verBtn:SetSize(160, 26)
    verBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, actionY - 14)
    verBtn:SetText("Run Version Check")
    verBtn:SetScript("OnClick", function()
        RAPE.BroadcastVersionCheck()
    end)
    verBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Broadcast a version check to all group members.\nAfter 5 seconds, non-responders are marked as 'Not Installed'.")
        GameTooltip:Show()
    end)
    verBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Whisper All Missing button
    local whisperAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    whisperAllBtn:SetSize(180, 26)
    whisperAllBtn:SetPoint("LEFT", verBtn, "RIGHT", 8, 0)
    whisperAllBtn:SetText("Whisper All Missing/Old")
    whisperAllBtn:SetScript("OnClick", function()
        local count = 0
        for name in pairs(RAPE.Roster) do
            local status = GetVersionStatus(name)
            if status == "not_installed" or status == "outdated" then
                local msg = GetWhisperMessage(status)
                SendChatMessage(msg, "WHISPER", nil, name)
                count = count + 1
            end
        end
        RAPE.Print(string.format("|cffff8800[Admin]|r Whispered %d player(s).", count))
    end)
    whisperAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Send a whisper to all players who don't have the addon\nor have an outdated version.")
        GameTooltip:Show()
    end)
    whisperAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ============================================================
    -- Force Settings section
    -- ============================================================

    local fsDiv = panel:CreateTexture(nil, "BACKGROUND")
    fsDiv:SetPoint("TOPLEFT",  panel, "BOTTOMLEFT",  8, actionY - 48)
    fsDiv:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", -8, actionY - 48)
    fsDiv:SetHeight(1)
    fsDiv:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    local fsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fsLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, actionY - 64)
    fsLabel:SetText("|cff888888Force Setting Broadcast:|r")

    -- Setting name edit box
    local nameLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 42)
    nameLabel:SetText("Setting:")
    nameLabel:SetWidth(46)

    local nameEB = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    nameEB:SetPoint("LEFT", nameLabel, "RIGHT", 4, 0)
    nameEB:SetSize(140, 20)
    nameEB:SetAutoFocus(false)
    nameEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    AF.settingNameEB = nameEB

    -- Setting value edit box
    local valLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valLabel:SetPoint("LEFT", nameEB, "RIGHT", 10, 0)
    valLabel:SetText("Value:")
    valLabel:SetWidth(36)

    local valEB = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    valEB:SetPoint("LEFT", valLabel, "RIGHT", 4, 0)
    valEB:SetSize(100, 20)
    valEB:SetAutoFocus(false)
    valEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    AF.settingValueEB = valEB

    -- Broadcast Setting button
    local bcastBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    bcastBtn:SetSize(120, 24)
    bcastBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 10)
    bcastBtn:SetText("Broadcast")
    bcastBtn:SetScript("OnClick", function()
        local sName = strtrim(nameEB:GetText() or "")
        local sVal  = strtrim(valEB:GetText() or "")
        if sName == "" then
            RAPE.Print("|cffff4444[Admin]|r Setting name cannot be empty.")
            return
        end
        if sVal == "" then
            RAPE.Print("|cffff4444[Admin]|r Setting value cannot be empty.")
            return
        end
        if not IsInGroup() then
            RAPE.Print("|cffff4444[Admin]|r Not in a group.")
            return
        end
        local payload = sName .. "|" .. sVal
        C_ChatInfo.SendAddonMessage("RAPE_FSET", payload, RAPE.GetMsgChannel())
        RAPE.Print(string.format("|cffff8800[Admin]|r Broadcast forced setting: %s = %s", sName, sVal))
    end)
    bcastBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Broadcast a forced setting to all group members with the addon.\nFormat: setting_name | value")
        GameTooltip:Show()
    end)
    bcastBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Status indicator (checking in progress)
    local statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, actionY - 8)
    statusText:SetJustifyH("RIGHT")
    AF.statusText = statusText

    -- Auto-refresh while visible
    local elapsed = 0
    panel:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 1.0 then
            elapsed = 0
            AF.Refresh()
        end
    end)

    panel:Hide()
end

-- ============================================================
-- Refresh the roster list
-- ============================================================

function AF.Refresh()
    if not AF.panel or not AF.panel:IsShown() then return end

    local child = AF.rosterChild
    if not child then return end

    -- Clear old rows
    for _, row in ipairs(AF.rosterRows or {}) do
        row:Hide()
    end
    AF.rosterRows = {}

    -- Build sorted roster
    local members = {}
    for name, class in pairs(RAPE.Roster) do
        table.insert(members, { name = name, class = class })
    end
    table.sort(members, function(a, b) return a.name < b.name end)

    child:SetHeight(#members * ROW_H + 4)

    for i, m in ipairs(members) do
        local y = -(i - 1) * ROW_H - 2

        local row = CreateFrame("Frame", nil, child)
        row:SetPoint("TOPLEFT",  child, "TOPLEFT",  0, y)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        row:SetHeight(ROW_H)
        table.insert(AF.rosterRows, row)

        -- Alternating background
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end

        -- Player name (class colored)
        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", row, "LEFT", 6, 0)
        nameFS:SetWidth(180)
        nameFS:SetJustifyH("LEFT")
        local r, g, b = RAPE.GetClassColor(m.class)
        nameFS:SetTextColor(r, g, b, 1)
        nameFS:SetText(m.name)

        -- Version display
        local verFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        verFS:SetPoint("LEFT", row, "LEFT", 194, 0)
        verFS:SetWidth(120)
        verFS:SetJustifyH("LEFT")

        local status = GetVersionStatus(m.name)
        local verText = RAPE.VersionResponses[m.name]

        if status == "current" then
            verFS:SetText("|cff00ff00v" .. verText .. "|r")
        elseif status == "outdated" then
            verFS:SetText("|cffffff00v" .. verText .. "|r")
        elseif status == "not_installed" then
            verFS:SetText("|cffff4444Not Installed|r")
        else
            verFS:SetText("|cff666666—|r")
        end

        -- Whisper button
        local wBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        wBtn:SetSize(70, 18)
        wBtn:SetPoint("LEFT", row, "LEFT", 324, 0)
        wBtn:SetText("Whisper")

        local capturedName = m.name
        local capturedStatus = status
        wBtn:SetScript("OnClick", function()
            local msg = GetWhisperMessage(capturedStatus)
            SendChatMessage(msg, "WHISPER", nil, capturedName)
            RAPE.Print(string.format("|cffff8800[Admin]|r Whispered %s.", capturedName))
        end)
        wBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Send a whisper to " .. capturedName .. "\nwith addon install/update instructions.")
            GameTooltip:Show()
        end)
        wBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Dim whisper button if version is current
        if status == "current" then
            wBtn:SetAlpha(0.4)
        end
    end

    -- Update status text
    if RAPE.VersionCheckInProgress then
        AF.statusText:SetText("|cffffff00Checking...|r")
    elseif next(RAPE.VersionResponses) then
        -- Count stats
        local installed, missing, outdated = 0, 0, 0
        for name in pairs(RAPE.Roster) do
            local s = GetVersionStatus(name)
            if s == "current" then installed = installed + 1
            elseif s == "not_installed" then missing = missing + 1
            elseif s == "outdated" then outdated = outdated + 1
            end
        end
        AF.statusText:SetText(string.format("|cff00ff00%d|r ok  |cffff4444%d|r missing  |cffffff00%d|r old", installed, missing, outdated))
    else
        AF.statusText:SetText("|cff666666No check run yet|r")
    end
end

-- ============================================================
-- Toggle
-- ============================================================

function AF.Toggle()
    if not AF.panel then AF.Build() end
    if AF.panel:IsShown() then
        AF.panel:Hide()
    else
        -- Permission check
        if not IsRaidLeaderOrAssist() and IsInRaid() then
            RAPE.Print("|cffff4444[Admin]|r You must be raid leader or assistant to use the admin panel.")
            return
        end
        AF.panel:Show()
        AF.Refresh()
    end
end
