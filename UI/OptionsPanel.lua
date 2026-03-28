-- Create a panel (lazy -- no WoW frames are created until Show is called)
RAPE.MainPanel = LanternUX:CreatePanel({
      name    = "RAPEFrame",  -- global frame name (required, used for ESC-to-close)
      title   = "Redhawk Advanced Performance Enhancer",
      icon    = "Interface\\Addons\\RAPE\\rape_icon.png",  -- optional title bar icon
      version = "1.0",              -- optional, shown in title bar
})

local MyDB = {
    Features = {
        VoidMarkedTracker = {
            enabled = true
        }
    }
}

-- Add a page with widgets
RAPE.MainPanel:AddPage("general", {
      label   = "General",
      widgets = function()
         return {
            { type = "header", text = "Basic Settings" },
            { type = "toggle", label = "Enable Feature",
               get = function() return MyDB.enabled end,
               set = function(val) MyDB.enabled = val end,
               desc = "Toggles the main feature on or off.",
            },
            { type = "range", label = "Speed", min = 1, max = 10, step = 1,
               get = function() return MyDB.speed end,
               set = function(val) MyDB.speed = val end,
            },
            { type = "select", label = "Mode",
               values = { fast = "Fast", slow = "Slow" },
               get = function() return MyDB.mode end,
               set = function(val) MyDB.mode = val end,
            },
         }
      end,
})
RAPE.MainPanel:AddSidebarGroup("adminGroup",{
    label = 'Admin'
})

RAPE.MainPanel:AddPage("features", {
    sidebarGroup = "adminGroup",
    label = "Features",
    widgets = function()
        return {
            { type = "header", text = "Features" },
            { 
                type = "toggle", 
                label = "Void Marked Tracker",
                get = function() return MyDB.Features.VoidMarkedTracker.enabled end,
                set = function(val) MyDB.Features.VoidMarkedTracker.enabled = val end,
                desc = "Toggles tracking of Void Marked debuff"
            }
        }
    end
})
--name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(raidIndex);



RAPE.MainPanel:AddPage("versioncheck", {
    label = "Version Check",
    sidebarGroup = "adminGroup",
    frame = function(parent)
        local f = CreateFrame("Frame", "RAPE_VersionCheckPage", parent)
        f:SetAllPoints()

        local dt = LanternUX.CreateDataTable(f, {
            columns = {
                { key = "class",     label = "Class",     width = 80 },
                { key = "name",      label = "Name", width = 300 },
                { key = "rank",      label = "Rank",      width = 100 },
                { key = "version", label = "Version", width = 200 },
            },
            searchPlaceholder = "Search members...",
            pageSize = 40,
            defaultSort = { key = "class", ascending = true }
        })

        dt.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        dt.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 40, 40)
        dt:SetNoDataText("Not in raid")
        dt:SetData(RAPE.RaidRoster)
        dt:Refresh()

        return f
    end
})

RAPE.MainPanel:Toggle()