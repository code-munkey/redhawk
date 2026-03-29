-- MonkeyTracker: OptionsPanel.lua
-- Contains the LanternUX main panel for configuration and admin / raid leader features.

function RAPE.BuildMainPanel()
    if RAPE.MainPanel then return end

    -- Create a panel (lazy -- no WoW frames are created until Show is called)
    RAPE.MainPanel = LanternUX:CreatePanel({
          name    = "RAPEMainPanel",
          title   = "Redhawk Advanced Performance Enhancer",
          icon    = "Interface\\Addons\\RAPE\\rape_icon.png",  -- optional title bar icon
          version = RAPE.VERSION,  -- shown in title bar
    })

    local MyDB = RAPE.db or {
        Features = {
            VoidMarkedTracker = {
                enabled = true
            }
        }
    }

    RAPE.MainPanel:AddSidebarGroup("cdTrackerGroup", { label = "Cooldown Tracker" })

    -- Shared button styling function for custom pages out of the box
    local function StyleLanternExecuteBtn(btn)
        if not btn.SetBackdrop and BackdropTemplateMixin then
            Mixin(btn, BackdropTemplateMixin)
        end
        
        if btn.SetBackdrop then
            btn:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            btn:SetBackdropColor(unpack(LanternUX.Theme.buttonBg))
            btn:SetBackdropBorderColor(unpack(LanternUX.Theme.buttonBorder))
        end
        
        btn:SetNormalFontObject(LanternUX.Theme.fontBody)
        local fs = btn:GetFontString()
        if fs then fs:SetTextColor(unpack(LanternUX.Theme.buttonText)) end
        
        btn:SetScript("OnEnter", function()
            if btn.SetBackdropColor then
                btn:SetBackdropColor(unpack(LanternUX.Theme.buttonHover))
                btn:SetBackdropBorderColor(unpack(LanternUX.Theme.inputFocus))
            end
        end)
        btn:SetScript("OnLeave", function()
            if btn.SetBackdropColor then
                btn:SetBackdropColor(unpack(LanternUX.Theme.buttonBg))
                btn:SetBackdropBorderColor(unpack(LanternUX.Theme.buttonBorder))
            end
        end)
    end


    -- ============================================================
    -- Tracker Setup: Spells
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

    RAPE.MainPanel:AddPage("trackerSpells", {
        sidebarGroup = "cdTrackerGroup",
        label = "Spells",
        frame = function(parent)
            local f = CreateFrame("Frame", "RAPE_TrackerSpellsPage", parent)
            f:SetAllPoints()

            local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
            sf:SetPoint("TOPLEFT",     f, "TOPLEFT",     0,   0)
            sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 0)
        
            local child = CreateFrame("Frame", nil, sf)
            child:SetWidth(parent:GetWidth() - 36)
            sf:SetScrollChild(child)

            f.rows = {}

            -- Draw function
            f.UpdateDisplay = function()
                for _, row in ipairs(f.rows) do row:Hide() end
                
                local spells = GetSortedSpells()
                local ROW_H  = 24
                child:SetHeight(#spells * ROW_H + 4)
            
                for i, spell in ipairs(spells) do
                    local capturedID = spell.id
                    local y = -(i - 1) * ROW_H - 2
            
                    local row = f.rows[i]
                    if not row then
                        row = CreateFrame("Frame", nil, child)
                        row:SetHeight(ROW_H)
                        
                        local bg = row:CreateTexture(nil, "BACKGROUND")
                        bg:SetAllPoints()
                        bg:SetColorTexture(1, 1, 1, 0.03)
                        row.bg = bg

                        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                        cb:SetSize(20, 20)
                        cb:SetPoint("LEFT", row, "LEFT", 2, 0)
                        row.cb = cb

                        local icon = row:CreateTexture(nil, "ARTWORK")
                        icon:SetSize(18, 18)
                        icon:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                        row.icon = icon

                        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        lbl:SetPoint("LEFT",  icon, "RIGHT", 4, 0)
                        lbl:SetPoint("RIGHT", row,  "RIGHT", -60, 0)
                        lbl:SetJustifyH("LEFT")
                        row.lbl = lbl

                        local winBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                        StyleLanternExecuteBtn(winBtn)
                        winBtn:SetSize(52, 18)
                        winBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                        row.winBtn = winBtn

                        table.insert(f.rows, row)
                    end

                    row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
                    row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
                    row:Show()

                    row.bg:SetShown(i % 2 == 0)

                    row.cb:SetChecked(not (RAPE.db.disabledSpells[capturedID]))
                    row.cb:SetScript("OnClick", function(self)
                        if self:GetChecked() then
                            RAPE.db.disabledSpells[capturedID] = nil
                        else
                            RAPE.db.disabledSpells[capturedID] = true
                        end
                    end)

                    local tex = C_Spell.GetSpellTexture(spell.id)
                    if tex then row.icon:SetTexture(tex) end

                    local r, g, b = RAPE.GetClassColor(spell.class)
                    row.lbl:SetTextColor(r, g, b, 1)
                    row.lbl:SetText(spell.class .. "  " .. spell.name)

                    local function UpdateWinBtnText()
                        local assigned = "All"
                        for idx, wincfg in ipairs(RAPE.db.windows) do
                            if wincfg.spells[capturedID] then
                                assigned = "W" .. idx
                                break
                            end
                        end
                        row.winBtn:SetText(assigned)
                    end

                    row.winBtn:SetScript("OnClick", function()
                        local currentWin = 0
                        for idx, wincfg in ipairs(RAPE.db.windows) do
                            if wincfg.spells[capturedID] then
                                currentWin = idx
                                break
                            end
                        end
                        for _, wincfg in ipairs(RAPE.db.windows) do
                            wincfg.spells[capturedID] = nil
                        end
                        local nextWin = currentWin + 1
                        if nextWin <= #RAPE.db.windows then
                            RAPE.db.windows[nextWin].spells[capturedID] = true
                        end
                        UpdateWinBtnText()
                    end)
                    row.winBtn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Click to cycle window assignment.\n|cffaaaaaa'All' = show in every window|r")
                        GameTooltip:Show()
                    end)
                    row.winBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

                    UpdateWinBtnText()
                end
            end

            f:SetScript("OnShow", f.UpdateDisplay)
            f.UpdateDisplay()
            return f
        end
    })

    -- ============================================================
    -- Tracker Setup: Windows
    -- ============================================================

    RAPE.MainPanel:AddPage("trackerWindows", {
        sidebarGroup = "cdTrackerGroup",
        label = "Windows",
        frame = function(parent)
            local f = CreateFrame("Frame", "RAPE_TrackerWindowsPage", parent)
            f:SetAllPoints()

            local addBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
            StyleLanternExecuteBtn(addBtn)
            addBtn:SetSize(140, 24)
            addBtn:SetText("+ Add Window")
            addBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
            addBtn:SetScript("OnClick", function()
                RAPE.WM.AddWindow()
                f.UpdateDisplay()
            end)
        
            local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
            sf:SetPoint("TOPLEFT",     f, "TOPLEFT",     0, 0)
            sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 32)
        
            local child = CreateFrame("Frame", nil, sf)
            child:SetWidth(parent:GetWidth() - 36)
            sf:SetScrollChild(child)

            f.rows = {}

            f.UpdateDisplay = function()
                for _, row in ipairs(f.rows) do row:Hide() end
                
                local ROW_H = 30
                child:SetHeight(#RAPE.db.windows * ROW_H + 4)
            
                for i, wincfg in ipairs(RAPE.db.windows) do
                    local capturedI = i
                    local y = -(i - 1) * ROW_H - 2
            
                    local row = f.rows[i]
                    if not row then
                        row = CreateFrame("Frame", nil, child)
                        row:SetHeight(ROW_H)

                        local numLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        numLbl:SetPoint("LEFT", row, "LEFT", 4, 0)
                        numLbl:SetWidth(24)
                        row.numLbl = numLbl

                        local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                        eb:SetPoint("LEFT",  numLbl, "RIGHT", 6, 0)
                        eb:SetPoint("RIGHT", row,    "RIGHT", -80, 0)
                        eb:SetHeight(20)
                        eb:SetAutoFocus(false)
                        row.eb = eb

                        local visBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                        StyleLanternExecuteBtn(visBtn)
                        visBtn:SetSize(50, 20)
                        visBtn:SetPoint("RIGHT", row, "RIGHT", -28, 0)
                        row.visBtn = visBtn

                        local remBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                        StyleLanternExecuteBtn(remBtn)
                        remBtn:SetSize(22, 20)
                        remBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                        remBtn:SetText("✕")
                        row.remBtn = remBtn

                        table.insert(f.rows, row)
                    end

                    row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
                    row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
                    row:Show()

                    row.numLbl:SetText("|cff888888W" .. i .. "|r")

                    row.eb:SetText(wincfg.label or ("Window " .. i))
                    row.eb:SetScript("OnEnterPressed", function(self)
                        wincfg.label = self:GetText()
                        RAPE.WM.UpdateWindowLabel(capturedI)
                        self:ClearFocus()
                    end)
                    row.eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

                    local vis = wincfg.hidden and "Show" or "Hide"
                    row.visBtn:SetText(vis)
                    row.visBtn:SetScript("OnClick", function(self)
                        if RAPE.db.windows[capturedI].hidden then
                            RAPE.WM.ShowWindow(capturedI)
                            self:SetText("Hide")
                        else
                            RAPE.WM.HideWindow(capturedI)
                            self:SetText("Show")
                        end
                    end)

                    if #RAPE.db.windows > 1 then
                        row.remBtn:Show()
                        row.remBtn:SetScript("OnClick", function()
                            RAPE.WM.RemoveWindow(capturedI)
                            f.UpdateDisplay()
                        end)
                    else
                        row.remBtn:Hide()
                    end
                end
            end

            f:SetScript("OnShow", f.UpdateDisplay)
            f.UpdateDisplay()
            return f
        end
    })

    -- ============================================================
    -- Tracker Setup: Appearance
    -- ============================================================

    local fontPaths = {
        "Fonts\\FRIZQT__.TTF",
        "Fonts\\ARIALN.TTF",
        "Fonts\\MORPHEUS.ttf",
        "Fonts\\SKURRI.TTF",
    }
    local fontNames = {
        ["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata",
        ["Fonts\\ARIALN.TTF"] = "Arial Narrow",
        ["Fonts\\MORPHEUS.ttf"] = "Morpheus",
        ["Fonts\\SKURRI.TTF"] = "Skurri",
    }

    RAPE.MainPanel:AddPage("trackerAppearance", {
        sidebarGroup = "cdTrackerGroup",
        label = "Appearance",
        widgets = function()
            return {
                { type = "header", text = "Bar Appearance" },
                {
                    type = "range", label = "Bar Height (px)",
                    min = 16, max = 48, step = 1,
                    get = function() return RAPE.db.barHeight end,
                    set = function(val) RAPE.db.barHeight = val end,
                },
                {
                    type = "select", label = "Font",
                    values = fontNames,
                    sorting = fontPaths,
                    get = function() return RAPE.db.barFont end,
                    set = function(val) RAPE.db.barFont = val end,
                },
                {
                    type = "range", label = "Font Size",
                    min = 8, max = 20, step = 1,
                    get = function() return RAPE.db.barFontSize end,
                    set = function(val) RAPE.db.barFontSize = val end,
                },
                { type = "header", text = "Category Visibility" },
                {
                    type = "toggle", label = "Healing",
                    get = function() return RAPE.db.categoryFilter[RAPE.CATEGORY.HEALING] ~= false end,
                    set = function(val) RAPE.db.categoryFilter[RAPE.CATEGORY.HEALING] = val end,
                },
                {
                    type = "toggle", label = "Defensive",
                    get = function() return RAPE.db.categoryFilter[RAPE.CATEGORY.DEFENSIVE] ~= false end,
                    set = function(val) RAPE.db.categoryFilter[RAPE.CATEGORY.DEFENSIVE] = val end,
                },
                {
                    type = "toggle", label = "Utility",
                    get = function() return RAPE.db.categoryFilter[RAPE.CATEGORY.UTILITY] ~= false end,
                    set = function(val) RAPE.db.categoryFilter[RAPE.CATEGORY.UTILITY] = val end,
                },
                { type = "divider" },
                {
                    type = "execute", label = "Apply Appearance Changes",
                    func = function() RAPE.WM.RebuildAll(); RAPE.Print("Appearance applied.") end,
                    desc = "Applies font and height changes to existing trackers."
                }
            }
        end
    })

    -- ============================================================
    -- Role Assistance
    -- ============================================================
    
    RAPE.MainPanel:AddSidebarGroup("roleAssistanceGroup",{
        label = 'Role Assistance'
    })

    RAPE.MainPanel:AddPage("piAssistance", {
        sidebarGroup = "roleAssistanceGroup",
        label = "PI Assistance",
        widgets = function()
            local wg = {
                { type = "header", text = "PI Assistance Options" },
                {
                    type = "select", label = "Display Mode",
                    values = { [1] = "List Window", [2] = "Raid Frame Glow", [3] = "Both" },
                    get = function() return RAPE.db.piAssistanceMode end,
                    set = function(val) 
                        RAPE.db.piAssistanceMode = val
                        if RAPE.PI then RAPE.PI.CheckActiveDPSCDs() end
                    end,
                },
                { 
                    type = "execute", label = "Toggle List Window",
                    func = function() if RAPE.PIFrame then RAPE.PIFrame.Toggle() end end,
                    desc = "Test or manually toggle the PI Assistance tracking window."
                },
                { type = "divider" },
                { type = "header", text = "Tracked Group Members" },
            }
            
            local sortedRoster = {}
            for name, class in pairs(RAPE.Roster) do table.insert(sortedRoster, {name=name, class=class}) end
            table.sort(sortedRoster, function(a, b) return a.name < b.name end)
            
            if #sortedRoster == 0 then
                table.insert(wg, { 
                    type = "execute", 
                    label = "No group members detected.", 
                    func = function() end,
                    desc = "Join a party or raid to select members to track."
                })
            end
            
            for _, player in ipairs(sortedRoster) do
                local r, g, b = RAPE.GetClassColor(player.class)
                local hex = string.format("FF%02x%02x%02x", r*255, g*255, b*255)
                table.insert(wg, {
                    type = "toggle",
                    label = "|c" .. hex .. player.name .. "|r",
                    get = function() return RAPE.db.piTrackedPlayers and RAPE.db.piTrackedPlayers[player.name] end,
                    set = function(val) 
                        if not RAPE.db.piTrackedPlayers then RAPE.db.piTrackedPlayers = {} end
                        RAPE.db.piTrackedPlayers[player.name] = val
                        if RAPE.PI then RAPE.PI.CheckActiveDPSCDs() end
                    end,
                })
            end
            
            return wg
        end
    })

    -- ============================================================
    -- Admin / General Features
    -- ============================================================

    RAPE.MainPanel:AddSidebarGroup("adminGroup",{
        label = 'Admin & Tools'
    })

    RAPE.MainPanel:AddPage("general", {
          sidebarGroup = "adminGroup",
          label   = "General Tools",
          widgets = function()
             return {
                { type = "header", text = "Feature Toggles" },
                { type = "toggle", label = "Debug Mode",
                   get = function() return RAPE.db.debugMode end,
                   set = function(val)
                       RAPE.db.debugMode = val
                       RAPE.Print("Debug mode:", val and "ON" or "OFF")
                   end,
                   desc = "Toggles debug logging in the chat window.",
                },
                { 
                    type = "toggle", 
                    label = "Void Marked Tracker",
                    get = function() return RAPE.db.windows[1].locked end,  -- Example placeholder using existing db
                    set = function(val) RAPE.db.windows[1].locked = val; RAPE.WM.ApplyLockState(1) end,
                    desc = "Toggles tracking of Void Marked debuff (Placeholder locked window)"
                },
                { type = "divider" },
                { type = "header", text = "Communication Tools" },
                { type = "execute", label = "Request All Spell Lists",
                   func = function() RAPE.RequestSpellLists() end,
                   desc = "Asks all group members to rebroadcast their spell lists.\nUseful if someone's cooldowns aren't showing.",
                },
                { type = "select", label = "Request Target Player",
                   values = function()
                       local tbl = {}
                       for name in pairs(RAPE.Roster) do tbl[name] = name end
                       return tbl
                   end,
                   get = function() return RAPE.ToolsTargetPlayer end,
                   set = function(val) RAPE.ToolsTargetPlayer = val end,
                },
                { type = "execute", label = "Request Refresh",
                   func = function() if RAPE.ToolsTargetPlayer then RAPE.RequestPlayerRefresh(RAPE.ToolsTargetPlayer) end end,
                   disabled = function() return not RAPE.ToolsTargetPlayer end,
                }
             }
          end,
    })

    -- Helpers for Version Control
    local function CompareVersions(v1, v2)
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

    local function GetVersionStatusStr(playerName)
        local ver = RAPE.VersionResponses[playerName]
        if not ver then return "|cff666666Unknown|r" end
        if ver == "NOT_INSTALLED" then return "|cffff4444Not Installed|r" end
        local cmp = CompareVersions(ver, RAPE.VERSION)
        if cmp == 0 then return "|cff00ff00v" .. ver .. "|r" end
        if cmp < 0 then return "|cffffff00v" .. ver .. "|r (Old)" end
        return "|cff00ff00v" .. ver .. "|r"  -- newer is fine
    end
    
    local function GetWhisperMessage(playerName)
        local ver = RAPE.VersionResponses[playerName]
        if ver == "NOT_INSTALLED" or not ver then
            return string.format("Hey! Our raid uses the MonkeyTracker addon for cooldown tracking. Please install it. Current version: v%s", RAPE.VERSION)
        else
            return string.format("Hey! Our raid uses the MonkeyTracker addon for cooldown tracking. Please update yours to the latest version: v%s", RAPE.VERSION)
        end
    end

    -- Add version check page
    RAPE.MainPanel:AddPage("versioncheck", {
        label = "Version Control",
        sidebarGroup = "adminGroup",
        frame = function(parent)
            local f = CreateFrame("Frame", "RAPE_VersionCheckPage", parent)
            f:SetAllPoints()

            -- We need to transform the roster data into an array for the data table
            local function GetRosterDataArray()
                local data = {}
                for name, class in pairs(RAPE.Roster) do
                    table.insert(data, {
                        name = name,
                        class = class,
                        version = RAPE.VersionResponses[name] or "Unknown"
                    })
                end
                return data
            end

            local dt = LanternUX.CreateDataTable(f, {
                columns = {
                    { 
                        key = "class", 
                        label = "Class", 
                        width = 80,
                        format = function(val)
                            local r, g, b = RAPE.GetClassColor(val)
                            local hex = string.format("FF%02x%02x%02x", r*255, g*255, b*255)
                            return string.format("|c%s%s|r", hex, val)
                        end
                    },
                    { 
                        key = "name", 
                        label = "Player", 
                        width = 150,
                        format = function(val, entry)
                            local r, g, b = RAPE.GetClassColor(entry.class)
                            local hex = string.format("FF%02x%02x%02x", r*255, g*255, b*255)
                            return string.format("|c%s%s|r", hex, val)
                        end
                    },
                    { 
                        key = "version", 
                        label = "Version Status", 
                        width = 150,
                        format = function(val, entry)
                            return GetVersionStatusStr(entry.name)
                        end
                    },
                },
                searchPlaceholder = "Search members...",
                pageSize = 20,
                defaultSort = { key = "name", ascending = true }
            })

            -- Position the table
            dt.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
            dt.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 40, 50)
            dt:SetNoDataText("Not in a group or no roster found.")
            dt:SetData(GetRosterDataArray())
            dt:Refresh()

            -- Run Version Check button
            local verBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
            StyleLanternExecuteBtn(verBtn)
            verBtn:SetSize(150, 26)
            verBtn:SetText("Run Version Check")
            verBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 10)
            verBtn:SetScript("OnClick", function()
                RAPE.BroadcastVersionCheck()
            end)

            -- Whisper Missing button
            local whisperAllBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
            StyleLanternExecuteBtn(whisperAllBtn)
            whisperAllBtn:SetSize(180, 26)
            whisperAllBtn:SetText("Whisper All Missing/Old")
            whisperAllBtn:SetPoint("LEFT", verBtn, "RIGHT", 10, 0)
            whisperAllBtn:SetScript("OnClick", function()
                local count = 0
                for name in pairs(RAPE.Roster) do
                    local ver = RAPE.VersionResponses[name]
                    if not ver or ver == "NOT_INSTALLED" or CompareVersions(ver, RAPE.VERSION) < 0 then
                        local msg = GetWhisperMessage(name)
                        SendChatMessage(msg, "WHISPER", nil, name)
                        count = count + 1
                    end
                end
                RAPE.Print(string.format("|cffff8800[Admin]|r Whispered %d player(s).", count))
            end)

            -- Update routine to refresh the table periodically while it's visible
            local elapsed = 0
            f:SetScript("OnUpdate", function(self, elapsedSec)
                elapsed = elapsed + elapsedSec
                if elapsed > 1.0 then
                    elapsed = 0
                    if not dt.frame:IsVisible() then return end
                    dt:SetData(GetRosterDataArray())
                    dt:Refresh()
                end
            end)

            f.dataTable = dt
            return f
        end
    })

end